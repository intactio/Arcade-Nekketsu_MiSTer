/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    One MSM5205 channel with its address counter. Copy of jtdd_adpcm
    (Jose Tejada Gomez, 2019) plus MAME's stop at the end of the 64 kB
    ROM (spdodgeb_state::adpcm_int: pos >= 0x10000). Date: 18-10-2026 */

module jtdodge_adpcm(
    input               clk,
    input               rst,
    input               cen_oki,        // 384 kHz
    // communication with the sound CPU
    input   [ 7:0]      cpu_dout,
    input   [ 1:0]      cpu_AB,         // 0 start, 1 end page, 2 start page, 3 stop
    input               cs,
    // ROM
    output     [15:0]   rom_addr,
    output              rom_cs,
    input      [ 7:0]   rom_data,
    input               rom_ok,
    // Sound output
    output  signed [11:0] snd
);

reg [9:0] cnt;
reg [3:0] din;
reg [7:0] addr0, addr1;
reg       ad_rst;
wire      sample;
wire      over = addr0 >= addr1 || addr0[7];  // MAME: pos >= end || pos >= 0x10000

always @(posedge clk, posedge rst) begin
    if(rst) begin
        addr0  <= 8'd0;
        addr1  <= 8'd0;
        ad_rst <= 1'b1;
        cnt    <= 10'd0;
        din    <= 4'b0;
    end else begin
        if(cs) begin
            case(cpu_AB)
                2'd0: ad_rst <= 1'b0;
                2'd1: addr1  <= cpu_dout & 8'h7f;
                2'd2: addr0  <= cpu_dout & 8'h7f;
                2'd3: begin
                    ad_rst <= 1'b1;       // stop
                    cnt    <= 10'd0;
                end
            endcase
            if( cpu_AB != 2'd0 ) begin
                ad_rst <= 1'b1;
                cnt    <= 10'd0;
            end
        end
        if(rom_ok) din  <= !cnt[0] ? rom_data[7:4] : rom_data[3:0];
        if( !ad_rst ) begin
            if( sample ) begin
                cnt  <= cnt + 10'd1;
                if(&cnt) addr0 <= addr0+8'd1;
            end
            if( over ) begin
                ad_rst <= 1'b1;
                cnt    <= 10'd0;
            end
        end
    end
end

assign rom_addr = { addr0[6:0], cnt[9:1] };
assign rom_cs   = 1'b1;

jt5205 #(.INTERPOL(0)) u_decod(
    .rst    ( ad_rst    ),
    .clk    ( clk       ),
    .cen    ( cen_oki   ),
    .sel    ( 2'b10     ),  // S48: 384 kHz / 48 = 8 kHz
    .din    ( din       ),
    .sound  ( snd       ),
    .irq    ( sample    ),
    // unused
    .vclk_o (           ),
    .sample (           )
);

endmodule
