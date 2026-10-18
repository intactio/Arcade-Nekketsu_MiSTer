/*  This file is part of Nekketsu (not an official jotego core).
    Nekketsu is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Video timing: 6 MHz, 384 x 272. Lines are numbered as on the
    Renegade board (TA-0018, Super Dodge Ball's sibling): the line counter
    runs 8-255, then 232-255 with V8 set. The interrupts come from counter
    edges and the row drawn on a line is the count minus ROW_SUB: rows
    9-246 are visible (238 lines), IRQ every 8 lines, NMI on the last
    visible line. Date: 18-10-2026 */

module jtnkdodge_video(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              running,    // low while JTFRAME's pause stops the CPU
    // CPU
    input      [11:0]  cpu_addr,
    input      [ 7:0]  cpu_dout,
    input              cpu_rnw,
    input              vram_cs,
    input              objram_cs,
    output     [ 7:0]  vram_dout,
    input      [ 8:0]  scrpos,
    input              flip,
    input      [ 1:0]  tile_pal,
    input      [ 1:0]  obj_pal,
    // interrupts
    output reg         irq_set,
    output reg         nmi_set,
    // ROMs
    output     [17:2]  scr_addr,
    output             scr_cs,
    input      [31:0]  scr_data,
    input              scr_ok,
    output     [17:2]  obj_addr,
    output             obj_cs,
    input      [31:0]  obj_data,
    input              obj_ok,
    output     [10:0]  pal_addr,
    input      [ 7:0]  pal_data,
    // video signals
    output             HS,
    output             VS,
    output             LVBL,
    output             vblank,     // IN0 bit 0
    output             LHBL,
    output     [7:0]   red,
    output     [7:0]   green,
    output     [7:0]   blue,
    input      [3:0]   gfx_en,
    input      [7:0]   debug_bus
);

// Line numbering as on the board. These values put the court scroll
// write of the IRQ handler (a delay loop, then $3004 at 5 lines + 270 px)
// in the hblank between rows 23 and 24, under the title bar, and in the
// mirrored place when flipped (IRQ #28). MAME's spdodgeb instead: ROW_SUB
// 8, counts 8-247 visible, V2 falling without gate, no IRQ on the NMI
// line, NMI on vdump 256, vblank bit from ~LVBL, events where vdump changes.
localparam [7:0] ROW_SUB    = 8'd2;     // rows are two lines old (VF')
localparam [8:0] VIS_FIRST  = 9'd11,    // first and last visible count (V8=0):
                 VIS_LAST   = 9'd248;   // rows 9-246
localparam       IRQ_BIT    = 2,        // IRQ on an edge of this counter bit:
                 IRQ_RISE   = 1,        // V2 rising, counts 12, 20, ...
                 IRQ_GATE   = 1,        // none while the vblank bit is high
                 IRQ_ON_NMI = 1;        // IRQ and NMI are separate flip-flops
localparam [8:0] NMI_LINE   = 9'd240;   // vdump of count 248, where CNT_VER rises
localparam       VBL_CNTVER = 1;        // vblank bit from CNT_VER, else ~LVBL
localparam [8:0] H_EVENT    = 9'd368;   // the counter steps 16 px before the active area

wire [8:0] vdump, vrender, hdump;
reg  [8:0] vcnt_l;
reg        cnt_ver_l;
wire [8:0] vcnt, vcnt_r;             // { V8, V[7:0] }
wire [7:0] row, row_r;
wire       cnt_ver;

// vdump 0-247 is count 8-255, vdump 248-271 is count 232-255 with V8 set
function [8:0] vcount( input [8:0] line );
    vcount = line < 9'd248 ? { 1'b0, line[7:0]+8'd8 } : { 1'b1, line[7:0]-8'd16 };
endfunction

assign vcnt    = vcount( vdump   );
assign vcnt_r  = vcount( vrender );
assign row     = vcnt[7:0]   - ROW_SUB;
assign row_r   = vcnt_r[7:0] - ROW_SUB;
// high from count 248 to the end of the V8 lines, plus count 8 (V8
// delayed one line on the board)
assign cnt_ver = vcnt[8] || &vcnt[7:3] || vdump==9'd0;
assign vblank  = VBL_CNTVER ? cnt_ver_l : ~LVBL;

