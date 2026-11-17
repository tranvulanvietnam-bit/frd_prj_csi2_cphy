`timescale 1ns / 1ps


module axi4_stream_to_native #(
    parameter int PIXEL_W = 40
)(
    input  logic clk,
    input  logic rst_n,

    // AXI4-Stream slave
    input  logic [PIXEL_W-1:0] s_axis_tdata,
    input  logic               s_axis_tvalid,
    output logic               s_axis_tready,
    input  logic               s_axis_tlast,
    input  logic               s_axis_tuser,

    // Video configuration
    input  logic        cfg_pixel_mode,
    input  logic [5:0]  cfg_data_id,
    input  logic [15:0] cfg_word_count,

    // Native video output
    output pixel_pkg::video_interface_t out_data,
    output logic                        out_valid,
    output logic                        out_vid_en,
    output logic                        out_hsync,
    output logic                        out_vsync
);

    typedef enum logic [1:0] {
        ST_WAIT,
        ST_VSYNC_DONE,
        ST_PIXEL,
        ST_EOL_GAP
    } state_t;

    state_t state_q;

    logic [15:0] frame_num_q;
    logic [15:0] line_num_q;

    logic frame_seen_q;
    logic line_active_q;

    logic in_handshake;

    assign s_axis_tready =
        (state_q == ST_PIXEL) && rst_n;

    assign in_handshake =
        s_axis_tvalid && s_axis_tready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_q       <= ST_WAIT;
            frame_num_q   <= '0;
            line_num_q    <= '0;
            frame_seen_q  <= 1'b0;
            line_active_q <= 1'b0;

            out_data      <= '0;
            out_valid     <= 1'b0;
            out_vid_en    <= 1'b0;
            out_hsync     <= 1'b0;
            out_vsync     <= 1'b0;
        end
        else begin
            // Default pulse values
            out_valid  <= 1'b0;
            out_vid_en <= 1'b0;
            out_hsync  <= 1'b0;
            out_vsync  <= 1'b0;

            // Video metadata
            out_data.pixel_mode <= cfg_pixel_mode;
            out_data.data_id    <= cfg_data_id;
            out_data.word_count <= cfg_word_count;
            out_data.frame_num  <= frame_num_q;
            out_data.line_num   <= line_num_q;

            case (state_q)

                ST_WAIT: begin
                    // Inspect first beat without accepting it
                    if (s_axis_tvalid) begin
                        if (s_axis_tuser) begin
                            // Start of frame
                            out_vsync <= 1'b1;

                            line_num_q <= '0;
                            out_data.line_num <= '0;

                            if (!frame_seen_q) begin
                                frame_seen_q <= 1'b1;
                            end
                            else begin
                                frame_num_q <= frame_num_q + 1'b1;
                                out_data.frame_num <=
                                    frame_num_q + 1'b1;
                            end

                            state_q <= ST_VSYNC_DONE;
                        end
                        else begin
                            // Start of next line
                            out_hsync <= 1'b1;
                            state_q   <= ST_PIXEL;
                        end
                    end
                end

                ST_VSYNC_DONE: begin
                    // HSYNC follows VSYNC
                    out_hsync <= 1'b1;
                    state_q   <= ST_PIXEL;
                end

                ST_PIXEL: begin
                    // Keep video enable active across
                    // AXI TVALID bubbles inside a line.
                    out_vid_en <=
                        line_active_q || in_handshake;

                    if (in_handshake) begin
                        out_data.pixel <= s_axis_tdata;
                        out_valid      <= 1'b1;

                        if (s_axis_tlast) begin
                            // Last pixel of line
                            line_active_q <= 1'b0;
                            line_num_q <= line_num_q + 1'b1;
                            state_q <= ST_EOL_GAP;
                        end
                        else begin
                            line_active_q <= 1'b1;
                        end
                    end
                end

                ST_EOL_GAP: begin
                    // Ensure VID_EN falls before
                    // the next HSYNC/VSYNC event.
                    state_q <= ST_WAIT;
                end

                default: begin
                    state_q <= ST_WAIT;
                end

            endcase
        end
    end

endmodule
