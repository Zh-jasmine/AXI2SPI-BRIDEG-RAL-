class axi_base_seq extends uvm_sequence #(axi_seq_item);

    `uvm_object_utils(axi_base_seq)

    function new(string name = "axi_base_seq");
        super.new(name);
    endfunction : new

endclass : axi_base_seq


class axi_write_seq extends axi_base_seq;

    `uvm_object_utils(axi_write_seq)

    rand bit [31:0] waddr;
    rand bit [31:0] wdata;
    rand bit [ 3:0] wstrb = 4'hF;
    int unsigned aw_delay = 0;   // AW 通道延迟（ACLK 周期）
    int unsigned w_delay  = 0;   // W  通道延迟（ACLK 周期）

    function new(string name = "axi_write_seq");
        super.new(name);
    endfunction : new

    task body();
        axi_seq_item item = axi_seq_item::type_id::create("item");

        start_item(item);
        item.addr     = waddr;
        item.wdata    = wdata;
        item.wstrb    = wstrb;
        item.write    = 1;
        item.aw_delay = aw_delay;
        item.w_delay  = w_delay;
        finish_item(item);
    endtask : body

endclass : axi_write_seq


class axi_read_seq extends axi_base_seq;

    `uvm_object_utils(axi_read_seq)

    rand bit [31:0] raddr;
    bit [31:0]      rdata_o;   // 读回数据：driver 填好 item.rdata 后回传给上层 test

    function new(string name = "axi_read_seq");
        super.new(name);
    endfunction : new

    task body();
        axi_seq_item item = axi_seq_item::type_id::create("item");

        start_item(item);
        item.addr  = raddr;
        item.write = 0;
        finish_item(item);
        rdata_o = item.rdata;  // finish_item 返回时 driver 已写好 rdata（同一对象引用）
    endtask : body

endclass : axi_read_seq



// ============================================================
// axi_spi_cfg_seq — SPI 寄存器配置 sequence
// ============================================================
class axi_spi_cfg_seq extends axi_base_seq;

    `uvm_object_utils(axi_spi_cfg_seq)

    // ---- 寄存器地址 ----
    localparam ADDR_START     = 32'h00;
    localparam ADDR_SPI_MODE  = 32'h08;
    localparam ADDR_SCK_SPEED = 32'h0C;
    localparam ADDR_WORD_LEN  = 32'h10;
    localparam ADDR_IFG       = 32'h14;
    localparam ADDR_CS_SCK    = 32'h18;
    localparam ADDR_SCK_CS    = 32'h1C;
    localparam ADDR_MOSI_DATA = 32'h20;

    // ---- 寄存器值 ----
    rand bit [1:0]  word_len_enc;
    rand bit [1:0]  spi_mode_enc;
    rand bit [1:0]  sck_speed_enc;
    rand bit [7:0]  ifg;
    rand bit [7:0]  cs_sck;
    rand bit [7:0]  sck_cs;
    rand bit [31:0] mosi_data;

    // ---- 开关 ----
    bit cfg_word_len;
    bit cfg_spi_mode;
    bit cfg_sck_speed;
    bit cfg_ifg;
    bit cfg_cs_sck;
    bit cfg_sck_cs;
    bit cfg_mosi_data;
    bit do_start;

    int unsigned wait_ns = 20000;

    constraint c_valid { word_len_enc inside {0,1,2,3};
                         spi_mode_enc inside {0,1,2,3};
                         sck_speed_enc inside {0,1,2,3}; }

    function new(string name = "axi_spi_cfg_seq");
        super.new(name);
    endfunction : new

    task write_reg(bit [31:0] addr, bit [31:0] data);
        axi_seq_item item = axi_seq_item::type_id::create("item");
        start_item(item);
        item.addr  = addr;
        item.wdata = data;
        item.wstrb = 4'hF;
        item.write = 1;
        finish_item(item);
    endtask : write_reg

    function automatic string spi_mode_str(bit [1:0] enc);
        case (enc)
            2'b00: return "Mode 0 (CPOL=0,CPHA=0)";
            2'b01: return "Mode 1 (CPOL=0,CPHA=1)";
            2'b10: return "Mode 2 (CPOL=1,CPHA=0)";
            2'b11: return "Mode 3 (CPOL=1,CPHA=1)";
            default: return "unknown";
        endcase
    endfunction

    task body();
        if (cfg_word_len) begin
            `uvm_info(get_name(), $sformatf("配置字长: %0d-bit (addr 0x10)", word_len_enc == 0 ? 32 : word_len_enc == 1 ? 16 : word_len_enc == 2 ? 8 : 4), UVM_LOW)
            write_reg(ADDR_WORD_LEN, {30'h0, word_len_enc});
        end

        if (cfg_spi_mode) begin
            `uvm_info(get_name(), $sformatf("配置 SPI 模式: %s (addr 0x08)", spi_mode_str(spi_mode_enc)), UVM_LOW)
            write_reg(ADDR_SPI_MODE, {30'h0, spi_mode_enc});
        end

        if (cfg_sck_speed) begin
            `uvm_info(get_name(), $sformatf("配置 SCK 分频: %0d (addr 0x0C)", sck_speed_enc), UVM_LOW)
            write_reg(ADDR_SCK_SPEED, {30'h0, sck_speed_enc});
        end

        if (cfg_cs_sck) begin
            `uvm_info(get_name(), $sformatf("配置 CS→SCK 延迟: %0d (addr 0x18)", cs_sck), UVM_LOW)
            write_reg(ADDR_CS_SCK, {24'h0, cs_sck});
        end

        if (cfg_sck_cs) begin
            `uvm_info(get_name(), $sformatf("配置 SCK→CS 延迟: %0d (addr 0x1C)", sck_cs), UVM_LOW)
            write_reg(ADDR_SCK_CS, {24'h0, sck_cs});
        end

        if (cfg_ifg) begin
            `uvm_info(get_name(), $sformatf("配置帧间隔 IFG: %0d (addr 0x14)", ifg), UVM_LOW)
            write_reg(ADDR_IFG, {24'h0, ifg});
        end

        if (cfg_mosi_data) begin
            `uvm_info(get_name(), $sformatf("写入 MOSI 数据: 0x%0h (addr 0x20)", mosi_data), UVM_LOW)
            write_reg(ADDR_MOSI_DATA, mosi_data);
        end

        if (do_start) begin
            `uvm_info(get_name(), "发起 SPI 传输 (写 start=0→1)", UVM_LOW)
            write_reg(ADDR_START, 32'h0);   // 先清零，确保上升沿
            write_reg(ADDR_START, 32'h1);   // 再写 1，触发传输
            #(wait_ns);
            `uvm_info(get_name(), "SPI 传输完成", UVM_LOW)
        end
    endtask : body

endclass : axi_spi_cfg_seq
