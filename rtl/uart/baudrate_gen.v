// ============================================================================
// File Name: baudrate_gen.v
// Module: baudrate_gen
// Description: Baud rate generator producing 16x oversampling tick and 1x TX tick.
// Author: Lý Tuấn Nghi (lytuannghi) & Multi-Agent IC Design Team
// ============================================================================

`timescale 1ns / 1ps

module baudrate_gen (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] baud_div,   // Divisor value
    output reg         rx_tick,    // 16x oversampling pulse
    output reg         tx_tick     // 1x baud pulse
);

    reg [15:0] count;
    reg [3:0]  tx_div16;

    // Generate rx_tick (at 16x the target baud rate)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count   <= 16'd0;
            rx_tick <= 1'b0;
        end else if (baud_div == 16'd0) begin
            count   <= 16'd0;
            rx_tick <= 1'b0;
        end else begin
            if (count >= baud_div - 1'b1) begin
                count   <= 16'd0;
                rx_tick <= 1'b1;
            end else begin
                count   <= count + 1'b1;
                rx_tick <= 1'b0;
            end
        end
    end

    // Divide rx_tick by 16 to produce 1x tx_tick
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tx_div16 <= 4'd0;
            tx_tick  <= 1'b0;
        end else if (rx_tick) begin
            if (tx_div16 == 4'd15) begin
                tx_div16 <= 4'd0;
                tx_tick  <= 1'b1;
            end else begin
                tx_div16 <= tx_div16 + 1'b1;
                tx_tick  <= 1'b0;
            end
        end else begin
            tx_tick <= 1'b0;
        end
    end

endmodule
