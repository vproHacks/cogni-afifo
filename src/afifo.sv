// ============================================================================
// Asynchronous FIFO for Clock Domain Crossing
// ============================================================================
// Based on Cliff Cummings' design methodology
// Features:
//   - Gray code pointer synchronization
//   - Two-stage flip-flop synchronizers
//   - Parameterized depth and data width
//   - Full metastability protection
// ============================================================================

module afifo #(
    parameter DSIZE = 8,      // Data width
    parameter ASIZE = 4       // Address width (depth = 2^ASIZE)
)(
    // Write clock domain
    input  wire                 i_wclk,
    input  wire                 i_wrst_n,
    input  wire                 i_wr,
    input  wire [DSIZE-1:0]     i_wdata,
    output reg                  o_wfull,
    
    // Read clock domain
    input  wire                 i_rclk,
    input  wire                 i_rrst_n,
    input  wire                 i_rd,
    output wire [DSIZE-1:0]     o_rdata,
    output reg                  o_rempty
);

    // ========================================================================
    // Internal Signal Declarations
    // ========================================================================
    
    // Binary pointers (ASIZE+1 bits for full/empty distinction)
    reg  [ASIZE:0]  wbin, wbin_next;
    reg  [ASIZE:0]  rbin, rbin_next;
    
    // Gray code pointers
    reg  [ASIZE:0]  wgray, wgray_next;
    reg  [ASIZE:0]  rgray, rgray_next;
    
    // Synchronized Gray pointers (2-stage synchronizers)
    reg  [ASIZE:0]  wq2_rgray, wq1_rgray;  // Read pointer sync'd to write domain
    reg  [ASIZE:0]  rq2_wgray, rq1_wgray;  // Write pointer sync'd to read domain
    
    // Memory write enable
    wire            wen;
    
    // ========================================================================
    // Dual-Port RAM (FIFO Memory)
    // ========================================================================
    
    reg [DSIZE-1:0] mem [0:(1<<ASIZE)-1];
    
    // Write operation
    assign wen = i_wr & ~o_wfull;
    
    always @(posedge i_wclk) begin
        if (wen)
            mem[wbin[ASIZE-1:0]] <= i_wdata;
    end
    
    // Read operation (combinational read)
    assign o_rdata = mem[rbin[ASIZE-1:0]];
    
    // ========================================================================
    // Write Clock Domain Logic
    // ========================================================================
    
    // Write pointer increment
    assign wbin_next = wbin + (wen ? 1'b1 : 1'b0);
    
    // Binary to Gray conversion for write pointer
    assign wgray_next = wbin_next ^ (wbin_next >> 1);
    
    // Write pointer and Gray code register
    always @(posedge i_wclk or negedge i_wrst_n) begin
        if (!i_wrst_n) begin
            wbin  <= {(ASIZE+1){1'b0}};
            wgray <= {(ASIZE+1){1'b0}};
        end else begin
            wbin  <= wbin_next;
            wgray <= wgray_next;
        end
    end
    
    // Synchronize read pointer into write clock domain (2-stage synchronizer)
    always @(posedge i_wclk or negedge i_wrst_n) begin
        if (!i_wrst_n) begin
            wq1_rgray <= {(ASIZE+1){1'b0}};
            wq2_rgray <= {(ASIZE+1){1'b0}};
        end else begin
            wq1_rgray <= rgray;
            wq2_rgray <= wq1_rgray;
        end
    end
    
    // Full flag generation
    // Full when: MSB bits differ, all other bits match
    always @(posedge i_wclk or negedge i_wrst_n) begin
        if (!i_wrst_n)
            o_wfull <= 1'b0;
        else
            o_wfull <= (wgray_next[ASIZE]     != wq2_rgray[ASIZE]  ) &&
                       (wgray_next[ASIZE-1]   != wq2_rgray[ASIZE-1]) &&
                       (wgray_next[ASIZE-2:0] == wq2_rgray[ASIZE-2:0]);
    end
    
    // ========================================================================
    // Read Clock Domain Logic
    // ========================================================================
    
    // Read pointer increment
    wire ren;
    assign ren = i_rd & ~o_rempty;
    assign rbin_next = rbin + (ren ? 1'b1 : 1'b0);
    
    // Binary to Gray conversion for read pointer
    assign rgray_next = rbin_next ^ (rbin_next >> 1);
    
    // Read pointer and Gray code register
    always @(posedge i_rclk or negedge i_rrst_n) begin
        if (!i_rrst_n) begin
            rbin  <= {(ASIZE+1){1'b0}};
            rgray <= {(ASIZE+1){1'b0}};
        end else begin
            rbin  <= rbin_next;
            rgray <= rgray_next;
        end
    end
    
    // Synchronize write pointer into read clock domain (2-stage synchronizer)
    always @(posedge i_rclk or negedge i_rrst_n) begin
        if (!i_rrst_n) begin
            rq1_wgray <= {(ASIZE+1){1'b0}};
            rq2_wgray <= {(ASIZE+1){1'b0}};
        end else begin
            rq1_wgray <= wgray;
            rq2_wgray <= rq1_wgray;
        end
    end
    
    // Empty flag generation
    // Empty when read and write Gray pointers are equal
    always @(posedge i_rclk or negedge i_rrst_n) begin
        if (!i_rrst_n)
            o_rempty <= 1'b1;  // Start empty
        else
            o_rempty <= (rgray_next == rq2_wgray);
    end

endmodule
