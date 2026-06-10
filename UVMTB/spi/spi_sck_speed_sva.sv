// ============================================================
// spi_sck_speed_sva — SCK 速度检查(上升沿间隔 = GCLK周期数)
//
//   $rose(SCLK) |=> 静默 [PER-2:PER] 拍 ##1 $rose(SCLK)
//   参数 PER 决定期望周期，允许 ±1 拍容差
//   CS 高时(非传输) disable
// ============================================================

module spi_sck_speed_sva #(parameter int PER = 16)
                          (input logic GCLK, SCLK, CS, bit en);

    property p_sck_speed;
        @(posedge GCLK) disable iff (!en || CS)
        $rose(SCLK)
        |=>
        (!$rose(SCLK))[*PER-2:PER]
        ##1 $rose(SCLK);
    endproperty

    SCK_SPEED_CHK: assert property(p_sck_speed)
        else $error("SCK speed FAIL: PER=%0d", PER);
    SCK_SPEED_COV: cover property(p_sck_speed);

endmodule
