// ============================================================================
// File Name: apb_uart_top.v
// Module: apb_uart_top
// Description: Top-Level Integration of Industrial APB UART Controller with FIFO.
// Author: Lý Tuấn Nghi (lytuannghi) & Multi-Agent IC Design Team
// ============================================================================

`timescale 1ns / 1ps

module apb_uart_top (
    // AMBA 3 APB Bus Interface
    input  wire        pclk,
    input  wire        preset_n,
    input  wire [3:0]  paddr,
    input  wire        psel,
    input  wire        penable,
    input  wire        pwrite,
    input  wire [31:0] pwdata,
    output wire [31:0] prdata,
    output wire        pready,
    output wire        pslverr,

    // Serial Pins
    output wire        uart_txd,
    input  wire        uart_rxd,

    // Interrupt
    output wire        uart_interrupt
);

    // Internal wires
    wire [15:0] reg_baud_div;
    wire [7:0]  reg_ctrl;
    wire [7:0]  reg_status;

    wire        rx_tick, tx_tick;

    // FIFO Connections
    wire        tx_fifo_wr_en;
    wire [7:0]  tx_fifo_wr_data;
    wire        tx_fifo_rd_en;
    wire [7:0]  tx_fifo_rd_data;
    wire        tx_fifo_full, tx_fifo_empty;
    wire        tx_fifo_overflow, tx_fifo_underflow;

    wire        rx_fifo_wr_en;
    wire [7:0]  rx_fifo_wr_data;
    wire        rx_fifo_rd_en;
    wire [7:0]  rx_fifo_rd_data;
    wire        rx_fifo_full, rx_fifo_empty;
    wire        rx_fifo_overflow, rx_fifo_underflow;

    // UART Engine wires
    wire        raw_txd;
    wire        tx_busy, tx_done;
    wire        rx_busy, rx_done, frame_err;
    wire [7:0]  rx_byte;

    // Loopback multiplexer: When reg_ctrl[4] = 1, internally route TX to RX
    wire effective_rxd = reg_ctrl[4] ? raw_txd : uart_rxd;
    assign uart_txd    = raw_txd;

    // Status Register bits:
    // [0]: TX FIFO Empty
    // [1]: TX FIFO Full
    // [2]: RX FIFO Ready (Not Empty)
    // [3]: RX FIFO Full
    // [4]: TX Transmitter Busy
    // [5]: Overrun Error (TX or RX overflow)
    assign reg_status = {
        2'b00,
        (tx_fifo_overflow || rx_fifo_overflow),
        tx_busy,
        rx_fifo_full,
        !rx_fifo_empty,
        tx_fifo_full,
        tx_fifo_empty
    };

    // 1. APB Slave & Register Bank
    apb_slave_regs u_apb_slave (
        .pclk            (pclk),
        .preset_n        (preset_n),
        .paddr           (paddr),
        .psel            (psel),
        .penable         (penable),
        .pwrite          (pwrite),
        .pwdata          (pwdata),
        .prdata          (prdata),
        .pready          (pready),
        .pslverr         (pslverr),
        .reg_baud_div    (reg_baud_div),
        .reg_ctrl        (reg_ctrl),
        .reg_status      (reg_status),
        .tx_fifo_wr_en   (tx_fifo_wr_en),
        .tx_fifo_wr_data (tx_fifo_wr_data),
        .rx_fifo_rd_en   (rx_fifo_rd_en),
        .rx_fifo_rd_data (rx_fifo_rd_data),
        .uart_interrupt  (uart_interrupt)
    );

    // 2. Transmit (TX) FIFO
    fifo_sync #(.DATA_WIDTH(8), .FIFO_DEPTH(16), .ADDR_WIDTH(4)) u_tx_fifo (
        .clk       (pclk),
        .rst_n     (preset_n),
        .wr_en     (tx_fifo_wr_en),
        .wr_data   (tx_fifo_wr_data),
        .rd_en     (tx_fifo_rd_en),
        .rd_data   (tx_fifo_rd_data),
        .full      (tx_fifo_full),
        .empty     (tx_fifo_empty),
        .count     (),
        .overflow  (tx_fifo_overflow),
        .underflow (tx_fifo_underflow)
    );

    // 3. Receive (RX) FIFO
    fifo_sync #(.DATA_WIDTH(8), .FIFO_DEPTH(16), .ADDR_WIDTH(4)) u_rx_fifo (
        .clk       (pclk),
        .rst_n     (preset_n),
        .wr_en     (rx_done),
        .wr_data   (rx_byte),
        .rd_en     (rx_fifo_rd_en),
        .rd_data   (rx_fifo_rd_data),
        .full      (rx_fifo_full),
        .empty     (rx_fifo_empty),
        .count     (),
        .overflow  (rx_fifo_overflow),
        .underflow (rx_fifo_underflow)
    );

    // 4. Baudrate Generator
    baudrate_gen u_baud_gen (
        .clk      (pclk),
        .rst_n    (preset_n),
        .baud_div (reg_baud_div),
        .rx_tick  (rx_tick),
        .tx_tick  (tx_tick)
    );

    // 5. UART Transmitter Core
    // Auto-pop TX FIFO when transmitter is idle, TX is enabled, and FIFO has pending data
    reg tx_trigger;
    always @(posedge pclk or negedge preset_n) begin
        if (!preset_n) begin
            tx_trigger <= 1'b0;
        end else begin
            if (reg_ctrl[0] && !tx_busy && !tx_fifo_empty && !tx_trigger) begin
                tx_trigger <= 1'b1;
            end else begin
                tx_trigger <= 1'b0;
            end
        end
    end
    assign tx_fifo_rd_en = tx_trigger;

    uart_tx u_uart_tx (
        .clk       (pclk),
        .rst_n     (preset_n),
        .tx_tick   (tx_tick),
        .tx_start  (tx_trigger),
        .tx_data   (tx_fifo_rd_data),
        .tx_enable (reg_ctrl[0]),
        .txd       (raw_txd),
        .tx_busy   (tx_busy),
        .tx_done   (tx_done)
    );

    // 6. UART Receiver Core
    uart_rx u_uart_rx (
        .clk       (pclk),
        .rst_n     (preset_n),
        .rx_tick   (rx_tick),
        .rxd       (effective_rxd),
        .rx_enable (reg_ctrl[1]),
        .rx_data   (rx_byte),
        .rx_done   (rx_done),
        .rx_busy   (rx_busy),
        .frame_err (frame_err)
    );

endmodule
