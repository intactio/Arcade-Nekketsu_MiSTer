/*  This file is part of Nekketsu (not an official jotego core).
    Nekketsu is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Sprites, based on jtkunio_obj by Jose Tejada Gomez. 64 entries of
    { 240-Y, attr, code, X }, attr = { tall, ~hflip, colour[2:0], code[10:8] }
    (MAME spdodgeb_state::draw_sprites). 16x16, 4 bpp, MAME spritelayout:
    planes 3,2 in the upper half of the ROM, planes 1,0 in the lower half;
    after the hhvvvv sort one 32-bit word holds one row of one half:
    byte k = pixels 4k..4k+3, high nibble = upper plane, bit j = pixel j.

    After reset the sprite ROM is copied from SDRAM to two 32K x 32 BRAMs
    (lower and upper half), so each sprite row is read in one clock; blank
    rows are skipped. At most 15 entries share a visible row in play
    (MAME, 20000 frames), well under the 32 the list holds.

    Pipeline as on the Renegade board, one line per stage: the line two
    before display reads sprite RAM in step with the beam (entry k at
    board H 4k..4k+3, board H = hdump+16) and lists the entries on that
    row, 32 at most like the board's match RAM; the next line draws the
    list into the line buffer; the line after shows it. Date: 18-10-2026 */

module jtnkdodge_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              hs,
    input      [ 7:0]  vscan,       // row shown two lines later
    input              line_lsb,    // vdump[0], selects the list
    input      [ 8:0]  hdump,
    input      [ 1:0]  obj_pal,

    input      [ 7:0]  cpu_addr,
    input              objram_cs,
    input              cpu_wrn,
    input      [ 7:0]  cpu_dout,
    // ROM access (only to fill the BRAMs)
    output             rom_cs,
    output     [17:2]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 8:0]  pxl,         // { obj_pal, colour, pixel }
    input      [ 7:0]  debug_bus
);

// MAME's X is the left edge on screen; the line buffer is read with hdump.
// -1 measured against MAME attract frames on the device (sprites were one
// pixel to the right).
localparam [8:0] XOFFSET = 9'h1ff;

wire        vram_we;
wire [ 7:0] scan_dout;
wire [ 8:0] scan_h;
wire [ 6:0] buf_din;
reg  [ 7:0] x, sy, sydiff;
reg  [ 4:0] ydiff;
reg  [ 8:0] buf_addr;
reg  [ 2:0] dr_pal, pal, s_pal;
reg         tall, dr_hflip, hflip, dr_busy, inzone, dr_start, dr_rd, dr_load,
            s_tall, s_hflip, rd_busy, rd_valid, list_we;
reg  [10:0] code;
reg  [ 2:0] s_code;
reg  [ 7:0] s_codel;
reg  [ 5:0] list_cnt0, list_cnt1, rd_idx;
reg  [ 4:0] list_wa;
reg  [28:0] list_din;
wire [28:0] list_dout;
wire [ 5:0] wr_cnt = line_lsb ? list_cnt1 : list_cnt0;
wire [ 5:0] rd_cnt = line_lsb ? list_cnt0 : list_cnt1;
reg  [14:0] dr_row;      // { code, row } in the BRAMs
reg  [ 3:0] pxl_cnt;
reg  [63:0] pxl_data;    // { plane3, plane2, plane1, plane0 } x 16 pixels
wire [31:0] lo_q, hi_q;
wire        buf_we, dr_free;

assign vram_we   = objram_cs & ~cpu_wrn;
assign dr_free   = !( dr_busy || dr_start || dr_rd || dr_load );
// board H: 0 at hdump 368, 16 px before the active area
assign scan_h    = hdump >= 9'd368 ? hdump - 9'd368 : hdump + 9'd16;

// the row where the sprite's bottom tile starts is 240-Y, so a row is
// in the sprite when (row + Y) mod 256 is in F0-FF (E0-FF if tall)
always @* begin
    sydiff = vscan + sy;
    inzone = &sydiff[7:5] && (s_tall || sydiff[4]);
