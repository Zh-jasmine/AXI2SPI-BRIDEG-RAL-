// ============================================================
// axi_spi_reg_adapter — RAL ↔ AXI 总线事务转换器
//   reg2bus: 把 RAL 的通用读写 uvm_reg_bus_op 翻译成 axi_seq_item
//   bus2reg: 把 driver 执行完的 axi_seq_item 翻回 uvm_reg_bus_op（取 rdata）
//   provides_responses = 0：driver 在同一个 req 对象上回填 rdata
//                           （见 axi_driver.drive_read: item.rdata = vif.RDATA），
//                           所以 reg 层用同一 req 调 bus2reg，无需独立 rsp。
// ============================================================
`ifndef AXI_SPI_REG_ADAPTER_SV
`define AXI_SPI_REG_ADAPTER_SV

class axi_spi_reg_adapter extends uvm_reg_adapter;
    `uvm_object_utils(axi_spi_reg_adapter)

    function new(string name = "axi_spi_reg_adapter");
        super.new(name);
        supports_byte_enable = 0;   // RAL 不下发 byte enable（reg 级整字写）
        provides_responses   = 0;   // 读数据由 driver 回填到同一 req
    endfunction

    // RAL → 总线：生成一笔 AXI 事务
    virtual function uvm_sequence_item reg2bus(const ref uvm_reg_bus_op rw);
        axi_seq_item item = axi_seq_item::type_id::create("ral_item");
        item.write    = (rw.kind == UVM_WRITE);
        item.addr     = rw.addr;
        item.wdata    = rw.data;
        item.wstrb    = 4'hF;       // reg 级写：全字节有效
        item.aw_delay = 0;
        item.w_delay  = 0;
        return item;
    endfunction

    // 总线 → RAL：driver 执行完后，取回结果
    virtual function void bus2reg(uvm_sequence_item bus_item,
                                  ref uvm_reg_bus_op rw);
        axi_seq_item item;
        if (!$cast(item, bus_item)) begin
            `uvm_fatal("RAL_ADAPTER", "bus2reg: $cast to axi_seq_item failed")
            return;
        end
        rw.kind   = item.write ? UVM_WRITE : UVM_READ;
        rw.addr   = item.addr;
        rw.data   = item.write ? item.wdata : item.rdata;
        rw.status = UVM_IS_OK;
    endfunction

endclass : axi_spi_reg_adapter

`endif
