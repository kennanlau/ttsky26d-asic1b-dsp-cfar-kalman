/*
 * Copyright (c) 2026 Lars Nitschke
 * SPDX-License-Identifier: Apache-2.0
 *
 * Mode mux → V, half_sel (combinational).
 * V is always a nominal 16-cell sum: GO/SO/SIDE double the selected half.
 */

`default_nettype none

module cfar_combine (
    input  wire [10:0] S_A,
    input  wire [10:0] S_B,
    input  wire [2:0]  mode,
    output wire [11:0] V,
    output wire        half_sel
);


  // requires reg for procedural assigns (cannot assign to a wire inside always).
  reg [11:0] V_reg;       // 12 bits: max CA sum 2×2040 = 4080
  reg        half_sel_reg;

  always @* begin
    case (mode)
      3'b000: begin  // CA
        V_reg        = {1'b0, S_A} + {1'b0, S_B};
        half_sel_reg = 1'b0;
      end
      3'b001: begin  // GO: 2 × max; half_sel = 1 if B chosen (tie → 0)
        V_reg        = {(S_A > S_B) ? S_A : S_B, 1'b0};
        half_sel_reg = (S_B > S_A);
      end
      3'b010: begin  // SO: 2 × min; half_sel = 1 if B chosen (tie → 0)
        V_reg        = {(S_A < S_B) ? S_A : S_B, 1'b0};
        half_sel_reg = (S_B < S_A);
      end
      3'b011: begin  // SIDE_A
        V_reg        = {S_A, 1'b0};
        half_sel_reg = 1'b0;
      end
      3'b100: begin  // SIDE_B
        V_reg        = {S_B, 1'b0};
        half_sel_reg = 1'b1;
      end
      default: begin  // 101–111 behave as CA (explicit default avoids a latch)
        V_reg        = {1'b0, S_A} + {1'b0, S_B};
        half_sel_reg = 1'b0;
      end
    endcase
  end

  assign V        = V_reg;
  assign half_sel = half_sel_reg;

endmodule

`default_nettype wire
