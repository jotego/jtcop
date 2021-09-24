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

module jtcop_bac06(
    input       rst,
    input       clk,        // 12MHz original
    input       clk_cpu,
    inout       pxl2_cen,   // 12 MHz
    inout       pxl_cen,    //  6 MHz

    input       mode_cs,
    input       sft_cs,     // scroll
    input       map_cs,     // memory

    // CPU interface
    input   [15:0] cpu_dout,
    input   [12:1] cpu_addr,
    input          cpu_rnw,
    input   [ 1:0] cpu_dsn,
    output  [15:0] cpu_din,

    // Timer signals
    inout   [8:0]  vdump,
    inout   [8:0]  vrender,
    inout   [8:0]  hdump,
    inout   [8:0]  LHBL,
    inout   [8:0]  LVBL,
    inout   [8:0]  HS,
    inout   [8:0]  VS,

    // ROMs
    input          rom_cs,
    output  [16:0] rom_addr,    // MSB = bank selection
    input   [15:0] rom_data,
    input          rom_ok
);

parameter RAM_AW=11,    // normally 4kB (AW=11, 16 bits), it can be 8kB too
          MASTER=0      // One BAC06 chip will be the timing master

reg  [ 7:0] mmr_mode[0:3];
reg  [15:0] mmr_sft [0:3];

reg  [15:0] mmr_mux;
wire [15:0] cpu_ram;

assign cpu_din <= (mode_cs | sft_cs ) ? mmr_mux : cpu_ram;

always @(posedge clk) begin
    if( rst ) begin
        mmr_mode[0] <= 0; mmr_mode[1] <= 0; mmr_mode[2] <= 0; mmr_mode[3] <= 0;
        mmr_sft [0] <= 0; mmr_sft [1] <= 0; mmr_sft [2] <= 0; mmr_sft [3] <= 0;
    end else begin
        if( sft_cs )
            mmr_mux <= mmr_sft[cpu_addr[2:1]];
        else
            mmr_mux <= { 8'hff, mmr_mode[cpu_addr[2:1]] };
        if( cpu_we ) begin
            if( mode_cs && !cpu_dsn[0] )
                mmr_mode <= cpu_dout[7:0];
            if( sft_cs && !cpu_dsn[0] )
                mmr_sft[ 7:0] <= cpu_dout[7:0];
            if( sft_cs && !cpu_dsn[1] )
                mmr_sft[15:8] <= cpu_dout[15:8];
        end
    end
end

generate
    if( MASTER ) begin
        jtframe_cen48 u_cen(
            .clk    ( clk       ),    // 48 MHz
            .cen6   ( pxl_cen   ),
            .cen12  ( pxl2_cen  ),
            // unused
            .cen16(), .cen8(), .cen4(), .cen4_12(), .cen3(),
            .cen3q(), .cen1p5(), .cen16b(), .cen12b(),
            .cen6b(), .cen3b(), .cen3qb(), .cen1p5b()
        );

        jtframe_vtimer(
            .clk        ( clk       ),
            .pxl_cen    ( pxl_cen   ),
            .vdump      ( vdump     ),
            .vrender    ( vrender   ),
            .vrender1   (           ),
            .H          ( hdump     ),
            .Hinit      (           ),
            .Vinit      (           ),
            .LHBL       ( LHBL      ),
            .LVBL       ( LVBL      ),
            .HS         ( HS        ),
            .VS         ( VS        )
        );
    end
endgenerate

wire [1:0] cpu_we = {2{~cpu_rnw & map_cs}} & ~cpu_dsn;

jtframe_dual_ram16 #(.aw(RAM_AW)) u_ram(
    // Port 0
    .clk0   ( clk       ),
    .data0  (           ),
    .addr0  ( addr      ),
    .we0    ( 1'b0      ),
    .q0     ( ram_dout  ),
    // Port 1, CPU
    .clk1   ( clk_cpu   ),
    .data1  ( cpu_dout  ),
    .addr1  ( cpu_addr[RAM_AW:1] ),
    .we1    ( cpu_we    ),
    .q1     ( cpu_ram   )
);

endmodule