// Control Modules

// Clock divider module to lower clock frequency

module clkDiv(
    input wire CLKin,
    output wire CLKout
);
    
    parameter COUNTER_SIZE = 64; 
    parameter COUNTER_TARGET = 1;

    reg[COUNTER_SIZE - 1:0] counter = 0;

    always @(posedge CLKin) begin
        counter <= counter  + 1;
    end

   // Output frequency = f(CLKin) / log2(COUNTER_TARGET - 1)
   assign CLKout = counter[COUNTER_TARGET];

endmodule


// Instruction Decoder to map opcodes to control signals.
// barrell shifter - mux / smallest design 
// decoder based

module InstructionDecoder( 
    input  [3:0] instructionIn,
    output reg  LDA,
    output reg  LDB,
    output reg  LDO,
    output reg  LDSA,
    output reg  LDSB,
    output reg  LSH,
    output reg  RSH,
    output reg  CLR,
    output reg  SNZA,
    output reg  SNZS,
    output reg  ADD,
    output reg  SUB,
    output reg  AND,
    output reg  OR,
    output reg  XOR,
    output reg  INV
);
    // 1-hot control signal encoding
    reg [15:0] ControlSignals; 
    reg NOP;

        
    always @(*) begin // decoder based MUX hopefully smaller than shifter based reg
        
        {LDA,LDB,LDO,LDSA,LDSB,LSH,RSH,CLR,SNZA,SNZS,ADD,SUB,AND,OR,XOR,INV} = 0;

        case (instructionIn)
            0:  LDA = 1;
            1:  LDB = 1;
            2:  LDO = 1;
            3: LDSA = 1;
            4: LDSB = 1;
            5:  LSH = 1;
            6:  RSH = 1;
            7:  CLR = 1;
            8: SNZA = 1;
            9: SNZS = 1;
            10: ADD = 1;
            11: SUB = 1;
            12: AND = 1;
            13: OR = 1;
            14: XOR = 1;
            15: INV = 1;
            default:  NOP = 1;
        endcase
    end

endmodule

module InstructionDecoder_BarrelShift( 
    input  [3:0] instructionIn,
    output  LDA,
    output  LDB,
    output  LDO,
    output  LDSA,
    output  LDSB,
    output  LSH,
    output  RSH,
    output  CLR,
    output  SNZA,
    output  SNZS,
    output  ADD,
    output  SUB,
    output  AND,
    output  OR,
    output  XOR,
    output  INV
);
    // 1-hot control signal encoding
    reg [15:0] ControlSignals; 
    reg NOP;

    assign {LDA,LDB,LDO,LDSA,LDSB,LSH,RSH,CLR,SNZA,SNZS,ADD,SUB,AND,OR,XOR,INV} = 1 << instructionIn;

endmodule

// Multiplexers

module SR_MUX (
    input wire       _LDSA,
    input wire       _LDSB,
    input wire [3:0] Aout,
    input wire [3:0] Bout,
    output wire [3:0] shiftIn,
    output wire      _LSR
);
    assign _LSR = _LDSA | _LDSB;
    
   /* always @(*) begin
        if (_LDSA) begin
           shiftIn = Aout;
        end else if (_LDSB) begin
           shiftIn = Bout;
        end else begin
           shiftIn = 0;
        end
    end 
    */
    
    // explicit MUX definition - might be smaller?
    assign shiftIn = _LDSA ? Aout : (_LDSB ? Bout: 0 );
    
endmodule

module ADD_MUX (
    input wire _ADD,
    input wire _SNZA,
    input wire _SNZS,
    input wire SF,
    output reg _ADDin
);
    // mux implimentation

   /* always @(*) begin
        if (SF & (_SNZA | _SNZS))
            _ADDin = 1'b1;
        else
            _ADDin = _ADD;
        end
    
    */
    
    //  combinational expression 
    always @(*) begin
        _ADDin = ((_SNZA | _SNZS) & SF) | _ADD ;
    end
    


endmodule


module ALU_MUX (
    input wire       _SNZA,
    input wire       _SNZS,
    input wire       SF,
    input wire [7:0] shiftOut,
    input wire [7:0] ACCout,
    input wire [3:0] Aout,
    input wire [3:0] Bout,
    output reg [7:0] in1,
    output reg [7:0] in2
);
    wire cond_snza = (_SNZA && SF);
    wire cond_snzs = (_SNZS && SF);

    always @(*) begin
        in1 = cond_snza ? Aout :
            cond_snzs ? shiftOut :
            Aout;

        in2 = (cond_snza || cond_snzs) ? ACCout : Bout;
    end

endmodule


module ENABLE_ACC_MUX(
    input wire  _AND, _OR, _XOR, _INV, _ADDin, _SUB, _CLR,
    output wire enableACC
);
    assign enableACC = _CLR || _ADDin || _SUB || _AND ||  _OR || _XOR || _INV;  // alu needs to be enabled usign the relevant instruction

endmodule

