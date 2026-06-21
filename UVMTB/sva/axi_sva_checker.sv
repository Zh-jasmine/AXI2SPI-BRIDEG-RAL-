module axi_sva_checker (
    input logic        ACLK,
    input logic        ARESETn,
    input logic [31:0] AWADDR,
    input logic [ 2:0] AWPROT,
    input logic        AWVALID,
    input logic        AWREADY,
    input logic [31:0] WDATA,
    input logic [ 3:0] WSTRB,
    input logic        WVALID,
    input logic        WREADY,
    input logic [ 1:0] BRESP,
    input logic        BVALID,
    input logic        BREADY,
    input logic [31:0] ARADDR,
    input logic [ 2:0] ARPROT,
    input logic        ARVALID,
    input logic        ARREADY,
    input logic [31:0] RDATA,
    input logic [ 1:0] RRESP,
    input logic        RVALID,
    input logic        RREADY
);

    localparam int MAX_HANDSHAKE_GAP = 32;

    // [1] 复位期间：所有 slave 输出必须清零
    property p_axi_reset;
        @(posedge ACLK) !ARESETn |=>
            (!AWREADY && !WREADY && !BVALID &&
             !ARREADY && !RVALID &&
             (BRESP == 2'b00) && (RRESP == 2'b00) &&
             (RDATA == 32'h0));
    endproperty

    AXI_RESET_CHK: assert property(p_axi_reset)
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



    property p_aw_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        AWVALID && !AWREADY |=> AWVALID && $stable(AWADDR);
    endproperty

    AXI_AW_STABLE_CHK: assert property(p_aw_stable)
        else $error("AXI AW stable fail: AWADDR/AWPROT changed while AWVALID && !AWREADY");

    property p_w_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        WVALID && !WREADY |=> WVALID && $stable(WDATA) && $stable(WSTRB);
    endproperty

    AXI_W_STABLE_CHK: assert property(p_w_stable)
        else $error("AXI W stable fail: WDATA/WSTRB changed while WVALID && !WREADY");

    property p_ar_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        ARVALID && !ARREADY |=> ARVALID && $stable(ARADDR) ;
    endproperty

    AXI_AR_STABLE_CHK: assert property(p_ar_stable)
        else $error("AXI AR stable fail: ARADDR/ARPROT changed while ARVALID && !ARREADY");

    property p_b_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        BVALID && !BREADY |=> BVALID && $stable(BRESP);
    endproperty

    AXI_B_STABLE_CHK: assert property(p_b_stable)
        else $error("AXI B stable fail: BRESP changed while BVALID && !BREADY");

    property p_r_stable;
        @(posedge ACLK) disable iff (!ARESETn)
        RVALID && !RREADY |=> RVALID && $stable(RDATA) && $stable(RRESP);
    endproperty

    AXI_R_STABLE_CHK: assert property(p_r_stable)
        else $error("AXI R stable fail: RDATA/RRESP changed while RVALID && !RREADY");

    property p_awready_requires_aw_w_valid;
        @(posedge ACLK) disable iff (!ARESETn)
        AWREADY |-> AWVALID && WVALID;
    endproperty

    AXI_AWREADY_STYLE_CHK: assert property(p_awready_requires_aw_w_valid)
        else $error("AXI DUT style fail: AWREADY asserted without both AWVALID and WVALID");

    property p_wready_requires_aw_w_valid;
        @(posedge ACLK) disable iff (!ARESETn)
        WREADY |-> AWVALID && WVALID;
    endproperty

    AXI_WREADY_STYLE_CHK: assert property(p_wready_requires_aw_w_valid)
        else $error("AXI DUT style fail: WREADY asserted without both AWVALID and WVALID");

    
    
    AXI_AW_W_SAME_COV: cover property (
        @(posedge ACLK) disable iff (!ARESETn)
        AWVALID && WVALID && AWREADY && WREADY
    );

    AXI_AW_FIRST_COV: cover property (
        @(posedge ACLK) disable iff (!ARESETn)
        (AWVALID && !WVALID) ##[1:MAX_HANDSHAKE_GAP] (AWVALID && WVALID && AWREADY && WREADY)
    );

    AXI_W_FIRST_COV: cover property (
        @(posedge ACLK) disable iff (!ARESETn)
        (WVALID && !AWVALID) ##[1:MAX_HANDSHAKE_GAP] (AWVALID && WVALID && AWREADY && WREADY)
    );

    AXI_AR_HANDSHAKE_COV: cover property (
        @(posedge ACLK) disable iff (!ARESETn)
        ARVALID && ARREADY
    );

endmodule : axi_sva_checker
