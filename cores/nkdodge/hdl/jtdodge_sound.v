/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Sound board: 6809, YM3812, 2 x MSM5205. Based on jtkunio_sound by
    Jose Tejada Gomez; map from MAME's spdodgeb_state::sound_map:
      0000-0FFF RAM, 1000 latch, 2800-2801 YM3812, 3800-3807 ADPCM,
      8000-FFFF ROM.  Date: 18-10-2026 */

module jtdodge_sound(
    input                rst,
    input                clk,        // 24 MHz
    input                cen3,
    input                cen1p5,
    input                cen_oki,    // 384 kHz
    input                snd_irq,
    input         [ 7:0] snd_latch,
    output        [14:0] rom_addr,
    output reg           rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,
    output        [15:0] pcm0_addr,
    output               pcm0_cs,
    input         [ 7:0] pcm0_data,
    input                pcm0_ok,
    output        [15:0] pcm1_addr,
    output               pcm1_cs,
    input         [ 7:0] pcm1_data,
    input                pcm1_ok,
    output signed [15:0] fm,
    output signed [11:0] pcm0,
    output signed [11:0] pcm1
);
`ifndef NOSOUND
wire        [ 7:0] cpu_dout, ram_dout, fm_dout;
wire        [15:0] A;
reg         [ 7:0] cpu_din;
wire               cpu_rnw, firq_n, irq_n;
reg                ram_cs, latch_cs, fm_cs, adpcm_cs;

assign rom_addr = A[14:0];

always @(*) begin
    rom_cs   = A[15];
    ram_cs   = 0;
    latch_cs = 0;
    fm_cs    = 0;
    adpcm_cs = 0;
    if( !A[15] && !A[14] ) case( A[13:11] )
        0,1: ram_cs   = 1;
        2:   latch_cs = 1;
        5:   fm_cs    = 1;
        7:   adpcm_cs = !cpu_rnw;
        default:;
    endcase
end

always @(*) begin
    cpu_din = rom_cs   ? rom_data  :
              ram_cs   ? ram_dout  :
              latch_cs ? snd_latch :
              fm_cs    ? fm_dout   :
              8'hff;
end

// IRQ on a new latch value, cleared when the latch is read
jtframe_ff u_ff(
    .clk      ( clk         ),
    .rst      ( rst         ),
    .cen      ( 1'b1        ),
    .din      ( 1'b1        ),
    .q        (             ),
    .qn       ( irq_n       ),
    .set      ( 1'b0        ),
    .clr      ( latch_cs    ),
    .sigedge  ( snd_irq     )
);

jtframe_sys6809 #(.RAM_AW(12),.CENDIV(0)) u_cpu(
    .rstn       ( ~rst      ),
    .clk        ( clk       ),
    .cen        ( cen1p5    ),
    .cpu_cen    (           ),
    .VMA        (           ),
    // Interrupts
    .nIRQ       ( irq_n     ),
    .nFIRQ      ( firq_n    ),
    .nNMI       ( 1'b1      ),
    .irq_ack    (           ),
    // Bus sharing
    .bus_busy   ( 1'b0      ),
    // memory interface
    .A          ( A         ),
    .RnW        ( cpu_rnw   ),
    .ram_cs     ( ram_cs    ),
    .rom_cs     ( rom_cs    ),
    .rom_ok     ( rom_ok    ),
    // Bus multiplexer is external
    .ram_dout   ( ram_dout  ),
    .cpu_dout   ( cpu_dout  ),
    .cpu_din    ( cpu_din   )
);

jtopl2 u_opl(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen3      ),
    .din    ( cpu_dout  ),
    .addr   ( A[0]      ),
    .cs_n   ( ~fm_cs    ),
    .wr_n   ( cpu_rnw   ),
    .dout   ( fm_dout   ),
    .irq_n  ( firq_n    ),
    .snd    ( fm        ),
    .sample (           )
);

// offset & 1 selects the chip, offset / 2 the register
jtdodge_adpcm u_adpcm0(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .cen_oki    ( cen_oki       ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_AB     ( A[2:1]        ),
    .cs         ( adpcm_cs & ~A[0] ),
    .rom_addr   ( pcm0_addr     ),
    .rom_cs     ( pcm0_cs       ),
    .rom_data   ( pcm0_data     ),
    .rom_ok     ( pcm0_ok       ),
    .snd        ( pcm0          )
);

jtdodge_adpcm u_adpcm1(
    .clk        ( clk           ),
    .rst        ( rst           ),
    .cen_oki    ( cen_oki       ),
    .cpu_dout   ( cpu_dout      ),
    .cpu_AB     ( A[2:1]        ),
    .cs         ( adpcm_cs &  A[0] ),
    .rom_addr   ( pcm1_addr     ),
    .rom_cs     ( pcm1_cs       ),
    .rom_data   ( pcm1_data     ),
    .rom_ok     ( pcm1_ok       ),
    .snd        ( pcm1          )
);
`else
    initial rom_cs   = 0;
    assign rom_addr  = 0;
    assign pcm0_addr = 0;
    assign pcm0_cs   = 0;
    assign pcm1_addr = 0;
    assign pcm1_cs   = 0;
    assign fm        = 0;
    assign pcm0      = 0;
    assign pcm1      = 0;
`endif
endmodule
