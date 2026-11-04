/*
 * Copyright (c) 2026 Lars Nitschke
 * SPDX-License-Identifier: Apache-2.0
 *
 * Sliding window + incremental half-sums.
 * S_A == sum(r[0..7]), S_B == sum(r[13..20]) at all times.
 * Reset zeroes chain and sums together — an incremental sum never self-corrects.
 */

`default_nettype none

module cfar_window (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  sample,
    output wire [7:0]  cut,
    output wire [10:0] S_A,
    output wire [10:0] S_B
);

  // Fixed roles: r[0..7]=train A, r[8..9]=guard, r[10]=CUT,
  //              r[11..12]=guard, r[13..20]=train B.
  reg [7:0]  r [0:20];
  reg [10:0] S_A_reg, S_B_reg;  // 11 bits: 8 × 255 = 2040
  integer    i;

  assign cut = r[10];
  assign S_A = S_A_reg;
  assign S_B = S_B_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      S_A_reg <= 11'd0;
      S_B_reg <= 11'd0;
      for (i = 0; i < 21; i = i + 1)
        r[i] <= 8'd0;
    end else begin

      // Widen 8-bit operands to 11 bits so the add/sub does not truncate.
      S_A_reg <= S_A_reg + {3'b0, sample} - {3'b0, r[7]};
      S_B_reg <= S_B_reg + {3'b0, r[12]} - {3'b0, r[20]};

      // Shift toward higher indices; newest sample lands in r[0].
      r[0] <= sample;
      for (i = 20; i > 0; i = i - 1)
        r[i] <= r[i - 1];
    end
  end

endmodule

`default_nettype wire
