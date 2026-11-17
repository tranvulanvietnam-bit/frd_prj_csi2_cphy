`timescale 1ns / 1ps
import pixel_pkg::*;

module decode_fifo(
   input  logic                              clk,
   input  logic                              rst_n,
   
   input  payload_sb_t                       in_data,
   input  logic                              in_valid,
   output logic                              in_ready,
   
   output payload_sb_t                       out_data,
   output logic                              out_valid,
   input  logic                              out_ready
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
//   typedef struct packed {
//      logic [1:0]   payload_id;
//      logic [4:0]   nbytes;
//      logic [127:0] pixel;
//   } fifo2dld_t;
   
//   // Input/ Output transaction identifier
//   localparam logic [1:0] ID_LPKT_BODY = 2'b00;
//   localparam logic [1:0] ID_LPKT_HDR  = 2'b01;
//   localparam logic [1:0] ID_SPKT      = 2'b10;
//   localparam logic [1:0] ID_LPKT_LAST = 2'b11;
   
//   localparam logic [5:0] SP_DT_FS = 6'b000000;
//   localparam logic [5:0] SP_DT_FE = 6'b000001;
//   localparam logic [4:0] RES      = 5'b00000;
module crc_fifo(
   input  logic        clk,
   input  logic        rst_n,
  
   input  payload_sb_t in_data,
   input  logic        in_valid,
   output logic        in_ready,
  
   output fifo2dld_t   out_data,
   output logic        out_valid,
   input  logic        out_ready
);
   assign in_ready = 1'b1;
   
   payload_sb_t mem;
   
   // write data from decode   
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         mem  <= '0;
      end else if (in_valid) begin
         mem  <= in_data;
      end
   end
   
   logic [1:0]  payload_id;
   
   assign payload_id = in_data.payload_id;
   
   logic is_spkt, is_hdr, is_last;
   
   assign is_spkt = (payload_id == ID_SPKT);
   assign is_hdr  = (payload_id == ID_LPKT_HDR);
   assign is_last = (payload_id == ID_LPKT_LAST);
   
   logic [5:0] payload_last_nbytes;
   
   assign payload_last_nbytes  = 
      {2'b0, ~in_data.word_count[3], in_data.word_count[2:0]};
      
//-------------------------------------------------
// extra_transaction control
//-------------------------------------------------
   logic dif_frame_flag;
   
   assign dif_frame_flag = (mem.frame_num != in_data.frame_num);

   logic extra_tx_4crc ;
   
   assign extra_tx_4crc = 
      (payload_last_nbytes == 5'd15) &
      (is_last);
      
   logic extra_tx;
   
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         extra_tx <= 1'b0;
      end
      else begin 
         extra_tx <= in_valid & 
                     (extra_tx_4crc | dif_frame_flag);
      end
   end

   // Identify the SECOND output as SOF
   logic is_spkt_sof;
   
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
          is_spkt_sof <= 1'b0;
      end else begin
          is_spkt_sof <= extra_tx &
                        (is_spkt);
      end
   end

//-------------------------------------------------
// NEW FRAME event CONTROL    
//-------------------------------------------------     
   logic first_frame_sof;  
             
   always_ff @(posedge clk or negedge rst_n) begin
      if (!rst_n) begin
         first_frame_sof <= 1'b1;
      end
      else begin
         if (out_valid) begin
            first_frame_sof <= 1'b0;
         end
      end
   end   
   
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
   logic [127:0] crc_sp_lph_input;
   logic         crc_sp_lph_valid;
   logic [5:0]   crc_sp_lph_nbytes; // value from 0 to 16 
   logic         crc_sp_lph_first; // crc_base = in_first ? RESET : NO_RESET;   
   logic [15:0]  crc_sp_lph_result;
   
   logic [127:0] crc_lp_payload_input;
   logic         crc_lp_payload_valid;
   logic [5:0]   crc_lp_payload_nbytes; // value from 0 to 16 
   logic         crc_lp_payload_first; // crc_base = in_first ? RESET : NO_RESET;   
   logic [15:0]  crc_lp_payload_result;
      
   assign crc_lp_payload_valid = in_valid & 
                                 (!is_spkt);
                                 // LPH, LP_BODY, LP_LAST
                                    
   assign crc_sp_lph_valid     = (in_valid | extra_tx) & 
                                 (is_spkt  | is_hdr);
                                 // SP, SP_EXTRA, LPH
//----------------------------------------- 
// CRC INPUT ASSIGN                             
//----------------------------------------- 
   // Drive input for crc_lp_payload
   always_comb begin
      case (payload_id)
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
           crc_lp_payload_nbytes = payload_last_nbytes;
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
      case (payload_id)
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
//---------------------------------------------------
// OUTPUT ASSIGN
//---------------------------------------------------
logic [15:0] frame_end_num;

assign frame_end_num = (extra_tx)? mem.frame_num[15:0] - 1'b1 :
                       mem.frame_num[15:0];

always_comb begin
   case (mem.payload_id) 
   ID_SPKT: begin
      out_data.payload_id = ID_SPKT;
      out_data.nbytes     = 5'd6;
      
      if (is_spkt_sof | first_frame_sof) begin
         out_data.pixel = 128'({      
            RES, vc[1:0], SP_DT_FS,   
            mem.frame_num[15:0],  
            crc_sp_lph_result[15:0]});
      end else begin
         out_data.pixel = 128'({
            RES, vc[1:0], SP_DT_FE, 
            frame_end_num[15:0],
            crc_sp_lph_result[15:0]});
      end
   end
   ID_LPKT_HDR: begin
      out_data.payload_id = ID_LPKT_HDR;
      out_data.nbytes     = 5'd6;
      out_data.pixel      = 128'({
         RES, vc[1:0], in_data.data_id[5:0], 
         in_data.word_count[15:0],
         crc_sp_lph_result[15:0],
         mem.pixel[63:0]}); 
   end
   ID_LPKT_BODY: begin
      out_data.payload_id = ID_LPKT_BODY;
      out_data.nbytes     = 5'd16;
      out_data.pixel      = mem.pixel;
   end
   ID_LPKT_LAST: begin
      case (1'b1)
         (payload_last_nbytes == 7'd15): begin
            if (extra_tx) begin
               out_data.payload_id = ID_LPKT_BODY;
               out_data.nbytes     = 5'd16;
               out_data.pixel      = {
                  crc_lp_payload_result[7:0],
                  mem.pixel[119:0]};
            end else begin
               out_data.payload_id = ID_LPKT_LAST;
               out_data.nbytes     = 5'd1;
               out_data.pixel      = 128'(crc_lp_payload_result[15:8]);
            end
         end
         (payload_last_nbytes == 7'd14): begin
            out_data.payload_id = ID_LPKT_LAST;
            out_data.nbytes     = 5'd16;
            out_data.pixel      = {
               crc_lp_payload_result[15:0],
               mem.pixel[111:0]};
         end
         (payload_last_nbytes < 7'd14): begin
            out_data.payload_id = ID_LPKT_LAST;
            out_data.nbytes     = 
               7'(payload_last_nbytes + 7'd2);
            out_data.pixel      = 
               mem.pixel |
               (128'(crc_lp_payload_result) << (payload_last_nbytes * 8));
         end
      endcase
      
   end
   default: begin
      out_data = '0;
   end
   endcase
end    
   
endmodule

module crc16_stream_128 (
    input  logic         clk,
    input  logic         rst_n,

    input  logic [127:0] in_data,
    input  logic         in_valid,

    // Packet control
    input  logic         in_first,

    // Number of valid bytes: 0 to 16
    input  logic [5:0]   valid_bytes,

    output logic [15:0]  crc_out
);

    localparam logic [15:0] CRC_INIT = 16'hFFFF;
    localparam logic [15:0] CRC_POLY = 16'h8408;

    logic [15:0] crc_reg;
    logic [15:0] crc_base;
    logic [15:0] crc_next;

    // -------------------------------------------
    // CRC-16 calculation function
    // LSB-first, reflected polynomial 0x8408
    // -------------------------------------------
    function automatic logic [15:0] calc_crc16 (
        input logic [15:0]  crc_in,
        input logic [127:0] data_in,
        input logic [5:0]   byte_count
    );
        logic [15:0] crc;

        crc = crc_in;

        for (int b = 0; b < 16; b++) begin
            if (b < int'(byte_count)) begin

                for (int i = 0; i < 8; i++) begin
                    if (crc[0] ^ data_in[b*8+i])
                        crc = (crc >> 1) ^ CRC_POLY;
                    else
                        crc = crc >> 1;
                end

            end
        end

        return crc;
    endfunction

    // -------------------------------------------
    // CRC initialization selection
    // -------------------------------------------
    assign crc_base =
        in_first ? CRC_INIT : crc_reg;

    // -------------------------------------------
    // Combinational CRC calculation
    // -------------------------------------------
    assign crc_next =
        calc_crc16(crc_base, in_data, valid_bytes);

    // -------------------------------------------
    // Sequential CRC register
    // -------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crc_reg       <= CRC_INIT;
        end
        else begin
            if (in_valid) begin
               // Update accumulated CRC every beat
               crc_reg <= crc_next;
            end
        end
    end
    
    assign crc_out  = crc_reg;

endmodule
