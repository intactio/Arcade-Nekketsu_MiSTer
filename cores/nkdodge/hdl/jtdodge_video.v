/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Video timing as MAME's spdodgeb: 6 MHz, 384 x 272, lines 0-239 visible.
    IRQ request on lines 0, 8, ... 248, 264; NMI on line 256.
    Date: 18-10-2026 */

module jtdodge_video(
    input              rst,
    input              clk,
    input              pxl_cen,
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
    output             LHBL,
    output     [7:0]   red,
    output     [7:0]   green,
    output     [7:0]   blue,
    input      [3:0]   gfx_en,
    input      [7:0]   debug_bus
);

wire [8:0] vdump, vrender, hdump;
reg  [8:0] vdump_l;

// lines 0-239 visible, as MAME's set_raw(6M, 384, 0, 256, 272, 0, 240)
jtframe_vtimer #(
    .V_START    ( 9'd0      ),
    .VB_START   ( 9'd239    ),  // LVBL follows these one line late:
    .VB_END     ( 9'd271    ),  // lines 0-239 visible (checked on the device)
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

// one clk pulse when a new line starts
always @(posedge clk) begin
    vdump_l <= vdump;
    irq_set <= vdump!=vdump_l && vdump[2:0]==0 && vdump!=9'd256;
    nmi_set <= vdump!=vdump_l && vdump==9'd256;
end

wire [10:0] scan_addr;
wire [ 8:0] scrpos_d;
wire [ 1:0] tile_pal_d, obj_pal_d;
reg  [12:0] snap[0:31];
wire [ 8:0] vsel = vdump<=9'd15 ? 9'd0 : vdump - 9'd15 + 9'd7;

// MAME draws up to the IRQ line + 16 with the registers as they were when
// the IRQ came (update_partial(scanline+16), marked "pretty off" there).
// That leaves line 24, the first sky line under the 3-row title bar, on
// the title scroll. Here line n uses the registers as they were at the IRQ
// on line 8*ceil((n-15)/8), so the title bar ends at line 23, on its tile
// boundary. Everything else matches MAME.
always @(posedge clk) begin
    if( irq_set || nmi_set ) snap[ vdump[7:3] ] <= { obj_pal, tile_pal, scrpos };
end
assign { obj_pal_d, tile_pal_d, scrpos_d } = snap[ vsel[7:3] ];
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

jtdodge_scroll u_scroll(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .hs         ( HS          ),
    .hdump      ( hdump       ),
    .vdump      ( vdump       ),
    .scrpos     ( scrpos_d    ),
    .tile_pal   ( tile_pal_d  ),
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

jtdodge_colmix u_colmix(
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

jtdodge_obj u_obj(
    .rst        ( rst         ),
    .clk        ( clk         ),
    .pxl_cen    ( pxl_cen     ),
    .hs         ( HS          ),
    .vrender    ( vrender[7:0]),
    .hdump      ( hdump       ),
    .obj_pal    ( obj_pal_d   ),
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
