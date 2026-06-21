`ifndef SPI_MISO_SLAVE_MODEL_SV
`define SPI_MISO_SLAVE_MODEL_SV

// Simple 8-bit Mode0 MISO slave model for testbench readback tests.
// The model loads tx_data on CS falling edge and shifts left on SCLK falling edge.
module spi_miso_slave_model (
    input  logic       GCLK,
    input  logic       SCLK,
    input  logic       CS,
    input  logic [7:0] tx_data,
    output logic       MISO
);

    logic [7:0] shift_reg;
    logic       sck_d;
    logic       cs_d;

    always @(posedge GCLK) begin
        sck_d <= SCLK;
        cs_d  <= CS;

        if (cs_d && !CS) begin
            shift_reg <= tx_data;
        end else if (!CS && sck_d && !SCLK) begin
            shift_reg <= {shift_reg[6:0], 1'b0};
        end
    end

    assign MISO = shift_reg[7];

endmodule : spi_miso_slave_model

`endif