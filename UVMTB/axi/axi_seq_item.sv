class axi_seq_item extends uvm_sequence_item;

    rand bit        write;                 
    rand bit [31:0] addr;
    rand bit [31:0] wdata;                   
    rand bit [ 3:0] wstrb;                       

 
    rand int unsigned aw_delay;                  
    rand int unsigned w_delay;                  

    bit [31:0] rdata;                           
    bit [ 1:0] bresp;                         
    bit [ 1:0] rresp;                          

    // Constraints
    constraint c_addr_aligned { addr[1:0] == 2'b00; }
    constraint c_wstrb_valid  { wstrb != 4'b0; }
    constraint c_delay_default { aw_delay == 0; w_delay == 0; }

    `uvm_object_utils_begin(axi_seq_item)
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
