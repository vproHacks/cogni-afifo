/*
 * Copyright (c) 2025 Vraj
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_afifo (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // All output pins must be assigned. If not used, assign to 0.
  
  assign uio_oe = 8'b0000_0011; // set bidirectional as inputs/outputs
  assign uio_out[5:0] = 6'b0000_00; // set unused bidirectional outputs to LOW

  afifo #(
     .DSIZE(8),
     .ASIZE(4)
  ) U1 (
        .i_wclk(uio_in[0]), // Use I/O for these
        .i_wrst_n(uio_in[1]), // Use I/O for this
        .i_wr(uio_in[2]), // Use I/O for this

        .i_rclk(uio_in[3]), // Use I/O for these
        .i_rrst_n(uio_in[4]), // use I/O for these 
        .i_rd(uio_in[5]), // Use I/O for these

        .o_wfull(uio_out[6]), // Use I/O for these  
        .o_rempty(uio_out[7]), // Use I/O for these


        .i_wdata(ui_in[7:0]), // Full Input line
        .o_rdata(uo_out[7:0]) // Full Output line

  );

  // List all unused inputs to prevent warnings
  wire _unused = &{ena, 1'b0};

endmodule