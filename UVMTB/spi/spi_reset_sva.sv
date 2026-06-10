// ============================================================
// spi_reset_sva — 复位期间 SPI 引脚回到 idle
//
//   CS=1(释放)、SCK=0、MOSI=0
//   依据 SPI_master.v 复位值：chip_sel_v<=1, sck_v<=0, mosi_v<=0
//   DUT 同步复位 → |=> 延一拍检查
// ============================================================

module spi_reset_sva (
    input logic ACLK,
    input logic ARESETn,
    input logic CS,
    input logic SCK,
    input logic MOSI
);

    property p_spi_reset_idle;
        @(posedge ACLK) !ARESETn |=>
            ((CS === 1'b1) && (SCK === 1'b0) && (MOSI === 1'b0));
    endproperty

    SPI_RESET_CHK: assert property(p_spi_reset_idle)
        else $error("SPI reset: 引脚未回 idle (CS=%b SCK=%b MOSI=%b)", CS, SCK, MOSI);

endmodule
