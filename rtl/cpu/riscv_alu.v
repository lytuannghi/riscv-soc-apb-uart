// ============================================================================
// File Name: riscv_alu.v
// Module: riscv_alu
// Description: Arithmetic Logic Unit for RISC-V RV32I Base Integer Instruction Set.
// Author: Lý Tuấn Nghi (lytuannghi) & 7-Agent SoC Engineering Team
// ============================================================================

`timescale 1ns / 1ps

module riscv_alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero,
    output wire        less_than
);

    // ALU Operations Encoding
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_SLL  = 4'b0010;
    localparam ALU_SLT  = 4'b0011; // Signed less than
    localparam ALU_SLTU = 4'b0100; // Unsigned less than
    localparam ALU_XOR  = 4'b0101;
    localparam ALU_SRL  = 4'b0110;
    localparam ALU_SRA  = 4'b0111; // Arithmetic right shift
    localparam ALU_OR   = 4'b1000;
    localparam ALU_AND  = 4'b1001;
    localparam ALU_LUI  = 4'b1010; // Pass B directly (Upper immediate)

    wire signed [31:0] signed_a = a;
    wire signed [31:0] signed_b = b;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_SLL:  result = a << b[4:0];
            ALU_SLT:  result = (signed_a < signed_b) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_XOR:  result = a ^ b;
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = signed_a >>> b[4:0];
            ALU_OR:   result = a | b;
            ALU_AND:  result = a & b;
            ALU_LUI:  result = b;
            default:  result = 32'd0;
        endcase
    end

    assign zero      = (result == 32'd0);
    assign less_than = result[0];

endmodule
