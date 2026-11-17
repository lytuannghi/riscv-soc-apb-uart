// ============================================================================
// File Name: soc_interconnect.v
// Module: soc_interconnect
// Description: Memory Interconnect & APB Bridge for RISC-V Mini-SoC.
// Author: Lý Tuấn Nghi (lytuannghi) & 7-Agent SoC Engineering Team
// ============================================================================

`timescale 1ns / 1ps

module soc_interconnect (
    input  wire        clk,
    input  wire        rst_n,

    // CPU Instruction Bus
    input  wire [31:0] cpu_instr_addr,
    output wire [31:0] cpu_instr_data,

    // CPU Data Bus
    input  wire [31:0] cpu_data_addr,
    input  wire [31:0] cpu_data_wdata,
    input  wire [3:0]  cpu_data_wstrb,
    input  wire        cpu_data_we,
    input  wire        cpu_data_req,
    output reg  [31:0] cpu_data_rdata,
    output reg         cpu_data_ready,

    // APB Slave Peripheral Interface (UART)
    output wire [3:0]  apb_paddr,
    output reg         apb_psel,
    output reg         apb_penable,
    output wire        apb_pwrite,
    output wire [31:0] apb_pwdata,
    input  wire [31:0] apb_prdata,
    input  wire        apb_pready
);

    // -------------------------------------------------------------------------
    // Address Decoding Map
    // 0x0000_0000 - 0x0000_03FF: Instruction ROM (1 KB)
    // 0x0000_0400 - 0x0000_07FF: Data RAM (1 KB)
    // 0x8000_0000 - 0x8000_000F: APB UART Peripheral
    // -------------------------------------------------------------------------
    wire is_ram = (cpu_data_addr >= 32'h0000_0400 && cpu_data_addr < 32'h0000_0800);
    wire is_apb = (cpu_data_addr[31] == 1'b1); // 0x8000_0000 region

    // -------------------------------------------------------------------------
    // 1. Instruction ROM (256 words x 32-bit = 1 KB)
    // -------------------------------------------------------------------------
    reg [31:0] rom [0:255];
    wire [7:0] rom_addr = cpu_instr_addr[9:2]; // Word-aligned address

    integer i;
    initial begin
        // Initialize with default NOPs
        for (i = 0; i < 256; i = i + 1) rom[i] = 32'h00000013; // NOP (addi x0, x0, 0)
        // Load machine code from firmware hex file
        $readmemh("D:/CODE/GGANTIGRAVITY/riscv-soc-apb-uart/firmware/boot_firmware.hex", rom);
    end

    assign cpu_instr_data = rom[rom_addr];

    // -------------------------------------------------------------------------
    // 2. Data RAM (256 words x 32-bit = 1 KB)
    // -------------------------------------------------------------------------
    reg [31:0] ram [0:255];
    wire [7:0] ram_addr = cpu_data_addr[9:2];

    always @(posedge clk) begin
        if (cpu_data_req && is_ram && cpu_data_we) begin
            if (cpu_data_wstrb[0]) ram[ram_addr][7:0]   <= cpu_data_wdata[7:0];
            if (cpu_data_wstrb[1]) ram[ram_addr][15:8]  <= cpu_data_wdata[15:8];
            if (cpu_data_wstrb[2]) ram[ram_addr][23:16] <= cpu_data_wdata[23:16];
            if (cpu_data_wstrb[3]) ram[ram_addr][31:24] <= cpu_data_wdata[31:24];
        end
    end

    wire [31:0] ram_rdata = ram[ram_addr];

    // -------------------------------------------------------------------------
    // 3. APB Master State Machine (Converts CPU bus to APB protocol)
    // -------------------------------------------------------------------------
    localparam APB_IDLE   = 2'b00;
    localparam APB_SETUP  = 2'b01;
    localparam APB_ACCESS = 2'b10;

    reg [1:0] apb_state;

    assign apb_paddr  = cpu_data_addr[3:0];
    assign apb_pwrite = cpu_data_we;
    assign apb_pwdata = cpu_data_wdata;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            apb_state   <= APB_IDLE;
            apb_psel    <= 1'b0;
            apb_penable <= 1'b0;
        end else begin
            case (apb_state)
                APB_IDLE: begin
                    apb_penable <= 1'b0;
                    if (cpu_data_req && is_apb) begin
                        apb_psel  <= 1'b1;
                        apb_state <= APB_SETUP;
                    end else begin
                        apb_psel <= 1'b0;
                    end
                end

                APB_SETUP: begin
                    apb_penable <= 1'b1; // Enter Access Phase
                    apb_state   <= APB_ACCESS;
                end

                APB_ACCESS: begin
                    if (apb_pready) begin
                        apb_psel    <= 1'b0;
                        apb_penable <= 1'b0;
                        apb_state   <= APB_IDLE;
                    end
                end

                default: apb_state <= APB_IDLE;
            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Response Multiplexer to CPU
    // -------------------------------------------------------------------------
    always @(*) begin
        if (is_ram) begin
            cpu_data_rdata = ram_rdata;
            cpu_data_ready = 1'b1; // Zero-wait-state RAM
        end else if (is_apb) begin
            cpu_data_rdata = apb_prdata;
            cpu_data_ready = (apb_state == APB_ACCESS && apb_pready);
        end else begin
            cpu_data_rdata = 32'd0;
            cpu_data_ready = 1'b1;
        end
    end

endmodule
