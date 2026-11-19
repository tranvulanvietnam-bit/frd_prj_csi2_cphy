`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
package pixel_pkg;

localparam logic [5:0] DATATYPE_IS_RAW20 = 6'h2F;

   typedef struct packed {
      logic [1:0]   payload_id; 
      logic [5:0]   data_id;
      logic [15:0]  word_count;
      logic [15:0]  frame_num;
      logic [15:0]  line_num;
      logic [127:0] pixel;
   } payload_sb_t ;

   typedef struct packed {
      logic                   pixel_mode; //1:MONO, 0: DUAL
      logic [5:0]             data_id;
      logic [15:0]            word_count;
      logic [15:0]            frame_num;
      logic [15:0]            line_num;
      logic [39:0]            pixel;
   } video_interface_t;
   
   typedef struct packed {
      logic [1:0]   payload_id;
      logic [4:0]   nbytes;
      logic [127:0] pixel;
   } fifo2dld_t;
   
   // Input/ Output transaction identifier
   localparam logic [1:0] ID_LPKT_BODY = 2'b00;
   localparam logic [1:0] ID_LPKT_HDR  = 2'b01;
   localparam logic [1:0] ID_SPKT      = 2'b10;
   localparam logic [1:0] ID_LPKT_LAST = 2'b11;
   
   localparam logic [5:0] SP_DT_FS = 6'b000000;
   localparam logic [5:0] SP_DT_FE = 6'b000001;
   localparam logic [7:0] RES      = 8'b00000000;
   
   
   
   localparam logic [1:0] vc = 2'b01; //virtual channel identifier
   
endpackage