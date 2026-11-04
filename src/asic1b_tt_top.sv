// ASIC-1B A5A: TinyTapeout-compatible 8-bit GPIO wrapper for A3 pipeline.
// Candidate only; not a frozen release pin contract.
// Input ui_in[7:0]: one sample every clock, including while reading status.
// After reset the FIRST input byte is consumed as DSP mode/scale configuration.
// Inputs uio_in[2:0]: CFAR mode on the profile_sop cycle.
//        uio_in[5:3]: CFAR alpha on the profile_sop cycle.
//        uio_in[6]: profile_sop strobe (one clock).
//        uio_in[7]: 0 -> uo_out CFAR result, 1 -> diagnostic page.
// After SOP, CFAR mode/alpha are latched. When uio_in[7]=1 the host may
// use uio_in[3:0] as a diagnostic page while SOP stays 0.
// Diagnostic page: 0=DSP, 1=CFAR, 2=bin low, 3=bin high,
// 4=x low, 5=x high, 6=P low, 7=P high, 8=detect count,
// 9=update count, 10={6'b0,index_overflow,event_overflow}.
// Current A3 profile indexing continues advancing after SOP (no EOF input).
// Host must stop/reset before 512 samples and must never assume backpressure.
`timescale 1ns/1ps
`default_nettype none
module tt_um_asic1b_dsp (
    input wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input wire ena,
    input wire clk,
    input wire rst_n
);
    wire [7:0] dsp_sample, cfar_status;
    wire detection_event, kalman_update_event, event_overflow, profile_overflow;
    wire [8:0] detected_bin;
    wire [9:0] track_x_q46, track_p_q46;
    wire [7:0] detection_count, update_count;

    asic1b_pipeline u_pipeline (
        .clk(clk),.rst_n(rst_n),.sample_in(ui_in),
        .profile_sop(uio_in[6]),
        .cfar_mode(uio_in[2:0]),.cfar_alpha(uio_in[5:3]),
        .dsp_sample(dsp_sample),.cfar_status(cfar_status),
        .detection_event(detection_event),.detected_bin(detected_bin),
        .kalman_update_event(kalman_update_event),
        .track_x_q46(track_x_q46),.track_p_q46(track_p_q46),
        .detection_count(detection_count),.update_count(update_count),
        .event_overflow(event_overflow),.profile_overflow(profile_overflow)
    );

    reg [7:0] diag;
    always @* begin
        case (uio_in[3:0])
            4'd0:  diag = dsp_sample;
            4'd1:  diag = cfar_status;
            4'd2:  diag = detected_bin[7:0];
            4'd3:  diag = {7'b0,detected_bin[8]};
            4'd4:  diag = track_x_q46[7:0];
            4'd5:  diag = {6'b0,track_x_q46[9:8]};
            4'd6:  diag = track_p_q46[7:0];
            4'd7:  diag = {6'b0,track_p_q46[9:8]};
            4'd8:  diag = detection_count;
            4'd9:  diag = update_count;
            4'd10: diag = {6'b0,profile_overflow,event_overflow};
            default: diag = 8'd0;
        endcase
    end
    assign uo_out  = uio_in[7] ? diag : cfar_status;
    assign uio_out = 8'b0;
    assign uio_oe  = 8'b0;
    wire _unused = &{ena,detection_event,kalman_update_event};
endmodule
`default_nettype wire
