class spi_config extends uvm_object;

    `uvm_object_utils(spi_config)

    virtual spi_interface  vif;

    // SPI 模式：spi_mode[1]=CPOL, spi_mode[0]=CPHA
    bit [1:0] spi_mode;

    // 字长配置（与 DUT slv_reg4 编码一致）：0=32b, 1=16b, 2=8b, 3=4b
    bit [1:0] word_len;

    function new(string name = "spi_config");
        super.new(name);
    endfunction : new

endclass : spi_config
