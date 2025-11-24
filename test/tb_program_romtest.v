`default_nettype none
`timescale 1ns/1ps

module tb_program_romtest;

    localparam ADDR_WIDTH = 8;

    reg  [ADDR_WIDTH-1:0] addressIn;
    wire [3:0]            dataOut;

    ProgramROMtest #(
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .addressIn(addressIn),
        .dataOut  (dataOut)
    );

    integer i;
    integer errors;

    // Small task to check a single address
    task check;
        input [ADDR_WIDTH-1:0] addr;
        input [3:0]            expected;
        begin
            addressIn = addr;
            #1; // allow combinational logic to settle
            if (dataOut !== expected) begin
                $display("ERROR: addr %0d: expected %b, got %b", addr, expected, dataOut);
                errors = errors + 1;
            end else begin
                $display("OK:    addr %0d: got %b", addr, dataOut);
            end
        end
    endtask

    initial begin
        errors = 0;

        // Explicitly check all the special cases 0..31
        check( 0, 4'b0000);
        check( 1, 4'b0001);
        check( 2, 4'b0100);
        check( 3, 4'b0110);
        check( 4, 4'b1000);
        check( 5, 4'b0110);
        check( 6, 4'b0011);
        check( 7, 4'b0101);
        check( 8, 4'b1001);
        check( 9, 4'b0100);
        check(10, 4'b0110);
        check(11, 4'b0110);
        check(12, 4'b0110);
        check(13, 4'b0011);
        check(14, 4'b0101);
        check(15, 4'b0101);
        check(16, 4'b1001);
        check(17, 4'b0100);
        check(18, 4'b0110);
        check(19, 4'b0110);
        check(20, 4'b0110);
        check(21, 4'b0110);
        check(22, 4'b0011);
        check(23, 4'b0101);
        check(24, 4'b0101);
        check(25, 4'b0101);
        check(26, 4'b1001);
        check(27, 4'b0010);
        check(28, 4'b0111);
        check(29, 4'b0111);
        check(30, 4'b0111);
        check(31, 4'b0111);

        // Optionally, sample a few default/NOP addresses (e.g. 32, 100, 255)
        check(32, 4'b0111);
        check(100,4'b0111);
        check(255,4'b0111);

        if (errors == 0) begin
            $display("PROGRAM ROM TEST PASSED");
        end else begin
            $display("PROGRAM ROM TEST FAILED: %0d errors", errors);
        end

        $finish;
    end

endmodule

`default_nettype wire
