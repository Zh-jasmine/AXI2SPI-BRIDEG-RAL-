// spi_ifg_test — VPlan 3.3
//   验证帧间隔 IFG（inter-frame gap）
//   遍历 ifg=0/4/16，每档连发 2 帧观察间隔

`ifndef SPI_IFG_TEST_SV
`define SPI_IFG_TEST_SV

class spi_ifg_test extends test_base;
    `uvm_component_utils(spi_ifg_test)
    function new(string name = "spi_ifg_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic int ifg;
        automatic axi_spi_cfg_seq cfg;
        automatic axi_spi_cfg_seq s;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i) 0: ifg = 0; 1: ifg = 4; 2: ifg = 16; endcase

            cfg = axi_spi_cfg_seq::type_id::create("cfg");
            cfg.cfg_word_len   = 1;  cfg.word_len_enc   = 2'b10;
            cfg.cfg_spi_mode   = 1;  cfg.spi_mode_enc   = 2'b00;
            cfg.cfg_sck_speed  = 1;  cfg.sck_speed_enc  = 2'b11;
            cfg.cfg_cs_sck     = 1;  cfg.cs_sck         = 8'h4;
            cfg.cfg_sck_cs     = 1;  cfg.sck_cs         = 8'h4;
            cfg.cfg_ifg        = 1;  cfg.ifg            = ifg;
            cfg.start(env.axi_agt.axi_sqr);

            spi_vif.exp_cs_sck     = 4;
            spi_vif.exp_sck_cs     = 4;
            spi_vif.exp_ifg        = -1;
            spi_vif.exp_sck_speed  = 3;
            spi_vif.timing_check_en = 1;

            repeat (2) begin
                s = axi_spi_cfg_seq::type_id::create("s");
                s.cfg_mosi_data  = 1;  s.mosi_data      = 32'hA5;
                s.do_start       = 1;  s.wait_ns        = 30000;
                s.start(env.axi_agt.axi_sqr);
            end
            if (!spi_vif.CS) @(posedge spi_vif.CS);
            spi_vif.timing_check_en = 0;
            `uvm_info(get_name(), $sformatf("IFG=%0d done", ifg), UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass : spi_ifg_test

`endif
