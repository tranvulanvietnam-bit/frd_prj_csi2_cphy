`timescale 1ns / 1ps

module pxl_accumulator_128bits (
   input  logic                              clk,
   input  logic                              rst_n,
  
   input  pixel_pkg::video_interface_t       in_data,
   input  logic                              in_valid,
   
   input  logic                              in_vid_en,
   input  logic                              posedge_vsync,

   output pixel_pkg::payload_sb_t out_data,
   output logic                              out_valid
);

   import pixel_pkg::*;
   
   localparam int         ACCU_W       = 120;
  
   logic [39:0]            in_pixel;
   logic [127:0]           out_pixel;

   logic [1:0]             payload_id;
   logic [ACCU_W-1:0]      accum, accum_next;
   logic [7:0]             bit_count, bit_count_next;
   logic [7:0]             total_bits;

   logic [127:0] combined_output;

   logic output_full;
   logic lp_hdr_out_done, lp_hdr_out_valid;
   
   logic pre_vid_en;
   logic negedge_vid_en;
   
   logic is_raw20, is_mono;

   assign in_pixel = in_data.pixel;

   assign is_mono  = in_data.pixel_mode;
   
   assign is_raw20 = (in_data.data_id == DATATYPE_IS_RAW20);
   
// -------------------------------------------
// LONG PACKET HEADER OUTPUT FLAG
// -------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         lp_hdr_out_done <= 1'b0;
      end
      else begin
         if (negedge_vid_en | posedge_vsync)
            lp_hdr_out_done <= 1'b0;
         else if (lp_hdr_out_valid) begin
            lp_hdr_out_done <= 1'b1;
         end
      end
   end
   
   assign lp_hdr_out_valid = 
      in_valid & in_vid_en & 
      !lp_hdr_out_done & total_bits[6];
      
// -------------------------------------------
// LINE END EVENT AND FLUSH CONTROL AND OUTPUT
// -------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n)
         pre_vid_en <= 1'b0;
      else
         pre_vid_en <= in_vid_en;
   end
   
   assign negedge_vid_en = pre_vid_en & !in_vid_en;
   
// -------------------------------------------
// Output control
// -------------------------------------------
   assign output_full =
      in_valid & in_vid_en & total_bits[7];

   assign out_valid =
      posedge_vsync | 
      lp_hdr_out_valid | 
      output_full | 
      negedge_vid_en;

// -------------------------------------------
// Output data selection
// -------------------------------------------
   always_comb begin
      out_pixel = '0;
      
      // ID_LPKT_LAST
      if (negedge_vid_en) begin
         out_pixel = 128'(accum);
      end
      
      // ID_LPKT_HDR contains 64 valid pixel bits.
      else if (lp_hdr_out_valid) begin
      
         // ID_LPKT_HDR if (raw20)
         if (is_raw20) begin
            out_pixel = 128'({in_pixel[23:0],accum[39:0]});
         end
         
         // ID_LPKT_HDR if (rgb565)
         else begin
            if (is_mono) begin
               out_pixel = 128'({in_pixel[15:0],accum[47:0]});
            end
            else begin
               out_pixel = 128'({in_pixel[31:0],accum[31:0]});
            end
         end
      end
      
      // ID_LPKT_BODY 
      else if (output_full) begin
         out_pixel = combined_output;
      end
   end
   
   assign out_data.pixel      = out_pixel;
   
   // -------------------------------------------
   // payload_id determine
   // -------------------------------------------
   always_comb begin
      payload_id = ID_LPKT_BODY;
      if (posedge_vsync) begin
         payload_id = ID_SPKT;
      end
      else if (lp_hdr_out_valid) begin
         // Bypass input pixel to output
         payload_id = ID_LPKT_HDR;
      end
      else if (negedge_vid_en) begin
         payload_id = ID_LPKT_LAST;
      end
   end
   
   assign out_data.payload_id = payload_id;
   
   // -------------------------------------------
   // Sideband direct pass-through
   // -------------------------------------------
   assign out_data.data_id    = in_data.data_id;
   assign out_data.word_count = in_data.word_count;
   assign out_data.frame_num  = in_data.frame_num;
   assign out_data.line_num   = in_data.line_num;
   
   // -------------------------------------------
   // Combined Output based on Datatype
   // -------------------------------------------
   always_comb begin
      combined_output = '0;
      if (is_raw20) begin
         case (bit_count)
            8'd120:
               combined_output = {in_pixel[7:0],
                                  accum[119:0]};

            8'd112:
               combined_output = {in_pixel[15:0],
                                  accum[111:0]};

            8'd104:
               combined_output = {in_pixel[23:0],
                                  accum[103:0]};

            8'd96:
               combined_output = {in_pixel[31:0],
                                  accum[95:0]};

            8'd88:
               combined_output = {in_pixel[39:0],
                                  accum[87:0]};

            default:
               combined_output = '0;
         endcase
      end
      else begin // data type is RGB565
         if (is_mono) begin // mode is MONO
            combined_output = {
               in_pixel[15:0],
               accum[111:0]
            };
         end
         else begin         // mode is DUAL
            combined_output = {
               in_pixel[31:0],
               accum[95:0]
            };
         end
      end
   end
   
   // -------------------------------------------
   // total bits calculate
   // -------------------------------------------
   always_comb begin
      if (is_raw20)
         total_bits = bit_count + 8'd40;
      else // data type is RGB565
         total_bits = bit_count + (is_mono? 8'd16: 8'd32);
   end 
   
// -------------------------------------------
// Accumulator next-state logic
// -------------------------------------------   
   always_comb begin
      accum_next     = accum;
      bit_count_next = bit_count;
      
      // event vsync rise and after flush, reset
      if (posedge_vsync | negedge_vid_en) begin
         accum_next     = ACCU_W'(1'b0);
         bit_count_next = 8'b0;
      end
      
      // when input is valid
      else if (in_valid & in_vid_en) begin
      
         // if total bits not > 128 bit, normal accumulate
         if (!output_full) begin
         
            if (lp_hdr_out_valid) begin
            
               if (is_raw20) begin
                  accum_next     = ACCU_W'(in_pixel[39:24]);

                  bit_count_next = 8'd16;
               end
               
               // else if (is_rgb565)
               else begin
                  accum_next     = ACCU_W'(1'b0);

                  bit_count_next = 8'b0;
               end
            end
            
            // else if (invalid & !lp_hdr_out_valid)
            else begin
               accum_next =
                  accum | (ACCU_W'(in_pixel) << bit_count);

               bit_count_next = total_bits;
            end
         end
         
         // total bits >128, output and shift remain to LSB
         else begin
         
            // data type is raw20
            if (is_raw20) begin
               case (bit_count)
                  8'd88: begin
                     accum_next     = ACCU_W'(1'b0);
                     bit_count_next = 8'd0;
                  end

                  8'd96: begin
                     accum_next     = ACCU_W'(in_pixel[39:32]);
                     bit_count_next = 8'd8;
                  end

                  8'd104: begin
                     accum_next     = ACCU_W'(in_pixel[39:24]);
                     bit_count_next = 8'd16;
                  end

                  8'd112: begin
                     accum_next     = ACCU_W'(in_pixel[39:16]);
                     bit_count_next = 8'd24;
                  end

                  8'd120: begin
                     accum_next     = ACCU_W'(in_pixel[39:8]);
                     bit_count_next = 8'd32;
                  end

                  default: begin
                     accum_next     = accum;
                     bit_count_next = bit_count;
                  end
               endcase
            end
            else begin
               // data type is rgb565, no remain
               accum_next     = ACCU_W'(1'b0);
               bit_count_next = 8'b0;
            end
         end
      end
   end

   // -------------------------------------------
   // Sequential registers
   // -------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         accum     <= ACCU_W'(1'b0);
         bit_count <= 8'b0;         
      end
      else begin
         accum     <= accum_next;
         bit_count <= bit_count_next;
      end
   end

endmodule
