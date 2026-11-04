// ASIC-1B A3: integration smoke only. NOT a TinyTapeout pin-level top.
// Upstream FIR/IIR, CFAR and Kalman arithmetic RTL are unchanged.
// Input contract: one config byte after reset (DSP mode + scale), then a
// continuous byte stream; first real profile sample asserts profile_sop.
// No stream-valid or backpressure: every clock after setup is a sample.
// CFAR outputs 1D detection decisions; range-bin index is attached here.
// Detection cluster holdoff is deliberately fixed at 64 cycles in A3 only.
// Kalman state is signed Q4.6, bin index maps to bin/64. Not physical range.
// Initial prior state x=0, P=1.0; measurement noise R=1.0.
// Must be redesigned/qualified for a production tracker, wider range,
// buffering, true coordinates, false alarm goals and final TT pin protocol.
`timescale 1ns/1ps
`default_nettype none
module asic1b_pipeline (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] sample_in,
    input  wire       profile_sop,
    input  wire [2:0] cfar_mode,
    input  wire [2:0] cfar_alpha,
    output wire [7:0] dsp_sample,
    output wire [7:0] cfar_status,
    output reg        detection_event,
    output reg [8:0]  detected_bin,
    output reg        kalman_update_event,
    output reg [9:0]  track_x_q46,
    output reg [9:0]  track_p_q46,
    output reg [7:0]  detection_count,
    output reg [7:0]  update_count,
    output reg        event_overflow,
    output reg        profile_overflow
);
    wire [7:0] dsp_uio_out, dsp_uio_oe;
    wire [7:0] cfar_uio_out, cfar_uio_oe;
    reg sop_d;
    wire [7:0] cfar_control = {1'b0, sop_d, cfar_alpha, cfar_mode};

    tt_um_dsp_top u_dsp (
        .clk(clk), .rst_n(rst_n), .ena(1'b1),
        .ui_in(sample_in), .uio_in(8'b0),
        .uo_out(dsp_sample), .uio_out(dsp_uio_out), .uio_oe(dsp_uio_oe)
    );
    tt_um_larsnit_cfar u_cfar (
        .clk(clk), .rst_n(rst_n), .ena(1'b1),
        .ui_in(dsp_sample), .uio_in(cfar_control),
        .uo_out(cfar_status), .uio_out(cfar_uio_out), .uio_oe(cfar_uio_oe)
    );

    // Match the CFAR's 12-clock indexed window: first valid result
    // corresponds to profile bin 10 after 21 samples plus output register.
    reg [8:0] bin_d [0:11];
    reg [8:0] stream_bin;
    reg       profile_active;
    integer   i;
    reg [6:0] suppression;

    // Hold one detection while the Kalman update processes it.
    reg       pending;
    reg [9:0] pending_z;
    reg       kal_start;
    reg       running;
    reg [9:0] z_in, x_in, p_in;
    wire [9:0] core_x, core_p;
    wire       core_done, core_busy;

    kalman_update u_kalman (
       .clk(clk), .rst_n(rst_n), .start(kal_start),
       .z(z_in), .x_in(x_in), .P_in(p_in), .r_val(10'd64),
       .x_out(core_x), .P_out(core_p),
       .done(core_done), .busy(core_busy)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sop_d              <= 1'b0;
            stream_bin         <= 9'd0;
            profile_active     <= 1'b0;
            suppression        <= 7'd0;
            pending            <= 1'b0;
            pending_z          <= 10'd0;
            kal_start          <= 1'b0;
            running            <= 1'b0;
            z_in               <= 10'd0;
            x_in               <= 10'd0;
            p_in               <= 10'd0;
            track_x_q46        <= 10'd0;
            track_p_q46        <= 10'd64;
            detection_event    <= 1'b0;
            detected_bin       <= 9'd0;
            kalman_update_event<= 1'b0;
            detection_count    <= 8'd0;
            update_count       <= 8'd0;
            event_overflow     <= 1'b0;
            profile_overflow   <= 1'b0;
            for (i=0; i<12; i=i+1) bin_d[i] <= 9'd0;
        end else begin
            sop_d <= profile_sop;
            kal_start <= 1'b0;
            detection_event <= 1'b0;
            kalman_update_event <= 1'b0;

            if (sop_d) begin
                profile_active <= 1'b1;
                stream_bin <= 9'd1;
                bin_d[0] <= 9'd0;
            end else if (profile_active) begin
                bin_d[0] <= stream_bin;
                if (stream_bin == 9'd511) profile_overflow <= 1'b1;
                else stream_bin <= stream_bin + 9'd1;
            end else begin
                bin_d[0] <= 9'd0;
            end
            for (i=1; i<12; i=i+1) bin_d[i] <= bin_d[i-1];
            if (suppression!=0) suppression <= suppression - 7'd1;

            // CFAR output is registered; read at this edge, one clock
            // after the corresponding bin_d[11] was advanced.
            if (cfar_status[1] && cfar_status[0] && suppression==0) begin
                detection_event <= 1'b1;
                detected_bin <= bin_d[11];
                detection_count <= detection_count + 8'd1;
                suppression <= 7'd64;
                if (pending || running || kal_start) begin
                    event_overflow <= 1'b1; // Explicit failure: NO silent drop
                end else begin
                    pending <= 1'b1;
                    pending_z <= {1'b0,bin_d[11]}; // Q4.6: bin/64
                end
            end

            if (pending && !running && !kal_start) begin
                z_in <= pending_z;
                x_in <= track_x_q46;
                p_in <= track_p_q46;
                kal_start <= 1'b1;
                pending <= 1'b0;
                running <= 1'b1;
            end
            if (running && core_done) begin
                track_x_q46 <= core_x;
                track_p_q46 <= core_p;
                running <= 1'b0;
                kalman_update_event <= 1'b1;
                update_count <= update_count + 8'd1;
            end
        end
    end
    wire _unused = &{dsp_uio_out,dsp_uio_oe,cfar_uio_out,cfar_uio_oe,core_busy};
endmodule
`default_nettype wire
