`timescale 1ns/1ps

module tb_spi_read_byte;

    reg clk;
    reg rst_n;

    reg         start;
    reg [15:0]  addr;
    wire        busy;
    wire        done;
    wire [7:0]  data_out;

    wire cs_n;
    wire sck;
    wire mosi;
    wire miso;

    // DUT: SPI master
    spi_read_byte dut (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (start),
        .addr    (addr),
        .busy    (busy),
        .done    (done),
        .data_out(data_out),
        .cs_n    (cs_n),
        .sck     (sck),
        .mosi    (mosi),
        .miso    (miso)
    );

    // SPI RAM model
    spi_ram_model #(
        .MEM_BYTES(256)
    ) ram (
        .cs_n (cs_n),
        .sck  (sck),
        .mosi (mosi),
        .miso (miso)
    );

    // Clock: 20 ns period
    always #10 clk = ~clk;

    // Preload address 0x0012 with 0xA5
    initial begin
        ram.mem[8'h12] = 8'hA5;  // same as addr 0x0012 in our simple model
    end

    initial begin
        $dumpfile("tb_spi_read_byte.vcd");
        $dumpvars(0, tb_spi_read_byte);

        clk   = 1'b0;
        rst_n = 1'b0;
        start = 1'b0;
        addr  = 16'h0000;

        #50;
        rst_n = 1'b1;

        #50;

        // request a read from 0x0012
        addr  = 16'h0012;
        start = 1'b1;
        #20;
        start = 1'b0;

        // wait for transaction to finish
        wait(done == 1'b1);
        #20;

        if (data_out == 8'hA5) begin
            $display("PASS: Read 0x%02X from address 0x%04X", data_out, addr);
        end else begin
            $display("FAIL: Expected 0xA5, got 0x%02X", data_out);
        end

        #100;
        $finish;
    end

endmodule
