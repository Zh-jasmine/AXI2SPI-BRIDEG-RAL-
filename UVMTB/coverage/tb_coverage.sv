
`ifndef TB_COVERAGE_SV
`define TB_COVERAGE_SV

`uvm_analysis_imp_decl(_cov_axi)
`uvm_analysis_imp_decl(_cov_spi)

class tb_coverage extends uvm_component;

    `uvm_component_utils(tb_coverage)

    uvm_analysis_imp_cov_axi #(axi_seq_item, tb_coverage) axi_export;
    uvm_analysis_imp_cov_spi #(spi_seq_item, tb_coverage) spi_export;

    bit [1:0] cur_sck_speed = 2'd0;              // 从 AXI 写跟踪当前 sck_speed

    // covergroup 采样用的临时变量
    bit [1:0]  s_mode, s_wlen, s_speed;
    bit [31:0] s_data;

    covergroup cg_spi_frame;
        option.per_instance = 1;

        cp_mode:  coverpoint s_mode  { bins mode0={0}; bins mode1={1};
                                       bins mode2={2}; bins mode3={3}; }
        cp_wlen:  coverpoint s_wlen  { bins w32={0}; bins w16={1};
                                       bins w8={2};  bins w4={3}; }
        cp_speed: coverpoint s_speed { bins d128={0}; bins d64={1};
                                       bins d32={2};  bins d16={3}; }
        cp_data:  coverpoint s_data  { bins zero={0}; bins nonzero={[1:$]}; }

        // 完备性核心：每种 mode 配每种 word_len 是否都测到（16 格）
        x_mode_wlen:  cross cp_mode, cp_wlen;
        // 每种 mode 配每档 SCK 速度（16 格）
        x_mode_speed: cross cp_mode, cp_speed;
    endgroup

    function new(string name="tb_coverage", uvm_component parent=null);
        super.new(name, parent);
        cg_spi_frame = new();
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        axi_export = new("axi_export", this);
        spi_export = new("spi_export", this);
    endfunction

    // AXI 写 slv_reg3 (0x0C) → 更新当前 sck_speed
    function void write_cov_axi(axi_seq_item item);
        if (item.write && item.addr[5:2] == 4'h3)   // 4'h3 = 0x0C>>2 = slv_reg3
            cur_sck_speed = item.wdata[1:0];
    endfunction

    // 每笔实际 SPI 传输 → 采样 covergroup
    function void write_cov_spi(spi_seq_item item);
        s_mode  = item.spi_mode;
        s_wlen  = item.word_len;
        s_speed = cur_sck_speed;
        s_data  = item.spi_data;
        cg_spi_frame.sample();
    endfunction

    function void report_phase(uvm_phase phase);
        `uvm_info("COV", $sformatf("functional coverage = %0.2f%%",
            cg_spi_frame.get_inst_coverage()), UVM_LOW)
    endfunction

endclass

`endif // TB_COVERAGE_SV
