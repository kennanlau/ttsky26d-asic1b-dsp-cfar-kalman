/*
 * Copyright (c) 2026 Lars Nitschke
 * SPDX-License-Identifier: Apache-2.0
 *
 * Shift-add α multiplier and 19-bit comparison → det.
 * detect  ⟺  (CUT << 5) > K·V   (strict >; equality is not a detection)
 */

`default_nettype none

module cfar_threshold (
    input  wire [7:0]  cut,
    input  wire [11:0] V,
    input  wire [2:0]  alpha_sel,
    output wire        det
);

  // Widen V before shifting: in Verilog, V<<n stays 12 bits and would wrap.
  wire [18:0] V19 = {7'b0, V};

  // K·V via shift-add (at most four terms per K). 19 bits: max 120×4080 = 489600.
  reg [18:0] thr;
  always @* begin
    case (alpha_sel)
      3'b000: thr = (V19 << 4) + (V19 << 3) +  V19;             // K = 25
      3'b001: thr = (V19 << 5) + (V19 << 1);                     // K = 34
      3'b010: thr = (V19 << 5) + (V19 << 3) + (V19 << 2);        // K = 44
      3'b011: thr = (V19 << 5) + (V19 << 4) + (V19 << 3);        // K = 56
      3'b100: thr = (V19 << 6) + (V19 << 2) + (V19 << 1);        // K = 70
      3'b101: thr = (V19 << 6) + (V19 << 3) + (V19 << 1);        // K = 74
      3'b110: thr = (V19 << 6) + (V19 << 5);                     // K = 96
      3'b111: thr = (V19 << 6) + (V19 << 5) + (V19 << 4) + (V19 << 3); // K = 120
      default: thr = (V19 << 4) + (V19 << 3) + V19;              // K = 25
    endcase
  end

  // Widen cut before << 5 (bare cut<<5 stays 8 bits and drops MSBs).
  wire [18:0] cut_shifted = {11'b0, cut} << 5;

  // Continuous assign to output wire is fine; thr is reg because it is
  // assigned procedurally inside always @*.
  assign det = (cut_shifted > thr);

endmodule

`default_nettype wire
