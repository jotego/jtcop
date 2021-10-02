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

// Largest ROM seen
// As   | Size
// -----|------------------
// gfx1 | 0x20000 =  64 kB
// gfx2 | 0x40000 = 128 kB
// gfx3 | 0x40000 = 256 kB  (midres)

// The memory connected to the BAC06 is divided in two regions
// by the MSB. The lower region corresponds to the tilemap
// and is selected by the /NMAPSEL pin (#95).
// The upper region contains the row/column scroll information.
// The CPU selects it with pin /FSFT
// The BAC-06 outputs a /NMAP pin to the memory, which gets
// renamed in the schematics to BxMSFT, signalling the use
// for each memory half

// The BAC06 lets 12 address bits pass through to the memory
// but only the BAC06 used for B0 (background 0) has a 12+1 A
// memory connected. The other two chips had 10+1 A memories

// Only B0's BAC06 has the /NUDS and /NLDS inputs connected
// directly to the processor's outputs. The other chips have these
// signals gated by their respective chip select signals.
// I think this means that the processor could access the memory
// at any time, regardless of the /NSIFT and /NMAPSEL inputs


module jtcop_bac06(
    input       rst,
    input       clk,        // 12MHz original
    input       clk_cpu,
    inout       pxl2_cen,   // 12 MHz
    inout       pxl_cen,    //  6 MHz

    input       mode_cs,
    input       sift_cs,    // scroll
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
    inout          LHBL,
    inout          LVBL,
    inout          HS,
    inout          VS,

    // ROMs
    output         rom_cs,
    output  [18:0] rom_addr,    // top 2 bits are NCGSEL[1:0]
    input   [31:0] rom_data,
    input          rom_ok,

    output  [ 7:0] pxl          // pixel output
);

parameter RAM_AW=11,    // normally 4kB (AW=11, 16 bits), it can be 8kB too
          MASTER=0      // One BAC06 chip will be the timing master

reg  [ 7:0] mode[0:3];
reg  [15:0] hscr;
reg  [15:0] vscr;
reg  [ 3:0] colscr_sh;
reg  [ 3:0] rowscr_sh;

reg  [15:0] mmr_mux;
wire [15:0] cpu_ram;
wire [ 1:0] ncgsel;


assign cpu_din = cpu_ram;

function [15:0] combine( input [15:0] din );
    combine = { cpu_dsn[1] ? din[15:8] : cpu_dout[15:8],
                cpu_dsn[0] ? din[ 7:0] : cpu_dout[ 7:0]  };
endfunction


always @(posedge clk) begin
    if( rst ) begin
        mode[0] <= 0; mode[1] <= 0; mode[2] <= 0; mode[3] <= 0;
        mode[4] <= 0; mode[5] <= 0; mode[6] <= 0; mode[7] <= 0;
    end else begin
        if( cpu_we && mode_cs ) begin
            if( !cpu_addr[4] ) begin
                if( !cpu_dsn[0] ) mode[cpu_addr[2:1]] <= cpu_dout[7:0];
            else begin
                case( cpu_addr[2:1] )
                    0: hscr <= combine( hscr );
                    1: vscr <= combine( vscr );
                    2: if( !cpu_dsn[0] ) colscr_sh <= cpu_dout[3:0];
                    3: if( !cpu_dsn[1] ) rowscr_sh <= cpu_dout[3:0];
                endcase
            end
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

wire [1:0] cpu_we = {2{~cpu_rnw & (map_cs | sift_cs)}} & ~cpu_dsn;
wire [RAM_AW-1:0] cpu_acc = { sift_cs, cpu_addr[RAM_AW-2:0] };

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
    .addr1  ( cpu_acc   ),
    .we1    ( cpu_we    ),
    .q1     ( cpu_ram   )
);

endmodule