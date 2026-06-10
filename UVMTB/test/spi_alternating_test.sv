// spi_alternating_test — VPlan 6.2
//   交替发 0x55/0xAA 共 6 帧，验证相邻位翻转不串扰
//   scoreboard 比对每帧

`ifndef SPI_ALTERNATING_TEST_SV
`define SPI_ALTERNATING_TEST_SV

class spi_alternating_test extends test_base;
    `uvm_component_utils(spi_alternating_test)
    function new(string name = "spi_alternating_test", uvm_component parent = null);
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
        seq.start(env.axi_agt.axi_sqr);

        for (int i = 0; i < 6; i++) begin
            seq = axi_spi_cfg_seq::type_id::create($sformatf("alt%0d", i));
            seq.cfg_mosi_data = 1;  seq.mosi_data = (i % 2) ? 32'hAA : 32'h55;
            seq.do_start      = 1;  seq.wait_ns   = 2000;
            seq.start(env.axi_agt.axi_sqr);
        end
        `uvm_info(get_name(), "[6.2] alternating 0x55/0xAA done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_alternating_test

`endif
