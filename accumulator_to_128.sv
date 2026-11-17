`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
module pixel_accumulator_to_128_dont_erase (
    input logic clk,
    input logic rst_n,
    
    pixel_accumulator_if.slave pixel_in,

    output logic [127:0] out_data,
    output logic         out_valid,
    input  logic         out_ready
);
 
   localparam int ACCU_W = 160;
   localparam int IN_W  = pixel_in.DATA_W;

   logic [ACCU_W-1:0] accum;
   logic [ACCU_W-1:0] accum_next;
   
   logic [ACCU_W-1:0] accum_shift;
   logic [7:0] bit_count_shift; 
    
   logic [7:0] bit_count;
   logic [7:0] bit_count_next;

   logic in_handshake;
   logic out_handshake;

   // -------------------------------------------
   // Output interface
   // -------------------------------------------
   
   // if bit_count[7] = 1; bit_count >= 128; else bit_count < 128
   assign out_valid = (bit_count[7]); 
   
   // read OUT_W = 128 LSB
   assign out_data  = accum[127:0];

   assign out_handshake = out_valid & out_ready;

   // -------------------------------------------
   // Input interface
   // -------------------------------------------
   
   // input ready when bit_count after write input smaller than accumulator w
   // when read and write at same clock, must minus the out_w
   assign pixel_in.ready = (bit_count - (out_handshake ? 128 : 8'd0)) <= (ACCU_W - IN_W);

   assign in_handshake = pixel_in.valid & pixel_in.ready;

   // -------------------------------------------
   // Accumulator next-state logic
   // -------------------------------------------
   always_comb begin  
      accum_shift     = {128'd0, accum[159:128]};
      bit_count_shift = bit_count - 128;
       
      // if out and in same clk. append data to the shifted accumualator
      // case for synthesizer implement mux, if else for priority encoder
      case ({out_handshake, in_handshake})
         2'b11: begin // both out and in
            accum_next     = accum_shift | ({128'd0, pixel_in.data} << bit_count_shift);
            bit_count_next = bit_count_shift + IN_W;
         end
         2'b10: begin // only output
            accum_next     = accum_shift; 
            bit_count_next = bit_count_shift;
         end
         2'b01: begin // only input
            accum_next     = accum | ({128'd0, pixel_in.data} << bit_count);
            bit_count_next = bit_count + IN_W;
         end
         default: begin
            accum_next     = accum;
            bit_count_next = bit_count;
         end
      endcase
   end

   // -------------------------------------------
   // Sequential registers
   // -------------------------------------------
   always_ff @(posedge clk or negedge rst_n) begin
       if (!rst_n) begin
           accum     <= '0;
           bit_count <= '0;
       end
       else begin
           accum     <= accum_next;
           bit_count <= bit_count_next;
       end
   end

endmodule