// vdump 0 is count 8: vdump 3-240 visible
jtframe_vtimer #(
    .V_START    ( 9'd0      ),
    // LVBL follows these one line late: VB_START is the last visible line
    // and VB_END the line before the first one (checked on the device)
    .VB_START   ( VIS_LAST-9'd8 ),
    .VB_END     ( VIS_FIRST==9'd8 ? 9'd271 : VIS_FIRST-9'd9 ),
    .VS_START   ( 9'd252    ),
    .VCNT_END   ( 9'd271    ),
    .HB_START   ( 9'd256    ),
    .HB_END     ( 9'd0      ),
    .HS_START   ( 9'd303    ),
    .HS_END     ( 9'd303+9'd32 ),
    .HCNT_END   ( 9'd383    )
) u_vtimer (
    .clk     ( clk          ),
    .pxl_cen ( pxl_cen      ),
    .vdump   ( vdump        ),
    .vrender ( vrender      ),
    .vrender1(              ),
    .H       ( hdump        ),
    .Hinit   (              ),
    .Vinit   (              ),
    .LHBL    ( LHBL         ),
    .LVBL    ( LVBL         ),
    .HS      ( HS           ),
    .VS      ( VS           )
);

// the counter steps at H_EVENT; vdump already holds the new line there.
// irq_set and nmi_set are one clk pulses
always @(posedge clk) begin
    irq_set <= 0;
    nmi_set <= 0;
    if( pxl_cen && hdump==H_EVENT ) begin
        vcnt_l    <= vcnt;
        cnt_ver_l <= cnt_ver;
        irq_set   <= vcnt[IRQ_BIT]!=vcnt_l[IRQ_BIT] && vcnt[IRQ_BIT]==IRQ_RISE[0]
                  && !(IRQ_GATE[0] && cnt_ver) && (IRQ_ON_NMI[0] || vdump!=NMI_LINE);
        nmi_set   <= vdump==NMI_LINE;
    end
end

// The scroll and palette registers are used as they are, as on the board
// (no latch between the CPU write and the video). JTFRAME's pause stops
// the CPU, and with it the interrupt handlers that rewrite the registers
// for each part of the screen, so each line's values are recorded while
// running and replayed while paused.
reg  [12:0] line_regs[0:511];
reg  [12:0] held;
wire [12:0] live = { obj_pal, tile_pal, scrpos };
wire [ 8:0] scrpos_v;
wire [ 1:0] tile_pal_v, obj_pal_v;

always @(posedge clk) if( pxl_cen ) begin
    if( running && hdump==H_EVENT ) line_regs[vdump] <= live;
    if( hdump==9'd304 ) held <= line_regs[vdump];  // vdump steps at 303
end
assign { obj_pal_v, tile_pal_v, scrpos_v } = running ? live : held;

wire [10:0] scan_addr;
wire [ 7:0] code_dout, attr_dout, code_cpu, attr_cpu;
wire [ 8:0] scr_pxl, obj_pxl;

assign vram_dout = cpu_addr[11] ? attr_cpu : code_cpu;

// 4 kB video RAM: 000-7FF tile code, 800-FFF attribute
jtframe_dual_ram #(.AW(11)) u_code(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_addr[10:0] ),
    .we0    ( vram_cs & ~cpu_rnw & ~cpu_addr[11] ),
    .q0     ( code_cpu    ),
    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan_addr   ),
    .we1    ( 1'b0        ),
    .q1     ( code_dout   )
);

jtframe_dual_ram #(.AW(11)) u_attr(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_addr[10:0] ),
    .we0    ( vram_cs & ~cpu_rnw & cpu_addr[11] ),
    .q0     ( attr_cpu    ),
    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( scan_addr   ),
    .we1    ( 1'b0        ),
    .q1     ( attr_dout   )
);

jtnkdodge_scroll u_scroll(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .hs         ( HS          ),
    .hdump      ( hdump       ),
    .vdump      ( { 1'b0, row } ),
    .scrpos     ( scrpos_v    ),
    .tile_pal   ( tile_pal_v  ),
    .vram_addr  ( scan_addr   ),
    .code_lsb   ( code_dout   ),
    .attr       ( attr_dout   ),
    .rom_addr   ( scr_addr    ),
    .rom_cs     ( scr_cs      ),
    .rom_data   ( scr_data    ),
    .rom_ok     ( scr_ok      ),
    .pxl        ( scr_pxl     ),
    .debug_bus  ( debug_bus   )
);

jtnkdodge_colmix u_colmix(
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .LHBL       ( LHBL        ),
    .hdump      ( hdump       ),
    .LVBL       ( LVBL        ),
    .scr_pxl    ( scr_pxl     ),
    .obj_pxl    ( obj_pxl     ),
    .pal_addr   ( pal_addr    ),
    .pal_data   ( pal_data    ),
    .red        ( red         ),
    .green      ( green       ),
    .blue       ( blue        ),
    .gfx_en     ( gfx_en      )
);

jtnkdodge_obj u_obj(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .hs         ( HS          ),
    .vrender    ( row_r       ),
    .hdump      ( hdump       ),
    .obj_pal    ( obj_pal_v   ),
    .cpu_addr   ( cpu_addr[7:0] ),
    .objram_cs  ( objram_cs   ),
    .cpu_wrn    ( cpu_rnw     ),
    .cpu_dout   ( cpu_dout    ),
    .rom_cs     ( obj_cs      ),
    .rom_addr   ( obj_addr    ),
    .rom_data   ( obj_data    ),
    .rom_ok     ( obj_ok      ),
    .pxl        ( obj_pxl     ),
    .debug_bus  ( debug_bus   )
);

endmodule
