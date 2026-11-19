`timescale 1ns / 1ps

import pixel_pkg::*;

module crc_ctrl(
    input logic                   clk                   ,
    input logic                   rst_n                 ,
    
    input logic                   in_valid              ,
    
    input logic                   extra_tx              ,
    
    input logic                   first_frame_sof       ,
    input logic                   is_spkt               ,
    input logic                   is_hdr                ,
    
    input pixel_pkg::payload_sb_t in_data               ,
    input pixel_pkg::payload_sb_t mem                   ,
    
    input logic [4:0]             payload_last_nbytes   ,
    
    output logic [15:0]           crc_sp_lph_result     ,
    output logic [15:0]           crc_lp_payload_result
    );
   logic [127:0] crc_sp_lph_input;
   logic         crc_sp_lph_valid;
   logic [5:0]   crc_sp_lph_nbytes; // value from 0 to 16 
   logic         crc_sp_lph_first; // crc_base = in_first ? RESET : NO_RESET;   
   
   logic [127:0] crc_lp_payload_input;
   logic         crc_lp_payload_valid;
   logic [5:0]   crc_lp_payload_nbytes; // value from 0 to 16 
   logic         crc_lp_payload_first; // crc_base = in_first ? RESET : NO_RESET;
    
   assign crc_lp_payload_valid = in_valid & 
                                 (!is_spkt);
                                 // LPH, LP_BODY, LP_LAST
                                    
   assign crc_sp_lph_valid     = (in_valid | extra_tx) & 
                                 (is_spkt  | is_hdr);
                                 // SP, SP_EXTRA, LPH
   
   // Drive input for crc_lp_payload
   always_comb begin
      case (in_data.payload_id)
        (ID_LPKT_BODY): begin
           crc_lp_payload_nbytes = 5'd16;
           crc_lp_payload_first  = 1'b0; // no reset 
           crc_lp_payload_input  = in_data.pixel[127:0];
        end
        (ID_LPKT_HDR): begin
           crc_lp_payload_nbytes = 5'd8;
           crc_lp_payload_first  = 1'b1; // reset 
           crc_lp_payload_input  = 128'(in_data.pixel[63:0]);
        end
        (ID_SPKT): begin
           crc_lp_payload_nbytes = 5'd0;
           crc_lp_payload_first  = 1'b1; // reset 
           crc_lp_payload_input  = {128{1'b0}};
        end
        (ID_LPKT_LAST): begin
           crc_lp_payload_nbytes = payload_last_nbytes[4:0];
           crc_lp_payload_first  = 1'b0; // no reset
           crc_lp_payload_input  = in_data[127:0];
        end
        default: begin
           crc_lp_payload_nbytes = 5'd0;         
           crc_lp_payload_first  = 1'b1; // reset
           crc_lp_payload_input  = {128{1'b0}};     
        end
      endcase
   end
   
   // Drive input for crc_sp_lph
   always_comb begin
      case (in_data.payload_id)
        (ID_LPKT_BODY): begin
           crc_sp_lph_nbytes = 5'd0;          
           crc_sp_lph_first  = 1'b1; // reset 
           crc_sp_lph_input  = {128{1'b0}};   
        end
        (ID_LPKT_HDR): begin
           crc_sp_lph_nbytes = 5'd4;
           crc_sp_lph_first  = 1'b1;
           crc_sp_lph_input  = 128'({ // lpkt_hdr
              RES[7:0], vc[1:0], 
              in_data.data_id[5:0], 
              in_data.word_count[15:0]});
        end
        (ID_SPKT): begin
           if (first_frame_sof) begin
              crc_sp_lph_nbytes = 5'd4;
              crc_sp_lph_first  = 1'b1;
              crc_sp_lph_input  = 128'({
                 RES[7:0], vc[1:0], 
                 SP_DT_FS[5:0], 
                 in_data.frame_num[15:0]});
           end else begin
              if (in_valid) begin // EOF //replace in_valid with dif_frame_flag if timing
                 crc_sp_lph_nbytes = 5'd4;
                 crc_sp_lph_first  = 1'b1;
                 crc_sp_lph_input  = 128'({
                    RES[7:0], vc[1:0], 
                    SP_DT_FE[5:0], 
                    mem.frame_num[15:0]}); // old frame_num
              end else if (!in_valid) begin //SOF
                 crc_sp_lph_nbytes = 5'd4;
                 crc_sp_lph_first  = 1'b1;
                 crc_sp_lph_input  = 128'({
                    RES[7:0], vc[1:0], 
                    SP_DT_FS[5:0], 
                    in_data.frame_num[15:0]}); // new frame_num
              end
           end
        end
        (ID_LPKT_LAST): begin
           crc_sp_lph_nbytes = 5'd0;         
           crc_sp_lph_first  = 1'b1; // reset
           crc_sp_lph_input  = {128{1'b0}};  
        end
        default: begin
           crc_sp_lph_nbytes = 5'd0;         
           crc_sp_lph_first  = 1'b1; // reset
           crc_sp_lph_input  = {128{1'b0}};  
        end
      endcase
   end                                  
           
//-----------------------------------------
// CRC ENGINE
//-----------------------------------------  
// to calculate sp and lph crc
   crc16_stream_128 u_sp_lph_crc (
    .clk         (clk),
    .rst_n       (rst_n),
    
    .in_data     (crc_sp_lph_input),
    .in_valid    (crc_sp_lph_valid),

    // Packet control
    .in_first    (crc_sp_lph_first),

    // Number of valid bytes: 0 to 16
    .valid_bytes (crc_sp_lph_nbytes),
    .crc_out     (crc_sp_lph_result)
);
 
   // to calculate crc lp_body_and_last
   crc16_stream_128 u_lp_payload_crc (
    .clk         (clk),
    .rst_n       (rst_n),
    
    .in_data     (crc_lp_payload_input),    
    .in_valid    (crc_lp_payload_valid),    

    // Packet control                   
    .in_first    (crc_lp_payload_first),    

    // Number of valid bytes: 0 to 16   
    .valid_bytes (crc_lp_payload_nbytes),   
    .crc_out     (crc_lp_payload_result)    
);          
                                
endmodule
