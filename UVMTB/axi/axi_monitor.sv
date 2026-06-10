class axi_monitor extends uvm_monitor;

    `uvm_component_utils(axi_monitor);

    axi_config              con_cfg;
    virtual axi_interface   vif;

    uvm_analysis_port#(axi_seq_item) axi_mtr_port;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        axi_mtr_port = new("axi_mtr_port", this);

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", con_cfg))
            `uvm_fatal(get_name(), {"axi_config must be set for: ", get_full_name()})

        vif = con_cfg.vif;
    endfunction : build_phase

    task run_phase(uvm_phase phase);
        super.run_phase(phase);

        fork
            write_monitor();
            read_monitor();
        join_none
    endtask

    task write_monitor();
        forever begin
            axi_seq_item item = axi_seq_item::type_id::create("item");

            @(posedge vif.ACLK);
            wait (vif.AWVALID && vif.AWREADY && vif.WVALID && vif.WREADY);

            item.addr  = vif.AWADDR;
            item.write = 1;
            item.wdata = vif.WDATA;
            item.wstrb = vif.WSTRB;

            @(posedge vif.ACLK);
            wait (vif.BVALID && vif.BREADY);
            item.bresp = vif.BRESP;

            axi_mtr_port.write(item);
        end
    endtask : write_monitor

    task read_monitor();
        forever begin
            axi_seq_item item = axi_seq_item::type_id::create("item");

            @(posedge vif.ACLK);
            wait (vif.ARVALID && vif.ARREADY);

            item.addr  = vif.ARADDR;
            item.write = 0;

            @(posedge vif.ACLK);
            wait (vif.RVALID && vif.RREADY);
            item.rdata = vif.RDATA;
            item.rresp = vif.RRESP;

            axi_mtr_port.write(item);
        end
    endtask : read_monitor

endclass : axi_monitor
