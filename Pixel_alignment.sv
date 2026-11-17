`timescale 1ns / 1ps
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

module Pixel_alignment(
   input  logic                        clk,
   input  logic                        rst_n,
   input  logic                        in_vsync,
   input  logic                        in_hsync,
   input  logic                        in_vid_en,
   input  pixel_pkg::video_interface_t in_data
    );
    logic pre_hsync, hsync_rise;
    logic pre_vsync, vsync_rise;
    
    pixel_pkg::video_interface_t 
       data_input_packing_to_pxl_accumulator;
       
    logic valid_input_packing_to_pxl_accumulator;
    
    pixel_pkg::payload_sb_t 
       data_pxl_accumulator_cdc;
       
    logic valid_pxl_accumulator_cdc;
// -------------------------------------------
// HSYNC RISE EVENT CREATE
// -------------------------------------------    
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) 
         pre_vsync <= 1'b0;
      else
         pre_vsync <= in_vsync;
   end
   
   assign vsync_rise = in_vsync & !pre_vsync;

// -------------------------------------------
// HSYNC RISE EVENT CREATE
// -------------------------------------------    
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) 
         pre_hsync <= 1'b0;
      else
         pre_hsync <= in_hsync;
   end
   
   assign hsync_rise = in_hsync & !pre_hsync;

// -------------------------------------------
// INPUT PACKING
// -------------------------------------------
Input_Packing u_input_packing (
   .clk           (clk),
   .rst_n         (rst_n),
   .in_hsync_rise (hsync_rise),
   .in_vid_en     (in_vid_en),
   .in_data       (in_data),  
   
   .out_data      (data_input_packing_to_pxl_accumulator), 
   .out_valid     (valid_input_packing_to_pxl_accumulator)
);

// -------------------------------------------
// pxl_accummulator 128-bit
// -------------------------------------------
pxl_accumulator_128bits u_pxl_accumulator_128bits (
   .clk           (clk),
   .rst_n         (rst_n),
   
   .in_data       (data_input_packing_to_pxl_accumulator),
   .in_valid      (valid_input_packing_to_pxl_accumulator),
   .in_vid_en     (in_vid_en),
   .posedge_vsync (vsync_rise),
   
   .out_data      (data_pxl_accumulator_cdc),
   .out_valid     (valid_pxl_accumulator_cdc)
);

endmodule
