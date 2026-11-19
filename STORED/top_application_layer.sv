`timescale 1ns / 1ps

import pixel_pkg::*;

module top_application_layer (
   input  logic        clk,
   input  logic        rst_n,
  
   input  payload_sb_t in_data,
   input  logic        in_valid,
   output logic        in_ready,
  
   output fifo2dld_t   out_data  ,
   output logic        out_valid ,
   input  logic        out_ready   
);

payload_sb_t decode2crc_data ;
logic        decode2crc_valid;
logic        decode2crc_ready;

mem_register u_decode (
  .clk       (clk      ),
  .rst_n     (rst_n    ),

  .in_data   (in_data  ),
  .in_valid  (in_valid ),
  .in_ready  (in_ready ),

  .out_data  (decode2crc_data ),
  .out_valid (decode2crc_valid),
  .out_ready (decode2crc_ready) 
);

crc_fifo u_crc (
   .clk       (clk             ),
   .rst_n     (rst_n           ),
                                 
   .in_data   (decode2crc_data ),
   .in_valid  (decode2crc_valid),
   .in_ready  (decode2crc_ready),
                                 
   .out_data  (out_data ),
   .out_valid (out_valid),
   .out_ready (out_ready)       
);

endmodule
