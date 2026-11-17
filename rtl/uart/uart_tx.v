// ============================================================================
// File Name: uart_tx.v
// Module: uart_tx
// Description: UART Transmitter FSM (1 Start bit, 8 Data bits, 1 Stop bit).
// Author: Lý Tuấn Nghi (lytuannghi) & Multi-Agent IC Design Team
// ============================================================================

`timescale 1ns / 1ps

module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       tx_tick,      // Baud rate tick (1x)
    input  wire       tx_start,     // Trigger transmit
    input  wire [7:0] tx_data,      // Byte to transmit
    input  wire       tx_enable,    // Module enable
    output reg        txd,          // Serial output pin
    output reg        tx_busy,      // High during active transmission
    output reg        tx_done       // Single-cycle pulse upon transmission complete
);

    localparam STATE_IDLE  = 3'b000;
    localparam STATE_START = 3'b001;
    localparam STATE_DATA  = 3'b010;
    localparam STATE_STOP  = 3'b011;
    localparam STATE_DONE  = 3'b100;

    reg [2:0] state;
    reg [2:0] bit_idx;
    reg [7:0] data_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= STATE_IDLE;
            txd      <= 1'b1; // UART idle line is high
            tx_busy  <= 1'b0;
            tx_done  <= 1'b0;
            bit_idx  <= 3'd0;
            data_reg <= 8'd0;
        end else begin
            tx_done <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    txd     <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start && tx_enable) begin
                        data_reg <= tx_data;
                        tx_busy  <= 1'b1;
                        state    <= STATE_START;
                    end
                end

                STATE_START: begin
                    txd <= 1'b0; // Drive Start Bit (Low)
                    if (tx_tick) begin
                        bit_idx <= 3'd0;
                        state   <= STATE_DATA;
                    end
                end

                STATE_DATA: begin
                    txd <= data_reg[bit_idx]; // LSB first
                    if (tx_tick) begin
                        if (bit_idx == 3'd7) begin
                            state <= STATE_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end
                end

                STATE_STOP: begin
                    txd <= 1'b1; // Stop bit (High)
                    if (tx_tick) begin
                        state <= STATE_DONE;
                    end
                end

                STATE_DONE: begin
                    tx_done <= 1'b1;
                    tx_busy <= 1'b0;
                    state   <= STATE_IDLE;
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
