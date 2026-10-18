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
    Date: 18-10-2026 */

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
    // ROM access
    output reg         rom_cs,
    output     [17:2]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,
    output     [ 8:0]  pxl,         // { obj_pal, colour, pixel }
    input      [ 7:0]  debug_bus
);

// MAME's X is the left edge on screen; the line buffer is read with hdump.
// Checked against MAME frames in Task 7.
localparam [8:0] XOFFSET = 9'd0;

wire        vram_we;
wire [ 7:0] scan_dout;
wire [ 7:0] scan_addr;
reg  [ 5:0] obj_cnt;
wire [ 6:0] buf_din;
reg         cen = 0;
reg  [ 7:0] x, y, ydiff;
reg  [ 8:0] buf_addr;
reg  [ 2:0] dr_pal, pal;
reg  [ 2:0] st;
reg         tall, dr_hflip, hflip, done, dr_busy,
            half, inzone, dr_start;
reg  [10:0] code, dr_code;
reg  [ 3:0] dr_ysub, pxl_cnt;
reg  [31:0] lo_data;     // lower half: planes 1,0
reg  [63:0] pxl_data;    // { plane3, plane2, plane1, plane0 } x 16 pixels
wire        buf_we;

assign scan_addr = { obj_cnt, st[1:0] };
assign vram_we   = objram_cs & ~cpu_wrn;
assign rom_addr  = { half, dr_code, dr_ysub }; // 1+11+4=16

// the line where the sprite's bottom tile starts is 240-Y, so a line is
// in the sprite when (line + Y) mod 256 is in F0-FF (E0-FF if tall)
always @* begin
    ydiff  = vrender + y;
    inzone = &ydiff[7:5] && (tall || ydiff[4]);
end

always @(posedge clk) begin
    cen <= ~cen;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        st       <= 0;
        done     <= 0;
        obj_cnt  <= 0;
        dr_start <= 0;
    end else begin
        if( hs ) begin
            st       <= 0;
            obj_cnt  <= 0;
            done     <= 0;
            dr_start <= 0;
        end else if( cen && !done ) begin
            if( st != 4 ) st <= st+3'd1;
            dr_start <= 0;
            case( st )
                0: y <= scan_dout;
                1: { tall, hflip, pal, code[10:8] } <= { scan_dout[7], ~scan_dout[6], scan_dout[5:0] };
                2: code[7:0] <= scan_dout;
                3: begin
                    x <= scan_dout;
                    // double height: top tile code&~1, bottom tile code|1
                    if( tall ) code[0] <= ydiff[4];
                end
                4: if( !inzone || !dr_busy ) begin
                    st <= 0;
                    dr_start <= inzone;
                    obj_cnt  <= obj_cnt + 1'd1;
                    done     <= &obj_cnt;
                end
            endcase
        end
    end
end

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
assign buf_we = dr_busy & ~rom_cs;

always @(posedge clk) begin
    if( dr_busy ) begin
        if( rom_cs ) begin
            pxl_cnt <= 0;
            if( rom_ok && cen ) begin
                if( !half ) begin
                    lo_data <= rom_data;
                    half    <= 1;
                end else begin
                    pxl_data <= unpack( rom_data, lo_data );
                    rom_cs   <= 0;
                end
            end
        end else begin
            pxl_cnt   <= pxl_cnt + 4'd1;
            dr_busy   <= ~&pxl_cnt;
            pxl_data  <= dr_hflip ? pxl_data>>1 : pxl_data<<1;
            buf_addr  <= buf_addr + 1'd1;
        end
    end
    if( dr_start && cen ) begin
        dr_busy   <= 1;
        // MAME: X above 248 is drawn at X-256 (off the left edge)
        buf_addr  <= { x>8'd248, x } + XOFFSET;
        dr_pal    <= pal;
        dr_hflip  <= hflip;
        dr_code   <= code;
        dr_ysub   <= ydiff[3:0];
        rom_cs    <= 1;
        half      <= 0;
    end
    if( hs ) begin
        dr_busy <= 0;
        rom_cs  <= 0;
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
    .rd_addr( hdump     ),
    .rd     ( pxl_cen   ),
    .rd_data( buf_q     )
);

assign pxl = { obj_pal, buf_q };

endmodule
