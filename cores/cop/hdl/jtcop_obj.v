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
    Date: 4-10-2021 */

module jtcop_obj(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,

    input              LVBL,
    input              hinit,
    input              vload,
    input      [ 7:0]  vdump,
    input      [ 7:0]  hdump,


    // CPU interface
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    output     [15:0]  obj_dout,
    input      [ 1:0]  cpu_dsn,
    input              cpu_rnw,
    input              objram_cs,

    // DMA trigger
    input              obj_copy,
    input              mixpsel,

    output     [7:0]   pxl
);

wire [ 9:0]   tbl_addr;
wire [15:0]   tbl_dout;

jtcop_obj_buffer u_buffer(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_cpu    ( clk_cpu   ),
    .pxl_cen    ( pxl_cen   ),

    .LVBL       ( LVBL      ),
    .hinit      ( hinit     ),
    .vload      ( vload     ),
    .vdump      ( vdump[7:0]),
    .hdump      ( hdump[7:0]),

    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .cpu_dout   ( cpu_dout  ),
    .obj_dout   ( obj_dout  ),
    .cpu_dsn    ( cpu_dsn   ),
    .cpu_rnw    ( cpu_rnw   ),
    .objram_cs  ( objram_cs ),

    // Object engine
    .tbl_addr   ( tbl_addr  ),
    .tbl_dout   ( tbl_dout  ),

    // DMA trigger
    .obj_copy   ( obj_copy  ),
    .mixpsel    ( mixpsel   )
);

endmodule