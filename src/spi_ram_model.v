// spi_ram_model.v
// Simple behavioural SPI RAM model (READ 0x03 only).
// Mode 0: sample MOSI on rising edge, change MISO on falling edge.

`timescale 1ns/1ps

module spi_ram_model #(
    parameter MEM_BYTES = 256
)(
    input  wire cs_n,
    input  wire sck,
    input  wire mosi,
    output reg  miso
);
    // Internal memory
    reg [7:0] mem [0:MEM_BYTES-1];

    // Internal state
    localparam ST_CMD     = 2'd0;
    localparam ST_ADDR_HI = 2'd1;
    localparam ST_ADDR_LO = 2'd2;
    localparam ST_DATA    = 2'd3;

    reg [1:0]  state;
    reg [7:0]  in_shift;
    reg [2:0]  rx_cnt;       // 0..7 within a byte
    reg [7:0]  cmd;
    reg [15:0] addr;
    reg [7:0]  out_shift;

    // Reset state whenever CS goes high (end of transaction)
    always @(posedge cs_n) begin
        state    <= ST_CMD;
        in_shift <= 8'h00;
        rx_cnt   <= 3'd0;
        cmd      <= 8'h00;
        addr     <= 16'h0000;
        out_shift<= 8'h00;
        miso     <= 1'b0;
    end

    // Receive command and address on rising edge of SCK
    always @(posedge sck) begin
        if (!cs_n) begin
            in_shift <= {in_shift[6:0], mosi};
            rx_cnt   <= rx_cnt + 3'd1;

            if (rx_cnt == 3'd7) begin
                // Just received a full byte
                case (state)
                    ST_CMD: begin
                        cmd   <= {in_shift[6:0], mosi};
                        state <= ST_ADDR_HI;
                    end
                    ST_ADDR_HI: begin
                        addr[15:8] <= {in_shift[6:0], mosi};
                        state      <= ST_ADDR_LO;
                    end
                    ST_ADDR_LO: begin
                        addr[7:0]  <= {in_shift[6:0], mosi};
                        state      <= ST_DATA;
                        // Prepare the data byte to send
                        out_shift  <= mem[{in_shift[6:0], mosi} % MEM_BYTES];
                    end
                    default: ; // ignore
                endcase
                rx_cnt <= 3'd0;
            end
        end
    end

    // Drive MISO on falling edge of SCK in data phase
    always @(negedge sck) begin
        if (!cs_n) begin
            if (state == ST_DATA && cmd == 8'h03) begin
                // Output MSB first
                miso      <= out_shift[7];
                out_shift <= {out_shift[6:0], 1'b0};
                // We only care about the first 8 bits; master stops after 1 byte
            end else begin
                miso <= 1'b0;
            end
        end
    end

endmodule
