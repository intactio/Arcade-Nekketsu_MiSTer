/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Sprites, based on jtkunio_obj by Jose Tejada Gomez. 64 entries of
    { 240-Y, attr, code, X }, attr = { tall, ~hflip, colour[2:0], code[10:8] }
    (MAME spdodgeb_state::draw_sprites). 16x16, 4 bpp, MAME spritelayout:
    planes 3,2 in the upper half of the ROM, planes 1,0 in the lower half;
    after the hhvvvv sort one 32-bit word holds one row of one half:
    byte k = pixels 4k..4k+3, high nibble = upper plane, bit j = pixel j.

    During play 40-64 entries overlap each line (unused ones included), more
    than two SDRAM reads per sprite allow in one line. So after reset the
    sprite ROM is copied from SDRAM to two 32K x 32 BRAMs (lower and upper
    half), and each sprite row is then read in one clock; blank rows are
    skipped. Date: 18-10-2026 */

module jtdodge_obj(
    input              rst,
    input              clk,
    input              pxl_cen,

    input              hs,
    input      [ 7:0]  vrender,
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
wire [ 7:0] scan_addr;
reg  [ 5:0] obj_cnt;
wire [ 6:0] buf_din;
reg  [ 7:0] x, y, ydiff;
reg  [ 8:0] buf_addr;
reg  [ 2:0] dr_pal, pal;
reg  [ 2:0] st;
reg         tall, dr_hflip, hflip, done, dr_busy, x_new,
            inzone, dr_start, dr_rd, dr_load;
reg  [10:0] code;
reg  [14:0] dr_row;      // { code, row } in the BRAMs
reg  [ 3:0] pxl_cnt;
reg  [63:0] pxl_data;    // { plane3, plane2, plane1, plane0 } x 16 pixels
wire [31:0] lo_q, hi_q;
wire        buf_we, dr_free;

assign scan_addr = { obj_cnt, st[1:0] };
assign vram_we   = objram_cs & ~cpu_wrn;
assign dr_free   = !( dr_busy || dr_start || dr_rd || dr_load );

// the line where the sprite's bottom tile starts is 240-Y, so a line is
// in the sprite when (line + Y) mod 256 is in F0-FF (E0-FF if tall)
always @* begin
    ydiff  = vrender + y;
    inzone = &ydiff[7:5] && (tall || ydiff[4]);
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
// line scan, one step per clock. scan_dout follows scan_addr one clock
// later, so byte n of an entry arrives in state n+1 (X in state 4)
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 0;
        done     <= 0;
        obj_cnt  <= 0;
        dr_start <= 0;
        x_new    <= 0;
    end else begin
        dr_start <= 0;
        x_new    <= st==3;
        if( x_new ) x <= scan_dout;     // first clock of state 4 only
        if( hs || copying ) begin
            st       <= 0;
            obj_cnt  <= 0;
            done     <= 0;
        end else if( !done ) begin
            if( st != 4 ) st <= st+3'd1;
            case( st )
                1: y <= scan_dout;
                2: { tall, hflip, pal, code[10:8] } <= { scan_dout[7], ~scan_dout[6], scan_dout[5:0] };
                3: code[7:0] <= scan_dout;
                4: if( !x_new && (!inzone || dr_free) ) begin
                    st       <= 0;
                    dr_start <= inzone;
                    obj_cnt  <= obj_cnt + 1'd1;
                    done     <= &obj_cnt;
                end
            endcase
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
    .addr1  ( scan_addr   ),
    .we1    ( 1'b0        ),
    .q1     ( scan_dout   )
);

wire [6:0] buf_q;
// hdump 256-383 reads buffer 384-511 (-128..-1), where sprites that start
// left of the screen are drawn, so the pixel at -1 shows at x=0
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
