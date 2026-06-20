// spi_cs_sck_test — VPlan 3.1
//   验证 CS↓ 到首个 SCK 沿的延迟（CS_SCK 寄存器）
//   遍历 cs_sck=2/4/8 三档，SVA spi_cs_sck_sva 逐帧检查

`ifndef SPI_CS_SCK_TEST_SV
`define SPI_CS_SCK_TEST_SV

class spi_cs_sck_test extends test_base;
    `uvm_component_utils(spi_cs_sck_test)
    function new(string name = "spi_cs_sck_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic int cs_sck;
        automatic axi_spi_cfg_seq seq;
        phase.raise_objection(this);
        #200;

        for (int i = 0; i < 3; i++) begin
            case (i) 0: cs_sck = 2; 1: cs_sck = 4; 2: cs_sck = 8; endcase

            spi_vif.exp_cs_sck     = cs_sck;
            spi_vif.exp_sck_cs     = 4;
            spi_vif.exp_ifg        = -1;
            spi_vif.exp_sck_speed  = 3;
            spi_vif.timing_check_en = 1;

            seq = axi_spi_cfg_seq::type_id::create("seq");
        seq.cs_sck_i         = cs_sck;
        seq.mosi_data_i      = 32'hA5;
        seq.start(env.axi_agt.axi_sqr);
        wait_spi_frame_done();

            if (!spi_vif.CS) @(posedge spi_vif.CS);
            spi_vif.timing_check_en = 0;
            `uvm_info(get_name(), $sformatf("CS_SCK=%0d done", cs_sck), UVM_LOW)
        end
        phase.drop_objection(this);
    endtask
endclass : spi_cs_sck_test

`endif
