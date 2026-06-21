class tb_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(tb_scoreboard)

    localparam bit [5:0] SPI_DATA_ADDR     = 6'h20;
    localparam string    WORD_LEN_HDL_PATH = "tb_top.DUT.AXI_SPI_n_regs0.slv_reg4";

    `uvm_analysis_imp_decl(_axi)
    `uvm_analysis_imp_decl(_spi)

    uvm_analysis_imp_axi #(axi_seq_item, tb_scoreboard) axi_export;
    uvm_analysis_imp_spi #(spi_seq_item, tb_scoreboard) spi_export;

    bit [31:0] expected_data_q[$];
    axi_config axi_cfg;

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

        if (!uvm_config_db#(axi_config)::get(this, "", "axi_config", axi_cfg)) begin
            `uvm_fatal(get_name(), "axi_config not found in config_db")
        end
    endfunction : build_phase

    function void write_axi(axi_seq_item item);
        uvm_hdl_data_t val;
        bit [1:0]      word_len;
        bit [31:0]     exp_data;

        if (!item.write)
            return;

        if (item.addr[5:2] != SPI_DATA_ADDR[5:2])
            return;

        if (!uvm_hdl_read(WORD_LEN_HDL_PATH, val)) begin
            `uvm_error("SCB", "read slv_reg4 failed")
            word_len = 2'd2;
        end else begin
            word_len = val[1:0];
        end

        case (word_len)
            2'd0:    exp_data = item.wdata;
            2'd1:    exp_data = {16'd0, item.wdata[15:0]};
            2'd2:    exp_data = {24'd0, item.wdata[7:0]};
            2'd3:    exp_data = {28'd0, item.wdata[3:0]};
            default: exp_data = {24'd0, item.wdata[7:0]};
        endcase

        expected_data_q.push_back(exp_data);
        axi_write_data_count++;
    endfunction : write_axi

    function void write_spi(spi_seq_item item);
        bit [31:0] exp_data;

        if (expected_data_q.size() == 0) begin
            `uvm_error("SCB_UNEXP_SPI", $sformatf(
                "Unexpected SPI data (queue empty): spi_data=0x%0h", item.spi_data))
            return;
        end

        exp_data = expected_data_q.pop_front();

        if (exp_data == item.spi_data) begin
            match_count++;
            `uvm_info("SCB_MATCH", $sformatf(
                "PASS: expected 0x%0h == actual 0x%0h (match=%0d)",
                exp_data, item.spi_data, match_count), UVM_MEDIUM)
        end else begin
            mismatch_count++;
            `uvm_error("SCB_MISMATCH", $sformatf(
                "FAIL: expected 0x%0h != actual 0x%0h (mismatch=%0d)",
                exp_data, item.spi_data, mismatch_count))
        end
    endfunction : write_spi

    task run_phase(uvm_phase phase);
        forever begin
            @(negedge axi_cfg.vif.ARESETN);
            expected_data_q.delete();
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