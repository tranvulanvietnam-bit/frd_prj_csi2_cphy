`timescale 1ns / 1ps

module Input_Packing (
   input  logic                                 clk,
   input  logic                                 rst_n,
   input  logic                                 in_hsync_rise,
   input  logic                                 in_vid_en,
   input  pixel_pkg::video_interface_t          in_data,
   
   output pixel_pkg::video_interface_t          out_data,
   output logic                                 out_valid
);

   logic                    is_raw20, en_pixel_store, is_mono;
   logic                    count;  // 0: waiting for first MONO pixel; 1: second MONO pixel
   logic                    is_valid_tx_px;
   logic [19:0]             pixel_store;
   logic [39:0]             packed_pixel ;

   assign is_mono        = in_data.pixel_mode; //1:MONO, 0: DUAL
   
   assign is_raw20       = (in_data.data_id == 16'h2F);
   
   assign en_pixel_store = is_raw20 & is_mono;
   
   // -------------------------------------------
   // INPUT WRITE 
   // -------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         count       <= 1'b0;
         pixel_store <= '0;
      end
      else begin
         if (in_hsync_rise) begin // reset at hsync rise event
            count       <= 1'b0;
            pixel_store <= '0;
         end
         else if (in_vid_en & en_pixel_store) begin //MONO mode and RAW20
            if (!count) begin
               pixel_store <= in_data.pixel[19:0];
            end
            count <= ~count;
            $write("%t count = %0d", $time, count);
         end
      end
   end

   // -------------------------------------------
   // Output Control
   // -------------------------------------------
//   datatyppe | pixelmode | count | 
//   raw20     | mono      | 0     | pixel store <= input
//   raw20     | mono      | 1     | output = {store, input}
//   raw20     | dual      | x     | bybass input
//   rgb565    | mono      | x     | bybass input
//   rgb565    | dual      | x     | bybass input 
   
   
   assign is_valid_tx_px = 
      in_vid_en & 
      (!is_mono | !is_raw20 | count);
   
   assign out_valid = is_valid_tx_px;
   // -------------------------------------------
   // Output Data Select decide by MODE
   // -------------------------------------------
   always_comb begin
      packed_pixel = '0;
      if (!en_pixel_store) begin
         packed_pixel = in_data.pixel;
      end
      else if (count) begin
         packed_pixel = 128'({in_data.pixel[19:0], pixel_store});
      end
   end
 
   assign out_data.pixel = packed_pixel ; 
   // -------------------------------------------
   // Bybass metadata
   // -------------------------------------------  
   assign out_data.pixel_mode = in_data.pixel_mode;
   assign out_data.data_id    = in_data.data_id;
   assign out_data.word_count = in_data.word_count;
   assign out_data.frame_num  = in_data.frame_num;
   assign out_data.line_num   = in_data.line_num;
      
endmodule