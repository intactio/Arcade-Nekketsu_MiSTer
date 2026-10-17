/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Super Dodge Ball / Nekketsu Koukou Dodgeball Bu (Technos, 1987).
    Built on JTFRAME and jtkunio by Jose Tejada Gomez. Date: 18-10-2026 */

module jtdodge_game(
    `include "jtframe_game_ports.inc" // see $JTFRAME/hdl/inc/jtframe_game_ports.inc
);

wire [11:0] cpu_addr;
wire [ 7:0] cpu_dout, vram_dout, snd_latch;
wire [ 8:0] scrpos;
wire [ 1:0] tile_pal, obj_pal;
wire        cpu_rnw, vram_cs, objram_cs, snd_irq, flip, irq_set, nmi_set;

assign dip_flip   = flip;
assign debug_view = 0;

jtdodge_main u_main(
    .rst         ( rst24        ),
    .clk         ( clk24        ),
    .cen8        ( cen8         ),
    .cen4        ( cen4         ),
    .LVBL        ( LVBL         ),
    .irq_set     ( irq_set      ),
    .nmi_set     ( nmi_set      ),

    .joystick1   ( joystick1[5:0] ),
    .joystick2   ( joystick2[5:0] ),
    .start       ( cab_1p[1:0]  ),
    .coin        ( coin[1:0]    ),
    .service     ( service      ),
    .dipsw       ( dipsw[15:0]  ),

    .bus_addr    ( cpu_addr     ),
    .cpu_dout    ( cpu_dout     ),
    .cpu_rnw     ( cpu_rnw      ),
    .vram_cs     ( vram_cs      ),
    .objram_cs   ( objram_cs    ),
    .vram_dout   ( vram_dout    ),
    .scrpos      ( scrpos       ),
    .flip        ( flip         ),
    .tile_pal    ( tile_pal     ),
    .obj_pal     ( obj_pal      ),

    .snd_latch   ( snd_latch    ),
    .snd_irq     ( snd_irq      ),

    .rom_addr    ( main_addr    ),
    .rom_cs      ( main_cs      ),
    .rom_data    ( main_data    ),
    .rom_ok      ( main_ok      ),

    .mcu_addr    ( mcu_addr     ),
    .mcu_data    ( mcu_data     )
);

jtdodge_sound u_sound(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .cen6       ( cen6          ),
    .cen3       ( cen3          ),
    .cen1p5     ( cen1p5        ),
    .snd_irq    ( snd_irq       ),
    .snd_latch  ( snd_latch     ),

    .rom_addr   ( snd_addr      ),
    .rom_cs     ( snd_cs        ),
    .rom_data   ( snd_data      ),
    .rom_ok     ( snd_ok        ),

    .pcm0_addr  ( pcm0_addr     ),
    .pcm0_cs    ( pcm0_cs       ),
    .pcm0_data  ( pcm0_data     ),
    .pcm0_ok    ( pcm0_ok       ),
    .pcm1_addr  ( pcm1_addr     ),
    .pcm1_cs    ( pcm1_cs       ),
    .pcm1_data  ( pcm1_data     ),
    .pcm1_ok    ( pcm1_ok       ),

    .fm         ( fm            ),
    .pcm0       ( pcm0          ),
    .pcm1       ( pcm1          )
);

jtdodge_video u_video(
    .rst        ( rst24         ),
    .clk        ( clk24         ),
    .pxl_cen    ( pxl_cen       ),

    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_rnw    ( cpu_rnw       ),
    .vram_cs    ( vram_cs       ),
    .objram_cs  ( objram_cs     ),
    .vram_dout  ( vram_dout     ),
    .scrpos     ( scrpos        ),
    .flip       ( flip          ),
    .tile_pal   ( tile_pal      ),
    .obj_pal    ( obj_pal       ),

    .irq_set    ( irq_set       ),
    .nmi_set    ( nmi_set       ),

    .scr_addr   ( scr_addr      ),
    .scr_cs     ( scr_cs        ),
    .scr_data   ( scr_data      ),
    .scr_ok     ( scr_ok        ),
    .obj_addr   ( obj_addr      ),
    .obj_cs     ( obj_cs        ),
    .obj_data   ( obj_data      ),
    .obj_ok     ( obj_ok        ),
    .pal_addr   ( pal_addr      ),
    .pal_data   ( pal_data      ),

    .HS         ( HS            ),
    .VS         ( VS            ),
    .LVBL       ( LVBL          ),
    .LHBL       ( LHBL          ),
    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .gfx_en     ( gfx_en        ),
    .debug_bus  ( debug_bus     )
);

endmodule
