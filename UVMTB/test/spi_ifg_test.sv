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
        automatic axi_spi_cfg_seq s;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i) 0: ifg = 0; 1: ifg = 4; 2: ifg = 16; endcase

            spi_vif.exp_cs_sck     = 4;
            spi_vif.exp_sck_cs     = 4;
            spi_vif.exp_ifg        = -1;
            spi_vif.exp_sck_speed  = 3;
            spi_vif.timing_check_en = 1;

            repeat (2) begin
                s = axi_spi_cfg_seq::type_id::create("s");
        s.mosi_data_i      = 32'hA5;
        s.ifg_i            = ifg;
        s.start(env.axi_agt.axi_sqr);
        wait_spi_frame_done();
            end
            if (!spi_vif.CS) @(posedge spi_vif.CS);
            spi_vif.timing_check_en = 0;
            `uvm_info(get_name(), $sformatf("IFG=%0d done", ifg), UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass : spi_ifg_test

`endif
