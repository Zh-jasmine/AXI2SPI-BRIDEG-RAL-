// ============================================================
// tb_top.sv — UVM 顶层 + SVA 多例化
// ============================================================

`timescale 1ns / 1ps

import uvm_pkg::*;
`include "uvm_macros.svh"

// AXI agent files
`include "axi/axi_seq_item.sv"
`include "axi/axi_interface.sv"
`include "axi/axi_config.sv"
`include "axi/axi_sequencer.sv"
`include "axi/axi_driver.sv"
`include "axi/axi_monitor.sv"
`include "axi/axi_agent.sv"
`include "axi/axi_sequence_lib.sv"

// SPI agent files (passive)
`include "spi/spi_seq_item.sv"
`include "spi/spi_interface.sv"
`include "spi/spi_config.sv"
`include "spi/spi_monitor.sv"

// SVA checkers
`include "spi/spi_cs_sck_sva.sv"
`include "spi/spi_sck_speed_sva.sv"
`include "spi/spi_sck_cs_sva.sv"
`include "spi/spi_reset_sva.sv"
`include "axi/axi_reset_sva.sv"

// Scoreboard
`include "scoreboard/tb_scoreboard.sv"

// Functional coverage
`include "coverage/tb_coverage.sv"

// Environment
`include "env/environment_config.sv"
`include "env/tb_environment.sv"

// RAL (寄存器抽象层)
`include "ral/axi_spi_reg_adapter.sv"
`include "ral/axi_spi_reg_block.sv"

// Test library
`include "test/test_base.sv"
// SPI tests
`include "test/spi_word_len_test.sv"
`include "test/spi_mode_test.sv"
`include "test/spi_cs_sck_test.sv"
`include "test/spi_sck_cs_test.sv"
`include "test/spi_ifg_test.sv"
`include "test/spi_sck_speed_test.sv"
`include "test/spi_burst_test.sv"
`include "test/spi_alternating_test.sv"
`include "test/spi_data_all_0_test.sv"
`include "test/spi_data_all_1_test.sv"
`include "test/spi_miso_base.sv"
`include "test/spi_miso_read_test.sv"
`include "test/spi_miso_all_0_test.sv"
`include "test/spi_miso_all_1_test.sv"
`include "test/spi_random_test.sv"
// AXI tests
`include "test/axi_busy_test.sv"
`include "test/axi_handshake_test.sv"
`include "test/axi_wstrb_test.sv"
`include "test/axi_concurrent_test.sv"
// RAL test
`include "test/ral_test.sv"
// Reset tests
`include "test/reset_mid_test.sv"
`include "test/reset_sva_test.sv"

