`timescale 1ns / 1ps
import pixel_pkg::*;

module crc_fifo(
   input  logic        clk       ,
   input  logic        rst_n     ,
  
   input  payload_sb_t in_data   ,
   input  logic        in_valid  ,
   output logic        in_ready  ,
  
   output fifo2dld_t   out_data  ,
   output logic        out_valid ,
   input  logic        out_ready
);
   logic [4:0]  payload_last_nbytes;
   
   payload_sb_t mem;
   
   logic        is_spkt, is_hdr;
   
   logic        extra_tx        ;    
   logic        is_spkt_sof     ;
   logic        first_frame_sof ;
   
   logic [15:0] crc_sp_lph_result, crc_lp_payload_result;
   
   
   assign in_ready = 1'b1;
   
   always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
           mem <= '0;
        end else begin
           if (in_valid) 
              mem <= in_data;
        end 
    end
   
   assign payload_last_nbytes = 
      {1'b0, ~in_data.word_count[3], in_data.word_count[2:0]};
   
//-------------------------------------------------
// extra_beat_ctrl
//-------------------------------------------------
extra_beat_ctrl u_extra_beat_ctrl (
  .clk                 (clk                ),
  .rst_n               (rst_n              ),
                      
  .in_data             (in_data            ),
  .mem                 (mem                ),
                     
  .in_valid            (in_valid           ),
  .out_valid           (out_valid          ),
                    
  .payload_last_nbytes (payload_last_nbytes),
                     
  .is_spkt             (is_spkt            ),
  .is_hdr              (is_hdr             ),
                    
  .extra_tx            (extra_tx           ),
  .is_spkt_sof         (is_spkt_sof        ),
  .first_frame_sof     (first_frame_sof    )
);

//-------------------------------------------------
// out_valid Control
//-------------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         out_valid <= 1'b0;
      end else begin
         out_valid <= (in_valid | extra_tx);
      end
   end
       
//---------------------------------------------------
// CRC ENGINE CONTROL
//---------------------------------------------------     
crc_ctrl u_crc_ctrl (
  .clk                   (clk                  ),     
  .rst_n                 (rst_n                ),
                         
  .in_valid              (in_valid             ),
                         
  .extra_tx              (extra_tx             ),
                         
  .first_frame_sof       (first_frame_sof      ),
  .is_spkt               (is_spkt              ),
  .is_hdr                (is_hdr               ),
  
  .in_data               (in_data              ),
  .mem                   (mem                  ),
  
  .payload_last_nbytes   (payload_last_nbytes  ),
  
  .crc_sp_lph_result     (crc_sp_lph_result    ),
  .crc_lp_payload_result (crc_lp_payload_result)
);
//---------------------------------------------------
// OUTPUT ASSIGN
//---------------------------------------------------
output_pack u_output_pack (
  .in_data               (in_data              ),               
  .mem                   (mem                  ),                   
                           
  .payload_last_nbytes   (payload_last_nbytes  ),   
                         
  .extra_tx              (extra_tx             ),              
  .is_spkt_sof           (is_spkt_sof          ),           
  .first_frame_sof       (first_frame_sof      ),       
                      
  .crc_sp_lph_result     (crc_sp_lph_result    ),     
  .crc_lp_payload_result (crc_lp_payload_result), 
                         
  .out_data              (out_data             )          
);   
   
endmodule


