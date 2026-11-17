# 🏗️ RISC-V RV32I Mini-SoC with AMBA APB UART IP - Architecture Specification

**Author:** Lý Tuấn Nghi ([@lytuannghi](https://github.com/lytuannghi))  
**Design Role:** SoC Architect & IC Design Lead  
**EDA Platform:** Icarus Verilog + VVP + WaveTrace / Surfer VCD Viewer  

---

## 1. System Overview
The **RISC-V Mini-SoC** is a complete synthesizable embedded System-on-Chip (SoC) designed for micro-controller workloads. It brings together an open-standard RV32I processor core with an AMBA APB peripheral infrastructure and high-throughput on-chip memory.

Key features:
- **Processor:** 32-bit RISC-V RV32I Core with 32 registers (`x0-x31`), full ALU, conditional branching, and multi-cycle synchronous stall interface.
- **Interconnect:** Address-decoding memory crossbar converting CPU memory requests into SRAM access or AMBA 3 APB transfers.
- **Memory Subsystem:**
  - `0x0000_0000 - 0x0000_03FF`: 1 KB Instruction Boot ROM (Loaded with RV32I machine code).
  - `0x0000_0400 - 0x0000_07FF`: 1 KB Scratchpad Data RAM (Zero-wait-state synchronous write, asynchronous read).
- **Peripheral:** Memory-Mapped AMBA 3 APB UART Controller (`0x8000_0000 - 0x8000_000F`) featuring independent 16-deep FIFOs and a 16x oversampled baud rate generator.

---

## 2. Address Memory Map

| Address Range | Device / Block | Size | Access | Description |
| :---: | :---: | :---: | :---: | :--- |
| `0x0000_0000 - 0x0000_03FF` | **Boot ROM** | 1 KB (256x32) | R | Preloaded with bare-metal bootloader and application hex. |
| `0x0000_0400 - 0x0000_07FF` | **Data RAM** | 1 KB (256x32) | R/W | Scratchpad SRAM for local computation, variables, and stack. |
| `0x8000_0000` | **UART_DATA** | 4 B | R/W | Transmit FIFO Write / Receive FIFO Read buffer. |
| `0x8000_0004` | **UART_STATUS**| 4 B | R | Flags: `[0]` TX Empty, `[1]` TX Full, `[2]` RX Ready, `[4]` TX Busy. |
| `0x8000_0008` | **UART_CTRL**  | 4 B | R/W | Control: `[0]` TX Enable, `[1]` RX Enable, `[4]` Loopback mode. |
| `0x8000_000C` | **UART_BAUD**  | 4 B | R/W | 16-bit Divisor: $f_{baud} = \frac{f_{clk}}{16 \times \text{baud\_div}}$. |

---

## 3. Core Microarchitecture

### 3.1 RV32I Execution Engine
The processor core implements the unprivileged RV32I specification:
1. **Instruction Fetch (IF):** Instructions are fetched from Boot ROM addressed by the Program Counter (`PC`).
2. **Instruction Decode (ID):** Combinational decoding of opcode, funct3, funct7, source/destination registers (`rs1`, `rs2`, `rd`), and immediate sign extensions (`I`, `S`, `B`, `U`, `J` types).
3. **Execution & ALU:** Computes arithmetic/logical operations (`ADD`, `SUB`, `SLL`, `SLT`, `SLTU`, `XOR`, `SRL`, `SRA`, `OR`, `AND`, `LUI`).
4. **Memory / Stall Interface:** Handles Load/Store operations. Fast SRAM accesses complete in zero wait-states; APB peripheral operations dynamically stall the CPU via `data_req` and `data_ready` handshaking.

### 3.2 APB Bridge Protocol State Machine
The on-chip interconnect translates CPU memory-mapped reads and writes to the peripheral region into standard AMBA 3 APB protocol phases:
1. **IDLE:** Bus is inactive (`PSEL = 0, PENABLE = 0`).
2. **SETUP:** Upon CPU request to `0x8000_xxxx`, `PSEL` asserts high while `PADDR` and `PWDATA` stabilize.
3. **ACCESS:** Next cycle, `PENABLE` asserts high. When `PREADY` is returned by the slave, data is latched, and CPU `data_ready` is asserted.

---

## 4. Hardware/Software Co-Verification Results

During automated co-simulation, the core boots from ROM and performs:
1. UART initialization (`baud_div = 2`, `tx_en = 1`).
2. Calculation of Fibonacci sequence $F(0) \dots F(7) = 13$ stored directly into Data RAM.
3. Writing `"HELLO RISC-V!"` character-by-character into the UART TX FIFO.
4. Writing completion signature `0x12345678` into `RAM[16]`.

```text
========================================================
🚀 STARTING RISC-V MINI-SOC AUTOMATED VERIFICATION
========================================================
ℹ️  CPU Reset Released. Fetching instructions from ROM...
📡 UART CONSOLE OUTPUT: HELLO RISC-V!
--------------------------------------------------------
📊 VERIFYING ON-CHIP DATA MEMORY (RAM):
✅ [PASS] Fibonacci Sequence in RAM: F(7) = 13 Verified!
✅ [PASS] Firmware Completion Signature Verified (0x12345678)!
✅ [PASS] UART Serial Transmission Verified (Transmitted 13 characters)!
========================================================
🏆 STATUS: 100% RISC-V SOC VERIFICATION PASSED!
========================================================
```
