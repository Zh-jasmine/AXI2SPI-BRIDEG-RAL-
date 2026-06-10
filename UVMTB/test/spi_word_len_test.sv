// spi_word_len_test — VPlan 1
//   验证 SPI 字长配置：8b / 16b / 32b / 4b 四种 word_len 下
//   MOSI 输出数据与 AXI 写入一致（scoreboard 比对）

class spi_word_len_test extends test_base;

    `uvm_component_utils(spi_word_len_test)

    function new(string name = "spi_word_len_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;

        foreach_word_len(2'b10, 32'hAB,       20000);   // 8-bit
        foreach_word_len(2'b01, 32'h1234,     40000);   // 16-bit
        foreach_word_len(2'b00, 32'h89ABCDEF, 80000);   // 32-bit
        foreach_word_len(2'b11, 32'hA,        10000);   // 4-bit

        phase.drop_objection(this);
    endtask : run_phase

    local task automatic foreach_word_len(
        input bit [1:0]  word_len_enc,
        input bit [31:0] wdata,
        input int        wait_ns
    );
        axi_spi_cfg_seq seq = axi_spi_cfg_seq::type_id::create("seq");

        seq.cfg_word_len  = 1;
        seq.word_len_enc  = word_len_enc;
        seq.cfg_mosi_data = 1;
        seq.mosi_data     = wdata;
        seq.cfg_cs_sck    = 1;
        seq.cs_sck        = 8'h4;
        seq.do_start      = 1;
        seq.wait_ns       = wait_ns;

        seq.start(env.axi_agt.axi_sqr);
    endtask : foreach_word_len

endclass : spi_word_len_test
