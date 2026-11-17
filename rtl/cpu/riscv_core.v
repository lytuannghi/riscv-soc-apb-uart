// ============================================================================
// File Name: riscv_core.v
// Module: riscv_core
// Description: Synthesizable RISC-V RV32I Processor Core with Memory Stall support.
// Author: Lý Tuấn Nghi (lytuannghi) & 7-Agent SoC Engineering Team
// ============================================================================

`timescale 1ns / 1ps

module riscv_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction Memory Interface (ROM)
    output wire [31:0] instr_addr,
    input  wire [31:0] instr_data,

    // Data Memory / APB Interconnect Interface
    output wire [31:0] data_addr,
    output wire [31:0] data_wdata,
    output wire [3:0]  data_wstrb,   // Byte write strobe
    output wire        data_we,
    output wire        data_req,
    input  wire [31:0] data_rdata,
    input  wire        data_ready
);

    // CPU States
    localparam STATE_EXEC = 1'b0;
    localparam STATE_WAIT = 1'b1;

    reg state;
    reg [31:0] pc;
    wire [31:0] next_pc;

    assign instr_addr = pc;

    // -------------------------------------------------------------------------
    // Instruction Decoding
    // -------------------------------------------------------------------------
    wire [6:0] opcode = instr_data[6:0];
    wire [4:0] rd     = instr_data[11:7];
    wire [2:0] funct3 = instr_data[14:12];
    wire [4:0] rs1    = instr_data[19:15];
    wire [4:0] rs2    = instr_data[24:20];
    wire [6:0] funct7 = instr_data[31:25];

    // Immediate Formats
    wire [31:0] imm_i = {{20{instr_data[31]}}, instr_data[31:20]};
    wire [31:0] imm_s = {{20{instr_data[31]}}, instr_data[31:25], instr_data[11:7]};
    wire [31:0] imm_b = {{19{instr_data[31]}}, instr_data[31], instr_data[7], instr_data[30:25], instr_data[11:8], 1'b0};
    wire [31:0] imm_u = {instr_data[31:12], 12'b0};
    wire [31:0] imm_j = {{11{instr_data[31]}}, instr_data[31], instr_data[19:12], instr_data[20], instr_data[30:21], 1'b0};

    // Instruction Types
    wire is_r_type = (opcode == 7'b0110011);
    wire is_i_type = (opcode == 7'b0010011);
    wire is_load   = (opcode == 7'b0000011);
    wire is_store  = (opcode == 7'b0100011);
    wire is_branch = (opcode == 7'b1100011);
    wire is_jal    = (opcode == 7'b1101111);
    wire is_jalr   = (opcode == 7'b1100111);
    wire is_lui    = (opcode == 7'b0110111);
    wire is_auipc  = (opcode == 7'b0010111);

    // -------------------------------------------------------------------------
    // Register File Instance
    // -------------------------------------------------------------------------
    wire [31:0] reg_rdata1;
    wire [31:0] reg_rdata2;
    reg  [31:0] reg_wdata;
    reg         reg_we;

    riscv_regfile u_regfile (
        .clk    (clk),
        .rst_n  (rst_n),
        .raddr1 (rs1),
        .rdata1 (reg_rdata1),
        .raddr2 (rs2),
        .rdata2 (reg_rdata2),
        .we     (reg_we),
        .waddr  (rd),
        .wdata  (reg_wdata)
    );

    // -------------------------------------------------------------------------
    // ALU Control & Instance
    // -------------------------------------------------------------------------
    reg [3:0] alu_ctrl;
    always @(*) begin
        if (is_r_type) begin
            case (funct3)
                3'b000: alu_ctrl = (funct7[5]) ? 4'b0001 : 4'b0000; // SUB : ADD
                3'b001: alu_ctrl = 4'b0010; // SLL
                3'b010: alu_ctrl = 4'b0011; // SLT
                3'b011: alu_ctrl = 4'b0100; // SLTU
                3'b100: alu_ctrl = 4'b0101; // XOR
                3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRA : SRL
                3'b110: alu_ctrl = 4'b1000; // OR
                3'b111: alu_ctrl = 4'b1001; // AND
                default: alu_ctrl = 4'b0000;
            endcase
        end else if (is_i_type) begin
            case (funct3)
                3'b000: alu_ctrl = 4'b0000; // ADDI
                3'b001: alu_ctrl = 4'b0010; // SLLI
                3'b010: alu_ctrl = 4'b0011; // SLTI
                3'b011: alu_ctrl = 4'b0100; // SLTIU
                3'b100: alu_ctrl = 4'b0101; // XORI
                3'b101: alu_ctrl = (funct7[5]) ? 4'b0111 : 4'b0110; // SRAI : SRLI
                3'b110: alu_ctrl = 4'b1000; // ORI
                3'b111: alu_ctrl = 4'b1001; // ANDI
                default: alu_ctrl = 4'b0000;
            endcase
        end else if (is_load || is_store || is_jalr) begin
            alu_ctrl = 4'b0000; // ADD (Base + Offset)
        end else if (is_lui) begin
            alu_ctrl = 4'b1010; // LUI
        end else if (is_auipc) begin
            alu_ctrl = 4'b0000; // ADD (PC + Imm)
        end else begin
            alu_ctrl = 4'b0000;
        end
    end

    wire [31:0] alu_operand_a = (is_auipc) ? pc : reg_rdata1;
    wire [31:0] alu_operand_b = (is_r_type) ? reg_rdata2 :
                                (is_i_type || is_load || is_jalr) ? imm_i :
                                (is_store) ? imm_s :
                                (is_lui || is_auipc) ? imm_u : 32'd0;

    wire [31:0] alu_result;
    wire        alu_zero;
    wire        alu_less_than;

    riscv_alu u_alu (
        .a         (alu_operand_a),
        .b         (alu_operand_b),
        .alu_ctrl  (alu_ctrl),
        .result    (alu_result),
        .zero      (alu_zero),
        .less_than (alu_less_than)
    );

    // -------------------------------------------------------------------------
    // Branch Evaluation
    // -------------------------------------------------------------------------
    reg branch_taken;
    always @(*) begin
        if (is_branch) begin
            case (funct3)
                3'b000: branch_taken = (reg_rdata1 == reg_rdata2);                     // BEQ
                3'b001: branch_taken = (reg_rdata1 != reg_rdata2);                     // BNE
                3'b100: branch_taken = ($signed(reg_rdata1) < $signed(reg_rdata2));   // BLT
                3'b101: branch_taken = ($signed(reg_rdata1) >= $signed(reg_rdata2));  // BGE
                3'b110: branch_taken = (reg_rdata1 < reg_rdata2);                     // BLTU
                3'b111: branch_taken = (reg_rdata1 >= reg_rdata2);                    // BGEU
                default: branch_taken = 1'b0;
            endcase
        end else begin
            branch_taken = 1'b0;
        end
    end

    // Next PC calculation
    wire [31:0] pc_plus_4   = pc + 32'd4;
    wire [31:0] branch_target = pc + imm_b;
    wire [31:0] jal_target    = pc + imm_j;
    wire [31:0] jalr_target   = (reg_rdata1 + imm_i) & ~32'd1;

    assign next_pc = (is_branch && branch_taken) ? branch_target :
                     (is_jal)                     ? jal_target :
                     (is_jalr)                    ? jalr_target : pc_plus_4;

    // -------------------------------------------------------------------------
    // Memory Interface
    // -------------------------------------------------------------------------
    assign data_addr  = alu_result;
    assign data_wdata = reg_rdata2;
    assign data_wstrb = 4'b1111; // 32-bit word access
    assign data_req   = (state == STATE_EXEC) ? (is_load || is_store) :
                        (state == STATE_WAIT) ? 1'b1 : 1'b0;
    assign data_we    = is_store;

    // -------------------------------------------------------------------------
    // Execution State Machine & Register Writeback
    // -------------------------------------------------------------------------
    always @(*) begin
        reg_we    = 1'b0;
        reg_wdata = 32'd0;

        if (state == STATE_EXEC) begin
            if (is_r_type || is_i_type || is_lui || is_auipc) begin
                reg_we    = 1'b1;
                reg_wdata = alu_result;
            end else if (is_jal || is_jalr) begin
                reg_we    = 1'b1;
                reg_wdata = pc_plus_4;
            end
        end else if (state == STATE_WAIT) begin
            if (is_load && data_ready) begin
                reg_we    = 1'b1;
                reg_wdata = data_rdata;
            end
        end
    end

    // PC Update and State Transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc    <= 32'h0000_0000;
            state <= STATE_EXEC;
        end else begin
            case (state)
                STATE_EXEC: begin
                    if (is_load || is_store) begin
                        if (data_ready) begin
                            // Fast zero-wait response (RAM)
                            pc <= next_pc;
                        end else begin
                            // Multi-cycle access (e.g. APB Peripheral)
                            state <= STATE_WAIT;
                        end
                    end else begin
                        pc <= next_pc;
                    end
                end

                STATE_WAIT: begin
                    if (data_ready) begin
                        pc    <= next_pc;
                        state <= STATE_EXEC;
                    end
                end

                default: state <= STATE_EXEC;
            endcase
        end
    end

endmodule
