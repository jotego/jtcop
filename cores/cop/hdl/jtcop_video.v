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
    Date: 25-9-2021 */

module jtcop_video(
    input              rst,
    input              clk,
    input              clk_cpu,
    output             pxl2_cen,  // pixel clock enable (2x)
    output             pxl_cen,   // pixel clock enable

    // CPU interface
    input      [12:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  cpu_dsn,
    input              cpu_rnw,

    input              fmode_cs,
    input              bmode_cs,
    input              cmode_cs,

    // Palette
    input      [ 1:0]  pal_cs,
    input      [ 2:0]  prisel,
    output     [15:0]  pal_dout,

    // Objects
    input              objram_cs,
    input              obj_copy,
    input              mixpsel,
    output     [15:0]  obj_dout,

    // priority PROM
    input      [9:0]   prog_addr,
    input      [1:0]   prom_din,
    input              prio_we,

    // Background 0
    output             b0ram_cs,
    output      [12:0] b0ram_addr,
    input       [15:0] b0ram_data,
    input              b0ram_ok,

    output             b0rom_cs,
    output      [18:0] b0rom_addr,
    input       [31:0] b0rom_data,
    input              b0rom_ok,

    // Background 1
    output             b1ram_cs,
    output      [10:0] b1ram_addr,
    input       [15:0] b1ram_data,
    input              b1ram_ok,

    output             b1rom_cs,
    output      [18:0] b1rom_addr,
    input       [31:0] b1rom_data,
    input              b1rom_ok,

    // Background 2
    output             b2ram_cs,
    output      [10:0] b2ram_addr,
    input       [15:0] b2ram_data,
    input              b2ram_ok,

    output             b2rom_cs,
    output      [18:0] b2rom_addr,
    input       [31:0] b2rom_data,
    input              b2rom_ok,

    // Video signal
    output             HS,
    output             VS,
    output             LVBL,
    output             LHBL,
    output             LHBL_dly,
    output             LVBL_dly,
    output             flip,

    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue,

    // Debug
    input      [ 3:0]  gfx_en
);

wire   [8:0]  vdump, vrender, hdump;
wire   [7:0]  ba0_pxl, ba1_pxl, ba2_pxl, obj_pxl;
wire          vload, hinit;
reg           gmode_cs, gsft_cs, gmap_cs;

jtcop_bac06 #(.MASTER(1),.RAM_AW(13)) u_ba0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( fmode_cs      ),
    .flip       ( flip          ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
//    .cpu_din    ( cpu_din       ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),

    // VRAM
    .ram_cs     ( b0ram_cs      ),
    .ram_addr   ( b0ram_addr    ),
    .ram_data   ( b0ram_data    ),
    .ram_ok     ( b0ram_ok      ),

    // ROMs
    .rom_cs     ( b0rom_cs      ),
    .rom_addr   ( b0rom_addr    ),
    .rom_data   ( b0rom_data    ),
    .rom_ok     ( b0rom_ok      ),

    .pxl        ( ba0_pxl       )
);

jtcop_bac06 u_ba1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( bmode_cs      ),
    .flip       ( flip          ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
//    .cpu_din    ( cpu_din       ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),

    // VRAM
    .ram_cs     ( b1ram_cs      ),
    .ram_addr   ( b1ram_addr    ),
    .ram_data   ( b1ram_data    ),
    .ram_ok     ( b1ram_ok      ),

    // ROMs
    .rom_cs     ( b1rom_cs      ),
    .rom_addr   ( b1rom_addr    ),
    .rom_data   ( b1rom_data    ),
    .rom_ok     ( b1rom_ok      ),

    .pxl        ( ba1_pxl       )
);

jtcop_bac06 u_ba2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( cmode_cs      ),
    .flip       ( flip          ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
//    .cpu_din    ( cpu_din       ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),

    // VRAM
    .ram_cs     ( b2ram_cs      ),
    .ram_addr   ( b2ram_addr    ),
    .ram_data   ( b2ram_data    ),
    .ram_ok     ( b2ram_ok      ),

    // ROMs
    .rom_cs     ( b2rom_cs      ),
    .rom_addr   ( b2rom_addr    ),
    .rom_data   ( b2rom_data    ),
    .rom_ok     ( b2rom_ok      ),

    .pxl        ( ba2_pxl       )
);

jtcop_obj u_obj(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl_cen    ( pxl_cen       ),

    .LVBL       ( LVBL          ),
    .vload      ( vload         ),
    .hinit      ( hinit         ),
    .hdump      ( hdump[7:0]    ),
    .vdump      ( vdump[7:0]    ),

    // CPU interface
    .cpu_addr   ( cpu_addr[10:1]),
    .cpu_dout   ( cpu_dout      ),
    .obj_dout   ( obj_dout      ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_rnw    ( cpu_rnw       ),
    .objram_cs  ( objram_cs     ),

    // DMA trigger
    .obj_copy   ( obj_copy      ),
    .mixpsel    ( mixpsel       ),

    .pxl        ( obj_pxl       )
);

jtcop_colmix u_colmix(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl_cen    ( pxl_cen       ),

    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),

    // CPU interface
    .pal_cs     ( pal_cs        ),
    .cpu_addr   ( cpu_addr[10:1]),
    .cpu_dout   ( cpu_dout      ),
    .dsn        ( cpu_dsn       ),
    .cpu_din    ( pal_dout      ),

    .prisel     ( prisel        ),

    // priority PROM
    .prog_addr  ( prog_addr     ),
    .prom_din   ( prom_din      ),
    .prom_we    ( prio_we       ),

    .ba0_pxl    ( ba0_pxl       ),
    .ba1_pxl    ( 8'd0          ),
    .ba2_pxl    ( 8'd0          ),
    .obj_pxl    ( 8'd0          ),
    //.ba1_pxl    ( ba1_pxl       ),
    //.ba2_pxl    ( ba2_pxl       ),
    //.obj_pxl    ( obj_pxl       ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LVBL_dly   ( LVBL_dly      ),
    .LHBL_dly   ( LHBL_dly      ),

    .gfx_en     ( gfx_en        )
);

endmodule