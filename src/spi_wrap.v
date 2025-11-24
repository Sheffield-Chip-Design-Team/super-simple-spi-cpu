// spi_wrap.v
// 4-bit CPU with instructions fetched from external SPI RAM

module spi_wrap (
    input  wire       clk,
    input  wire       rst_n,
    input wire  [7:0] in_port,    // input port (from ui_in)
    output wire [7:0] out_port,   // what we show on uo_out
    output wire       valid,

    // SPI interface to external RAM (RP2040 emu)
    output wire       spi_cs_n,
    output wire       spi_sck,
    output wire       spi_mosi,
    input  wire       spi_miso
);

    // manual clock buffering to limit fanout
    (*keep*) wire clk_fsm = clk;
    (*keep*) wire clk_cpu = clk;
    (*keep*) wire clk_spi = clk;
    (*keep*) wire clk_status = clk;

    // CPU state / registers
    reg [11:0] pc;              // 12-bit program counter 
    reg [7:0] opcode_cache;
    reg [3:0] opcode1, opcode2;
    reg [3:0] curr_opcode;
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
        .clk     (clk_spi),
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
    localparam S_EXECUTE_1           = 3'd3;
    localparam S_EXECUTE_2           = 3'd4;

    reg [2:0] state;
    reg cpu_start;
    reg cpu_valid;

    // SPI FSM - fetch 2 opcodes and then execute both before fetching the next ones
    always @(posedge clk_fsm) begin
        if (!rst_n) begin
            state    <= S_RESET;
            spi_start <= 1'b0;
            cpu_start <= 1'b0;
            pc        <= 0;
            opcode1   <= 4'b0111;
            opcode2   <= 4'b0111;
            curr_opcode <= 4'b0111;
        end 
        
        else begin
            // default each cycle
            spi_start   <= 1'b0;
            cpu_start   <= 1'b0;
            case (state)
                
                S_RESET: begin
                    state <= S_FETCH_START;
                end

                // Ask SPI to fetch instr at address spi_addr (2 instructions per byte)
                S_FETCH_START: begin
                    if (!spi_busy) begin
                        spi_start <= 1'b1;   // one-cycle pulse
                        state     <= S_FETCH_WAIT_OPCODE;
                    end
                end

                // Wait until spi_read_byte says data_out is valid
                S_FETCH_WAIT_OPCODE: begin
                    if (spi_done) begin
                        spi_start <= 1'b1; // one-cycle pulse
                        opcode1   <= spi_data[3:0];
                        opcode2   <= spi_data[7:4];
                        state     <= S_EXECUTE_1;
                    end
                end

                // Execute first opcode
                S_EXECUTE_1: begin
                    cpu_start   <= 1'b1; 
                    curr_opcode <= opcode1;
                    state       <= S_EXECUTE_2;
                end

                // Execute second opcode
                S_EXECUTE_2: begin
                    cpu_start   <= 1'b1;
                    curr_opcode <= opcode2;
                    // increment the pc
                    pc          <= pc + 1;
                    state       <= S_FETCH_START;
                end
                
                default: state <= S_RESET;
            endcase
        end
    end

    always @(posedge clk_status) begin
        if (!rst_n) begin
           cpu_valid <= 0;
        end 

        cpu_valid <= cpu_start;
    end

    ExecutionUnit core (
        .clk(clk_cpu),
        .reset(!rst_n),
        .start(cpu_start),
        .opcode(curr_opcode),
        .operand(in_port),
        .cpuOut(out_port)
    );

    assign valid = cpu_valid;

endmodule
