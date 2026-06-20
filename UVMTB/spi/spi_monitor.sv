class spi_monitor extends uvm_monitor;

    `uvm_component_utils(spi_monitor)

    localparam string SPI_MODE_HDL_PATH = "tb_top.DUT.AXI_SPI_n_regs0.slv_reg2";
    localparam string WORD_LEN_HDL_PATH = "tb_top.DUT.AXI_SPI_n_regs0.slv_reg4";

    spi_config                        spi_cfg;
    axi_config                        axi_cfg;
    virtual spi_interface             vif;
    virtual axi_interface             axi_vif;

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

    task collect_spi();
        bit        cpha;
        bit [31:0] shift_reg;
        bit [1:0]  spi_mode_cfg;
        bit [1:0]  word_len_cfg;
        int        num_bits;
        uvm_hdl_data_t hdl_value;
        spi_seq_item item;

        forever begin
            @(negedge vif.CS);

            if (!uvm_hdl_read(SPI_MODE_HDL_PATH, hdl_value)) begin
                `uvm_error(get_name(), $sformatf("failed to read %s", SPI_MODE_HDL_PATH))
                spi_mode_cfg = 2'd0;
            end else begin
                spi_mode_cfg = hdl_value[1:0];
            end

            if (!uvm_hdl_read(WORD_LEN_HDL_PATH, hdl_value)) begin
                `uvm_error(get_name(), $sformatf("failed to read %s", WORD_LEN_HDL_PATH))
                word_len_cfg = 2'd2;
            end else begin
                word_len_cfg = hdl_value[1:0];
            end

            cpha = spi_mode_cfg[0];
            shift_reg = 32'd0;

            case (word_len_cfg)
                2'd0:    num_bits = 32;
                2'd1:    num_bits = 16;
                2'd2:    num_bits = 8;
                2'd3:    num_bits = 4;
                default: num_bits = 8;
            endcase

            fork : frame
                begin : do_sample
                    repeat (num_bits) begin
                        if (cpha == 1'b0)
                            @(posedge vif.SCLK);
                        else
                            @(negedge vif.SCLK);

                        shift_reg = {shift_reg[30:0], vif.MOSI};
                    end

                    item = spi_seq_item::type_id::create("item");
                    item.spi_data     = shift_reg;
                    item.word_len     = word_len_cfg;
                    item.spi_mode     = spi_mode_cfg;
                    item.capture_time = $realtime;

                    `uvm_info(get_name(), $sformatf("captured: %s", item.convert2string()), UVM_MEDIUM)

                    spi_mtr_port.write(item);
                end
                begin : reset_abort
                    @(negedge axi_vif.ARESETN);
                    `uvm_info(get_name(), "reset mid-frame: discard partial SPI frame", UVM_MEDIUM)
                end
            join_any
            disable frame;
        end
    endtask : collect_spi

endclass : spi_monitor
