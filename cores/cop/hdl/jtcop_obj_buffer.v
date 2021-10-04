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

module jtcop_obj_buffer(
    input              rst,
    input              clk,
    input              clk_cpu,
    input              pxl_cen,

    // CPU interface
    input      [10:1]  cpu_addr,
    input      [15:0]  cpu_dout,
    output     [15:0]  obj_dout,
    input      [ 1:0]  cpu_dsn,
    input              cpu_rnw,
    input              objram_cs,

    // DMA trigger
    input              obj_copy,
    input              mixpsel_cs
);

wire [1:0] cpu_we = ~({2{cpu_rnw}} | cpu_dsn) & {2{objram_cs}};

jtframe_dual_ram16 #(.aw(10)) u_buffer(
    // Port 0: CPU
    .clk0   ( clk_cpu   ),
    .data0  ( cpu_dout  ),
    .addr0  ( cpu_addr  ),
    .we0    ( cpu_we    ),
    .q0     ( obj_dout  ),
    // Port 1
    .clk1   ( clk       ),
    .data1  (           ),
    .addr1  (           ),
    .we1    (           ),
    .q1     (           )
);

endmodule