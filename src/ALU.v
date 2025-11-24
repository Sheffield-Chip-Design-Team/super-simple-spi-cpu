// Arithmetic Logic Unit

// Arithmetic Unit Components
/*
               Arithmetic Unit
                /            \
            Adder         Subtractor
        
*/

module ArithmeticLogicUnit (
    input            ADD,
    input            SUB,
    input wire       AND,
    input wire       OR,
    input wire       XOR,
    input wire       INV,
    input wire       CLR,
    input wire [INPUT_DATA_WIDTH-1:0] in1,
    input wire [INPUT_DATA_WIDTH-1:0] in2, 
    output reg [INPUT_DATA_WIDTH-1:0] out,
    output reg       overflow

);
    parameter INPUT_DATA_WIDTH = 8;
    parameter LOGIC_DATA_WIDTH = 4;
    parameter ARITHMETIC_DATA_WIDTH = 8;

    wire [INPUT_DATA_WIDTH-1:0] adderOut, subtractorOut, arithmeticOut;
    wire adderOverflowFlag, subtractorOverflowFlag, arithmeticOverflowFlag;

    wire [LOGIC_DATA_WIDTH-1:0] andOut;
    wire [LOGIC_DATA_WIDTH-1:0] orOut;
    wire [LOGIC_DATA_WIDTH-1:0] xorOut;
    wire [LOGIC_DATA_WIDTH-1:0] notOut;


    combAdderSubtractor arithmeticUnit (in1, in2, SUB, arithmeticOut, arithmeticOverflowFlag);


    combAND And (in1[LOGIC_DATA_WIDTH-1:0],in2[LOGIC_DATA_WIDTH-1:0], andOut);
    combOR  Or  (in1[LOGIC_DATA_WIDTH-1:0],in2[LOGIC_DATA_WIDTH-1:0], orOut);
    combXOR Xor (in1[LOGIC_DATA_WIDTH-1:0],in2[LOGIC_DATA_WIDTH-1:0], xorOut);
    combINV Inv (in1[LOGIC_DATA_WIDTH-1:0], notOut);

    always @(*) begin // mux for control signals - assumes they won't be sent together
        
        out = 0; // is this correct?
        overflow = 0; // is this correct
        
        // Arithmetic Operations
        if (ADD || SUB) begin
            out = arithmeticOut;
            overflow = arithmeticOverflowFlag;
        end
        
        // Logic Operations
        else if (AND) begin
            out = andOut;
            overflow = 0; 
        end

        else if (OR) begin
            out = orOut;
            overflow = 0;
        end

        else if (XOR) begin
            out =  xorOut;
            overflow = 0;    
        end

        else if (INV) begin
            out = notOut;
            overflow = 0;    
        end

        else if (CLR) begin
            out =  0;
            overflow = 0;    
        end
            
     end
     
endmodule

module FullAdder (
    input wire in1,
    input wire in2,
    input wire carryIn,
    output  sum,
    output  carryOut
);
    assign {carryOut,sum} = in1 + in2; // behavioural description

endmodule

// paramatreized bus sizes for input/output

module combAdder (  // Conbinational, Behavioural Description
    input wire  [DATA_WIDTH - 1:0]  in1,
    input wire  [DATA_WIDTH - 1:0]  in2,
    output reg  [DATA_WIDTH - 1:0]  out,
    output reg                      overflow  
);
    parameter DATA_WIDTH  = 4; //4-bit by default;

    always @(*) begin
        {overflow, out} = in1 + in2;
    end

endmodule

module combSubtractor (  // Combinational - Behavioural Description
    input wire  [DATA_WIDTH - 1:0]  in1,
    input wire  [DATA_WIDTH - 1:0]  in2,
    output reg  [DATA_WIDTH - 1:0]  out,
    output reg                      overflow  
);
    parameter DATA_WIDTH  = 4; //4-bit by default;

    always @(*) begin
        {overflow, out} = in1 - in2;
    end

endmodule

module combAdderSubtractor( // optimised adder/subtractor
    input wire [DATA_WIDTH-1:0] in1, in2,
    input wire sub, 
    output wire [DATA_WIDTH-1:0] out,
    output wire overflow
);
    parameter DATA_WIDTH = 8;
    assign {overflow, out} = in1 + (sub ? (~in2 + 1) : in2); // Two's complement for subtraction
endmodule


// Logic Unit Components

/*             Logic Unit
           /    |      |     \  
         AND   OR     XOR    INV
*/

// 4-bit AND - combinational

module combAND(
    input wire  [DATA_WIDTH-1:0] in1, in2,
    output wire [DATA_WIDTH-1:0] out
);
    parameter DATA_WIDTH  = 4; //4-bit by default;
    assign out = in1 & in2;

endmodule 

// 4-bit OR - combinational
module combOR(
    input  wire [DATA_WIDTH-1:0] in1, in2,
    output wire [DATA_WIDTH-1:0] out
);
    parameter DATA_WIDTH  = 4; //4-bit by default;
    assign out = in1 | in2;

endmodule

//4 -bit XOR - combinational 
module combXOR (
    input wire  [DATA_WIDTH-1:0] in1, in2,
    output wire [DATA_WIDTH-1:0] out
);
    parameter DATA_WIDTH  = 4; //4-bit by default;
    assign out = in1 ^ in2;

endmodule 

//4 -bit XOR - combinational 
module combINV (
    input wire [DATA_WIDTH-1:0] in1, 
    output wire [DATA_WIDTH-1:0] out
);
    parameter DATA_WIDTH  = 4; //4-bit by default;
    assign out = ~in1;

endmodule 

