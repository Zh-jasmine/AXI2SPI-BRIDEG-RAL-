class axi_driver extends uvm_driver #(axi_seq_item);

    `uvm_component_utils(axi_driver)

    axi_config axi_cfg;
    virtual axi_interface vif;

    function new(string name, uvm_component parent);
        super.new(name,parent);
    endfunction

    //build phase
    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(axi_config)::get(this,"","axi_config",axi_cfg)) begin
            `uvm_fatal(get_name(),{"axi_config must be set by",get_full_name()})
        end
        vif=axi_cfg.vif;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        fork
        get_and_drive();// 任务 1：从 sequencer 拿 item，驱动总线
        reset_signals();// 任务 2：监视复位，复位时清除所有 VALID 信号

        join_none
    endtask : run_phase

    //流程
    task get_and_drive ();
        forever begin
            axi_seq_item item;
            seq_item_port.get_next_item(item);

            if (item.write)
                drive_write(item);
            else
                drive_read(item);

            seq_item_port.item_done();
        end
    endtask : get_and_drive

    task drive_write(axi_seq_item item);
        // AW 和 W 通道支持三种时序：
        //   aw_delay == w_delay  → 同时到达（默认，兼容旧行为）
        //   aw_delay < w_delay   → AW 先到
        //   aw_delay > w_delay   → W 先到
        fork
            begin // AW 通道
                repeat (item.aw_delay) @(posedge vif.ACLK);
                vif.AWADDR  <= item.addr;
                vif.AWVALID <= 1'b1;
                @(posedge vif.ACLK);
                while (!vif.AWREADY)
                    @(posedge vif.ACLK);
                vif.AWVALID <= 1'b0;
            end
            begin // W 通道
                repeat (item.w_delay) @(posedge vif.ACLK);
                vif.WDATA  <= item.wdata;
                vif.WSTRB  <= item.wstrb;
                vif.WVALID <= 1'b1;
                @(posedge vif.ACLK);
                while (!vif.WREADY)
                    @(posedge vif.ACLK);
                vif.WVALID <= 1'b0;
            end
        join

        // B 通道
        vif.BREADY <= 1'b1;
        @(posedge vif.ACLK);
        while (!vif.BVALID)
            @(posedge vif.ACLK);
        item.bresp = vif.BRESP;
        vif.BREADY <= 1'b0;
    endtask

    task drive_read(axi_seq_item item);
        //AR通道
        vif.ARADDR  <= item.addr;
        vif.ARVALID <= 1'b1;
        @(posedge vif.ACLK);
        while (!vif.ARREADY)
            @(posedge vif.ACLK);
        vif.ARVALID <= 1'b0;

        //R通道
        vif.RREADY <= 1'b1;
        @(posedge vif.ACLK);
        while (!vif.RVALID)
            @(posedge vif.ACLK);
        item.rdata = vif.RDATA;
        item.rresp = vif.RRESP;
        vif.RREADY <= 1'b0;
    endtask : drive_read

    task reset_signals();
        forever begin
            @(negedge vif.ARESETN);
            vif.AWVALID <= 1'b0;
            vif.WVALID  <= 1'b0;
            vif.BREADY  <= 1'b0;
            vif.ARVALID <= 1'b0;
            vif.RREADY  <= 1'b0;
        end
    endtask : reset_signals

endclass
