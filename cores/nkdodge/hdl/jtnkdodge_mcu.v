/*  This file is part of Nekketsu (not an official jotego core).
    Nekketsu is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    HD63701Y0 that reads the controls for the main CPU. Wiring from MAME's
    spdodgeb_state::mcu_map and port callbacks. Date: 18-10-2026 */

module jtnkdodge_mcu(
    input              rst,
    input              clk,
    input              cen,
    input              nmi_set,    // main CPU write to $3005
    // main CPU side
    input       [ 7:0] latch_din,  // $3800
    input              latch_we,
    input       [ 2:0] res_addr,   // $3801-$3805
    output      [ 7:0] res_dout,
    output             busy,       // IN0 bit 1
    // ports (active low)
    input       [ 7:0] p1,         // P2: player 1
    input       [ 7:0] p2,         // P6: player 2
    input       [ 7:0] in1,        // P5: DIPs
    // ROM
    output      [13:0] rom_addr,
    input       [ 7:0] rom_data
);

wire [15:0] A;
wire [ 7:0] dout, p5_dout;
wire [ 4:0] p7_dout;
wire        wrn;
reg  [ 7:0] latch, res[1:5], ext_din;
reg  [ 2:0] nmi_cnt;
reg         nmi, nmi_l;

assign wrn      = p7_dout[1];
assign busy     = p5_dout[7];
assign res_dout = res_addr==0 || res_addr>5 ? 8'hff : res[res_addr];

always @(posedge clk) begin
    if( latch_we ) latch <= latch_din;
    ext_din <= A==16'h8080 ? latch : 8'hff;
end

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        res[1] <= 0; res[2] <= 0; res[3] <= 0; res[4] <= 0; res[5] <= 0;
    end else if( !wrn && A[15:3]==13'h1010 && A[2:0]!=0 && A[2:0]<=5 ) begin
        res[A[2:0]] <= dout;
    end
end

// jt680x samples NMI on cen and acts on its rising edge, so stretch the
// main CPU's write strobe over a few MCU cycles
always @(posedge clk, posedge rst) begin
    if( rst ) begin
        nmi     <= 0;
        nmi_l   <= 0;
        nmi_cnt <= 0;
    end else begin
        nmi_l <= nmi_set;
        if( nmi_set && !nmi_l ) begin
            nmi     <= 1;
            nmi_cnt <= 3'd4;
        end else if( cen && nmi_cnt!=0 ) begin
            nmi_cnt <= nmi_cnt - 3'd1;
            if( nmi_cnt==1 ) nmi <= 0;
        end
    end
end

jt63701y #(.ROMW(14),.MODE(2'd2)) u_63701(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .cen        ( cen           ),
    .nmi        ( nmi           ),
    // ports
    .p1_din     ( 8'hff         ),
    .p2_din     ( p1            ),
    .p3_din     ( ext_din       ),
    .p4_din     ( 8'hff         ),
    .p5_din     ( in1           ),
    .p6_din     ( p2            ),

    .p1_dout    ( A[ 7:0]       ),
    .p2_dout    (               ),
    .p3_dout    ( dout          ),
    .p4_dout    ( A[15:8]       ),
    .p5_dout    ( p5_dout       ),
    .p6_dout    (               ),
    .p7_dout    ( p7_dout       ),
    // ROM
    .rom_cs     (               ),
    .rom_addr   ( rom_addr      ),
    .rom_data   ( rom_data      )
);

endmodule
