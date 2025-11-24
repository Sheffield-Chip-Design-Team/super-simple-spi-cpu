`default_nettype none

module ProgramROMtest #(
    parameter ADDR_WIDTH = 8
)(
    input  wire [ADDR_WIDTH-1:0] addressIn,
    output reg  [3:0]            dataOut
);

    always @(*) begin
        case (addressIn)
            0:  dataOut = 4'b0000;  // LDA
            1:  dataOut = 4'b0001;  // LDB
            2:  dataOut = 4'b0100;  // LDSB
            3:  dataOut = 4'b0110;  // RSH
            4:  dataOut = 4'b1000;  // SNZ A
            5:  dataOut = 4'b0110;  // RSH
            6:  dataOut = 4'b0011;  // LDSA
            7:  dataOut = 4'b0101;  // LSH
            8:  dataOut = 4'b1001;  // SNZ S
            9:  dataOut = 4'b0100;  // LDSB
            10: dataOut = 4'b0110;  // RSH
            11: dataOut = 4'b0110;  // RSH
            12: dataOut = 4'b0110;  // RSH
            13: dataOut = 4'b0011;  // LDSA
            14: dataOut = 4'b0101;  // LSH
            15: dataOut = 4'b0101;  // LSH
            16: dataOut = 4'b1001;  // SNZ S
            17: dataOut = 4'b0100;  // LDSB
            18: dataOut = 4'b0110;  // RSH
            19: dataOut = 4'b0110;  // RSH
            20: dataOut = 4'b0110;  // RSH
            21: dataOut = 4'b0110;  // RSH
            22: dataOut = 4'b0011;  // LDSA
            23: dataOut = 4'b0101;  // LSH
            24: dataOut = 4'b0101;  // LSH
            25: dataOut = 4'b0101;  // LSH
            26: dataOut = 4'b1001;  // SNZS
            27: dataOut = 4'b0010;  // LDO
            28: dataOut = 4'b0111;  // CLR
            29: dataOut = 4'b0111;  // CLR
            30: dataOut = 4'b0111;  // CLR
            31: dataOut = 4'b0111;  // CLR
            default: dataOut = 4'b0111; // CLR - basically a NOP operation.
        endcase
    end 

endmodule

`default_nettype wire
