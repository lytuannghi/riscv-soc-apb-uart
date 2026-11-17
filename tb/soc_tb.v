// ============================================================================
// File Name: soc_tb.v
// Module: soc_tb
// Description: Complete Self-Checking Verification Testbench for RISC-V Mini-SoC.
// Author: Lý Tuấn Nghi (lytuannghi) & 7-Agent SoC Engineering Team
// ============================================================================

`timescale 1ns / 1ps

module soc_tb;

    reg clk = 1'b0;
    reg rst_n = 1'b0;
    wire uart_txd;
    reg  uart_rxd = 1'b1;
    wire uart_interrupt;

    // Instantiate Mini-SoC Top
    soc_top u_soc (
        .clk            (clk),
        .rst_n          (rst_n),
        .uart_txd       (uart_txd),
        .uart_rxd       (uart_rxd),
        .uart_interrupt (uart_interrupt)
    );

    // Clock generator: 50 MHz (20ns period)
    always #10 clk = ~clk;

    // -------------------------------------------------------------------------
    // Synchronous UART Monitor: Tracks TX FIFO pops directly & prints chars
    // -------------------------------------------------------------------------
    integer char_count = 0;
    always @(posedge clk) begin
        if (rst_n && u_soc.u_uart.tx_trigger) begin
            $write("%c", u_soc.u_uart.tx_fifo_rd_data);
            $fflush();
            char_count = char_count + 1;
        end
    end

    // -------------------------------------------------------------------------
    // Simulation Flow & Verification
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("D:/CODE/GGANTIGRAVITY/minipj/output/riscv_soc_waveform.vcd");
        $dumpvars(2, soc_tb);

        $display("\n========================================================");
        $display("🚀 STARTING RISC-V MINI-SOC AUTOMATED VERIFICATION");
        $display("========================================================");

        // Reset Sequence
        #50 rst_n = 1'b1;
        $display("ℹ️  CPU Reset Released. Fetching instructions from ROM...");
        $write("📡 UART CONSOLE OUTPUT: ");
        $fflush();

        // Run simulation for 120,000 ns (6,000 clock cycles)
        // Enough time for all 13 characters to transmit (13 * 6.4us = ~83us)
        #120000;

        $display("\n--------------------------------------------------------");
        $display("📊 VERIFYING ON-CHIP DATA MEMORY (RAM):");
        
        // Inspect Fibonacci results stored in Data RAM:
        // u_soc.u_interconnect.ram[0] = F0 = 0
        // u_soc.u_interconnect.ram[1] = F1 = 1
        // u_soc.u_interconnect.ram[7] = F7 = 13 (0x0D)
        if (u_soc.u_interconnect.ram[7] == 32'd13) begin
            $display("✅ [PASS] Fibonacci Sequence in RAM: F(7) = 13 Verified!");
        end else begin
            $display("❌ [FAIL] Fibonacci mismatch! Expected 13, Got %0d", u_soc.u_interconnect.ram[7]);
        end

        // Verify completion signature in RAM: 0x440 (word index 16 = 0x10) = 0x12345678
        if (u_soc.u_interconnect.ram[16] == 32'h12345678) begin
            $display("✅ [PASS] Firmware Completion Signature Verified (0x12345678)!");
        end else begin
            $display("❌ [FAIL] Completion signature mismatch! Got 0x%08X", u_soc.u_interconnect.ram[16]);
        end

        // Verify UART transmitted characters
        if (char_count >= 13) begin
            $display("✅ [PASS] UART Serial Transmission Verified (Transmitted %0d characters)!", char_count);
        end else begin
            $display("❌ [FAIL] Incomplete UART transmission! Transmitted %0d characters", char_count);
        end

        $display("========================================================");
        if (u_soc.u_interconnect.ram[7] == 32'd13 && u_soc.u_interconnect.ram[16] == 32'h12345678 && char_count >= 13) begin
            $display("🏆 STATUS: 100%% RISC-V SOC VERIFICATION PASSED!");
        end else begin
            $display("⚠️ STATUS: VERIFICATION FAILED!");
        end
        $display("========================================================\n");

        #100 $finish;
    end

endmodule
