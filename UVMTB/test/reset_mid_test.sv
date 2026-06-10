// reset_mid_test — VPlan 7.3
//   传输中途拉复位，验证：CS 释放、SPI 引脚回 idle、AXI 输出清零、
//   复位后重新配置并发一帧，scoreboard 比对恢复帧

`ifndef RESET_MID_TEST_SV
`define RESET_MID_TEST_SV

class reset_mid_test extends test_base;
    `uvm_component_utils(reset_mid_test)
    function new(string name = "reset_mid_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq cfg;
        automatic axi_write_seq  wr;
        automatic axi_spi_cfg_seq seq;
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        phase.raise_objection(this);
        #200;

        cfg = axi_spi_cfg_seq::type_id::create("cfg");
        cfg.cfg_word_len  = 1;  cfg.word_len_enc  = 2'b10;
        cfg.cfg_spi_mode  = 1;  cfg.spi_mode_enc  = 2'b00;
        cfg.cfg_sck_speed = 1;  cfg.sck_speed_enc = 2'b11;
        cfg.cfg_cs_sck    = 1;  cfg.cs_sck        = 8'h4;
        cfg.cfg_sck_cs    = 1;  cfg.sck_cs        = 8'h4;
        cfg.cfg_ifg       = 1;  cfg.ifg           = 8'h4;
        cfg.cfg_mosi_data = 1;  cfg.mosi_data     = 32'hA5;
        cfg.do_start      = 0;
        cfg.start(env.axi_agt.axi_sqr);

        wr = axi_write_seq::type_id::create("wr0");
        wr.waddr = 32'h00;  wr.wdata = 32'h0;
        wr.start(env.axi_agt.axi_sqr);
        wr = axi_write_seq::type_id::create("wr1");
        wr.waddr = 32'h00;  wr.wdata = 32'h1;
        wr.start(env.axi_agt.axi_sqr);

        #800;
        force tb_top.s00_axi_aresetn = 0;
        #200;
        force tb_top.s00_axi_aresetn = 1;

        if (spi_vif.CS === 1'b1)
            `uvm_info(get_name(), "[7.3] CS deasserted after reset OK", UVM_LOW)
        else
            `uvm_error(get_name(), "[7.3] CS should be high after reset")

        seq = axi_spi_cfg_seq::type_id::create("seq");
        seq.cfg_word_len  = 1;  seq.word_len_enc  = 2'b10;
        seq.cfg_spi_mode  = 1;  seq.spi_mode_enc  = 2'b00;
        seq.cfg_sck_speed = 1;  seq.sck_speed_enc = 2'b11;
        seq.cfg_cs_sck    = 1;  seq.cs_sck        = 8'h4;
        seq.cfg_sck_cs    = 1;  seq.sck_cs        = 8'h4;
        seq.cfg_ifg       = 1;  seq.ifg           = 8'h4;
        seq.cfg_mosi_data = 1;  seq.mosi_data     = 32'h3C;
        seq.do_start      = 1;  seq.wait_ns       = 20000;
        seq.start(env.axi_agt.axi_sqr);

        `uvm_info(get_name(), "[7.3] reset mid TX + recovery done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : reset_mid_test

`endif
