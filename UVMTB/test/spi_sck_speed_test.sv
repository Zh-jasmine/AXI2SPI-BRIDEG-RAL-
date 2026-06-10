// spi_sck_speed_test — VPlan 3.4
//   验证 SCK 分频：speed=0(/128) / 1(/64) / 2(/32) / 3(/16)
//   SVA spi_sck_speed_sva 逐帧检查 SCK 周期

`ifndef SPI_SCK_SPEED_TEST_SV
`define SPI_SCK_SPEED_TEST_SV

class spi_sck_speed_test extends test_base;
    `uvm_component_utils(spi_sck_speed_test)
    function new(string name = "spi_sck_speed_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        for (int speed = 0; speed < 4; speed++) begin

            spi_vif.exp_cs_sck     = 4;
            spi_vif.exp_sck_cs     = 4;
            spi_vif.exp_ifg        = -1;
            spi_vif.exp_sck_speed  = speed;
            spi_vif.timing_check_en = 1;

            seq = axi_spi_cfg_seq::type_id::create("seq");
            seq.cfg_word_len   = 1;  seq.word_len_enc   = 2'b10;
            seq.cfg_spi_mode   = 1;  seq.spi_mode_enc   = 2'b00;
            seq.cfg_sck_speed  = 1;  seq.sck_speed_enc  = speed;
            seq.cfg_cs_sck     = 1;  seq.cs_sck         = 8'h4;
            seq.cfg_sck_cs     = 1;  seq.sck_cs         = 8'h4;
            seq.cfg_ifg        = 1;  seq.ifg            = 8'h4;
            seq.cfg_mosi_data  = 1;  seq.mosi_data      = 32'hAA;
            seq.do_start       = 1;  seq.wait_ns        = 2000;
            seq.start(env.axi_agt.axi_sqr);

            if (!spi_vif.CS) @(posedge spi_vif.CS);
            spi_vif.timing_check_en = 0;
            `uvm_info(get_name(), $sformatf("SCK speed=%0d done", speed), UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass : spi_sck_speed_test

`endif
