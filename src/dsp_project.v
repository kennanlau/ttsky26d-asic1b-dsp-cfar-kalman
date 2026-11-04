/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_dsp_top (
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
 // Example: ou_out is the sum of ui_in and uio_in
    wire [7:0] x1, x2, x3;
  assign uio_out = 0;
  assign uio_oe  = 0;
    // Delay line
    delay_line u_delay (
        .clk(clk),
        .rst(~rst_n),
        .din(ui_in),
        .x1(x1),
        .x2(x2),
        .x3(x3)
    );

    // FIR core
fir_core u_fir (
    .clk(clk),
    .rst(~rst_n),
    .din(ui_in),
    .x1(x1),
    .x2(x2),
    .x3(x3),
    .dout(uo_out)
);
wire _unused = &{uio_in, ena};
    
endmodule
