// ============================================================
// SPI Interface — 纯信号定义
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


endinterface : spi_interface
