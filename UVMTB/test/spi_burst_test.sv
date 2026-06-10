// spi_burst_test — VPlan 6.1
//   连发 4 帧（0x11/0x22/0x33/0x44），验证背靠背 SPI 传输
//   scoreboard 自动比对 4 笔

`ifndef SPI_BURST_TEST_SV
`define SPI_BURST_TEST_SV

class spi_burst_test extends test_base;
    `uvm_component_utils(spi_burst_test)
    function new(string name = "spi_burst_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        automatic bit [31:0]  data_q[4] = '{32'h11, 32'h22, 32'h33, 32'h44};
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

        foreach (data_q[i]) begin
            seq = axi_spi_cfg_seq::type_id::create($sformatf("frame%0d", i));
            seq.cfg_mosi_data = 1;  seq.mosi_data = data_q[i];
            seq.do_start      = 1;  seq.wait_ns   = 2000;
            seq.start(env.axi_agt.axi_sqr);
        end
        `uvm_info(get_name(), "[6.1] 4-frame burst done", UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_burst_test

`endif
