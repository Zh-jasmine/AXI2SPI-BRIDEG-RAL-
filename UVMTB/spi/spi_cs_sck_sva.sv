// ============================================================
// spi_cs_sck_sva — CS↓ → 第一个 SCK 沿(GCLK周期数)
//
//   $fell(CS) |-> 静默 [EXP-2:EXP+1] 拍 ##1 SCK 变化
//   参数 EXP 决定期望延迟，允许 ±1 拍容差
// ============================================================

module spi_cs_sck_sva #(parameter int EXP = 4)
                       (input logic GCLK, SCLK, CS, bit en);

    property p_cs_sck;
        @(posedge GCLK) disable iff (!en)
        $fell(CS)
        |->
        (!$changed(SCLK))[*EXP-2:EXP+1]
        ##1 $changed(SCLK);
    endproperty

    CS_SCK_CHK: assert property(p_cs_sck)
        else $error("CS_SCK FAIL: EXP=%0d", EXP);
    CS_SCK_COV: cover property(p_cs_sck);

endmodule
