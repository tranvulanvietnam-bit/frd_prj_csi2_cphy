`timescale 1ns / 1ps

import pixel_pkg::*;

module top_layer_pixel2application(
   input  logic                        wr_clk,
   input  logic                        wr_rst_n,
   input  logic                        rd_clk,
   input  logic                        rd_rst_n,
   
   input  logic                        in_vsync  ,
   input  logic                        in_hsync  ,
   input  logic                        in_vid_en ,
   
   input  pixel_pkg::video_interface_t in_data   ,
   
   output fifo2dld_t   out_data  ,
   output logic        out_valid ,
   input  logic        out_ready   
    );
    
payload_sb_t data_pixel2cdc ;  
logic        valid_pixel2cdc;

payload_sb_t data_cdc2application;   
logic        valid_cdc2application;
logic        ready_cdc2application;
    
logic cdc_full, cdc_empty;    
    
top_pixel_layer u_pixel_layer (
  .clk       (wr_clk          ),
  .rst_n     (wr_rst_n        ),
                              
  .in_vsync  (in_vsync        ),
  .in_hsync  (in_hsync        ),
  .in_vid_en (in_vid_en       ),
                              
  .in_data   (in_data         ),
                       
  .out_data  (data_pixel2cdc  ),
  .out_valid (valid_pixel2cdc )
);    
    
cdc_fifo_top u_cdc_fifo (
  .wr_clk    (wr_clk               ),
  .wr_rst_n  (wr_rst_n             ),
  .rd_clk    (rd_clk               ),
  .rd_rst_n  (rd_rst_n             ),
 
  .in_data   (data_pixel2cdc       ),
  .in_valid  (valid_pixel2cdc      ),
  .full      (cdc_full),
  
  .out_data  (data_cdc2application ),
  .out_valid (valid_cdc2application),
  .out_ready (ready_cdc2application),
  .empty     (cdc_empty)
);

top_application_layer u_application_layer (
  .clk       (rd_clk               ),  
  .rst_n     (rd_rst_n             ),  
  
  .in_data   (data_cdc2application ), 
  .in_valid  (valid_cdc2application), 
  .in_ready  (ready_cdc2application), 
  
  .out_data  (out_data),
  .out_valid (out_valid),
  .out_ready (out_ready) 
);

always_ff @ (posedge wr_clk or negedge wr_rst_n) begin
   assert (!cdc_full ) 
   else $error("ERROR CDC IS FULL %0t",$time);
end
    
endmodule
