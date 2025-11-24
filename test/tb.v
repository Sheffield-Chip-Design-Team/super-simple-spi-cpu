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

  // Program external SPI RAM with the tiny CPU program
 // Program external SPI RAM with a simple CPU program
  initial begin

      // ram.mem[8'h00] = 8'b0001_0000; // LDB, LDA
      // ram.mem[8'h01] = 8'b0010_1010; // LDO, ADD
      // ram.mem[8'h02] = 8'b0010_1011; // LDO, SUB
      // ram.mem[8'h03] = 8'b0010_1110; // LDO, XOR
      // ram.mem[8'h04] = 8'b0110_0011; // RSH, LDSA
      // ram.mem[8'h05] = 8'b0010_1000; // LDSB, SNZ A
      // ram.mem[8'h06] = 8'b0100_0010; // SNZ S, LSH
      // ram.mem[8'h07] = 8'b0111_0010; // CLR, LDO



      // // load a multiplicartion program into ram
      ram.mem[8'h00] = 8'b0001_0000; // LDB, LDA
      ram.mem[8'h01] = 8'b0110_0100; // RSH, LDSB
      ram.mem[8'h02] = 8'b0110_1000; // RSH, SNZ A
      ram.mem[8'h03] = 8'b0101_0011; // LSH, LDSA
      ram.mem[8'h04] = 8'b0100_1001; // LDSB, SNZ S
      ram.mem[8'h05] = 8'b0110_0110; // RSH, RSH
      ram.mem[8'h06] = 8'b0011_0110; // LDSA, RSH
      ram.mem[8'h07] = 8'b0101_0101; // LSH, LSH
      ram.mem[8'h08] = 8'b0100_1001; // LDSB, SNZ S
      ram.mem[8'h09] = 8'b0110_0110; // RSH, RSH
      ram.mem[8'h0A] = 8'b0110_0110; // RSH, RSH
      ram.mem[8'h0B] = 8'b0101_0011; // LSH, LDSA
      ram.mem[8'h0C] = 8'b0101_0101; // LSH, LSH
      ram.mem[8'h0D] = 8'b0010_1001; // LDO, SNZ S
      ram.mem[8'h0E] = 8'b0111_0111; // CLR, CLR
      ram.mem[8'h0F] = 8'b0111_0111; // CLR, CLR
  end

endmodule
