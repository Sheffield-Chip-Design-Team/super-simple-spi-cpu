`timescale 1ns/1ps

module tb_tt_um_spi_test;

    reg  [7:0] ui_in;
    wire [7:0] uo_out;
    reg  [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    reg        ena;
    reg        clk;
    reg        rst_n;

    // DUT
    tt_um_example dut (
        .ui_in (ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena   (ena),
        .clk   (clk),
        .rst_n(rst_n)
    );

    // Hook SPI RAM to uio[0..3]
    wire cs_n = uio_out[0];
    wire mosi = uio_out[1];
    wire sck  = uio_out[3];
    wire miso;

    spi_ram_model #(.MEM_BYTES(256)) ram (
        .cs_n (cs_n),
        .sck  (sck),
        .mosi (mosi),
        .miso (miso)
    );

    // Feed MISO back into DUT
    always @* begin
        uio_in      = 8'h00;
        uio_in[2]   = miso;
    end

    // Clock
    always #10 clk = ~clk;

    // Preload RAM: mem[0x12] = 0xA5
    initial begin
        ram.mem[8'h12] = 8'hA5;
    end

    initial begin
        $dumpfile("tb_tt_um_spi_test.vcd");
        $dumpvars(0, tb_tt_um_spi_test);

        clk   = 0;
        rst_n = 0;
        ena   = 0;
        ui_in = 8'h00;

        #50;
        rst_n = 1;
        ena   = 1;

        // set address 0x12
        ui_in = 8'h12;

        // wait until the internal SPI read is done
        // (hierarchical access to spi_if.done)
        wait (dut.spi_if.done == 1'b1);
        #40; // give it a bit to propagate to uo_out

        if (uo_out == 8'hA5) begin
            $display("PASS: tt_um_spi_test read 0x%02X from addr 0x%02X", uo_out, ui_in);
        end else begin
            $display("FAIL: Expected 0xA5, got 0x%02X", uo_out);
        end

        #100;
        $finish;
    end

endmodule
