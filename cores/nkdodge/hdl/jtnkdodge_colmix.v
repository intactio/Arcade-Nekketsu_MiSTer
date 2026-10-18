/*  This file is part of Nekketsu (not an official jotego core).
    Nekketsu is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Colour PROMs (MAME spdodgeb_state::palette): entry i is
    R = .158[i] bits 3:0, G = .158[i] bits 7:4, B = .159[i] bits 3:0.
    The pal BRAM holds .158 at 000-3FF and .159 at 400-7FF.
    Tiles use entries 000-1FF, sprites 200-3FF (pen 0 transparent).
    Date: 18-10-2026 */

module jtnkdodge_colmix(
    input             clk,
    input             pxl_cen,
    input             LHBL,
    input      [ 8:0] hdump,
    input             LVBL,
    input      [ 8:0] scr_pxl,    // { tile_pal, colour, pixel }
    input      [ 8:0] obj_pxl,
    output reg [10:0] pal_addr,
    input      [ 7:0] pal_data,
    output reg [ 7:0] red,
    output reg [ 7:0] green,
    output reg [ 7:0] blue,
    input      [ 3:0] gfx_en
);

reg  [ 9:0] idx;
reg  [ 3:0] nr, ng, nb;
reg  [ 1:0] ph;
wire        hvis = hdump < 9'd256 || hdump == 9'd383;

// resistor DAC weights from MAME's palette(): 0x0e, 0x1f, 0x43, 0x8f
function [7:0] dac( input [3:0] c );
    dac = (c[0] ? 8'h0e : 8'd0) + (c[1] ? 8'h1f : 8'd0) +
          (c[2] ? 8'h43 : 8'd0) + (c[3] ? 8'h8f : 8'd0);
endfunction
wire        obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];

// four clk24 cycles per pixel: address .158, address .159 and read R/G,
// read B, output. pal_data follows pal_addr one clock later (checked on
// the device: reading at phase 2 returned the .159 data)
always @(posedge clk) begin
    ph <= pxl_cen ? 2'd0 : ph + 2'd1;
    case( ph )
        0: pal_addr <= { 1'b0, idx };
        1: begin
            pal_addr <= { 1'b1, idx };
            { ng, nr } <= pal_data;
        end
        2: nb <= pal_data[3:0];
        // the output runs one pixel ahead of LHBL here: blanking with LHBL
        // blacked out column 0 on the device, so open the window one pixel early
        3: { red, green, blue } <= (!LVBL || !hvis) ? 24'd0 : { dac(nr), dac(ng), dac(nb) };
    endcase
    if( pxl_cen ) begin
        idx <= !obj_blank ? { 1'b1, obj_pxl } :
               gfx_en[0]  ? { 1'b0, scr_pxl } : 10'd0;
    end
end

endmodule
