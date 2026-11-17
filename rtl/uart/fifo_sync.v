// ============================================================================
// File Name: fifo_sync.v
// Module: fifo_sync
// Description: Synchronous FIFO with FWFT (First-Word Fall-Through) and sticky flags.
// Author: Lý Tuấn Nghi (lytuannghi) & Multi-Agent IC Design Team
// ============================================================================

`timescale 1ns / 1ps

module fifo_sync #(
    parameter DATA_WIDTH = 8,
    parameter FIFO_DEPTH = 16,
    parameter ADDR_WIDTH = 4  // 2^4 = 16
)(
    input  wire                  clk,
    input  wire                  rst_n,      // Active Low Asynchronous Reset
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  full,
    output wire                  empty,
    output reg  [ADDR_WIDTH:0]   count,
    output reg                   overflow,
    output reg                   underflow
);

    reg [DATA_WIDTH-1:0] mem [0:FIFO_DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_ptr;
    reg [ADDR_WIDTH-1:0] rd_ptr;

    assign full  = (count == FIFO_DEPTH);
    assign empty = (count == 0);

    // FWFT (First-Word Fall-Through): Read data is immediately available from memory
    assign rd_data = empty ? {DATA_WIDTH{1'b0}} : mem[rd_ptr];

    // Write Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_ptr   <= 0;
            overflow <= 1'b0;
        end else begin
            if (wr_en && !full) begin
                mem[wr_ptr] <= wr_data;
                wr_ptr      <= wr_ptr + 1'b1;
            end else if (wr_en && full) begin
                overflow    <= 1'b1; // Sticky overflow flag
            end else if (rd_en) begin
                overflow    <= 1'b0; // Clear on pop
            end
        end
    end

    // Read Pointer Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_ptr    <= 0;
            underflow <= 1'b0;
        end else begin
            if (rd_en && !empty) begin
                rd_ptr    <= rd_ptr + 1'b1;
            end else if (rd_en && empty) begin
                underflow <= 1'b1;
            end else if (wr_en) begin
                underflow <= 1'b0;
            end
        end
    end

    // FIFO Count Tracker
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= 0;
        end else begin
            case ({wr_en && !full, rd_en && !empty})
                2'b10: count <= count + 1'b1;
                2'b01: count <= count - 1'b1;
                default: count <= count; // Simultaneous read & write or no-op
            endcase
        end
    end

endmodule
