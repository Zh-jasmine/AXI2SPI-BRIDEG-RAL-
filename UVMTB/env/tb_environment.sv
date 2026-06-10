class tb_environment extends uvm_env;

    `uvm_component_utils(tb_environment)

    environment_config env_cfg;

    axi_agent     axi_agt;
    spi_monitor   spi_mtr;
    tb_scoreboard scb;
    tb_coverage   cov;

    function new(string name = "tb_environment", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        if (!uvm_config_db#(environment_config)::get(this, "", "environment_config", env_cfg))
            `uvm_fatal(get_name(), "environment_config not found in config_db")

        // AXI agent — active, drives AXI bus
        uvm_config_db#(axi_config)::set(this, "axi_agt", "axi_config", env_cfg.axi_cfg);
        axi_agt = axi_agent::type_id::create("axi_agt", this);

        // SPI monitor — passive, monitors SPI output
        // 同时喂 axi_config，让 monitor 能看 ARESETN（reset 时中止当前帧）
        uvm_config_db#(spi_config)::set(this, "spi_mtr", "spi_config", env_cfg.spi_cfg);
        uvm_config_db#(axi_config)::set(this, "spi_mtr", "axi_config", env_cfg.axi_cfg);
        spi_mtr = spi_monitor::type_id::create("spi_mtr", this);

        // Scoreboard（axi_cfg 用于监听 ARESETN，reset 时 flush 期望队列）
        scb = tb_scoreboard::type_id::create("scb", this);
        scb.spi_cfg = env_cfg.spi_cfg;
        scb.axi_cfg = env_cfg.axi_cfg;

        // Functional coverage collector
        cov = tb_coverage::type_id::create("cov", this);
    endfunction : build_phase

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);

        // AXI monitor → scoreboard
        axi_agt.axi_mtr_port.connect(scb.axi_export);

        // SPI monitor → scoreboard
        spi_mtr.spi_mtr_port.connect(scb.spi_export);

        // monitors → coverage（analysis port 一对多）
        axi_agt.axi_mtr_port.connect(cov.axi_export);
        spi_mtr.spi_mtr_port.connect(cov.spi_export);
    endfunction : connect_phase

endclass : tb_environment