// DUT RTL
`include "../DUT/AXI_slave_top.v"


module tb_top;

    // ========== Clock & Reset ==========
    logic s00_axi_aclk;
    logic s00_axi_aresetn;

    initial begin
        s00_axi_aclk = 0;
        forever #5 s00_axi_aclk = ~s00_axi_aclk;
    end

    initial begin
        s00_axi_aresetn = 0;
        #100;
        s00_axi_aresetn = 1;
    end

    // ========== Interfaces ==========
    axi_interface axi_vif();
    spi_interface spi_vif();

    wire MOSI;
    wire SCK;
    wire CS;

    assign axi_vif.ACLK    = s00_axi_aclk;
    assign axi_vif.ARESETN = s00_axi_aresetn;
    assign spi_vif.GCLK    = s00_axi_aclk;
    assign spi_vif.SCLK    = SCK;
    assign spi_vif.MOSI    = MOSI;
    assign spi_vif.CS      = CS;

    // ============================================================
    // SVA: CS_SCK (generate 3 档: EXP=2,4,8)
    // ============================================================
    generate
        for (genvar g = 0; g < 3; g++) begin : gen_cs_sck
            localparam int VAL = (g == 0) ? 2 : (g == 1) ? 4 : 8;
            spi_cs_sck_sva #(.EXP(VAL)) u (
                .GCLK(spi_vif.GCLK),
                .SCLK(spi_vif.SCLK),
                .CS  (spi_vif.CS),
                .en  (spi_vif.timing_check_en && spi_vif.exp_cs_sck == VAL)
            );
        end
    endgenerate

    // ============================================================
    // SVA: SCK speed (generate 4 档: PER=128,64,32,16)
    // ============================================================
    generate
        for (genvar g = 0; g < 4; g++) begin : gen_sck_speed
            localparam int VAL = (g == 0) ? 128 : (g == 1) ? 64 : (g == 2) ? 32 : 16;
            spi_sck_speed_sva #(.PER(VAL)) u (
                .GCLK(spi_vif.GCLK),
                .SCLK(spi_vif.SCLK),
                .CS  (spi_vif.CS),
                .en  (spi_vif.timing_check_en && spi_vif.exp_sck_speed == g)
            );
        end
    endgenerate

    // ============================================================
    // SVA: SCK→CS 延迟
    // ============================================================
    spi_sck_cs_sva u_sck_cs (
        .GCLK      (spi_vif.GCLK),
        .SCLK      (spi_vif.SCLK),
        .CS        (spi_vif.CS),
        .en        (spi_vif.timing_check_en),
        .exp_sck_cs(spi_vif.exp_sck_cs)
    );

    // ============================================================
    // SVA: SPI 复位引脚检查
    // ============================================================
    spi_reset_sva u_spi_reset (
        .ACLK   (s00_axi_aclk),
        .ARESETn(s00_axi_aresetn),
        .CS     (CS),
        .SCK    (SCK),
        .MOSI   (MOSI)
    );

    // ============================================================
    // SVA: AXI 复位协议检查
    // ============================================================
    axi_reset_sva u_axi_reset (
        .ACLK   (s00_axi_aclk),
        .ARESETn(s00_axi_aresetn),
        .AWREADY(axi_vif.AWREADY),
        .WREADY (axi_vif.WREADY),
        .BVALID (axi_vif.BVALID),
        .BRESP  (axi_vif.BRESP),
        .ARREADY(axi_vif.ARREADY),
        .RVALID (axi_vif.RVALID),
        .RRESP  (axi_vif.RRESP),
        .RDATA  (axi_vif.RDATA),
        .AWVALID(axi_vif.AWVALID),
        .WVALID (axi_vif.WVALID),
        .ARVALID(axi_vif.ARVALID)
    );

    // ============================================================
    // DUT
    // ============================================================
    AXI_slave_top DUT (
        .s00_axi_aclk    (s00_axi_aclk),
        .s00_axi_aresetn (s00_axi_aresetn),
        .s00_axi_awaddr  (axi_vif.AWADDR[5:0]),
        .s00_axi_awprot  (axi_vif.AWPROT),
        .s00_axi_awvalid (axi_vif.AWVALID),
        .s00_axi_awready (axi_vif.AWREADY),
        .s00_axi_wdata   (axi_vif.WDATA),
        .s00_axi_wstrb   (axi_vif.WSTRB),
        .s00_axi_wvalid  (axi_vif.WVALID),
        .s00_axi_wready  (axi_vif.WREADY),
        .s00_axi_bresp   (axi_vif.BRESP),
        .s00_axi_bvalid  (axi_vif.BVALID),
        .s00_axi_bready  (axi_vif.BREADY),
        .s00_axi_araddr  (axi_vif.ARADDR[5:0]),
        .s00_axi_arprot  (axi_vif.ARPROT),
        .s00_axi_arvalid (axi_vif.ARVALID),
        .s00_axi_arready (axi_vif.ARREADY),
        .s00_axi_rdata   (axi_vif.RDATA),
        .s00_axi_rresp   (axi_vif.RRESP),
        .s00_axi_rvalid  (axi_vif.RVALID),
        .s00_axi_rready  (axi_vif.RREADY),
        .MISO            (spi_vif.MISO),
        .MOSI            (MOSI),
        .SCK             (SCK),
        .CS              (CS)
    );

    // ============================================================
    // MISO slave model (8-bit, Mode 0: CPOL=0/CPHA=0)
    //  CS↓ 装载 miso_tx_data，CS 低时每个 SCK 下降沿左移，MISO 输出当前 MSB；
    //  DUT 在 SCK 上升沿采样 → MSB first。用 GCLK 同步采边沿，避免多驱动。
    //  注：DUT 在 PRE_TRANS（首个 SCK 沿前）提前采第一位，若 rdata 差一位，
    //  按波形调 load/shift 时机即可。test 通过 spi_vif.miso_tx_data 设回送字节。
    // ============================================================
    logic [7:0] miso_sr;
    logic       sck_d, cs_d;
    always @(posedge s00_axi_aclk) begin
        sck_d <= SCK;
        cs_d  <= CS;
        if (cs_d && !CS)                       // CS 下降沿：装载
            miso_sr <= spi_vif.miso_tx_data;
        else if (!CS && sck_d && !SCK)         // CS 低 + SCK 下降沿：左移
            miso_sr <= {miso_sr[6:0], 1'b0};
    end
    assign spi_vif.MISO = miso_sr[7];

    // ========== UVM start ==========
    initial begin
        $fsdbDumpfile("tb_top.fsdb");
        $fsdbDumpvars(0, tb_top);
        uvm_config_db#(virtual axi_interface)::set(null, "uvm_test_top", "axi_vif", axi_vif);
        uvm_config_db#(virtual spi_interface)::set(null, "uvm_test_top", "spi_vif", spi_vif);
        run_test();
    end

endmodule : tb_top