end

//////////////////////////////////////////////////////////////
// SDRAM -> BRAM copy after reset: word address { half, code, row }
reg  [15:0] cp_addr;
reg         copying, cp_wait;

assign rom_cs   = copying;
assign rom_addr = cp_addr;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        cp_addr <= 0;
        copying <= 1;
        cp_wait <= 1;
    end else if( copying ) begin
        cp_wait <= 0;
        if( rom_ok && !cp_wait ) begin
            cp_addr <= cp_addr + 1'd1;
            cp_wait <= 1;   // ok must drop for the new address first
            if( &cp_addr ) copying <= 0;
        end
    end
end

wire cp_we = copying && rom_ok && !cp_wait;

jtframe_dual_ram #(.DW(32),.AW(15)) u_lo(
    .clk0   ( clk         ),
    .data0  ( rom_data    ),
    .addr0  ( cp_addr[14:0] ),
    .we0    ( cp_we & ~cp_addr[15] ),
    .q0     (             ),
    .clk1   ( clk         ),
    .data1  ( 32'd0       ),
    .addr1  ( dr_row      ),
    .we1    ( 1'b0        ),
    .q1     ( lo_q        )
);

jtframe_dual_ram #(.DW(32),.AW(15)) u_hi(
    .clk0   ( clk         ),
    .data0  ( rom_data    ),
    .addr0  ( cp_addr[14:0] ),
    .we0    ( cp_we &  cp_addr[15] ),
    .q0     (             ),
    .clk1   ( clk         ),
    .data1  ( 32'd0       ),
    .addr1  ( dr_row      ),
    .we1    ( 1'b0        ),
    .q1     ( hi_q        )
);

//////////////////////////////////////////////////////////////
// scan: the sprite RAM address is board H, one byte per pixel during
// board H 0-255. scan_dout follows the address well within the pixel.
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        list_we   <= 0;
        list_cnt0 <= 0;
        list_cnt1 <= 0;
    end else begin
        list_we <= 0;
        if( pxl_cen && !scan_h[8] ) begin
            if( scan_h==0 ) begin
                if( line_lsb ) list_cnt1 <= 0; else list_cnt0 <= 0;
            end
            case( scan_h[1:0] )
                0: sy <= scan_dout;
                1: { s_tall, s_hflip, s_pal, s_code } <= { scan_dout[7], ~scan_dout[6], scan_dout[5:0] };
                2: s_codel <= scan_dout;
                3: if( inzone && !wr_cnt[5] && !copying ) begin
                    list_we  <= 1;
                    list_wa  <= wr_cnt[4:0];
                    list_din <= { sydiff[4:0], s_tall, s_hflip, s_pal, s_code, s_codel, scan_dout };
                    if( line_lsb ) list_cnt1 <= list_cnt1 + 1'd1;
                    else           list_cnt0 <= list_cnt0 + 1'd1;
                end
            endcase
        end
    end
end

// the list written on one line is drawn on the next
jtframe_dual_ram #(.DW(29),.AW(6)) u_list(
    .clk0   ( clk         ),
    .data0  ( list_din    ),
    .addr0  ( { line_lsb, list_wa } ),
    .we0    ( list_we     ),
    .q0     (             ),

    .clk1   ( clk         ),
    .data1  ( 29'd0       ),
    .addr1  ( { ~line_lsb, rd_idx[4:0] } ),
    .we1    ( 1'b0        ),
    .q1     ( list_dout   )
);

// hand the entries to the drawing engine one at a time
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rd_idx   <= 0;
        rd_busy  <= 0;
        rd_valid <= 0;
        dr_start <= 0;
    end else begin
        dr_start <= 0;
        if( hs || copying ) begin
            rd_idx   <= 0;
            rd_busy  <= 0;
            rd_valid <= 0;
        end else if( !rd_busy ) begin
            rd_busy  <= rd_idx < rd_cnt;    // the address is set, data next clock
            rd_valid <= 0;
        end else if( !rd_valid ) begin
            rd_valid <= 1;
            { ydiff, tall, hflip, pal, code, x } <= list_dout;
        end else if( dr_free ) begin
            dr_start <= 1;
            rd_idx   <= rd_idx + 1'd1;
            rd_busy  <= 0;
        end
    end
end

//////////////////////////////////////////////////////////////
// drawing
// pixel j of group k, from the lower (lo) and upper (hi) half words
function [63:0] unpack( input [31:0] hi, input [31:0] lo );
    integer k, j;
    begin
        for( k=0; k<4; k=k+1 ) for( j=0; j<4; j=j+1 ) begin
            unpack[48+15-(4*k+j)] = hi[8*k+4+j];  // plane 3
            unpack[32+15-(4*k+j)] = hi[8*k  +j];  // plane 2
            unpack[16+15-(4*k+j)] = lo[8*k+4+j];  // plane 1
            unpack[   15-(4*k+j)] = lo[8*k  +j];  // plane 0
        end
    end
endfunction

// leftmost pixel in bit 15 of each plane; shifts left, or right if flipped
assign buf_din = { dr_pal, dr_hflip ?
    { pxl_data[48], pxl_data[32], pxl_data[16], pxl_data[ 0] } :
    { pxl_data[63], pxl_data[47], pxl_data[31], pxl_data[15] } };
assign buf_we = dr_busy;

// dr_start: set the BRAM address; dr_rd: the BRAM reads it;
// dr_load: its data is on lo_q/hi_q
always @(posedge clk) begin
    dr_rd   <= dr_start;
    dr_load <= dr_rd;
    if( dr_start ) begin
        // tall: top tile code&~1, bottom tile code|1
        dr_row    <= { code[10:1], tall ? ydiff[4] : code[0], ydiff[3:0] };
        // MAME: X above 248 is drawn at X-256 (off the left edge)
        buf_addr  <= { x>8'd248, x } + XOFFSET;
        dr_pal    <= pal;
        dr_hflip  <= hflip;
    end
    if( dr_load ) begin
        pxl_data <= unpack( hi_q, lo_q );
        pxl_cnt  <= 0;
        dr_busy  <= (hi_q | lo_q) != 0;  // blank rows draw nothing
    end else if( dr_busy ) begin
        pxl_cnt   <= pxl_cnt + 4'd1;
        dr_busy   <= ~&pxl_cnt;
        pxl_data  <= dr_hflip ? pxl_data>>1 : pxl_data<<1;
        buf_addr  <= buf_addr + 1'd1;
    end
    if( hs ) begin
        dr_busy <= 0;
        dr_rd   <= 0;
        dr_load <= 0;
    end
end

jtframe_dual_ram #(.AW(8)) u_ram(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_addr    ),
    .we0    ( vram_we     ),
    .q0     (             ),

    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan_h[7:0] ),
    .we1    ( 1'b0        ),
    .q1     ( scan_dout   )
);

wire [6:0] buf_q;
// hdump 256-383 reads buffer 384-511 (-128..-1), where sprites that start
// left of the screen are drawn (X above 248). Addresses 256-383 take the
// right-hand overflow of sprites at X 241-248 and are never shown
wire [8:0] rd_addr = hdump[8] ? { 2'b11, hdump[6:0] } : hdump;

jtframe_obj_buffer #(
    .DW     ( 7     ),
    .AW     ( 9     ),
    .ALPHAW ( 4     ),
    .ALPHA  ( 32'd0 )
) u_buffer(
    .clk    ( clk       ),
    .LHBL   ( ~hs       ),
    .flip   ( 1'b0      ),
    // New data writes
    .wr_data( buf_din   ),
    .wr_addr( buf_addr  ),
    .we     ( buf_we    ),
    // Old data reads (and erases)
    .rd_addr( rd_addr   ),
    .rd     ( pxl_cen   ),
    .rd_data( buf_q     )
);

assign pxl = { obj_pal, buf_q };

endmodule
