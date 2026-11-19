`timescale 1ns / 1ps

import pixel_pkg::*;

module extra_beat_ctrl(
   input                          clk                 ,
   input                          rst_n               ,
   
   input  pixel_pkg::payload_sb_t in_data             ,
   input  pixel_pkg::payload_sb_t mem                 ,
   
   input  logic                   in_valid            ,
  
   input  logic [4:0]             payload_last_nbytes ,
   input  logic                   out_valid           ,
  
   output logic                   is_spkt             ,
   output logic                   is_hdr              ,
  
   output logic                   extra_tx            ,
   output logic                   is_spkt_sof         ,
   output logic                   first_frame_sof     
    );
   logic is_last, dif_frame_flag, extra_tx_4crc;
   
   assign dif_frame_flag = (mem.frame_num != in_data.frame_num);
   
   assign extra_tx_4crc = 
      (payload_last_nbytes == 5'd15) &
      (is_last);
   
   logic [1:0]  payload_id;
   
   assign payload_id = in_data.payload_id;
   
   assign is_spkt    = (payload_id == ID_SPKT     );
   assign is_hdr     = (payload_id == ID_LPKT_HDR );
   assign is_last    = (payload_id == ID_LPKT_LAST);
   
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         extra_tx <= 1'b0;
      end
      else begin 
         extra_tx <= in_valid & 
                     (extra_tx_4crc | dif_frame_flag);
      end
   end

   // Identify the SECOND output as SOF
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          is_spkt_sof <= 1'b0;
      end else begin
          is_spkt_sof <= extra_tx &
                        (is_spkt);
      end
   end
    
//-------------------------------------------------
// NEW FRAME event CONTROL    
//-------------------------------------------------     
             
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         first_frame_sof <= 1'b1;
      end
      else begin
         if (out_valid) begin
            first_frame_sof <= 1'b0;
         end
      end
   end

endmodule
