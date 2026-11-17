`timescale 1ns / 1ps

module tb_decode_crc_fifo;
   import pixel_pkg::*;

   localparam time CLK_PERIOD = 10ns;
   localparam logic [5:0] DT_RAW20 = 6'h2F;

   logic clk = 1'b0;
   logic rst_n;
   always #(CLK_PERIOD / 2) clk = ~clk;

   // --------------------------------------------------
   // Stimulus -> decode_fifo -> crc_fifo -> output
   // --------------------------------------------------
   payload_sb_t in_data;
   logic        in_valid;
   logic        in_ready;

   payload_sb_t decode_data;
   logic        decode_valid;
   logic        decode_ready;

   fifo2dld_t out_data;
   logic      out_valid;
   logic      out_ready;

   decode_fifo u_decode (
      .clk       (clk),
      .rst_n     (rst_n),
      .in_data   (in_data),
      .in_valid  (in_valid),
      .in_ready  (in_ready),
      .out_data  (decode_data),
      .out_valid (decode_valid),
      .out_ready(decode_ready)
   );

   crc_fifo u_crc (
      .clk       (clk),
      .rst_n     (rst_n),
      .in_data   (decode_data),
      .in_valid  (decode_valid),
      .in_ready  (decode_ready),
      .out_data  (out_data),
      .out_valid (out_valid),
      .out_ready(out_ready)
   );

   // --------------------------------------------------
   // Waveform aliases for the LATEST crc_fifo RTL.
   // These signals are observation-only.
   // --------------------------------------------------
   payload_sb_t dbg_mem;
   logic [1:0]  dbg_payload_id;
   logic        dbg_is_spkt, dbg_is_hdr, dbg_is_last;
   logic [5:0]  dbg_last_nbytes;
   logic        dbg_extra_crc, dbg_extra_tx;
   logic        dbg_dif_frame_flag;
   logic        dbg_first_frame_sof, dbg_is_spkt_sof;
   logic [15:0] dbg_frame_end_num;

   assign dbg_mem             = u_crc.mem;
   assign dbg_payload_id      = u_crc.payload_id;
   assign dbg_is_spkt         = u_crc.is_spkt;
   assign dbg_is_hdr          = u_crc.is_hdr;
   assign dbg_is_last         = u_crc.is_last;
   assign dbg_last_nbytes     = u_crc.payload_last_nbytes;
   assign dbg_extra_crc       = u_crc.extra_tx_4crc;
   assign dbg_extra_tx        = u_crc.extra_tx;
   assign dbg_dif_frame_flag  = u_crc.dif_frame_flag;
   assign dbg_first_frame_sof = u_crc.first_frame_sof;
   assign dbg_is_spkt_sof     = u_crc.is_spkt_sof;
   assign dbg_frame_end_num   = u_crc.frame_end_num;

   logic [127:0] dbg_sp_input, dbg_lp_input;
   logic         dbg_sp_valid, dbg_lp_valid;
   logic [5:0]   dbg_sp_nbytes, dbg_lp_nbytes;
   logic         dbg_sp_first, dbg_lp_first;
   logic [15:0]  dbg_sp_result, dbg_lp_result;
   logic [15:0]  dbg_sp_reg, dbg_lp_reg;
   logic [15:0]  dbg_sp_next, dbg_lp_next;
   logic [15:0]  dbg_sp_base, dbg_lp_base;

   assign dbg_sp_input   = u_crc.crc_sp_lph_input;
   assign dbg_sp_valid   = u_crc.crc_sp_lph_valid;
   assign dbg_sp_nbytes  = u_crc.crc_sp_lph_nbytes;
   assign dbg_sp_first   = u_crc.crc_sp_lph_first;
   assign dbg_sp_result  = u_crc.crc_sp_lph_result;
   assign dbg_sp_reg     = u_crc.u_sp_lph_crc.crc_reg;
   assign dbg_sp_next    = u_crc.u_sp_lph_crc.crc_next;
   assign dbg_sp_base    = u_crc.u_sp_lph_crc.crc_base;

   assign dbg_lp_input   = u_crc.crc_lp_payload_input;
   assign dbg_lp_valid   = u_crc.crc_lp_payload_valid;
   assign dbg_lp_nbytes  = u_crc.crc_lp_payload_nbytes;
   assign dbg_lp_first   = u_crc.crc_lp_payload_first;
   assign dbg_lp_result  = u_crc.crc_lp_payload_result;
   assign dbg_lp_reg     = u_crc.u_lp_payload_crc.crc_reg;
   assign dbg_lp_next    = u_crc.u_lp_payload_crc.crc_next;
   assign dbg_lp_base    = u_crc.u_lp_payload_crc.crc_base;

   // --------------------------------------------------
   // Pixel pattern. Byte [7:0] is transmitted first.
   // --------------------------------------------------
   function automatic logic [127:0] make_pixel(input int unsigned seed);
      logic [127:0] value;
      value = '0;
      for (int i = 0; i < 16; i++)
         value[i*8 +: 8] = 8'(seed + i);
      return value;
   endfunction

   // --------------------------------------------------
   // One valid input sampled on one rising edge.
   // Adjacent send_pkt calls produce consecutive beats.
   // --------------------------------------------------
   task automatic send_pkt(
      input logic [1:0]   id,
      input logic [15:0]  frame_num,
      input logic [15:0]  line_num,
      input logic [15:0]  word_count,
      input logic [127:0] pixel,
      input string        tag
   );
      @(negedge clk);
      in_valid           = 1'b1;
      in_data.payload_id = id;
      in_data.data_id    = DT_RAW20;
      in_data.word_count = word_count;
      in_data.frame_num  = frame_num;
      in_data.line_num   = line_num;
      in_data.pixel      = pixel;

      $display("[%0t] INPUT  %-26s ID=%b FRAME=%0d LINE=%0d WC=%0d PIXEL=%032h",
               $time, tag, id, frame_num, line_num, word_count, pixel);
      @(posedge clk);
      #1;
   endtask

   // During blanking, keep input data fields unchanged.
   // This matches the present crc_fifo dependency on in_data
   // during extra_tx / is_spkt_sof cycles.
   task automatic blank(input int unsigned cycles);
      for (int i = 0; i < cycles; i++) begin
         @(negedge clk);
         in_valid = 1'b0;
         @(posedge clk);
         #1;
      end
   endtask

   // Each line: HDR holds first 8 pixel bytes;
   // BODY holds 16 bytes per beat; LAST holds 0..15 bytes.
   // WC = 8 + 16*body_beats + last_bytes (no CRC bytes).
   task automatic send_line(
      input logic [15:0] frame_num,
      input logic [15:0] line_num,
      input int unsigned body_beats,
      input int unsigned last_bytes,
      input int unsigned seed
   );
      logic [15:0]  wc;
      logic [127:0] last_pixel;

      wc = 16'(8 + 16*body_beats + last_bytes);
      $display("\n[%0t] LINE FRAME=%0d LINE=%0d WC=%0d (HDR=8 BODY=%0d LAST=%0d)",
               $time, frame_num, line_num, wc, body_beats, last_bytes);

      send_pkt(ID_LPKT_HDR, frame_num, line_num, wc,
               make_pixel(seed), "LPKT_HDR / VID_EN rise");

      for (int i = 0; i < body_beats; i++)
         send_pkt(ID_LPKT_BODY, frame_num, line_num, wc,
                  make_pixel(seed + 8 + i*16),
                  $sformatf("LPKT_BODY[%0d]", i));

      last_pixel = make_pixel(seed + 8 + body_beats*16);
      for (int i = int'(last_bytes); i < 16; i++)
         last_pixel[i*8 +: 8] = '0;

      send_pkt(ID_LPKT_LAST, frame_num, line_num, wc,
               last_pixel, "LPKT_LAST / VID_EN fall");

      // No new input while the extra CRC beat is emitted.
      blank(8);
   endtask

   // --------------------------------------------------
   // Monitors only: no assertions and no reference model.
   // Before posedge NBA: report CRC requests being sampled.
   // After posedge NBA: report registered results/outputs.
   // --------------------------------------------------
   always @(posedge clk) begin
      if (rst_n) begin
         if (decode_valid && dbg_dif_frame_flag)
            $display("[%0t] FRAME_CHANGE old=%0d incoming=%0d SPKT=%b",
                     $time, dbg_mem.frame_num, decode_data.frame_num,
                     dbg_is_spkt);

         if (dbg_sp_valid || dbg_lp_valid)
            $display("[%0t] CRC_REQ SP(v=%b first=%b bytes=%0d input=%032h) LP(v=%b first=%b bytes=%0d input=%032h)",
                     $time,
                     dbg_sp_valid, dbg_sp_first, dbg_sp_nbytes, dbg_sp_input,
                     dbg_lp_valid, dbg_lp_first, dbg_lp_nbytes, dbg_lp_input);
      end

      #2;
      if (rst_n) begin
         if (decode_valid)
            $display("[%0t] DECODE ID=%b FRAME=%0d LINE=%0d WC=%0d",
                     $time, decode_data.payload_id, decode_data.frame_num,
                     decode_data.line_num, decode_data.word_count);

         if (out_valid)
            $display("[%0t] OUTPUT ID=%b BYTES=%0d PIXEL=%032h | mem_frame=%0d extra=%b second_sof=%b first_sof=%b frame_end=%0d",
                     $time, out_data.payload_id, out_data.nbytes,
                     out_data.pixel, dbg_mem.frame_num, dbg_extra_tx,
                     dbg_is_spkt_sof, dbg_first_frame_sof, dbg_frame_end_num);
      end
   end

   // --------------------------------------------------
   // Main stimulus
   // --------------------------------------------------
   initial begin
      rst_n     = 1'b0;
      in_data   = '0;
      in_valid  = 1'b0;
      out_ready = 1'b1; // No downstream backpressure

      repeat (5) @(posedge clk);
      @(negedge clk);
      rst_n = 1'b1;
      blank(3);

      // TC1: frame 0 begins with SPKT, frame_num = 0.
      send_pkt(ID_SPKT, 16'd0, 16'd0, 16'd0, '0,
               "FRAME 0 / first VSYNC");
      blank(10);

      // TC2: frame 0 line 1: 8 + 16 + 15 = 39 bytes.
      // LAST requires an additional one-byte CRC output.
      send_line(16'd0, 16'd1, 1, 15, 'h10);

      // TC3: frame 0 line 2: 8 + 16 + 14 = 38 bytes.
      // LAST occupies exactly 16 bytes including CRC.
      send_line(16'd0, 16'd2, 1, 14, 'h50);
      blank(12);

      // TC4: new SPKT, frame_num changes 0 -> 1.
      // Inspect the expected EOF(frame 0) then SOF(frame 1).
      send_pkt(ID_SPKT, 16'd1, 16'd0, 16'd0, '0,
               "FRAME 1 / new VSYNC");
      blank(10);

      // TC5: frame 1 line 1, 8 + 2*16 + 15 = 55 bytes.
      send_line(16'd1, 16'd1, 2, 15, 'h90);
      blank(12);

      // TC6: same-frame SPKT (frame 1): inspect EOF only.
      // This tests the case dif_frame_flag=0, so no extra SOF.
      send_pkt(ID_SPKT, 16'd1, 16'd0, 16'd0, '0,
               "FRAME 1 / same-frame SPKT");
      blank(12);

      $display("\n[%0t] TESTBENCH COMPLETE -- waveform inspection only", $time);
      $finish;
   end

   initial begin
      $dumpfile("tb_decode_crc_fifo_new.vcd");
      $dumpvars(0, tb_decode_crc_fifo);
   end

   initial begin
      #100000;
      $fatal(1, "Testbench timeout");
   end
endmodule
