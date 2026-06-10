// ============================================================
// spi_sck_cs_sva — 最后 SCK 沿 → CS↑ 延迟(GCLK周期数)
//
//   计数器方式：纯 SVA 无法定位"最后一个 SCK 沿"，
//   用 always 计数 + SVA 在 CS↑ 时比对。
//   端口 exp_sck_cs 由 test 通过 spi_vif 设置。
// ============================================================

module spi_sck_cs_sva (
    input logic GCLK,
    input logic SCLK,
    input logic CS,
    input bit   en,
    input int   exp_sck_cs
);

    int  sck_cs_cnt;
    bit  sck_cs_done;

    always @(posedge GCLK) begin
        if (!en || $fell(CS)) begin
            sck_cs_cnt  <= 0;
            sck_cs_done <= 0;
        end else if ($changed(SCLK)) begin
            sck_cs_cnt  <= 1;
            sck_cs_done <= 0;
        end else if ($rose(CS)) begin
            sck_cs_done <= 1;
        end else begin
            sck_cs_cnt  <= sck_cs_cnt + 1;
            sck_cs_done <= 0;
        end
    end

    property p_sck_cs;
        @(posedge GCLK) disable iff (!en)
        sck_cs_done |-> (sck_cs_cnt >= exp_sck_cs - 1) &&
                        (sck_cs_cnt <= exp_sck_cs + 1);
    endproperty

    SCK_CS_CHK: assert property(p_sck_cs)
        else $error("SCK->CS FAIL: measured %0d, expected %0d", sck_cs_cnt, exp_sck_cs);

endmodule
