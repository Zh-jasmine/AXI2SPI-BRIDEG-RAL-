class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    spi_config                        spi_cfg;
    axi_config                        axi_cfg;
    virtual spi_interface             vif;
    virtual axi_interface             axi_vif;   // 仅用于监听 ARESETN

    uvm_analysis_port #(spi_seq_item) spi_mtr_port;

    function new(string name = "spi_monitor", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        spi_mtr_port = new("spi_mtr_port", this);

        if (!uvm_config_db #(spi_config)::get(this, "", "spi_config", spi_cfg))
            `uvm_fatal(get_name(), "spi_config not found in config_db")
        if (!uvm_config_db #(axi_config)::get(this, "", "axi_config", axi_cfg))
            `uvm_fatal(get_name(), "axi_config not found in config_db")

        vif     = spi_cfg.vif;
        axi_vif = axi_cfg.vif;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        fork
            collect_spi();
        join_none
    endtask : run_phase

    // ---- 核心：被动采集 SPI 数据 ----
    task collect_spi();
        bit        cpol;
        bit        cpha;
        bit [31:0] shift_reg;
        int        num_bits;
        spi_seq_item item;

        forever begin
            // 等 CS 拉低（开始一帧 SPI 传输）
            @(negedge vif.CS);

            cpol  = spi_cfg.spi_mode[1];
            cpha  = spi_cfg.spi_mode[0];
            shift_reg = 32'd0;

            // 根据 word_len 配置决定采多少个 bit
            case (spi_cfg.word_len)
                2'd0:    num_bits = 32;
                2'd1:    num_bits = 16;
                2'd2:    num_bits = 8;
                2'd3:    num_bits = 4;
                default: num_bits = 8;
            endcase

            // 采样与 reset 监听并行：reset 一来就中止当前帧（不上报残缺数据），
            // 回到 forever 顶部重新等下一个 CS。其他 test 不复位，ARESETN 全程为高，
            // reset_abort 分支永不触发，行为与改前逐位一致。
            fork : frame
                begin : do_sample
                    repeat (num_bits) begin
                        // CPHA=0 → 上升沿采样，CPHA=1 → 下降沿采样
                        if (cpha == 1'b0)
                            @(posedge vif.SCLK);
                        else
                            @(negedge vif.SCLK);

                        shift_reg = {shift_reg[30:0], vif.MOSI};
                    end

                    // 整帧采完才打包发出
                    item = spi_seq_item::type_id::create("item");
                    item.spi_data     = shift_reg;
                    item.word_len     = spi_cfg.word_len;
                    item.spi_mode     = spi_cfg.spi_mode;
                    item.capture_time = $realtime;

                    `uvm_info(get_name(), $sformatf("captured: %s", item.convert2string()), UVM_MEDIUM)

                    spi_mtr_port.write(item);
                end
                begin : reset_abort
                    @(negedge axi_vif.ARESETN);
                    `uvm_info(get_name(), "reset mid-frame: discard partial SPI frame", UVM_MEDIUM)
                end
            join_any
            disable frame;   // 杀掉未完成的分支（正常帧杀 reset_abort；reset 杀 do_sample）
        end
    endtask : collect_spi

endclass : spi_monitor
