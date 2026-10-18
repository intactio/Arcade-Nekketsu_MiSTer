/*  This file is part of Nekketsu (not an official jotego core).
    Nekketsu is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Based on jtkunio_main by Jose Tejada Gomez. Memory map from MAME's
    technos/spdodgeb.cpp; IRQ/NMI acknowledge from the game's handlers
    (the IRQ handler ends with a write to $3001, the NMI handler with a
    write to $3000). Date: 18-10-2026 */

module jtnkdodge_main(
    input              rst,
    input              clk,        // 24 MHz
    input              cen8,       // 4x the 2 MHz bus clock
    input              cen4,       // MCU clock
    input              vblank,     // IN0 bit 0, active high
    input              irq_set,    // IRQ request (one clk pulse)
    input              nmi_set,    // NMI request (one clk pulse)
    // cabinet I/O (all active low, as JTFRAME delivers them)
    input       [ 5:0] joystick1,
    input       [ 5:0] joystick2,
    input       [ 1:0] start,
    input       [ 1:0] coin,
    input              service,
    input       [15:0] dipsw,
    // video
    output      [11:0] bus_addr,
    output      [ 7:0] cpu_dout,
    output             cpu_rnw,
    output reg         vram_cs,
    output reg         objram_cs,
    input       [ 7:0] vram_dout,
    output reg  [ 8:0] scrpos,
    output reg         flip,
    output reg  [ 1:0] tile_pal,
    output reg  [ 1:0] obj_pal,
    // sound
    output reg  [ 7:0] snd_latch,
    output reg         snd_irq,
    // ROM
    output      [15:0] rom_addr,
    output reg         rom_cs,
    input       [ 7:0] rom_data,
    input              rom_ok,
    // MCU ROM
    output      [13:0] mcu_addr,
    input       [ 7:0] mcu_data
);
`ifndef NOMAIN
wire [15:0] cpu_addr;
wire [ 7:0] ram_dout, mcu_res;
reg  [ 7:0] cpu_din, cab_dout;
reg         bank, ram_cs, io_cs, mcu_cs, nmi_clr, irq_clr,
            scrlo_cs, mcunmi_cs, ctrl_cs, latch_cs;
wire        cpu_wr, cpu_rd, cpu_acc, irq, nmi, mcu_busy;

assign rom_addr = { cpu_addr[15], cpu_addr[15] ? cpu_addr[14] : bank, cpu_addr[13:0] };
assign bus_addr = cpu_addr[11:0];
assign cpu_rnw  = ~cpu_wr;
assign cpu_acc  = cpu_wr | cpu_rd;

always @* begin
    rom_cs    = 0;
    ram_cs    = 0;
    objram_cs = 0;
    vram_cs   = 0;
    io_cs     = 0;
    mcu_cs    = 0;
    nmi_clr   = 0;
    irq_clr   = 0;
    snd_irq   = 0;
    scrlo_cs  = 0;
    mcunmi_cs = 0;
    ctrl_cs   = 0;
    latch_cs  = 0;
    if( cpu_addr[15:14]!=0 ) begin
        rom_cs = cpu_rd;
    end else if( cpu_acc ) begin
        case( cpu_addr[13:12] )
            0: ram_cs    = 1;
            1: objram_cs = 1;
            2: vram_cs   = 1;
            3: if( !cpu_addr[11] ) begin
                io_cs = 1;
                if( cpu_wr ) case( cpu_addr[2:0] )
                    0: nmi_clr   = 1;
                    1: irq_clr   = 1;
                    2: snd_irq   = 1;
                    4: scrlo_cs  = 1;
                    5: mcunmi_cs = 1;
                    6: ctrl_cs   = 1;
                    default:;
                endcase
            end else begin
                mcu_cs   = 1;
                latch_cs = cpu_wr && cpu_addr[2:0]==0;
            end
        endcase
    end
end

always @(posedge clk) begin
    case( cpu_addr[0] )
        // IN0: vblank, MCU busy, unused, coins, service, difficulty DIP
        0: cab_dout <= { dipsw[9:8], service, coin[1:0], 1'b1, mcu_busy, vblank };
        1: cab_dout <= dipsw[7:0];
    endcase
end

always @* begin
    cpu_din = rom_cs ? rom_data  :
              ram_cs ? ram_dout  :
              vram_cs? vram_dout :
              mcu_cs ? mcu_res   :
              io_cs  ? cab_dout  : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        bank      <= 0;
        snd_latch <= 0;
        scrpos    <= 0;
        flip      <= 0;
        tile_pal  <= 0;
        obj_pal   <= 0;
    end else begin
        if( snd_irq  ) snd_latch    <= cpu_dout;
        if( scrlo_cs ) scrpos[7:0] <= cpu_dout;
        if( ctrl_cs  ) begin
            flip      <= cpu_dout[0];
            bank      <= ~cpu_dout[1];
            scrpos[8] <= cpu_dout[2];
            tile_pal  <= cpu_dout[5:4];
            obj_pal   <= cpu_dout[7:6];
        end
    end
end

// IRQ every 8 lines, cleared by writing to $3001
jtframe_ff u_irq (
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      ( irq       ),
    .qn     (           ),
    .set    ( 1'b0      ),
    .clr    ( irq_clr   ),
    .sigedge( irq_set   )
);

// vblank NMI, cleared by writing to $3000
jtframe_ff u_nmi (
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      ( nmi       ),
    .qn     (           ),
    .set    ( 1'b0      ),
    .clr    ( nmi_clr   ),
    .sigedge( nmi_set   )
);

jtframe_ram #(.AW(12)) u_ram(   // 4 kB work RAM at 0000-0FFF
    .clk    ( clk               ),
    .cen    ( 1'b1              ),
    .data   ( cpu_dout          ),
    .addr   ( cpu_addr[11:0]    ),
    .we     ( ram_cs & cpu_wr   ),
    .q      ( ram_dout          )
);

jt65c02 u_cpu(
    .rst    ( rst       ),
    .clk    ( clk       ),
    .cen    ( cen8      ),
    .irq    ( irq       ),
    .nmi    ( nmi       ),
    .opdec  ( 1'b0      ),
    .wr     ( cpu_wr    ),
    .rd     ( cpu_rd    ),
    .fetch  (           ),
    .addr   ( cpu_addr  ),
    .din    ( cpu_din   ),
    .dout   ( cpu_dout  )
);

jtnkdodge_mcu u_mcu(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen4          ),
    .nmi_set    ( mcunmi_cs     ),
    .latch_din  ( cpu_dout      ),
    .latch_we   ( latch_cs      ),
    .res_addr   ( cpu_addr[2:0] ),
    .res_dout   ( mcu_res       ),
    .busy       ( mcu_busy      ),
    .p1         ( { start[1], start[0], joystick1[5:4], joystick1[2], joystick1[3], joystick1[1:0] } ),
    .p2         ( { 2'b11,              joystick2[5:4], joystick2[2], joystick2[3], joystick2[1:0] } ),
    // IN1: b2 allow continue, b1 unknown DIP, other bits unused (high; b3 low would halt the MCU)
    .in1        ( { 5'h1f, dipsw[10], dipsw[11], 1'b1 } ),
    .rom_addr   ( mcu_addr      ),
    .rom_data   ( mcu_data      )
);
`else
    initial rom_cs    = 0;
    initial vram_cs   = 0;
    initial objram_cs = 0;
    initial snd_irq   = 0;
    initial snd_latch = 0;
    initial scrpos    = 0;
    initial flip      = 0;
    initial tile_pal  = 0;
    initial obj_pal   = 0;
    assign  rom_addr  = 0;
    assign  mcu_addr  = 0;
    assign  bus_addr  = 0;
    assign  cpu_rnw   = 1;
    assign  cpu_dout  = 0;
`endif
endmodule
