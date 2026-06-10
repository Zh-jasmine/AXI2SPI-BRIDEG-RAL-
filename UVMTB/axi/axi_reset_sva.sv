// ============================================================
// axi_reset_sva — AXI slave 复位协议检查
//
//   [1] AXI_RESET_CHK         复位期间所有输出清零
//   [2] AXI_RESET_RELEASE_CHK 复位释放后第一拍，master 无激励时
//                              slave 输出保持空闲
//   DUT 同步复位 → |=> 延一拍检查
// ============================================================

module axi_reset_sva (
    input logic        ACLK,
    input logic        ARESETn,
    // slave outputs
    input logic        AWREADY,
    input logic        WREADY,
    input logic        BVALID,
    input logic [1:0]  BRESP,
    input logic        ARREADY,
    input logic        RVALID,
    input logic [1:0]  RRESP,
    input logic [31:0] RDATA,
    // master outputs (for release check precondition)
    input logic        AWVALID,
    input logic        WVALID,
    input logic        ARVALID
);

    // [1] 复位期间：所有 slave 输出必须清零
    property p_axi_reset_idle;
        @(posedge ACLK) !ARESETn |=>
            (!AWREADY && !WREADY && !BVALID &&
             !ARREADY && !RVALID &&
             (BRESP == 2'b00) && (RRESP == 2'b00) &&
             (RDATA == 32'h0));
    endproperty

    AXI_RESET_CHK: assert property(p_axi_reset_idle)
        else $error("AXI reset: 输出未清零 (AWREADY=%b WREADY=%b BVALID=%b ARREADY=%b RVALID=%b BRESP=%b RRESP=%b RDATA=%h)",
                    AWREADY, WREADY, BVALID, ARREADY, RVALID, BRESP, RRESP, RDATA);

    // [2] 复位释放后第一拍：master 无激励时，slave 不得凭空拉 ready/valid
    //     前提：释放那一拍 master AWVALID/WVALID/ARVALID 全 0
    //     （如果 master 有悬挂事务，slave 回响应是合法的，不检查）
    property p_axi_reset_release;
        @(posedge ACLK)
        ($rose(ARESETn) && !AWVALID && !WVALID && !ARVALID) |=>
            (!AWREADY && !WREADY && !BVALID &&
             !ARREADY && !RVALID);
    endproperty

    AXI_RESET_RELEASE_CHK: assert property(p_axi_reset_release)
        else $error("AXI reset release: 释放后输出未保持空闲 (AWREADY=%b WREADY=%b BVALID=%b ARREADY=%b RVALID=%b)",
                    AWREADY, WREADY, BVALID, ARREADY, RVALID);

endmodule
