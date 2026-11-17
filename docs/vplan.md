# 🎯 RISC-V Mini-SoC Verification Plan (vPlan)

**Author:** Lý Tuấn Nghi ([@lytuannghi](https://github.com/lytuannghi))  
**Role:** Design Verification (DV) Lead  
**Target:** 100% Functional & Hardware/Software Co-Verification Pass  

---

## 1. Scope & Verification Goals
- Verify RV32I Core instruction fetch, decoding, ALU execution, and register file updates.
- Verify zero-wait-state Data SRAM byte, half-word, and word read/write transactions.
- Verify AMBA 3 APB Bridge protocol state machine (`IDLE` $\rightarrow$ `SETUP` $\rightarrow$ `ACCESS`).
- Verify multi-cycle CPU stall handling (`data_req` and `data_ready` handshaking).
- Verify end-to-end bare-metal firmware execution: CPU boots from ROM, performs algorithmic computations in RAM, drives the UART IP, and enters a clean quiescent halt state.

---

## 2. Test Matrix & Verification Coverage

| Test ID | Feature Under Test | Stimulus & Firmware Sequence | Expected Outcome | Verification Status |
| :---: | :--- | :--- | :--- | :---: |
| **SOC_RST_01** | Power-On Reset | Assert `rst_n` low for 50ns, verify PC resets to `0x0000_0000`. | Core cleanly boots from address `0x0` | **PASS (100%)** |
| **SOC_RAM_01** | Data Memory Access | Store Fibonacci terms $F(0)$ to $F(7)$ into RAM sequentially. | `RAM[7] == 13` (`0x0D`) | **PASS (100%)** |
| **SOC_APB_01** | APB Bridge Protocol | CPU issues memory access to `0x8000_xxxx` address space. | `PSEL` and `PENABLE` pulse according to AMBA 3 spec | **PASS (100%)** |
| **SOC_STALL_01**| Multi-Cycle Stall | CPU stalls in `STATE_WAIT` during APB wait states. | `PC` freezes until `PREADY` asserts | **PASS (100%)** |
| **SOC_UART_01**| UART Baudrate Setting| CPU writes `baud_div = 2` to `UART_BAUD` (`0x8000_000C`). | Baud generator sets 640ns bit time | **PASS (100%)** |
| **SOC_UART_02**| UART Control Register| CPU writes `0x01` to `UART_CTRL` (`0x8000_0008`) to enable TX. | `reg_ctrl[0] == 1` | **PASS (100%)** |
| **SOC_UART_03**| String Serial Stream | CPU writes `"HELLO RISC-V!"` into `UART_DATA` (`0x8000_0000`). | 13 characters popped and transmitted | **PASS (100%)** |
| **SOC_DONE_01**| Completion Signature | CPU writes magic word `0x12345678` to `RAM[16]` (`0x0000_0440`). | RAM holds signature `0x12345678` | **PASS (100%)** |

---

## 3. Co-Simulation Execution Summary

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
- **Total Simulation Time:** 120,150 ns (~6,008 clock cycles).
- **Execution Run Time:** < 1.0 second under Icarus Verilog VVP engine.
- **Waveform File:** `riscv_soc_waveform.vcd` (188 KB, ready for GTKWave, WaveTrace, or Surfer).
