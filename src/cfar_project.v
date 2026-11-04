/*
 * Copyright (c) 2026 Lars Nitschke
 * SPDX-License-Identifier: Apache-2.0
 *
 * Tiny Tapeout top: pin map, armed warm-up counter, config latch, output regs.
 * Datapath (window / combine / threshold) is combinatorial between the
 * window flops and these output registers → fixed latency of 12 cycles.
 */

`default_nettype none

module tt_um_larsnit_cfar (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  // ---- Pin map ----
  wire [7:0] sample_in = ui_in[7:0];
  wire [2:0] mode      = uio_in[2:0];
  wire [2:0] alpha_sel = uio_in[5:3];
  wire       sop       = uio_in[6];
  // uio_in[7] reserved — must be driven 0 by the host; sunk below

  // ---- Datapath wires ----
  wire [7:0]  cut;
  wire [10:0] S_A;
  wire [10:0] S_B;
  wire [11:0] V;
  wire        half_sel_c;
  wire        det_c;
  wire        valid_c;

  // ---- Config latch: captured on sop; reset defaults CA / alpha 000 ----
  reg [2:0] mode_latched;
  reg [2:0] alpha_sel_latched;

  // ---- Warm-up: sticky armed + saturating counter (must not wrap) ----
  reg       armed;
  reg [4:0] count;

  // ---- Output registers (pins show previous cycle's combo result) ----
  reg       det_r;
  reg       valid_r;
  reg       half_sel_r;
  reg [4:0] v_dbg_r;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mode_latched      <= 3'b000;
      alpha_sel_latched <= 3'b000;
      armed             <= 1'b0;
      count             <= 5'd0;
      det_r             <= 1'b0;
      valid_r           <= 1'b0;
      half_sel_r        <= 1'b0;
      v_dbg_r           <= 5'd0;
    end else begin
      // Config: only update on start-of-profile
      if (sop) begin
        mode_latched      <= mode;
        alpha_sel_latched <= alpha_sel;
      end

      // Sticky armed: set on first sop, cleared only by reset
      if (sop)
        armed <= 1'b1;

      // Counter: sop → 1; else count only while armed, saturate at 21
      if (sop)
        count <= 5'd1;
      else if (armed && count != 5'd21)
        count <= count + 5'd1;

      // Output register stage
      det_r      <= det_c;
      valid_r    <= valid_c;
      half_sel_r <= half_sel_c;
      v_dbg_r    <= V[11:7];
    end
  end

  assign valid_c = (count == 5'd21);

  // ---- Submodules: combine/threshold see latched config, not live pins ----
  cfar_window u_window (
      .clk    (clk),
      .rst_n  (rst_n),
      .sample (sample_in),
      .cut    (cut),
      .S_A    (S_A),
      .S_B    (S_B)
  );

  cfar_combine u_combine (
      .S_A      (S_A),
      .S_B      (S_B),
      .mode     (mode_latched),
      .V        (V),
      .half_sel (half_sel_c)
  );

  cfar_threshold u_threshold (
      .cut       (cut),
      .V         (V),
      .alpha_sel (alpha_sel_latched),
      .det       (det_c)
  );

  // uo_out[0]=det, [1]=valid, [2]=half_sel, [7:3]=v_dbg
  assign uo_out  = {v_dbg_r, half_sel_r, valid_r, det_r};
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  wire _unused = &{ena, uio_in[7], 1'b0};

endmodule

`default_nettype wire
