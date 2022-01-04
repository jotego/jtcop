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
    Date: 4-1-2021 */

// This module contains the protection mechanism
// used on Robocop. It consists of a Hud6280 and some logic
// This is not used in Bad Dudes, where a i8051 replaces it.

module jtcop_prot(
    input              rst,
    input              clk,

    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok
);

wire [20:0] A;
wire [ 7:0] dout;
reg  [ 7:0] din;
wire        waitn, wrn, rdn;

wire        ce, cek_n, ce7_n, cer_n;

reg         irqn, rdy;

assign waitn = rom_cs & ~rom_ok;

HUC6280 u_huc(
    .CLK        ( clk       ),
    .RST_N      ( ~rst      ),
    .WAIT_N     ( waitn     ),

    .A          ( A         ),
    .DI         ( din       ),
    .DO         ( dout      ),
    .WR_N       ( wrn       ),
    .RD_N       ( rdn       ),

    .RDY        ( rdy       ),
    .NMI_N      ( 1'b1      ),
    .IRQ1_N     ( irqn      ),
    .IRQ2_N     ( 1'b1      ),

    .CE         ( ce        ),
    .CEK_N      ( cek_n     ),
    .CE7_N      ( ce7_n     ),
    .CER_N      ( cer_n     ),
    // Unused
    .PRE_RD     (           ),
    .PRE_WR     (           ),
    .HSM        (           ),
    .O          (           ),
    .K          ( 8'd0      ),
    .VDCNUM     ( 1'b0      ),
    .AUD_LDATA  (           ),
    .AUD_RDATA  (           )
);

endmodule