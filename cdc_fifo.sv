`timescale 1ns / 1ps

module cdc_fifo_top(
    input  logic                              wr_clk,
    input  logic                              wr_rst_n,
    input  logic                              rd_clk,
    input  logic                              rd_rst_n,

    input  pixel_pkg::payload_sb_t in_data,
    input  logic                              in_valid,
    output logic                              full,

    output pixel_pkg::payload_sb_t out_data,
    output logic                              out_valid,
    input  logic                              out_ready,
    output logic                              empty
);
   localparam int ADDR_W = 3;
   localparam int PTR_W  = ADDR_W + 1; // wrap bit + address bits

   // wr_bin is fifo wr_addr, 
   // wr_gray sent to rd clock domain to know if empty -> read control
   logic [PTR_W-1:0] wr_bin, wr_gray;
   
   // rd_bin is fifo rd_addr, 
   // rd_gray sent to wr clock domain to know if full -> write control
   logic [PTR_W-1:0] rd_bin, rd_gray;
   
   logic [PTR_W-1:0] rd_gray_wsync;
   
   logic [PTR_W-1:0] wr_gray_rsync;

   logic wr_push, rd_pop;
   //--------------------------------------
   // Full and Empty control signal
   //--------------------------------------
   // gray pointer full when 2 msb unequal, rest lsb equal
   assign full  = (wr_gray == {
       ~rd_gray_wsync[PTR_W-1:PTR_W-2],
        rd_gray_wsync[PTR_W-3:0]
   });
   
   assign empty = (rd_gray == wr_gray_rsync);
   
   //--------------------------------------
   // write input control signal
   //--------------------------------------
   assign wr_push = in_valid & !full;

   //--------------------------------------
   // read output control signal
   //--------------------------------------
   assign rd_pop = !empty & out_ready;

   //--------------------------------------
   // WRITE FIFO DEPTH = 8
   //--------------------------------------
   cdc_fifo_mem8 mem (
       .wr_clk   (wr_clk),
       .wr_push  (wr_push),
       .wr_addr  (wr_bin[ADDR_W-1:0]),
       .wr_data  (in_data),
       .rd_clk   (rd_clk),
       .rd_pop   (rd_pop),
       .rd_addr  (rd_bin[ADDR_W-1:0]),
       .rd_data  (out_data)
   );
   //--------------------------------------
   // WRITE Pointer B2G, update when valid
   //--------------------------------------
   cdc_fifo #(.PTR_W(PTR_W)) wr_ptr_ctrl (
       .clk      (wr_clk),
       .rst_n    (wr_rst_n),
       .advance  (wr_push),
       .bin_ptr  (wr_bin),
       .gray_ptr (wr_gray)
   );
   
   //--------------------------------------
   // WRITE Gray Pointer, send to Read domain
   //--------------------------------------
   cdc_gray_sync2 #(.WIDTH(PTR_W)) wrgray_to_rd (
       .dst_clk    (rd_clk),
       .dst_rst_n  (rd_rst_n),
       .gray_async (wr_gray),
       .gray_sync  (wr_gray_rsync)
   );
   
   //--------------------------------------
   // Read Pointer B2G when Not Empty
   //--------------------------------------
   cdc_fifo #(.PTR_W(PTR_W)) rd_ptr_ctrl (
       .clk      (rd_clk),
       .rst_n    (rd_rst_n),
       .advance  (rd_pop),
       .bin_ptr  (rd_bin),
       .gray_ptr (rd_gray)
   );
   
   //--------------------------------------
   // Read gray pointer to the Write domain
   //--------------------------------------
   cdc_gray_sync2 #(.WIDTH(PTR_W)) rdgray_to_wr (
       .dst_clk    (wr_clk),
       .dst_rst_n  (wr_rst_n),
       .gray_async (rd_gray),
       .gray_sync  (rd_gray_wsync)
   );

   // ouput data is valid on each rd_pop = 1
   assign out_valid = rd_pop;


endmodule

module cdc_fifo #(
    parameter int PTR_W = 4
) (
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 advance,
    output logic [PTR_W-1:0]     bin_ptr,
    output logic [PTR_W-1:0]     gray_ptr
);
    logic [PTR_W-1:0] bin_inc;
    assign bin_inc = bin_ptr + 1'b1;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
           bin_ptr  <= '0;
           gray_ptr <= '0;
        end
        else if (advance) begin
           bin_ptr  <= bin_inc;
           gray_ptr <= (bin_inc >> 1) ^ bin_inc;
        end
    end
endmodule

// Synchronize a Gray-code pointer into a receiving clock domain.
module cdc_gray_sync2 #(
    parameter int WIDTH = 4
) (
    input  logic             dst_clk,
    input  logic             dst_rst_n,
    input  logic [WIDTH-1:0] gray_async,
    output logic [WIDTH-1:0] gray_sync
);
    logic [WIDTH-1:0] sync_ff1, sync_ff2;
    
    always_ff @(posedge dst_clk or negedge dst_rst_n) begin
       if (!dst_rst_n) begin
          sync_ff1 <= '0;
          sync_ff2 <= '0;
       end
       else begin
          sync_ff1 <= gray_async;
          sync_ff2 <= sync_ff1;
       end
    end

    assign gray_sync = sync_ff2;
endmodule

module cdc_fifo_mem8 (
    input  logic                              wr_clk,
    input  logic                              wr_push,
    input  logic [2:0]                        wr_addr,
    input  pixel_pkg::payload_sb_t wr_data,

    input  logic                              rd_clk,
    input  logic                              rd_pop,
    input  logic [2:0]                        rd_addr,
    output pixel_pkg::payload_sb_t rd_data
);
    pixel_pkg::payload_sb_t mem [0:7];

    always_ff @(posedge wr_clk) begin
       if (wr_push) // wr_push = in_valid & !full;
          mem[wr_addr] <= wr_data;
    end

    assign rd_data = (rd_pop)? mem[rd_addr]: '0;
    
endmodule
