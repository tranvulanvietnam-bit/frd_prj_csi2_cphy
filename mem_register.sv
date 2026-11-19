`timescale 1ns / 1ps

import pixel_pkg::*;

module mem_register(
   input  logic        clk       ,
   input  logic        rst_n     ,
 
   input  payload_sb_t in_data   ,
   input  logic        in_valid  ,
   output logic        in_ready  ,
 
   output payload_sb_t out_data  ,
   output logic        out_valid ,
   input  logic        out_ready
);
   assign in_ready = 1'b1;
   
   // write data from cdc    
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         out_data  <= '0;
      end else if (in_valid) begin
         out_data  <= in_data;
      end
   end
   
   always_ff @(posedge clk) begin
      out_valid <= in_valid;
   end
endmodule
