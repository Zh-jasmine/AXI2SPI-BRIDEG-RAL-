// spi_sck_cs_test — VPlan 3.2
//   验证最后 SCK 沿到 CS↑ 释放的延迟（SCK_CS 寄存器）
//   遍历 sck_cs=2/4/8 三档，SVA spi_sck_cs_sva 逐帧检查

`ifndef SPI_SCK_CS_TEST_SV
`define SPI_SCK_CS_TEST_SV

class spi_sck_cs_test extends test_base;
    `uvm_component_utils(spi_sck_cs_test)
    function new(string name = "spi_sck_cs_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic int sck_cs;
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i) 0: sck_cs = 2; 1: sck_cs = 4; 2: sck_cs = 8; endcase

            spi_vif.exp_cs_sck     = 4;
            spi_vif.exp_sck_cs     = sck_cs;
            spi_vif.exp_ifg        = -1;
            spi_vif.exp_sck_speed  = 3;
            spi_vif.timing_check_en = 1;

            seq = axi_spi_cfg_seq::type_id::create("seq");
        seq.sck_cs_i         = sck_cs;
        seq.mosi_data_i      = 32'h5A;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_frame_done();

            if (!spi_vif.CS) @(posedge spi_vif.CS);
            spi_vif.timing_check_en = 0;
            `uvm_info(get_name(), $sformatf("SCK_CS=%0d done", sck_cs), UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass : spi_sck_cs_test

`endif
