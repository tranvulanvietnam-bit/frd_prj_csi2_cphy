`timescale 1ns / 1ps
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
