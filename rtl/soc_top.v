// ============================================================================
// File Name: soc_top.v
// Module: soc_top
// Description: Top-Level Mini-SoC integrating RISC-V RV32I Core, Interconnect, & APB UART.
// Author: Lý Tuấn Nghi (lytuannghi) & 7-Agent SoC Engineering Team
// ============================================================================

`timescale 1ns / 1ps

module soc_top (
    input  wire        clk,
    input  wire        rst_n,

    // External UART Pins
    output wire        uart_txd,
    input  wire        uart_rxd,

    // SoC Status Indicator
    output wire        uart_interrupt
);

    // CPU <-> Interconnect Wires
    wire [31:0] cpu_instr_addr;
    wire [31:0] cpu_instr_data;

    wire [31:0] cpu_data_addr;
    wire [31:0] cpu_data_wdata;
    wire [3:0]  cpu_data_wstrb;
    wire        cpu_data_we;
    wire        cpu_data_req;
    wire [31:0] cpu_data_rdata;
    wire        cpu_data_ready;

    // Interconnect <-> APB UART Wires
    wire [3:0]  apb_paddr;
    wire        apb_psel;
    wire        apb_penable;
    wire        apb_pwrite;
    wire [31:0] apb_pwdata;
    wire [31:0] apb_prdata;
    wire        apb_pready;
    wire        apb_pslverr;

    // -------------------------------------------------------------------------
    // 1. RISC-V RV32I Processor Core
    // -------------------------------------------------------------------------
    riscv_core u_cpu (
        .clk            (clk),
        .rst_n          (rst_n),
        .instr_addr     (cpu_instr_addr),
        .instr_data     (cpu_instr_data),
        .data_addr      (cpu_data_addr),
        .data_wdata     (cpu_data_wdata),
        .data_wstrb     (cpu_data_wstrb),
        .data_we        (cpu_data_we),
        .data_req       (cpu_data_req),
        .data_rdata     (cpu_data_rdata),
        .data_ready     (cpu_data_ready)
    );

    // -------------------------------------------------------------------------
    // 2. SoC Bus Interconnect (ROM + RAM + APB Bridge)
    // -------------------------------------------------------------------------
    soc_interconnect u_interconnect (
        .clk            (clk),
        .rst_n          (rst_n),
        .cpu_instr_addr (cpu_instr_addr),
        .cpu_instr_data (cpu_instr_data),
        .cpu_data_addr  (cpu_data_addr),
        .cpu_data_wdata (cpu_data_wdata),
        .cpu_data_wstrb (cpu_data_wstrb),
        .cpu_data_we    (cpu_data_we),
        .cpu_data_req   (cpu_data_req),
        .cpu_data_rdata (cpu_data_rdata),
        .cpu_data_ready (cpu_data_ready),
        .apb_paddr      (apb_paddr),
        .apb_psel       (apb_psel),
        .apb_penable    (apb_penable),
        .apb_pwrite     (apb_pwrite),
        .apb_pwdata     (apb_pwdata),
        .apb_prdata     (apb_prdata),
        .apb_pready     (apb_pready)
    );

    // -------------------------------------------------------------------------
    // 3. APB UART Peripheral IP Core
    // -------------------------------------------------------------------------
    apb_uart_top u_uart (
        .pclk           (clk),
        .preset_n       (rst_n),
        .paddr          (apb_paddr),
        .psel           (apb_psel),
        .penable        (apb_penable),
        .pwrite         (apb_pwrite),
        .pwdata         (apb_pwdata),
        .prdata         (apb_prdata),
        .pready         (apb_pready),
        .pslverr        (apb_pslverr),
        .uart_txd       (uart_txd),
        .uart_rxd       (uart_rxd),
        .uart_interrupt (uart_interrupt)
    );

endmodule
