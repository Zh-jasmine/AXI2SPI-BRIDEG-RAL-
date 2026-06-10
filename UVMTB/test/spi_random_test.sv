// spi_random_test — VPlan 6.x
//   80 帧约束随机回归：mode × word_len × sck_speed × data 随机组合
//   scoreboard 逐帧比对，coverage 累积填满 cross bins

`ifndef SPI_RANDOM_TEST_SV
`define SPI_RANDOM_TEST_SV

class spi_random_test extends test_base;
    `uvm_component_utils(spi_random_test)

    int num_frames = 80;

    function new(string name = "spi_random_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < num_frames; i++) begin
            seq = axi_spi_cfg_seq::type_id::create($sformatf("rand%0d", i));
            seq.cfg_word_len  = 1;
            seq.cfg_spi_mode  = 1;
            seq.cfg_sck_speed = 1;
            seq.cfg_cs_sck    = 1;
            seq.cfg_sck_cs    = 1;
            seq.cfg_ifg       = 1;
            seq.cfg_mosi_data = 1;
            seq.do_start      = 1;

            if (!seq.randomize() with {
                cs_sck inside {[2:8]};
                sck_cs inside {[2:8]};
                ifg    inside {[1:8]};
            })
                `uvm_error(get_name(), "axi_spi_cfg_seq randomize failed")

            seq.wait_ns = 60000;
            seq.start(env.axi_agt.axi_sqr);
        end

        `uvm_info(get_name(), $sformatf("random regression done: %0d frames", num_frames), UVM_LOW)
        phase.drop_objection(this);
    endtask
endclass : spi_random_test

`endif
