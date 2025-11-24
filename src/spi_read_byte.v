// spi_read_byte.v
// Read exactly one byte from 23LC512-style SPI RAM.
// Command 0x03 + 16-bit address, then read 8 bits of data.

module spi_read_byte (
    input  wire        clk,
    input  wire        rst_n,

    // Control from CPU
    input  wire        start,      // pulse / level, ignored when busy
    input  wire [15:0] addr,       // address in external RAM

    // Status back to CPU
    output reg         busy,       // 1 while transaction in progress
    output reg         done,       // 1 for one clk when data_out is valid
    output reg  [7:0]  data_out,   // received byte

    // SPI signals
    output reg         cs_n,       // active-low chip select
    output reg         sck,        // SPI clock (mode 0)
    output reg         mosi,       // master-out
    input  wire        miso        // master-in
);


    // States
    localparam ST_IDLE  = 2'd0;
    localparam ST_SEND  = 2'd1;
    localparam ST_RECV  = 2'd2;
    localparam ST_DONE  = 2'd3;

    reg [1:0]  state;
    reg        phase;          // 0: SCK low phase, 1: SCK high phase

    reg [23:0] shift_out;      // 0x03 + addr[15:0]
    reg [7:0]  shift_in;       // incoming byte
    reg [4:0]  bit_count;      // fits 24 or 8

    wire clk_buf =  clk;
    
    always @(posedge clk) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            phase     <= 1'b0;
            cs_n      <= 1'b1;
            sck       <= 1'b0;
            mosi      <= 1'b0;
            busy      <= 1'b0;
            done      <= 1'b0;
            data_out  <= 8'h00;
            shift_out <= 24'h000000;
            shift_in  <= 8'h00;
            bit_count <= 5'd0;
        end else begin
            // default
            done <= 1'b0;

            case (state)
                // ------------------------------------------------------
                ST_IDLE: begin
                    busy  <= 1'b0;
                    cs_n  <= 1'b1;
                    sck   <= 1'b0;
                    phase <= 1'b0;

                    if (start) begin
                        // latch command + address
                        shift_out <= {8'h03, addr};
                        bit_count <= 5'd24;
                        shift_in  <= 8'h00;
                        cs_n      <= 1'b0;
                        busy      <= 1'b1;
                        state     <= ST_SEND;
                    end
                end

                // ------------------------------------------------------
                // Send 24 bits: command + address, MSB first
                // phase 0: SCK low, drive MOSI
                // phase 1: SCK high, then shift
                // ------------------------------------------------------
                ST_SEND: begin
                    if (phase == 1'b0) begin
                        // low phase
                        sck  <= 1'b0;
                        mosi <= shift_out[23];
                        phase <= 1'b1;
                    end else begin
                        // high phase
                        sck   <= 1'b1;
                        phase <= 1'b0;

                        shift_out <= {shift_out[22:0], 1'b0};

                        if (bit_count == 5'd1) begin
                            // last bit just sent
                            bit_count <= 5'd8; // prepare to receive 8 bits
                            state     <= ST_RECV;
                        end else begin
                            bit_count <= bit_count - 5'd1;
                        end
                    end
                end

                // ------------------------------------------------------
                // Receive 8 bits on MISO
                // phase 0: SCK low
                // phase 1: SCK high, sample MISO
                // ------------------------------------------------------
                ST_RECV: begin
                    if (phase == 1'b0) begin
                        sck   <= 1'b0;
                        mosi  <= 1'b0;  // don't care
                        phase <= 1'b1;
                    end else begin
                        sck   <= 1'b1;
                        phase <= 1'b0;

                        // sample MISO at rising edge
                        shift_in <= {shift_in[6:0], miso};

                        if (bit_count == 5'd1) begin
                            data_out <= {shift_in[6:0], miso};
                            state    <= ST_DONE;
                        end else begin
                            bit_count <= bit_count - 5'd1;
                        end
                    end
                end

                // ------------------------------------------------------
                ST_DONE: begin
                    cs_n  <= 1'b1;
                    sck   <= 1'b0;
                    busy  <= 1'b0;
                    done  <= 1'b1; // one-cycle pulse
                    state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
