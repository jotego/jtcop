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

/* Equations in PAL16L8B in location 9A
/rom_a9 = A13 +
       rdn +
       wrn +
       cer_n +
       /A20
/HDPSEL = A14 +
       rdn +
       wrn +
       cer_n +
       /A20
/rom_cs = /ce7_n & /cer_n & /rdn & /wrn & A20 & /A13
/lit_cs =  ce7_n & /cer_n & /rdn & /wrn & A20 & /A14
/big_cs = /ce7_n & /cer_n & /rdn & /wrn & A20 & /A14
*/
module jtcop_prot(
    input           rst,
    input           clk,
    input           clk_cpu,

    input    [11:1] main_addr,  // only 2kB are shared
    input    [ 7:0] main_dout,
    output   [ 7:0] main_din,
    input           main_cs,
    input           main_wrn,

    input     [8:0] prog_addr,
    input     [7:0] prog_data,
    input           prog_en
);

wire [20:0] A;
wire [ 7:0] dout;
reg  [ 7:0] din;
wire        waitn, wrn, rdn;

wire        ce, cek_n, ce7_n, cer_n;
            //hdpsel_n;
wire        main_we;

wire        set_irq, irqn;
reg         rom_cs, ram_cs, shd_cs;
wire [ 7:0] rom_dout, ram_dout, shd_dout;
wire        shd_we, ram_we;

assign main_we = main_cs & ~main_wrn;
assign waitn   = 1; // no bus contention for now
assign set_irq = main_cs && main_addr==11'h7ff;
assign irqn    = ~set_irq;
assign ram_we  = ram_cs & ~wrn;
assign shd_we  = shd_cs & ~wrn;

always @* begin
    rom_cs = A[20:16]==0 && !rdn;
    ram_cs = A[20] & ~A[13];    // 1f0000-1f1fff
    shd_cs = A[20] &  A[13];    // 1f2000-1f3fff
    // hdpsel_n = A[13] | rdn | wrn | ~A[20];
end

always @(posedge clk) begin
    din <=
        ram_cs ? ram_dout :
        shd_cs ? shd_dout :
        rom_cs && A[15:9]==~7'b0 ? rom_dout : 8'hff;
end
/*
jtframe_ff u_ff (
    .clk    ( clk       ),
    .rst    ( rst       ),
    .cen    ( 1'b1      ),
    .din    ( 1'b1      ),
    .q      (           ),
    .qn     ( irqn      ),
    .set    (           ),    // active high
    .clr,    // active high
    .sigedge( set_irq   )
);*/

jtframe_prom #(.aw(9)) u_rom(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( prog_data ),
    .rd_addr( A[8:0]    ),
    .wr_addr( prog_addr ),
    .we     ( prog_en   ),
    .q      ( rom_dout  )
);

jtframe_ram #(.aw(11)) u_ram(
    .clk    ( clk       ),
    .cen    ( 1'b1      ),
    .data   ( dout      ),
    .addr   ( A[10:0]   ),
    .we     ( ram_we    ),
    .q      ( ram_dout  )
);

jtframe_dual_ram #(.aw(13)) u_shared(
    .clk0   ( clk_cpu   ),
    .clk1   ( clk       ),
    // Main CPU
    .data0  ( main_dout ),
    .addr0  ({2'b00,main_addr} ), // upper most 2 bits are floating!
    .we0    ( main_we   ),
    .q0     ( main_din  ),
    // HuC6280
    .data1  ( dout      ),
    .addr1  ( A[12:0]   ),
    .we1    ( shd_we    ),
    .q1     ( shd_dout  )
);

HUC6280 u_huc(
    .CLK        ( clk       ),
    .RST_N      ( ~rst      ),
    .WAIT_N     ( waitn     ),

    .A          ( A         ),
    .DI         ( din       ),
    .DO         ( dout      ),
    .WR_N       ( wrn       ),
    .RD_N       ( rdn       ),

    .RDY        ( 1'b1      ),
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