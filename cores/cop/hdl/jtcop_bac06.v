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

// The /NUDS and /NLDS inputs of all chips are gated via a 74LS32
// chip by the /DSP chip select signal. That signal has a synchronization
// with the pixel clock. The BAC06 probably gives priority to the
// CPU when accessing memory, and the synchronization is done
// outside


module jtcop_bac06 #(
    parameter RAM_AW=11,    // normally 4kB (AW=11, 16 bits), it can be 16kB too (AW=13)
              MASTER=0      // One BAC06 chip will be the timing master
) (
    input       rst,
    input       clk,        // 12MHz original
    input       clk_cpu,
    inout       pxl2_cen,   // 12 MHz
    inout       pxl_cen,    //  6 MHz

    input       mode_cs,
    inout       flip,       // set by master BAC06

    // CPU interface
    input   [15:0] cpu_dout,
    input   [12:1] cpu_addr,
    input          cpu_rnw,
    input   [ 1:0] cpu_dsn,

    // Timer signals
    inout   [8:0]  vdump,
    inout   [8:0]  vrender,
    inout   [8:0]  hdump,
    inout          LHBL,
    inout          LVBL,
    inout          HS,
    inout          VS,
    inout          vload,
    inout          hinit,

    // VRAM
    output         ram_cs,
    output  [RAM_AW-1:0] ram_addr,
    input   [15:0] ram_data,
    input          ram_ok,

    // ROMs
    output         rom_cs,
    output  [18:0] rom_addr,    // top 2 bits are NCGSEL[1:0]
    input   [31:0] rom_data,
    input          rom_ok,

    output  [ 7:0] pxl          // pixel output
);


reg  [ 7:0] mode[0:3];
reg  [15:0] hscr;
reg  [15:0] vscr;
reg  [ 3:0] colscr_sh;
reg  [ 3:0] rowscr_sh;

reg  [15:0] mmr_mux;
wire [15:0] cpu_ram;
wire [ 1:0] ncgsel;

assign ram_cs = 0;
assign ram_addr = 0;


function [15:0] combine( input [15:0] din );
    combine = { cpu_dsn[1] ? din[15:8] : cpu_dout[15:8],
                cpu_dsn[0] ? din[ 7:0] : cpu_dout[ 7:0]  };
endfunction


always @(posedge clk) begin
    if( rst ) begin
        mode[0] <= 0; mode[1] <= 0; mode[2] <= 0; mode[3] <= 0;
    end else begin
        if( !cpu_rnw && mode_cs ) begin
            if( !cpu_addr[4] ) begin
                if( !cpu_dsn[0] ) mode[cpu_addr[2:1]] <= cpu_dout[7:0];
            end else begin
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
        wire [8:0] vrender1;
        assign flip  = 0;
        assign vload = vrender1==0; // second last line before the end of V blank

        jtframe_cen48 u_cen(
            .clk    ( clk       ),    // 48 MHz
            .cen6   ( pxl_cen   ),
            .cen12  ( pxl2_cen  ),
            // unused
            .cen16(), .cen8(), .cen4(), .cen4_12(), .cen3(),
            .cen3q(), .cen1p5(), .cen16b(), .cen12b(),
            .cen6b(), .cen3b(), .cen3qb(), .cen1p5b()
        );

        jtframe_vtimer #(
            .VB_END     ( 9'd271    ),
            .VS_START   ( 9'd255    ),
            .HS_START   ( 9'd327    ),
            .HB_START   ( 9'd255    ),
            .HB_END     ( 9'd383    ),
            .HINIT      ( 9'd255    )
        )   u_vtimer(
            .clk        ( clk       ),
            .pxl_cen    ( pxl_cen   ),
            .vdump      ( vdump     ),
            .vrender    ( vrender   ),
            .vrender1   ( vrender1  ),
            .H          ( hdump     ),
            .Hinit      ( hinit     ),
            .Vinit      (           ),
            .LHBL       ( LHBL      ),
            .LVBL       ( LVBL      ),
            .HS         ( HS        ),
            .VS         ( VS        )
        );
    end
endgenerate


endmodule