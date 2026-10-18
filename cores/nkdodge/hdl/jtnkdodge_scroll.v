/*  This file is part of Nekketsu (not an official jotego core).
    Nekketsu is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Background: one 64x32 map of 8x8 tiles, 4 bpp, X scroll only.
    MAME's background_scan: offset = col[4:0] + row<<5 + col[5]<<10,
    code at offset, attribute at offset+0x800 (attr[4:0] code MSBs,
    attr[7:5] colour). Date: 18-10-2026 */

module jtnkdodge_scroll(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              hs,
    input      [ 8:0]  hdump,
    input      [ 8:0]  vdump,
    input      [ 8:0]  scrpos,
    input      [ 1:0]  tile_pal,
    // VRAM (scan side)
    output     [10:0]  vram_addr,  // offset in each 2 kB half
    input      [ 7:0]  code_lsb,
    input      [ 7:0]  attr,
    // ROM
    output     [17:2]  rom_addr,
    output             rom_cs,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 8:0]  pxl,        // { tile_pal, colour, pixel }
    input      [ 7:0]  debug_bus
);

// MAME scrolls by the register + 5; the tilemap shows its data 8 pixels
// after the fetch; +2 more measured against MAME's warning screen.
localparam [8:0] HOFFSET = 9'd5 + 9'd8 + 9'd2;

wire [10:0] map_addr;
wire [31:0] planar;
wire [ 8:0] scrx = scrpos + HOFFSET;

// tilemap gives { row[4:0], col[5:0] }; VRAM holds { col[5], row, col[4:0] }
assign vram_addr = { map_addr[5], map_addr[10:6], map_addr[4:0] };

// ROM word after the hhvvv sort: byte k = pixels 2k (bits 6,4,2,0) and
// 2k+1 (bits 7,5,3,1) of one row, planes MSB to LSB.
// jtframe_tilemap wants { plane3, plane2, plane1, plane0 }, leftmost
// pixel in each byte's MSB.
function [7:0] plane( input [31:0] w, input integer p );
    plane = { w[2*p], w[2*p+1], w[8+2*p], w[8+2*p+1],
              w[16+2*p], w[16+2*p+1], w[24+2*p], w[24+2*p+1] };
endfunction

assign planar = { plane(rom_data,3), plane(rom_data,2), plane(rom_data,1), plane(rom_data,0) };

jtframe_scroll #(
    .SIZE       ( 8         ),
    .VA         ( 11        ),
    .CW         ( 13        ),
    .PW         ( 9         ),
    .MAP_HW     ( 9         ),
    .MAP_VW     ( 8         ),
    .HJUMP      ( 0         ),
    .HLOOP      ( 255       ),  // hdump 256-383 counts as -128..-1, so the first tile is fetched in time
    .LATCH_SCRX ( 1         )   // a new scroll value applies from the next line
) u_scroll(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .hs         ( hs        ),
    .vdump      ( vdump     ),
    .hdump      ( hdump     ),
    .blankn     ( 1'b1      ),
    .flip       ( 1'b0      ),
    .scrx       ( scrx      ),
    .scry       ( 8'd0      ),
    .vram_addr  ( map_addr  ),
    .code       ( { attr[4:0], code_lsb } ),
    .pal        ( { tile_pal, attr[7:5] } ),
    .hflip      ( 1'b0      ),
    .vflip      ( 1'b0      ),
    .rom_addr   ( rom_addr  ),
    .rom_data   ( planar    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    .pxl        ( pxl       )
);

endmodule
