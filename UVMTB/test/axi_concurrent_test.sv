// ============================================================
// axi_concurrent_test — AXI 读写通道并发验证（待改进项 5）
//
//   DUT 读(AR/R)与写(AW/W/B)通道是两套独立逻辑、信号不相交，
//   因此读写可真正并发。本 test 让二者同时活动：
//     - 写流：连续发 6 帧 SPI（mosi_data 每帧不同），数据由 scoreboard 比对
//     - 读流：写流进行期间持续读 busy(0x04)，制造 AR 流量
//   driver 切到 concurrent_mode：dispatch 把读/写分流到独立通道线程。
//
//   三重判据（全满足才算并发验证通过）：
//     1. 监控到 ARVALID 与 AW/W 同周期为高  → 并发真实发生
//     2. 仿真正常结束（无 hang）            → 读写互不死锁
//     3. scoreboard 全 match               → 写数据未被读流干扰
//
//   注意：本 test 不依赖读数据回传（并发模式下 rdata_o 不保证）。
// ============================================================
`ifndef AXI_CONCURRENT_TEST_SV
`define AXI_CONCURRENT_TEST_SV

class axi_concurrent_test extends test_base;
    `uvm_component_utils(axi_concurrent_test)

    bit concurrency_seen = 0;

    function new(string name = "axi_concurrent_test", uvm_component parent = null);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        // 打开 driver 并发模式（仅本 test；其余 test concurrent_mode 默认 0）
        env_cfg.axi_cfg.concurrent_mode = 1;
    endfunction

    task run_phase(uvm_phase phase);
        virtual axi_interface vif = env_cfg.axi_cfg.vif;
        automatic axi_spi_cfg_seq cfg;
        bit wr_done = 0;

        phase.raise_objection(this);
        #200;   // 等复位释放

        // ---- 一次性配置 SPI 参数（8-bit / Mode 0 / /16）----
        cfg = axi_spi_cfg_seq::type_id::create("cfg");
        cfg.cfg_word_len  = 1;  cfg.word_len_enc  = 2'b10;
        cfg.cfg_spi_mode  = 1;  cfg.spi_mode_enc  = 2'b00;
        cfg.cfg_sck_speed = 1;  cfg.sck_speed_enc = 2'b11;
        cfg.cfg_cs_sck    = 1;  cfg.cs_sck        = 8'h4;
        cfg.cfg_sck_cs    = 1;  cfg.sck_cs        = 8'h4;
        cfg.cfg_ifg       = 1;  cfg.ifg           = 8'h4;
        cfg.do_start      = 0;
        cfg.start(env.axi_agt.axi_sqr);

        // ---- 并发证据监控：AR 与 AW/W 同周期活动 ----
        fork : mon_blk
            forever begin
                @(posedge vif.ACLK);
                if (vif.ARVALID && (vif.AWVALID || vif.WVALID))
                    concurrency_seen = 1;
            end
        join_none

        // ---- 读写两条流并行 ----
        fork
            // 写流：连续发 6 帧 SPI（mosi_data 每帧不同）
            begin : wr_stream
                for (int i = 0; i < 6; i++) begin
                    automatic axi_spi_cfg_seq f =
                        axi_spi_cfg_seq::type_id::create($sformatf("f%0d", i));
                    f.cfg_mosi_data = 1;  f.mosi_data = 32'hC0 + i;
                    f.do_start      = 1;  f.wait_ns   = 20000;
                    f.start(env.axi_agt.axi_sqr);
                end
                wr_done = 1;
            end
            // 读流：写流进行期间持续读 busy(0x04)
            begin : rd_stream
                while (!wr_done) begin
                    automatic axi_read_seq r =
                        axi_read_seq::type_id::create("r");
                    r.raddr = 32'h04;
                    r.start(env.axi_agt.axi_sqr);
                    #500;   // 节流，避免灌爆读队列
                end
            end
        join

        disable mon_blk;

        if (concurrency_seen)
            `uvm_info(get_name(),
                "[PASS] 读写并发已观测：ARVALID 与 AW/W 同周期为高，通道互不阻塞、无死锁",
                UVM_LOW)
        else
            `uvm_error(get_name(),
                "[FAIL] 全程未观测到读写并发，读写可能被串行化")

        #1000;
        phase.drop_objection(this);
    endtask
endclass : axi_concurrent_test

`endif
