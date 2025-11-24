// `default_nettype none
// `timescale 1ns / 1ps

// /* This testbench just instantiates the module and makes some convenient wires
//    that can be driven / tested by the cocotb test.py.
// */
// module tb ();

//   // Dump the signals to a FST file. You can view it with gtkwave or surfer.
//   initial begin
//     $dumpfile("tb.fst");
//     $dumpvars(0, tb);
//     #1;
//   end

//   // Wire up the inputs and outputs:
//   reg clk;
//   reg rst_n;
//   reg ena;
//   reg [7:0] ui_in;
//   reg [7:0] uio_in;
//   wire [7:0] uo_out;
//   wire [7:0] uio_out;
//   wire [7:0] uio_oe;
// `ifdef GL_TEST
//   wire VPWR = 1'b1;
//   wire VGND = 1'b0;
// `endif

//   // Replace tt_um_example with your module name:
//   tt_um_example user_project (

//       // Include power ports for the Gate Level test:
// `ifdef GL_TEST
//       .VPWR(VPWR),
//       .VGND(VGND),
// `endif

//       .ui_in  (ui_in),    // Dedicated inputs
//       .uo_out (uo_out),   // Dedicated outputs
//       .uio_in (uio_in),   // IOs: Input path
//       .uio_out(uio_out),  // IOs: Output path
//       .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
//       .ena    (ena),      // enable - goes high when design is selected
//       .clk    (clk),      // clock
//       .rst_n  (rst_n)     // not reset
//   );

// endmodule


`default_nettype none
`timescale 1ns / 1ps

module tb ();

  // Dump the signals to a FST file. You can view it with gtkwave or surfer.
  initial begin
    $dumpfile("tb.fst");    // <<< important name for CI
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  // Power pins for gate-level sim
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // DUT: your TinyTapeout top
  tt_um_example user_project (
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  // --- Hook up SPI RAM model to uio pins ---

  wire cs_n = uio_out[0];
  wire mosi = uio_out[1];
  wire sck  = uio_out[3];
  wire miso;

  // Behavioural SPI RAM model (READ 0x03 only)
  spi_ram_model #(.MEM_BYTES(256)) ram (
      .cs_n (cs_n),
      .sck  (sck),
      .mosi (mosi),
      .miso (miso)
  );

  // Feed MISO back into DUT on uio_in[2]
  always @* begin
      uio_in      = 8'h00;
      uio_in[2]   = miso;
  end

  // Clock: 20 ns period = 50 MHz
  always #10 clk = ~clk;

  // Preload RAM and drive stimulus
  initial begin
      // Preload mem[0x12] = 0xA5
      ram.mem[8'h12] = 8'hA5;

      // Initial signals
      clk   = 1'b0;
      rst_n = 1'b0;
      ena   = 1'b0;
      ui_in = 8'h00;

      // Release reset and enable design
      #50;
      rst_n = 1'b1;
      ena   = 1'b1;

      // Set address we want to read: 0x12
      ui_in = 8'h12;

      // Wait for internal SPI read to finish
      // spi_if is the instance name inside tt_um_example:
      //   spi_read_byte spi_if ( ... );
      wait (user_project.spi_if.done == 1'b1);

      // Give a little time for uo_out to update
      #40;

      if (uo_out == 8'hA5) begin
          $display("PASS: tt_um_example read 0x%02X from addr 0x%02X", uo_out, ui_in);
      end else begin
          $display("FAIL: Expected 0xA5, got 0x%02X", uo_out);
      end

      #100;
      $finish;
  end

endmodule
