/*  This file is part of JTCOP.
    JTCOP program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    JTCOP program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with JTCOP.  If not, see <http://www.gnu.org/licenses/>.

    Author: Jose Tejada Gomez. Twitter: @topapate
    Version: 1.0
    Date: 24-9-2021 */

// The layer priority is solved as in MAME
// I hope to get access to a Midnight Resistance board
// at some point and derive the original circuit

module jtcop_colmix(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,

    input              LHBL,
    input              LVBL,

    // CPU interface
    input      [ 1:0]  pal_cs,
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dsn,
    output     [15:0]  cpu_din,

    input      [2:0]   prisel,

    // priority PROM
    input      [9:0]   prog_addr,
    input      [3:0]   prom_din,
    input              prom_we,

    input      [7:0]   ba0_pxl,
    input      [7:0]   ba1_pxl,
    input      [7:0]   ba2_pxl,
    input      [7:0]   obj_pxl, // called "MCOL" in the schematics

    output     [7:0]   red,
    output     [7:0]   green,
    output     [7:0]   blue,
    output             LVBL_dly,
    output             LHBL_dly,

    input      [ 3:0]  gfx_en,
    input      [ 7:0]  debug_bus
);

reg  [ 1:0] selbus;
wire [15:0] pal_bgr;
wire [ 1:0] we_gr;
reg  [ 9:0] pal_addr;
wire [ 3:0] r4,g4,b4;
wire        ba0_blank, obj_blank, ba1_blank, ba2_blank;
wire        obj_loprio;
reg  [ 7:0] scr_col;

assign we_gr = ~dsn & {2{pal_cs[0]}};
// conversion to 8-bit colour like the other games
assign red   = {2{r4}};
assign green = {2{g4}};
assign blue  = {2{b4}};

assign ba0_blank = ~|ba0_pxl[3:0] | ~gfx_en[0];
assign ba1_blank = ~|ba1_pxl[3:0] | ~gfx_en[1]; // should only 2:0 be used?
assign ba2_blank = ~|ba2_pxl[3:0] | ~gfx_en[2];
assign obj_blank = ~|obj_pxl[3:0] | ~gfx_en[3];
assign obj_loprio= prisel[1] & (obj_pxl[7]^prisel[2]);

localparam [1:0] BA0=01,BA1=2,BA2=3,OBJ=0;

always @* begin
    if( prisel[0] ) begin
        selbus = ba2_blank ? BA1 : BA2;
        scr_col = ba2_pxl;
    end else begin
        selbus = ba1_blank ? BA2 : BA1;
        scr_col = ba1_pxl;
    end
    if( !(obj_blank || (obj_loprio && scr_col[3:0]!=0) ) )
        selbus = OBJ;
    if( !ba0_blank )
        selbus = BA0;
end

always @(posedge clk) begin
    if( pxl_cen ) begin
        pal_addr[9:8] <= selbus;
        case( selbus )
            0: pal_addr[7:0] <= obj_pxl; // ok
            1: pal_addr[7:0] <= ba0_pxl;
            2: pal_addr[7:0] <= ba1_pxl;
            3: pal_addr[7:0] <= ba2_pxl;
        endcase
    end
end

jtframe_blank #(.DLY(2),.DW(12)) u_blank(
    .clk        ( clk       ),
    .pxl_cen    ( pxl_cen   ),
    .preLHBL    ( LHBL      ),
    .preLVBL    ( LVBL      ),
    .LHBL       ( LHBL_dly  ),
    .LVBL       ( LVBL_dly  ),
    .preLBL     (           ),
    .rgb_in     ( pal_bgr[11:0]   ),
    .rgb_out    ( { b4, g4, r4 } )
);

// Red - Green palette RAM
jtframe_dual_ram16 #(
    .aw        (  10        ),
    .simfile_lo("pal_lo.bin"),
    .simfile_hi("pal_hi.bin")
) u_ram_gr(
    // CPU writes
    .clk0   ( clk_cpu   ),
    .addr0  ( cpu_addr  ),
    .data0  ( cpu_dout  ),
    .we0    ( we_gr     ),
    .q0     ( cpu_din   ),

    // Video reads
    .clk1   ( clk       ),
    .addr1  ( pal_addr  ),
    .data1  (           ),
    .we1    ( 2'b0      )
    `ifndef GRAY
    ,.q1     ( pal_bgr  )
    `endif
);

`ifdef GRAY
    assign pal_bgr = {4{pal_addr[3:0]}};
`endif

// jtframe_prom #(
//     .aw     ( 8             ),
//     .dw     ( 4             ),
//     .simfile("../../../../rom/midres/7114.prm")
// ) u_selbus(
//     .clk    ( clk           ),
//     .cen    ( 1'b1          ),
//     .data   ( ~prom_din     ),
//     .rd_addr( seladdr       ),
//     .wr_addr( prog_addr[7:0]),
//     .we     ( prom_we       ),
//     .q      ( seldec        )
// );

endmodule
