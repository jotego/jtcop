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
    output             pxl2_cen,  // pixel clock enable (2x)
    output             pxl_cen,   // pixel clock enable

    // CPU interface
    input      [12:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    input      [ 1:0]  dsn,

    input      [ 1:0]  pal_cs,
    input              objram_cs,
    input              fmode_cs,
    input              fsft_cs,
    input              fmap_cs,
    input              bmode_cs,
    input              bsft_cs,
    input              bmap_cs,
    input              nexrm0_cs,   // ba3 chip selection
    input      [2:0]   prisel,

    // priority PROM
    input      [9:0]   prog_addr,
    input      [1:0]   prom_din,
    input              prio_we,

    // Background 0
    output             bac0_cs,
    output      [16:0] bac0_addr,
    input       [15:0] bac0_data,
    input              bac0_ok

    // Background 1
    output             bac1_cs,
    output      [16:0] bac1_addr,
    input       [15:0] bac1_data,
    input              bac1_ok

    // Background 2
    output             bac2_cs,
    output      [16:0] bac2_addr,
    input       [15:0] bac2_data,
    input              bac2_ok


    // Video signal
    output             HS,
    output             VS,
    output             LVBL,
    output             LHBL,
    output             LHBL_dly,
    output             LVBL_dly,

    output     [ 7:0]  red,
    output     [ 7:0]  green,
    output     [ 7:0]  blue
);

wire   [8:0]  vdump, vrender, hdump;
wire   [7:0]  ba0_pxl, ba1_pxl, ba2_pxl, obj_pxl;
reg           gmode_cs, gsft_cs, gmap_cs;

always @(*) begin
    gmode_cs  = 0;
    gsft_cs   = 0;
    gmap_cs   = 0;
    if( nexrm0_cs )  begin
        case( cpu_addr[10:9])
            0: gmode_cs = 1; // these signals could go
            1: gsft_cs  = 1; // in a different order
            2: gmap_cs  = 1;
            default:;
        endcase
    end
end

jtcop_bac06 #(.MASTER(1),.RAM_AW(12)) u_ba0(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( fmode_cs      ),
    .sift_cs    ( fsft_cs       ),
    .map_cs     ( fmap_cs       ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_din    ( cpu_din       ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),

    // ROMs
    .rom_cs     ( bac0_cs       ),
    .rom_addr   ( bac0_addr     ),
    .rom_data   ( bac0_data     ),
    .rom_ok     ( bac0_ok       ),
    .pxl        ( ba0_pxl       )
);

jtcop_bac06 u_ba1(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( bmode_cs      ),
    .sift_cs    ( bsft_cs       ),
    .map_cs     ( bmap_cs       ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_din    ( cpu_din       ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),

    // ROMs
    .rom_cs     ( bac1_cs       ),
    .rom_addr   ( bac1_addr     ),
    .rom_data   ( bac1_data     ),
    .rom_ok     ( bac1_ok       )
);

jtcop_bac06 u_ba2(
    .rst        ( rst           ),
    .clk        ( clk           ),
    .clk_cpu    ( clk_cpu       ),
    .pxl2_cen   ( pxl2_cen      ),
    .pxl_cen    ( pxl_cen       ),

    .mode_cs    ( fmode_cs      ),
    .sift_cs    ( fsft_cs       ),
    .map_cs     ( fmap_cs       ),

    // CPU interface
    .cpu_dout   ( cpu_dout      ),
    .cpu_addr   ( cpu_addr      ),
    .cpu_rnw    ( cpu_rnw       ),
    .cpu_dsn    ( cpu_dsn       ),
    .cpu_din    ( cpu_din       ),

    // Timer signals
    .vdump      ( vdump         ),
    .vrender    ( vrender       ),
    .hdump      ( hdump         ),
    .LHBL       ( LHBL          ),
    .LVBL       ( LVBL          ),
    .HS         ( HS            ),
    .VS         ( VS            ),

    // ROMs
    .rom_cs     ( bac2_cs       ),
    .rom_addr   ( bac2_addr     ),
    .rom_data   ( bac2_data     ),
    .rom_ok     ( bac2_ok       )
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
    .cpu_addr   ( cpu_addr      ),
    .cpu_dout   ( cpu_dout      ),
    .dsn        ( dsn           ),
    .cpu_din    ( cpu_din       ),

    .prisel     ( prisel        ),

    // priority PROM
    .prog_addr  ( prog_addr     ),
    .prom_din   ( prom_din      ),
    .prom_we    ( prio_we       ),

    .ba0_pxl    ( ba0_pxl       ),
    .ba1_pxl    ( ba1_pxl       ),
    .ba2_pxl    ( ba2_pxl       ),
    .obj_pxl    ( obj_pxl       ),

    .red        ( red           ),
    .green      ( green         ),
    .blue       ( blue          ),
    .LVBL_dly   ( LVBL_dly      ),
    .LHBL_dly   ( LHBL_dly      ),

    .gfx_en     ( gfx_en        )
);

endmodule