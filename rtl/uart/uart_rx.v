// ============================================================================
// File Name: uart_rx.v
// Module: uart_rx
// Description: UART Receiver with 16x oversampling and middle-bit sampling.
// Author: Lý Tuấn Nghi (lytuannghi) & Multi-Agent IC Design Team
// ============================================================================

`timescale 1ns / 1ps

module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_tick,      // 16x oversampling tick
    input  wire       rxd,          // Serial input pin
    input  wire       rx_enable,    // Module enable
    output reg  [7:0] rx_data,      // Received byte
    output reg        rx_done,      // Pulse when byte received
    output reg        rx_busy,      // Receiver active
    output reg        frame_err     // Framing error (Stop bit wasn't high)
);

    localparam STATE_IDLE  = 2'b00;
    localparam STATE_START = 2'b01;
    localparam STATE_DATA  = 2'b10;
    localparam STATE_STOP  = 2'b11;

    // 2-stage synchronizer for meta-stability avoidance
    reg rxd_sync1, rxd_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rxd_sync1 <= 1'b1;
            rxd_sync2 <= 1'b1;
        end else begin
            rxd_sync1 <= rxd;
            rxd_sync2 <= rxd_sync1;
        end
    end

    reg [1:0] state;
    reg [3:0] tick_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= STATE_IDLE;
            tick_cnt  <= 4'd0;
            bit_idx   <= 3'd0;
            shift_reg <= 8'd0;
            rx_data   <= 8'd0;
            rx_done   <= 1'b0;
            rx_busy   <= 1'b0;
            frame_err <= 1'b0;
        end else begin
            rx_done <= 1'b0;

            case (state)
                STATE_IDLE: begin
                    rx_busy   <= 1'b0;
                    tick_cnt  <= 4'd0;
                    bit_idx   <= 3'd0;
                    if (!rxd_sync2 && rx_enable) begin // Start bit detected (Falling edge)
                        rx_busy <= 1'b1;
                        state   <= STATE_START;
                    end
                end

                STATE_START: begin
                    if (rx_tick) begin
                        if (tick_cnt == 4'd7) begin // Sample at middle of start bit
                            if (!rxd_sync2) begin   // Valid start bit
                                tick_cnt <= 4'd0;
                                state    <= STATE_DATA;
                            end else begin          // Glitch, return to idle
                                state <= STATE_IDLE;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STATE_DATA: begin
                    if (rx_tick) begin
                        if (tick_cnt == 4'd15) begin // Middle of data bit
                            tick_cnt             <= 4'd0;
                            shift_reg[bit_idx]   <= rxd_sync2;
                            if (bit_idx == 3'd7) begin
                                state <= STATE_STOP;
                            end else begin
                                bit_idx <= bit_idx + 1'b1;
                            end
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                STATE_STOP: begin
                    if (rx_tick) begin
                        if (tick_cnt == 4'd15) begin // Middle of stop bit
                            rx_data   <= shift_reg;
                            rx_done   <= 1'b1;
                            frame_err <= !rxd_sync2; // Stop bit must be 1
                            state     <= STATE_IDLE;
                        end else begin
                            tick_cnt <= tick_cnt + 1'b1;
                        end
                    end
                end

                default: state <= STATE_IDLE;
            endcase
        end
    end

endmodule
