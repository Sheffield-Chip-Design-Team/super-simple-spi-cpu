// spi_cpu.v
// 8-bit CPU with instructions fetched from external SPI RAM

module spi_cpu (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [7:0] in_port,    // not used yet, but ready for IN instruction later
    output reg  [7:0] out_port,   // what we show on uo_out

    // SPI interface to external RAM (RP2040 emu)
    output wire       spi_cs_n,
    output wire       spi_sck,
    output wire       spi_mosi,
    input  wire       spi_miso
);

    // --- CPU state / registers ---
    reg [3:0] pc;         // 4-bit program counter = 16 instructions
    reg [7:0] A;          // accumulator
    reg       Z;          // zero flag

    reg [7:0] data_ram [0:15];  // small internal data RAM

    reg [7:0] instr;      // current instruction byte
    wire [3:0] opcode = instr[7:4];
    wire [3:0] operand = instr[3:0];

    integer i;

    // --- SPI reader wires ---
    reg        spi_start;
    reg [15:0] spi_addr;
    wire       spi_busy;
    wire       spi_done;
    wire [7:0] spi_data;

    // Instruction fetch address mapping:
    // here we just map PC to low bits of the address (0x0000..0x000F)
    always @* begin
        spi_addr = {12'h000, pc};  // 0x0000 + PC
    end

    spi_read_byte spi_if (
        .clk     (clk),
        .rst_n   (rst_n),
        .start   (spi_start),
        .addr    (spi_addr),
        .busy    (spi_busy),
        .done    (spi_done),
        .data_out(spi_data),
        .cs_n    (spi_cs_n),
        .sck     (spi_sck),
        .mosi    (spi_mosi),
        .miso    (spi_miso)
    );

    // --- CPU FSM: fetch via SPI, then execute ---

    localparam S_RESET       = 2'd0;
    localparam S_FETCH_START = 2'd1;
    localparam S_FETCH_WAIT  = 2'd2;
    localparam S_EXECUTE     = 2'd3;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_RESET;
            pc       <= 4'h0;
            A        <= 8'h00;
            Z        <= 1'b0;
            out_port <= 8'h00;
            spi_start <= 1'b0;

            for (i = 0; i < 16; i = i + 1) begin
                data_ram[i] <= 8'h00;
            end
        end else if (ena) begin
            // default each cycle
            spi_start <= 1'b0;

            case (state)
                //-----------------------
                S_RESET: begin
                    pc    <= 4'h0;
                    state <= S_FETCH_START;
                end

                //-----------------------
                // Ask SPI to fetch instr at address spi_addr
                S_FETCH_START: begin
                    if (!spi_busy) begin
                        spi_start <= 1'b1;   // one-cycle pulse
                        state     <= S_FETCH_WAIT;
                    end
                end

                //-----------------------
                // Wait until spi_read_byte says data_out is valid
                S_FETCH_WAIT: begin
                    if (spi_done) begin
                        instr <= spi_data;
                        state <= S_EXECUTE;
                    end
                end

                //-----------------------
                // Execute one instruction, then go back to fetch next
                S_EXECUTE: begin
                    // default: increment PC
                    pc <= pc + 4'd1;

                    case (opcode)
                        4'h0: begin
                            // NOP
                        end

                        4'h1: begin
                            // LDI imm4
                            A <= {4'b0000, operand};
                            Z <= (operand == 4'b0000);
                        end

                        4'h2: begin
                            // ADDI imm4
                            reg [7:0] tmp;
                            tmp = A + {4'b0000, operand};
                            A   <= tmp;
                            Z   <= (tmp == 8'h00);
                        end

                        4'h3: begin
                            // SUBI imm4
                            reg [7:0] tmp;
                            tmp = A - {4'b0000, operand};
                            A   <= tmp;
                            Z   <= (tmp == 8'h00);
                        end

                        4'h4: begin
                            // LDA addr
                            A <= data_ram[operand];
                            Z <= (data_ram[operand] == 8'h00);
                        end

                        4'h5: begin
                            // STA addr
                            data_ram[operand] <= A;
                        end

                        4'h6: begin
                            // JMP addr
                            pc <= operand;
                        end

                        4'h7: begin
                            // JZ addr
                            if (Z) begin
                                pc <= operand;
                            end
                        end

                        4'h8: begin
                            // OUT
                            out_port <= A;
                        end

                        default: begin
                            // treat others as NOP
                        end
                    endcase

                    // After execute, go fetch next instruction
                    state <= S_FETCH_START;
                end

                default: state <= S_RESET;
            endcase
        end
    end

endmodule
