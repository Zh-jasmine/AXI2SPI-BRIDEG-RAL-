// spi_mode_test — VPlan 2
//   验证 SPI Mode 0/1/2/3（CPOL×CPHA 四种组合）
//   8-bit 字长下逐 mode 发一帧，scoreboard 比对 MOSI 数据

class spi_mode_test extends test_base;

    `uvm_component_utils(spi_mode_test)

    function new(string name = "spi_mode_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);
        #200;

        cfg_word_len_only(2'b10);

        for (int m = 0; m < 4; m++) begin
            run_spi_mode(m[1:0], 32'hAB, 20000);
        end

        phase.drop_objection(this);
    endtask : run_phase

    local task automatic cfg_word_len_only(input bit [1:0] enc);
        axi_spi_cfg_seq seq = axi_spi_cfg_seq::type_id::create("cfg_wl");
        seq.cfg_word_len = 1;
        seq.word_len_enc = enc;
        seq.start(env.axi_agt.axi_sqr);
    endtask : cfg_word_len_only

    local task automatic run_spi_mode(
        input bit [1:0]  mode_enc,
        input bit [31:0] mosi_data,
        input int        wait_ns
    );
        axi_spi_cfg_seq seq = axi_spi_cfg_seq::type_id::create("seq");

        seq.cfg_spi_mode  = 1;
        seq.spi_mode_enc  = mode_enc;
        seq.cfg_mosi_data = 1;
        seq.mosi_data     = mosi_data;
        seq.cfg_cs_sck    = 1;
        seq.cs_sck        = 8'h4;
        seq.do_start      = 1;
        seq.wait_ns       = wait_ns;

        seq.start(env.axi_agt.axi_sqr);
    endtask : run_spi_mode

endclass : spi_mode_test
