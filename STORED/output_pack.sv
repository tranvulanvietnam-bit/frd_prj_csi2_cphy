`timescale 1ns / 1ps

import pixel_pkg::*;

module output_pack(
    input pixel_pkg::payload_sb_t in_data,
    input pixel_pkg::payload_sb_t mem,
    
    input logic [5:0]             payload_last_nbytes,

    input logic                   extra_tx,
    input logic                   is_spkt_sof,
    input logic                   first_frame_sof,

    input logic [15:0]            crc_sp_lph_result,
    input logic [15:0]            crc_lp_payload_result,
    
    output pixel_pkg::fifo2dld_t  out_data
    );
    
logic [15:0] frame_end_num;

assign frame_end_num = (extra_tx)? 
                       mem.frame_num[15:0] - 1'b1 :
                       mem.frame_num[15:0];
                       
always_comb begin
   case (mem.payload_id) 
   ID_SPKT: begin
      out_data.payload_id = ID_SPKT;
      out_data.nbytes     = 5'd6;
      
      if (is_spkt_sof | first_frame_sof) begin
         out_data.pixel = 128'({      
            RES, vc[1:0], SP_DT_FS,   
            mem.frame_num[15:0],  
            crc_sp_lph_result[15:0]});
      end else begin
         out_data.pixel = 128'({
            RES, vc[1:0], SP_DT_FE, 
            frame_end_num[15:0],
            crc_sp_lph_result[15:0]});
      end
   end
   ID_LPKT_HDR: begin
      out_data.payload_id = ID_LPKT_HDR;
      out_data.nbytes     = 5'd6;
      out_data.pixel      = 128'({
         RES, vc[1:0], mem.data_id[5:0], 
         mem.word_count[15:0],
         crc_sp_lph_result[15:0],
         mem.pixel[63:0]}); 
   end
   ID_LPKT_BODY: begin
      out_data.payload_id = ID_LPKT_BODY;
      out_data.nbytes     = 5'd16;
      out_data.pixel      = mem.pixel;
   end
   ID_LPKT_LAST: begin
      case (1'b1)
         (payload_last_nbytes == 7'd15): begin
            if (extra_tx) begin
               out_data.payload_id = ID_LPKT_BODY;
               out_data.nbytes     = 5'd16;
               out_data.pixel      = {
                  crc_lp_payload_result[7:0],
                  mem.pixel[119:0]};
            end else begin
               out_data.payload_id = ID_LPKT_LAST;
               out_data.nbytes     = 5'd1;
               out_data.pixel      = 128'(crc_lp_payload_result[15:8]);
            end
         end
         (payload_last_nbytes == 7'd14): begin
            out_data.payload_id = ID_LPKT_LAST;
            out_data.nbytes     = 5'd16;
            out_data.pixel      = {
               crc_lp_payload_result[15:0],
               mem.pixel[111:0]};
         end
         (payload_last_nbytes < 7'd14): begin
            out_data.payload_id = ID_LPKT_LAST;
            out_data.nbytes     = 
               5'(payload_last_nbytes + 5'd2);
            out_data.pixel      = 
               mem.pixel |
               (128'(crc_lp_payload_result) << (payload_last_nbytes * 8));
         end
      endcase
   end
   default: begin
      out_data = '0;
   end
   endcase
end
                      
endmodule
