/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Colour PROMs (MAME spdodgeb_state::palette): entry i is
    R = .158[i] bits 3:0, G = .158[i] bits 7:4, B = .159[i] bits 3:0.
    The pal BRAM holds .158 at 000-3FF and .159 at 400-7FF.
    Tiles use entries 000-1FF, sprites 200-3FF (pen 0 transparent).
    Date: 18-10-2026 */

module jtdodge_colmix(
    input             clk,
    input             pxl_cen,
    input             LHBL,
    input             LVBL,
    input      [ 8:0] scr_pxl,    // { tile_pal, colour, pixel }
    input      [ 8:0] obj_pxl,
    output reg [10:0] pal_addr,
    input      [ 7:0] pal_data,
    output reg [ 3:0] red,
    output reg [ 3:0] green,
    output reg [ 3:0] blue,
    input      [ 3:0] gfx_en
);

reg  [ 9:0] idx;
reg  [ 3:0] nr, ng;
reg  [ 1:0] ph;
wire        obj_blank = obj_pxl[3:0]==0 || !gfx_en[3];

// four clk24 cycles per pixel: address .158, address .159, read R/G,
// read B and output (the PROM BRAM answers one clock after the address)
always @(posedge clk) begin
    ph <= pxl_cen ? 2'd0 : ph + 2'd1;
    case( ph )
        0: pal_addr <= { 1'b0, idx };
        1: pal_addr <= { 1'b1, idx };
        2: { ng, nr } <= pal_data;
        3: { red, green, blue } <= (!LVBL || !LHBL) ? 12'd0 : { nr, ng, pal_data[3:0] };
    endcase
    if( pxl_cen ) begin
        idx <= !obj_blank ? { 1'b1, obj_pxl } :
               gfx_en[0]  ? { 1'b0, scr_pxl } : 10'd0;
    end
end

endmodule
