# RISC-V RV32I Mini-SoC with AMBA APB UART IP Core

[![Simulation](https://img.shields.io/badge/Simulation-100%25%20PASSED-brightgreen.svg?style=for-the-badge&logo=checkmarx)](https://github.com/lytuannghi)
[![ISA](https://img.shields.io/badge/ISA-RISC--V%20RV32I-blue.svg?style=for-the-badge)](https://riscv.org/)
[![Bus Protocol](https://img.shields.io/badge/Bus-AMBA%203%20APB-orange.svg?style=for-the-badge)](https://developer.arm.com/)
[![Multi-Agent AI](https://img.shields.io/badge/Design-7--Agent%20Autonomous%20Flow-purple.svg?style=for-the-badge)](https://github.com/lytuannghi)

A complete synthesizable **RISC-V RV32I Embedded System-on-Chip (SoC)** featuring:
- **Processor:** 32-bit RISC-V RV32I Core with 32 general-purpose registers (`x0-x31`) and ALU.
- **Memory Architecture:** 1 KB Instruction Boot ROM and 1 KB Data SRAM.
- **Bus System:** Memory-Mapped Interconnect and AMBA APB Master Bridge.
- **Peripheral:** Industrial APB UART Controller with independent 16-deep FIFOs.
- **Firmware:** Bare-metal assembly program computing Fibonacci numbers and streaming `"HELLO RISC-V!"` across the serial interface.

Designed and verified by **Lý Tuấn Nghi ([@lytuannghi](https://github.com/lytuannghi))** and the **7-Agent Autonomous SoC Team**.

---

## SoC Hardware Architecture

```mermaid
flowchart TD
    subgraph RISC_V_MINI_SOC
        CPU["RISC-V RV32I Core\n- 32x32-bit Regfile (x0-x31)\n- ALU & Branch Unit\n- PC Controller"]
        INTERCONNECT["SoC Bus Interconnect\n- Memory Address Decoder\n- APB Protocol Bridge"]
        ROM["Boot ROM (1 KB)\n- Firmware Machine Code"]
        RAM["Data SRAM (1 KB)\n- Scratchpad Memory"]
        UART["APB UART Controller IP\n- TX/RX FIFOs (16-deep)\n- 16x Oversampling Baud Gen\n- TX & RX Serial Engines"]
    end

    CPU <==>|Instruction Bus| INTERCONNECT
    CPU <==>|Data Bus & Stalls| INTERCONNECT
    INTERCONNECT <==> ROM
    INTERCONNECT <==> RAM
    INTERCONNECT <==>|AMBA APB Signals\nPSEL, PENABLE, PWRITE, PADDR, PWDATA, PRDATA, PREADY| UART
    UART --> UART_TXD["UART_TXD (Serial Output)"]
    UART_RXD["UART_RXD (Serial Input)"] --> UART
```

---

## Verification & Co-Simulation Results

```text
========================================================
 STARTING RISC-V MINI-SOC AUTOMATED VERIFICATION
========================================================
  CPU Reset Released. Fetching instructions from ROM...
 UART CONSOLE OUTPUT: HELLO RISC-V!
--------------------------------------------------------
 VERIFYING ON-CHIP DATA MEMORY (RAM):
 [PASS] Fibonacci Sequence in RAM: F(7) = 13 Verified!
 [PASS] Firmware Completion Signature Verified (0x12345678)!
 [PASS] UART Serial Transmission Verified (Received 13 characters)!
========================================================
 STATUS: 100% RISC-V SOC VERIFICATION PASSED!
========================================================
```

---

## Quickstart

```powershell
# Run the complete hardware/software co-simulation
python run_soc_flow.py

# View simulation waveforms
gtkwave output/waveform.vcd
```
