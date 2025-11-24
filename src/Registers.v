
// Register File

module RegisterFile (
    input                      clk,
    input                      reset,
    input  [INPUT_WIDTH -1:0]  AIn,
    input  [INPUT_WIDTH -1:0]  BIn,
    input  [OUTPUT_WIDTH -1:0] OIn,
    input                      LDA,
    input                      LDB,
    input                      LDO,
    output [INPUT_WIDTH -1:0]  Aout,
    output [INPUT_WIDTH -1:0]  Bout,
    output [OUTPUT_WIDTH-1:0]  Oout
);

    parameter OUTPUT_WIDTH = 8;
    parameter INPUT_WIDTH = 4;

    // A register
    ResetEnableDFF RegA (clk, reset, LDA, AIn, Aout);
    defparam RegA.DATA_WIDTH = INPUT_WIDTH;
    
    // B register
    ResetEnableDFF RegB (clk, reset, LDB, BIn, Bout);
    defparam RegB.DATA_WIDTH = INPUT_WIDTH;

    // O register
    ResetEnableDFF RegO (clk, reset, LDO, OIn, Oout);
    defparam RegO.DATA_WIDTH = 8;


endmodule

// Register Templates - paramaterised data widths

module DFF (  // standard D-type Flip Flop 
    input wire   clk,
    input wire  [DATA_WIDTH-1:0]  D,
    output reg  [DATA_WIDTH-1:0]  Q
);
    parameter DATA_WIDTH  = 4;

    always @(posedge clk) begin
            Q <= D;
    end

endmodule

module EnableDFF (  // DFF with enable 
    input wire clk,
    input wire enable,
    input wire [DATA_WIDTH-1:0] D,
    output reg [DATA_WIDTH-1:0] Q
);
    parameter DATA_WIDTH  = 4;

    always @(posedge clk) begin
        if (enable) begin
            Q <= D;
        end 
    end

endmodule

module ResetEnableDFF ( // synchronous reset with enable
    input wire clk,
    input wire reset,
    input wire enable,
    input wire [DATA_WIDTH-1:0] D,
    output reg [DATA_WIDTH-1:0] Q
);

    parameter DATA_WIDTH = 4;

    always @(posedge clk) begin
        if (reset) begin // Reset should be checked first
            Q <= 0; 
        end else if (enable) begin // Only update if enabled
            Q <= D;
        end
    end

endmodule

module ResetDFF ( // synchronous reset, no enable
    input wire clk,
    input wire reset,
    input wire [DATA_WIDTH-1:0] D,
    output reg [DATA_WIDTH-1:0] Q
);
    parameter   DATA_WIDTH = 8;

    always @(posedge clk) begin
        if (~reset) begin
            Q <= D;
        end else begin // reset behaviour
            Q <= 0;
        end
    end

endmodule


module Counter (   // counter D-type Flip Flop 
    input wire  clk,
    input wire  reset,
    input wire  enable,
    output reg  [DATA_WIDTH-1:0]  Q
);
    parameter DATA_WIDTH  = 4;

    always @(posedge clk) begin
        if (reset) begin // Reset should be checked first
            Q <= 0; 
        end else if (enable) begin // Only update if enabled
            Q <= Q + 1;
        end
    end

endmodule

// Shift Register
// Enable DFF with shift functionalit - flag implimented for RSH underflow

module ShiftRegister (  // synchronous reset, with enable
    input wire       clk,
    input wire       reset,
    input wire [3:0] in,
    input wire       loadEnable,
    input wire [1:0] shiftState,
    output reg [7:0] out,
    output reg       flag
);

    always @(posedge clk) begin
       
       if (~reset) begin
            
               if (loadEnable) begin
                    out <= in;
                    flag <= flag;
                end

                else if (~loadEnable)begin
        
                    if (shiftState == 2'b10) begin   //LSH
                        out <=  out << 1;
                        flag <= flag;
                    end

                    else if (shiftState == 2'b01) begin // RSH
                        out <= {1'b0, out[3:1]};
                        flag <= out[0]; // LSB of RSH is the flag (underflow)
                    end

                    else if (~(shiftState[0] ^ shiftState[1])) begin // no instructino
                        out <= out;
                        flag <= flag;
                    end
                end

        end else begin// reset logic   
            out <= 0;
            flag <= 0;
        end

    end

endmodule