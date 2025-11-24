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

  // Dump the signals to an FST file (CI expects tb.fst)
  initial begin
    $dumpfile("tb.fst");
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
  tt_um_spi_cpu_top user_project (
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

  // Program external SPI RAM with the tiny CPU program
  // Program external SPI RAM with a simple CPU program
  initial begin
      // Program at addresses 0x0000..0x0003:
      // 0: LDI 1   (0001_0001)
      // 1: ADDI 1  (0010_0001)
      // 2: ADDI 1  (0010_0001) -> A = 3
      // 3: OUT     (1000_0000) -> uo_out = 3
      //
      // No JMP instruction used.

      ram.mem[16'h0000] = 8'b0001_0001; // LDI 1
      ram.mem[16'h0001] = 8'b0010_0001; // ADDI 1
      ram.mem[16'h0002] = 8'b0010_0001; // ADDI 1
      ram.mem[16'h0003] = 8'b1000_0000; // OUT

      // Initial signals
      clk   = 1'b0;
      rst_n = 1'b0;
      ena   = 1'b0;
      ui_in = 8'h00;

      // Release reset and enable design
      #50;
      rst_n = 1'b1;
      ena   = 1'b1;

      // ui_in is currently unused by CPU, can leave as 0
  end

endmodule
