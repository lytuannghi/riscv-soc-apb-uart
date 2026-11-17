// ============================================================================
// File Name: riscv_regfile.v
// Module: riscv_regfile
// Description: 32x32-bit Register File for RISC-V RV32I with x0 tied to 0.
// Author: Lý Tuấn Nghi (lytuannghi) & 7-Agent SoC Engineering Team
// ============================================================================

`timescale 1ns / 1ps

module riscv_regfile (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [4:0]  raddr1,
    output wire [31:0] rdata1,
    input  wire [4:0]  raddr2,
    output wire [31:0] rdata2,
    input  wire        we,
    input  wire [4:0]  waddr,
    input  wire [31:0] wdata
);

    reg [31:0] regs [0:31];
    integer i;

    // Asynchronous Read with x0 hardwired to 0
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];

    // Synchronous Write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 32; i = i + 1) begin
                regs[i] <= 32'd0;
            end
        end else if (we && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

endmodule
