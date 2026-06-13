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
        // 任务 1：驱动总线。concurrent_mode=1 时读写分流到独立通道线程并发
        if (axi_cfg.concurrent_mode) get_and_drive_concurrent();
        else                         get_and_drive();
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

    // 并发模式：dispatch 把读/写 item 分流到两条独立通道线程。
    //   写线程串行驱动 AW/W/B，读线程串行驱动 AR/R——两组信号不相交，
    //   故 AR 与 AW 可在同一周期活动，验证 DUT 读写通道互不阻塞、不死锁。
    //   注意：读数据回传(rdata_o)在本模式下不保证（dispatch 提前 item_done），
    //         读仅用于制造 AR 流量并验证读响应；写数据正确性由 scoreboard 比对。
    task get_and_drive_concurrent();
        mailbox #(axi_seq_item) wr_mbx = new();
        mailbox #(axi_seq_item) rd_mbx = new();
        fork
            // 写通道线程：串行消费写队列
            forever begin
                axi_seq_item wit;
                wr_mbx.get(wit);
                drive_write(wit);
            end
            // 读通道线程：串行消费读队列
            forever begin
                axi_seq_item rit;
                rd_mbx.get(rit);
                drive_read(rit);
            end
            // dispatch：取 item 按方向入队，立即 item_done 放行下一笔
            forever begin
                axi_seq_item item;
                seq_item_port.get_next_item(item);
                if (item.write) wr_mbx.put(item);
                else            rd_mbx.put(item);
                seq_item_port.item_done();
            end
        join_none
    endtask : get_and_drive_concurrent

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
