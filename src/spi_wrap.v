// spi_wrap.v
// 4-bit CPU with instructions fetched from external SPI RAM

module spi_wrap (
    input  wire       clk,
    input  wire       rst_n,
    output wire [7:0] out_port,   // what we show on uo_out

    // SPI interface to external RAM (RP2040 emu)
    output wire       spi_cs_n,
    output wire       spi_sck,
    output wire       spi_mosi,
    input  wire       spi_miso
);

    // CPU state / registers
    reg [11:0] pc;        // 12-bit program counter 
    reg [3:0] opcode;
    reg [7:0] operand;
    reg [7:0] cpu_out;

    integer i;

    // SPI reader wires 
    reg        spi_start;
    reg [15:0] spi_addr;
    wire       spi_busy;
    wire       spi_done;
    wire [7:0] spi_data;

    // Instruction fetch address mapping:
    // here we just map PC to low bits of the address (0x0000..0x000F)
    always @* begin
        spi_addr = {4'h00, pc};  // 0x0000 + PC
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

    // fetch via SPI, then execute

    localparam S_RESET               = 3'd0;
    localparam S_FETCH_START         = 3'd1;
    localparam S_FETCH_WAIT_OPCODE   = 3'd2;
    localparam S_FETCH_WAIT_OPERAND  = 3'd3;
    localparam S_EXECUTE             = 3'd4;
    localparam S_VALID               = 3'd5;

    reg [2:0] state;
    reg valid;

    // SPI FSM - 2-stage fetch opcode then data

    always @(posedge clk) begin

        if (!rst_n) begin
            state    <= S_RESET;
            spi_start <= 1'b0;
            pc        <= 0;
        end 
        
        else begin
            // default each cycle
            spi_start <= 1'b0;
            valid       <= 1'b0;

            case (state)
                
                S_RESET: begin
                    state <= S_FETCH_START;
                end

                // Ask SPI to fetch instr at address spi_addr
                S_FETCH_START: begin
                    if (!spi_busy) begin
                        spi_start <= 1'b1;   // one-cycle pulse
                        state     <= S_FETCH_WAIT_OPCODE;
                    end
                end

                // Wait until spi_read_byte says data_out is valid
                S_FETCH_WAIT_OPCODE: begin
                    if (spi_done) begin
                        spi_start <= 1'b1;   // one-cycle pulse
                        opcode    <= spi_data[3:0];
                        state     <= S_FETCH_WAIT_OPERAND;
                    end
                end

                S_FETCH_WAIT_OPERAND: begin
                    if (spi_done) begin
                        operand <= spi_data; // 2 x 4-bit operands
                        state <= S_EXECUTE;
                        valid <= 1'b1;
                    end
                end

                // Execute one instruction, then go back to fetch next
                S_EXECUTE: begin
                    state <= S_FETCH_START;
                    pc <= pc + 1;
                end

                default: state <= S_RESET;
            endcase
        end
    end

    ExecutionUnit core (
        .clk(clk),
        .reset(!rst_n),
        .valid(valid),
        .pc(pc),
        .opcode(opcode),
        .operand(operand),
        .cpuOut(out_port)
    );

endmodule
