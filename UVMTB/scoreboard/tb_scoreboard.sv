class tb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tb_scoreboard)

    // 寄存器地址
    localparam bit [5:0] SPI_DATA_ADDR    = 6'h20;  // slv_reg8: mosi_data
    localparam bit [5:0] WORD_LEN_ADDR    = 6'h10;  // slv_reg4: word_len
    localparam bit [5:0] SPI_MODE_ADDR    = 6'h08;  // slv_reg2: spi_mode

    // Analysis ports
    `uvm_analysis_imp_decl(_axi)
    `uvm_analysis_imp_decl(_spi)

    uvm_analysis_imp_axi #(axi_seq_item, tb_scoreboard) axi_export;
    uvm_analysis_imp_spi #(spi_seq_item, tb_scoreboard) spi_export;

    // 预测队列：AXI 写 spi_data 时压入期望值，SPI 抓到数据时弹出比对
    bit [31:0] expected_data_q[$];

    // 当前 word_len 配置（跟踪 AXI 写 0x10 的值，默认 8-bit）
    bit [1:0] current_word_len = 2'd2;  // 默认 8-bit

    // Config
    spi_config spi_cfg;
    axi_config axi_cfg;   // 用于监听 ARESETN

    // 统计
    int axi_write_data_count;
    int match_count;
    int mismatch_count;

    function new(string name = "tb_scoreboard", uvm_component parent = null);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);

        axi_export = new("axi_export", this);
        spi_export = new("spi_export", this);
    endfunction : build_phase

    // AXI monitor 每抓到一笔 item 就会调这个函数
    function void write_axi(axi_seq_item item);
        if (!item.write) return;

        // 监听 word_len 寄存器写操作，更新当前配置
        if (item.addr[5:2] == WORD_LEN_ADDR[5:2]) begin
            current_word_len = item.wdata[1:0];
            // 同步到 spi_cfg，让 monitor 下一帧用新的 word_len
            if (spi_cfg != null)
                spi_cfg.word_len = current_word_len;
            `uvm_info("SCB_CFG", $sformatf(
                "word_len updated: %0d (%0d-bit)",
                current_word_len,
                current_word_len == 0 ? 32 :
                current_word_len == 1 ? 16 :
                current_word_len == 2 ? 8  : 4), UVM_MEDIUM)
        end

        // 监听 spi_mode 寄存器写操作，更新当前配置
        if (item.addr[5:2] == SPI_MODE_ADDR[5:2]) begin
            if (spi_cfg != null) begin
                spi_cfg.spi_mode = item.wdata[1:0];
                `uvm_info("SCB_CFG", $sformatf(
                    "spi_mode updated: 2'b%02b (CPOL=%0b, CPHA=%0b)",
                    item.wdata[1:0], item.wdata[1], item.wdata[0]), UVM_MEDIUM)
            end
        end

        // 监听 mosi_data 寄存器写操作，压入期望值
        if (item.addr[5:2] == SPI_DATA_ADDR[5:2]) begin
            bit [31:0] exp_data;
            case (current_word_len)
                2'd0:    exp_data = item.wdata;          // 32-bit
                2'd1:    exp_data = {16'd0, item.wdata[15:0]};  // 16-bit
                2'd2:    exp_data = {24'd0, item.wdata[7:0]};   // 8-bit
                2'd3:    exp_data = {28'd0, item.wdata[3:0]};   // 4-bit
                default: exp_data = {24'd0, item.wdata[7:0]};
            endcase
            expected_data_q.push_back(exp_data);
            axi_write_data_count++;
            `uvm_info("SCB_AXI_WRITE", $sformatf(
                "spi_data write: addr=0x%0h data=0x%0h expected=0x%0h (queue depth=%0d)",
                item.addr, item.wdata, exp_data, expected_data_q.size()), UVM_MEDIUM)
        end
    endfunction : write_axi

    // SPI monitor 每抓到一笔数据就会调这个函数
    function void write_spi(spi_seq_item item);
        bit [31:0] exp;

        if (expected_data_q.size() == 0) begin
            `uvm_error("SCB_UNEXP_SPI", $sformatf(
                "Unexpected SPI data (queue empty): spi_data=0x%0h", item.spi_data))
            return;
        end

        exp = expected_data_q.pop_front();

        if (exp == item.spi_data) begin
            match_count++;
            `uvm_info("SCB_MATCH", $sformatf(
                "PASS: expected 0x%0h == actual 0x%0h (match=%0d)",
                exp, item.spi_data, match_count), UVM_MEDIUM)
        end else begin
            mismatch_count++;
            `uvm_error("SCB_MISMATCH", $sformatf(
                "FAIL: expected 0x%0h != actual 0x%0h (mismatch=%0d)",
                exp, item.spi_data, mismatch_count))
        end
    endfunction : write_spi

    // reset 监听：DUT 复位时被打断的帧作废 —— 清空期望队列并复位 word_len 跟踪，
    // 让参考模型与 DUT 保持一致的复位语义
    task run_phase(uvm_phase phase);
        forever begin
            @(negedge axi_cfg.vif.ARESETN);
            if (expected_data_q.size() != 0) begin
                `uvm_info("SCB_RESET", $sformatf(
                    "reset detected: flushing %0d pending expected entries",
                    expected_data_q.size()), UVM_LOW)
                expected_data_q.delete();
            end
            current_word_len = 2'd2;          // 回到初始默认 8-bit
            if (spi_cfg != null)
                spi_cfg.word_len = current_word_len;
        end
    endtask : run_phase

    function void report_phase(uvm_phase phase);
        string scb_summary_msg;
        super.report_phase(phase);
        scb_summary_msg = $sformatf(
            "\n  AXI spi_data writes : %0d\n  SPI captures        : %0d\n  Matches             : %0d\n  Mismatches          : %0d\n  Pending in queue    : %0d\n",
            axi_write_data_count,
            match_count + mismatch_count,
            match_count,
            mismatch_count,
            expected_data_q.size());
        `uvm_info("SCB_SUMMARY", scb_summary_msg, UVM_LOW)

        if (mismatch_count == 0 && expected_data_q.size() == 0)
            `uvm_info("SCB_PASS", "*** SCOREBOARD PASSED ***", UVM_LOW)
        else
            `uvm_error("SCB_FAIL", "*** SCOREBOARD FAILED ***")
    endfunction : report_phase

endclass : tb_scoreboard
