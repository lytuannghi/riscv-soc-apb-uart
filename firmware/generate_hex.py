# ============================================================================
# RISC-V RV32I Machine Code Generator for Mini-SoC Boot Firmware
# ============================================================================

def encode_r(funct7, rs2, rs1, funct3, rd, opcode):
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_i(imm, rs1, funct3, rd, opcode):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode

def encode_s(imm, rs2, rs1, funct3, opcode):
    imm11_5 = (imm >> 5) & 0x7F
    imm4_0  = imm & 0x1F
    return (imm11_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (imm4_0 << 7) | opcode

def encode_b(imm, rs2, rs1, funct3, opcode):
    b12   = (imm >> 12) & 1
    b10_5 = (imm >> 5) & 0x3F
    b4_1  = (imm >> 1) & 0xF
    b11   = (imm >> 11) & 1
    return (b12 << 31) | (b10_5 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (b4_1 << 8) | (b11 << 7) | opcode

def encode_u(imm20, rd, opcode):
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | opcode

def encode_j(imm, rd, opcode):
    j20   = (imm >> 20) & 1
    j10_1 = (imm >> 1) & 0x3FF
    j11   = (imm >> 11) & 1
    j19_12= (imm >> 12) & 0xFF
    return (j20 << 31) | (j10_1 << 21) | (j11 << 20) | (j19_12 << 12) | (rd << 7) | opcode

# Instructions
OP_LUI    = 0x37
OP_OP_IMM = 0x13
OP_STORE  = 0x23
OP_LOAD   = 0x03
OP_BRANCH = 0x63
OP_JAL    = 0x6F
OP_OP     = 0x33

instructions = [
    # 0x00: lui x1, 0x80000 (Base address of APB UART = 0x8000_0000)
    encode_u(0x80000, 1, OP_LUI),

    # 0x04: addi x2, x0, 2 (Baud divisor = 2)
    encode_i(2, 0, 0x0, 2, OP_OP_IMM),

    # 0x08: sw x2, 12(x1) (UART_BAUD at 0x8000_000C = 2)
    encode_s(12, 2, 1, 0x2, OP_STORE),

    # 0x0C: addi x2, x0, 1 (TX Enable = 1)
    encode_i(1, 0, 0x0, 2, OP_OP_IMM),

    # 0x10: sw x2, 8(x1) (UART_CTRL at 0x8000_0008 = 1)
    encode_s(8, 2, 1, 0x2, OP_STORE),

    # 0x14: addi x3, x0, 0x400 (Base address of RAM = 0x400)
    encode_i(0x400, 0, 0x0, 3, OP_OP_IMM),

    # 0x18: addi x4, x0, 0 (F0 = 0)
    encode_i(0, 0, 0x0, 4, OP_OP_IMM),

    # 0x1C: sw x4, 0(x3) (RAM[0] = 0)
    encode_s(0, 4, 3, 0x2, OP_STORE),

    # 0x20: addi x5, x0, 1 (F1 = 1)
    encode_i(1, 0, 0x0, 5, OP_OP_IMM),

    # 0x24: sw x5, 4(x3) (RAM[1] = 1)
    encode_s(4, 5, 3, 0x2, OP_STORE),

    # Compute F2 = F0 + F1 = 1
    # 0x28: add x6, x4, x5
    encode_r(0, 5, 4, 0x0, 6, OP_OP),
    # 0x2C: sw x6, 8(x3)
    encode_s(8, 6, 3, 0x2, OP_STORE),

    # Compute F3 = F1 + F2 = 2
    # 0x30: add x4, x5, x6
    encode_r(0, 6, 5, 0x0, 4, OP_OP),
    # 0x34: sw x4, 12(x3)
    encode_s(12, 4, 3, 0x2, OP_STORE),

    # Compute F4 = F2 + F3 = 3
    # 0x38: add x5, x6, x4
    encode_r(0, 4, 6, 0x0, 5, OP_OP),
    # 0x3C: sw x5, 16(x3)
    encode_s(16, 5, 3, 0x2, OP_STORE),

    # Compute F5 = F3 + F4 = 5
    # 0x40: add x6, x4, x5
    encode_r(0, 5, 4, 0x0, 6, OP_OP),
    # 0x44: sw x6, 20(x3)
    encode_s(20, 6, 3, 0x2, OP_STORE),

    # Compute F6 = F4 + F5 = 8
    # 0x48: add x4, x5, x6
    encode_r(0, 6, 5, 0x0, 4, OP_OP),
    # 0x4C: sw x4, 24(x3)
    encode_s(24, 4, 3, 0x2, OP_STORE),

    # Compute F7 = F5 + F6 = 13 (0xD)
    # 0x50: add x5, x6, x4
    encode_r(0, 4, 6, 0x0, 5, OP_OP),
    # 0x54: sw x5, 28(x3)
    encode_s(28, 5, 3, 0x2, OP_STORE),
]

# Transmit string "HELLO RISC-V!" (ASCII: 72, 69, 76, 76, 79, 32, 82, 73, 83, 67, 45, 86, 33)
message = "HELLO RISC-V!"
for char in message:
    ascii_val = ord(char)
    # addi x7, x0, ascii_val
    instructions.append(encode_i(ascii_val, 0, 0x0, 7, OP_OP_IMM))
    # sw x7, 0(x1) (UART_DATA write)
    instructions.append(encode_s(0, 7, 1, 0x2, OP_STORE))

# Write completion flag to RAM: 0x440 = 0x12345678 (Signature)
instructions.append(encode_u(0x12345, 8, OP_LUI))
instructions.append(encode_i(0x678, 8, 0x0, 8, OP_OP_IMM))
instructions.append(encode_s(0x40, 8, 3, 0x2, OP_STORE))

# Infinite loop: jal x0, 0 (j .)
instructions.append(encode_j(0, 0, OP_JAL))

# Pad to 256 words with NOP (addi x0, x0, 0)
while len(instructions) < 256:
    instructions.append(0x00000013)

with open("D:/CODE/GGANTIGRAVITY/riscv-soc-apb-uart/firmware/boot_firmware.hex", "w") as f:
    for instr in instructions:
        f.write(f"{instr:08x}\n")

print(f"Generated {len(instructions)} words to boot_firmware.hex")
