// spi_miso_base_test — MISO 测试公共基类（不注册 factory，不可独立运行）
//   配 8-bit Mode0，设 MISO slave 回送字节，发一帧后读 slv_reg9(0x24) 比对
//   子类只需在 new() 中覆盖 exp_miso

`ifndef SPI_MISO_BASE_SV
`define SPI_MISO_BASE_SV

class spi_miso_base_test extends test_base;

    bit [7:0] exp_miso = 8'h00;

    function new(string name = "spi_miso_base_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    task run_phase(uvm_phase phase);
        virtual spi_interface spi_vif = env_cfg.spi_cfg.vif;
        automatic axi_spi_cfg_seq  cfg;
        automatic axi_read_seq rd;
        phase.raise_objection(this);
        #200;

        spi_vif.miso_tx_data = exp_miso;

        cfg = axi_spi_cfg_seq::type_id::create("cfg");
        cfg.mosi_data_i     = 32'hA5;
        cfg.start(env.axi_agt.axi_sqr);
        wait_spi_done();

        rd = axi_read_seq::type_id::create("rd_miso");
        rd.raddr = 32'h24;
        rd.start(env.axi_agt.axi_sqr);

        if (rd.rdata_o[7:0] === exp_miso)
            `uvm_info(get_name(), $sformatf(
                "[4.x] MISO readback OK: miso_tx=0x%02h, slv_reg9=0x%0h", exp_miso, rd.rdata_o), UVM_LOW)
        else
            `uvm_error(get_name(), $sformatf(
                "[4.x] MISO readback FAIL: expected 0x%02h, slv_reg9=0x%0h", exp_miso, rd.rdata_o))

        phase.drop_objection(this);
    endtask
endclass : spi_miso_base_test

`endif
