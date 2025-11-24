`default_nettype none

module ExecutionUnit #(
    parameter ROM_ADDRESS_WIDTH = 5,
    parameter INPUT_DATA_WIDTH  = 4,
    parameter OUTPUT_DATA_WIDTH = 8
)(
  input wire                          clk,
  input wire                          reset,
  input wire                          start,
  input wire [INPUT_DATA_WIDTH-1:0] opcode,
  input wire [INPUT_DATA_WIDTH*2-1:0] operand,
  output reg [OUTPUT_DATA_WIDTH-1:0]  cpuOut
);

    // Control Signals from Instruction Decoder
    wire _LDA, _LDB, _LDO;               // Load A, B and O registers
    wire _LSR;                           // Load Shift Register
    wire _ADD, _SUB;                     // Arithmetic Instructions
    wire _AND, _OR, _XOR, _INV;          // Logical Instructions
    wire _LDSA, _LDSB;                   // Load Shift Register from A or B register
    wire _LSH, _RSH;                     // Shift Instructions
    wire _SNZA, _SNZS;                   // Skip Next if Zero A or B
    wire enableACC;                      // Enable Accumulator
    
    wire  [INPUT_DATA_WIDTH-1:0]  Aout, Bout;
    wire  [OUTPUT_DATA_WIDTH-1:0] Oout;
    wire  [OUTPUT_DATA_WIDTH-1:0] Oin;

    wire [INPUT_DATA_WIDTH-1:0]  shiftIn;
    wire [OUTPUT_DATA_WIDTH-1:0] shiftOut;
    wire SF;                            // Shift Flag

    wire _ADDin; // ALU addition control flag

    wire [OUTPUT_DATA_WIDTH-1:0] ACCout;

    // Accumulator Input 
    wire        OF; 
    wire       _CLR;
    wire [OUTPUT_DATA_WIDTH-1:0] aluOut;

    // ALU inputs
    wire [OUTPUT_DATA_WIDTH-1:0] in1;
    wire [OUTPUT_DATA_WIDTH-1:0] in2;

    // Split clock into "sub-clocks" with keep attributes to fux fanout violations
    (* keep *) wire clk_pc   = clk;  // program counter clock
    (* keep *) wire clk_regs = clk;  // register file + ACC
    (* keep *) wire clk_sr   = clk;  // shift register 
    
    // Instruction Decoder
    // Decodes the opcode from the program rom and outputs the appropriate control signalsÃŸ
    InstructionDecoder decoder (
        .instructionIn(opcode),
        .LDA  (_LDA),
        .LDB  (_LDB),
        .LDO  (_LDO),
        .LDSA (_LDSA),
        .LDSB (_LDSB),
        .LSH  (_LSH),
        .RSH  (_RSH),
        .CLR  (_CLR),
        .SNZA (_SNZA),
        .SNZS (_SNZS),
        .ADD  (_ADD),
        .SUB  (_SUB),
        .AND  (_AND),
        .OR   (_OR),
        .XOR  (_XOR),
        .INV  (_INV)
    );

    // Regsiter File 
    // Contains A reg and B reg and O reg
    RegisterFile registerFile (
        .clk(clk_regs),
        .reset(reset),
        // split switch input into A and B input
        .AIn(operand[7:4]), 
        .BIn(operand[3:0]),
        .OIn(ACCout),
        .LDA(_LDA),
        .LDB(_LDB),
        .LDO(_LDO),
        .Aout(Aout),
        .Bout(Bout),
        .Oout(Oout)
    );

    // MUX for Shift Register Inputs 
    SR_MUX srmux (_LDSA, _LDSB, Aout, Bout, shiftIn, _LSR);

    // Shifter
    // Register for implimenting shift instructions and storing the results
    ShiftRegister sr (clk_sr, reset, shiftIn, (_LSR & start), {(_LSH & start), (_RSH & start)}, shiftOut, SF);

    // MUX for addition control flag

    ADD_MUX addmux (_ADD, _SNZA,_SNZS, SF, _ADDin);

    // MUX for ALU inputs , depends on control signals .
    // e.g (SNZA, SNZB, LDSA and LDSB require different inputs.

    ALU_MUX alumux (_SNZA, _SNZS, SF ,shiftOut, ACCout, Aout, Bout, in1, in2);

    // Arithmetic Logic Unit (combinatorial)
    ArithmeticLogicUnit alu( 
        .ADD(_ADDin),
        .SUB(_SUB),
        .AND(_AND),
        .OR (_OR),
        .XOR(_XOR),
        .INV(_INV),
        .CLR(_CLR),
        .in1(in1),
        .in2(in2), 
        .out(aluOut),
        .overflow(OF)
    );
    
    // Logic to enable the Accumulator 
    ENABLE_ACC_MUX accmux ( _AND, _OR, _XOR, _INV, _ADDin, _SUB, _CLR, enableACC);

    // Accumulator (ACC)
    // Stores the results of Arithmetic or Logical operations
    defparam ACC.DATA_WIDTH = OUTPUT_DATA_WIDTH;
    ResetEnableDFF ACC (clk, _CLR || reset, (enableACC) , aluOut, ACCout); 

    // CPU Output
    always @(posedge clk) begin
      if (start) begin
        cpuOut = Oout;
      end
    end
endmodule

