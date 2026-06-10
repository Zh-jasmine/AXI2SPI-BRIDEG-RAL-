// spi_data_all_0_test — VPlan 7.1
//   全 0 数据（0x00），验证 MOSI 全低、SCK 正常脉冲、scoreboard 匹配

`ifndef SPI_DATA_ALL_0_TEST_SV
`define SPI_DATA_ALL_0_TEST_SV

class spi_data_all_0_test extends test_base;
    `uvm_component_utils(spi_data_all_0_test)
    function new(string name = "spi_data_all_0_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        seq = axi_spi_cfg_seq::type_id::create("cfg");
        seq.cfg_word_len  = 1;  seq.word_len_enc  = 2'b10;
        seq.cfg_spi_mode  = 1;  seq.spi_mode_enc  = 2'b00;
        seq.cfg_sck_speed = 1;  seq.sck_speed_enc = 2'b11;
        seq.cfg_cs_sck    = 1;  seq.cs_sck        = 8'h4;
        seq.cfg_sck_cs    = 1;  seq.sck_cs        = 8'h4;
        seq.cfg_ifg       = 1;  seq.ifg           = 8'h4;
        seq.cfg_mosi_data = 1;  seq.mosi_data     = 32'h00;
        seq.do_start      = 1;  seq.wait_ns       = 20000;
        seq.start(env.axi_agt.axi_sqr);

        `uvm_info(get_name(), "[7.1] data=0x00 done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_data_all_0_test

`endif
