`timescale 1ns / 1ps

import pixel_pkg::*;

module top_pixel_layer(
   input  logic                        clk       ,
   input  logic                        rst_n     ,
   
   input  logic                        in_vsync  ,
   input  logic                        in_hsync  ,
   input  logic                        in_vid_en ,
   
   input  pixel_pkg::video_interface_t in_data   ,
   
   output pixel_pkg::payload_sb_t      out_data  ,
   output logic                        out_valid
    );
    logic pre_hsync, hsync_rise;
    logic pre_vsync, vsync_rise;
    
    pixel_pkg::video_interface_t data_input_packing_to_pxl_accumulator;
       
    logic                        valid_input_packing_to_pxl_accumulator;
    
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
   .clk           (clk                                   ),
   .rst_n         (rst_n                                 ),
   .in_hsync_rise (hsync_rise                            ),
   .in_vid_en     (in_vid_en                             ),
   .in_data       (in_data                               ),  
   
   .out_data      (data_input_packing_to_pxl_accumulator ), 
   .out_valid     (valid_input_packing_to_pxl_accumulator)
);

// -------------------------------------------
// pxl_accummulator 128-bit
// -------------------------------------------
pxl_accumulator_128bits u_pxl_accumulator_128bits (
   .clk           (clk                                   ),
   .rst_n         (rst_n                                 ),
   
   .in_data       (data_input_packing_to_pxl_accumulator ),
   .in_valid      (valid_input_packing_to_pxl_accumulator),
   
   .in_vid_en     (in_vid_en                             ),
   .posedge_vsync (vsync_rise                            ),
   
   .out_data      (out_data                              ),
   .out_valid     (out_valid                             )
);

endmodule
