/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // // All output pins must be assigned. If not used, assign to 0.
  // assign uo_out  = ui_in + uio_in;  // Example: ou_out is the sum of ui_in and uio_in
  // assign uio_out = 0;
  // assign uio_oe  = 0;

  // // List all unused inputs to prevent warnings
  // wire _unused = &{ena, clk, rst_n, 1'b0};

    wire [7:0] cpu_out;
    wire       spi_cs_n;
    wire       spi_sck;
    wire       spi_mosi;
    wire       spi_miso;

    spi_cpu cpu (
        .clk      (clk),
        .rst_n    (rst_n),
        .ena      (ena),
        .in_port  (ui_in),
        .out_port (cpu_out),
        .spi_cs_n (spi_cs_n),
        .spi_sck  (spi_sck),
        .spi_mosi (spi_mosi),
        .spi_miso (spi_miso)
    );

    // SPI → uio mapping
    assign uio_out[0] = spi_cs_n;
    assign uio_out[1] = spi_mosi;
    assign uio_out[3] = spi_sck;
    assign uio_out[2] = 1'b0;
    assign uio_out[7:4] = 4'b0000;

    assign uio_oe[0] = 1'b1;
    assign uio_oe[1] = 1'b1;
    assign uio_oe[3] = 1'b1;
    assign uio_oe[2] = 1'b0;
    assign uio_oe[7:4] = 4'b0000;

    assign spi_miso = uio_in[2];

    assign uo_out = ena ? cpu_out : 8'h00;

    wire _unused = &{uio_in[7:3], ena, 1'b0};

endmodule
