class axi_config extends uvm_object;

    `uvm_object_utils(axi_config)

    virtual axi_interface vif;

    // 0 = 串行驱动（默认，现有所有 test）；1 = 读写并发（仅 axi_concurrent_test）
    bit concurrent_mode = 0;

    function new(string name = "axi_config");
        super.new(name);
    endfunction : new

endclass : axi_config