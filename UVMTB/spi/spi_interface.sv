// ============================================================
// SPI Interface — 纯信号定义 (SVA 已迁至 spi_timing_checker)
// ============================================================

interface spi_interface;

    // --- 信号 ---
    logic       GCLK;   // 100MHz reference, from tb_top
    logic       SCLK;
    logic       MOSI;
    logic       CS;
    logic       MISO;             // DUT 输入：由 tb_top 的 MISO slave model 驱动

    // --- MISO 回送数据 (test 设定，model 按 8-bit Mode0 移位送出) ---
    logic [7:0] miso_tx_data = 8'h00;

    // --- SVA 期望值 (test 写入, checker 读取) ---
    int  exp_cs_sck     = 4;
    int  exp_sck_cs     = 4;
    int  exp_ifg        = 4;
    int  exp_sck_speed  = 3;

    // --- 门控: 1 = SVA 在线, 0 = 关闭 ---
    bit  timing_check_en = 0;

    // --- clocking blocks (SPI monitor 采样用, 不变) ---
    clocking mtr_cb @(posedge SCLK);
        input   MOSI;
        input   CS;
    endclocking

    clocking mtr_cb_negedge @(negedge SCLK);
        input   MOSI;
        input   CS;
    endclocking

endinterface : spi_interface
