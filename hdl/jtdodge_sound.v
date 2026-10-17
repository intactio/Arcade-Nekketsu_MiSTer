/*  This file is part of JTDODGE (not an official jotego core).
    JTDODGE program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Sound board: 6809, YM3812, 2 x MSM5205. Filled in by Task 5.
    Date: 18-10-2026 */

module jtdodge_sound(
    input                rst,
    input                clk,
    input                cen6,
    input                cen3,
    input                cen1p5,
    input                snd_irq,
    input         [ 7:0] snd_latch,
    output        [14:0] rom_addr,
    output               rom_cs,
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

assign rom_addr  = 0;
assign rom_cs    = 0;
assign pcm0_addr = 0;
assign pcm0_cs   = 0;
assign pcm1_addr = 0;
assign pcm1_cs   = 0;
assign fm        = 0;
assign pcm0      = 0;
assign pcm1      = 0;

endmodule
