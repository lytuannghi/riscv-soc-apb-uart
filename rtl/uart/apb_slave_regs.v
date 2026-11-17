// ============================================================================
// File Name: apb_slave_regs.v
// Module: apb_slave_regs
// Description: AMBA 3 APB Slave Interface & Memory-Mapped Register Bank.
// Author: Lý Tuấn Nghi (lytuannghi) & Multi-Agent IC Design Team
// ============================================================================

`timescale 1ns / 1ps

module apb_slave_regs (
    input  wire        pclk,
    input  wire        preset_n,
    input  wire [3:0]  paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output reg  [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Internal Register Signals
    output reg  [15:0] reg_baud_div,
    output reg  [7:0]  reg_ctrl,        // [0] tx_en, [1] rx_en, [4] loopback
    input  wire [7:0]  reg_status,      // [0] tx_empty, [1] tx_full, [2] rx_ready, [3] rx_full, [4] tx_busy, [5] overrun

    // FIFO Interface
    output reg         tx_fifo_wr_en,
    output reg  [7:0]  tx_fifo_wr_data,
    output reg         rx_fifo_rd_en,
    input  wire [7:0]  rx_fifo_rd_data,

    // Interrupt
    output wire        uart_interrupt
);

    assign pready  = 1'b1;  // Single-cycle zero wait state APB transfer
    assign pslverr = 1'b0;  // No slave error

    wire apb_write_en = psel && penable && pwrite;
    wire apb_read_en  = psel && !pwrite; // Read phase

    // Register Offsets
    localparam ADDR_DATA   = 4'h0;
    localparam ADDR_STATUS = 4'h4;
    localparam ADDR_CTRL   = 4'h8;
    localparam ADDR_BAUD   = 4'hC;

    // Interrupt asserts if RX has data ready or TX is empty and enabled
    assign uart_interrupt = reg_status[2] || (reg_status[0] && reg_ctrl[0]);

    // APB Write Transfers
    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            reg_baud_div    <= 16'd27;   // Default divisor (~115200 baud for 50MHz / 16)
            reg_ctrl        <= 8'h03;    // Default: TX & RX enabled (bits [1:0] = 2'b11)
            tx_fifo_wr_en   <= 1'b0;
            tx_fifo_wr_data <= 8'h00;
        end else begin
            tx_fifo_wr_en <= 1'b0; // Default single pulse

            if (apb_write_en) begin
                case (paddr)
                    ADDR_DATA: begin
                        tx_fifo_wr_en   <= 1'b1;
                        tx_fifo_wr_data <= pwdata[7:0];
                    end
                    ADDR_CTRL: begin
                        reg_ctrl <= pwdata[7:0];
                    end
                    ADDR_BAUD: begin
                        reg_baud_div <= pwdata[15:0];
                    end
                    default: ;
                endcase
            end
        end
    end

    // APB Read Transfers & FIFO Pop
    always @(*) begin
        rx_fifo_rd_en = 1'b0;
        prdata        = 32'h0;

        if (psel && penable && !pwrite) begin
            case (paddr)
                ADDR_DATA: begin
                    prdata        = {24'h0, rx_fifo_rd_data};
                    rx_fifo_rd_en = 1'b1; // Pop byte on read
                end
                ADDR_STATUS: begin
                    prdata = {24'h0, reg_status};
                end
                ADDR_CTRL: begin
                    prdata = {24'h0, reg_ctrl};
                end
                ADDR_BAUD: begin
                    prdata = {16'h0, reg_baud_div};
                end
                default: prdata = 32'h0;
            endcase
        end
    end

endmodule
