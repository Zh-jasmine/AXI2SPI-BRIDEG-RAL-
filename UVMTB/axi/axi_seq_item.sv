class axi_seq_item extends uvm_sequence_item;

    string item_type;
    string name;

    // Transaction fields (rand = driven by sequence/driver)
    rand bit        write;                       // 1 = write, 0 = read
    rand bit [31:0] addr;
    rand bit [31:0] wdata;                       // write data
    rand bit [ 3:0] wstrb;                       // byte enables

    // AW/W channel delay control (write only)
    // aw_delay > w_delay → W arrives first
    // aw_delay < w_delay → AW arrives first
    // aw_delay == w_delay → simultaneous (default)
    rand int unsigned aw_delay;                  // clocks before asserting AWVALID
    rand int unsigned w_delay;                   // clocks before asserting WVALID

    // Response fields (filled by monitor)
    bit [31:0] rdata;                            // read data
    bit [ 1:0] bresp;                            // write response
    bit [ 1:0] rresp;                            // read response

    // Constraints
    constraint c_addr_aligned { addr[1:0] == 2'b00; }
    constraint c_wstrb_valid  { wstrb != 4'b0; }
    constraint c_delay_default { aw_delay == 0; w_delay == 0; }

    `uvm_object_utils_begin(axi_seq_item)
        `uvm_field_string(item_type, UVM_DEFAULT)
        `uvm_field_string(name, UVM_DEFAULT)
        `uvm_field_int(write, UVM_DEFAULT)
        `uvm_field_int(addr, UVM_DEFAULT)
        `uvm_field_int(wdata, UVM_DEFAULT)
        `uvm_field_int(wstrb, UVM_DEFAULT)
        `uvm_field_int(aw_delay, UVM_DEFAULT)
        `uvm_field_int(w_delay, UVM_DEFAULT)
        `uvm_field_int(rdata, UVM_DEFAULT)
        `uvm_field_int(bresp, UVM_DEFAULT)
        `uvm_field_int(rresp, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "axi_seq_item");
        super.new(name);
    endfunction : new

endclass : axi_seq_item
