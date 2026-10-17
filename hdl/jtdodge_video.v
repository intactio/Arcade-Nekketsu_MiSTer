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
    output     [3:0]   red,
    output     [3:0]   green,
    output     [3:0]   blue,
    input      [3:0]   gfx_en,
    input      [7:0]   debug_bus
);

wire [8:0] vdump, vrender, hdump;
reg  [8:0] vdump_l;

// lines 0-239 visible, as MAME's set_raw(6M, 384, 0, 256, 272, 0, 240)
jtframe_vtimer #(
    .V_START    ( 9'd0      ),
    .VB_START   ( 9'd240    ),
    .VB_END     ( 9'd0      ),
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

// 4 kB video RAM: 000-7FF tile code, 800-FFF attribute
jtframe_dual_ram #(.AW(12)) u_vram(
    .clk0   ( clk         ),
    .data0  ( cpu_dout    ),
    .addr0  ( cpu_addr    ),
    .we0    ( vram_cs & ~cpu_rnw ),
    .q0     ( vram_dout   ),
    .clk1   ( clk         ),
    .data1  ( 8'd0        ),
    .addr1  ( 12'd0       ),
    .we1    ( 1'b0        ),
    .q1     (             )
);

// filled in by Tasks 6 and 7
assign scr_addr = 0;
assign scr_cs   = 0;
assign obj_addr = 0;
assign obj_cs   = 0;
assign pal_addr = 0;
assign { red, green, blue } = 0;

endmodule
