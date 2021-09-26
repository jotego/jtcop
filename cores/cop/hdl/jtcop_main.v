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

module jtcop_main(
    input              rst,
    input              clk,

    // external interrupts
    input              LVBL,
    input              sec2,

    // sound
    output             snd_irqn,
    output reg [7:0]   snd_latch,

    // Palette
    output reg [2:0]   prisel,
    output reg [1:0]   pal_cs,

    output reg         fmode_cs,
    output reg         fsft_cs,
    output reg         fmap_cs,
    output reg         bmode_cs,
    output reg         bsft_cs,
    output reg         bmap_cs,
    output reg         nexrm0_cs,

    // cabinet I/O
    input       [ 7:0] joystick1,
    input       [ 7:0] joystick2,

    input       [ 1:0] start_button,
    input       [ 1:0] coin_input,
    input              service,

    // RAM access
    output             ram_cs,
    output             vram_cs,
    input       [15:0] ram_data,   // coming from VRAM or RAM
    input              ram_ok,

    // DIP switches
    input              dip_pause,
    input              dip_test,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,
);

wire [23:1] A;
wire        BERRn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
wire        BRn, BGACKn, BGn, RnW;
wire        ASn, UDSn, LDSn, BUSn, VPAn;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

reg         snreq, eep_cs;

assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;
assign BUSn  = ASn | (LDSn & UDSn);
assign VPAn  = ~&{ FC, ~ASn };

assign snd_irqn = ~snreq;

always @(*) begin
    IPLn = 7;
    if( vint )
        IPLn = 6;
    else if( secirq )
        IPLn = 5;
    else if( nexirq )
        IPLn = 4;
end

always @(*) begin
    rom_cs     = 0;
    eep_cs     = 0;
    fmode_cs   = 0;
    fsft_cs    = 0;
    fmap_cs    = 0;
    bmode_cs   = 0;
    bsft_cs    = 0;
    bmap_cs    = 0;
    nexrm0_cs  = 0;
    nexrm1     = 0;
    prisel_cs  = 0;
    dm_cs      = 0;
    snreq      = 0;
    sec        = 0;
    vint_clr   = 0;
    mixpsel_cs = 0;
    cblk       = 0;
    nexout     = 0;
    read_cs    = 0;
    nexin_cs   = 0;
    pal_cs     = 0;
    sysram     = 0;
    mix        = 0;

    if( !ASn ) begin
        case( A[21:20] )
            0: rom_cs = A[19:16]<6 && RnW;
            1: eep_cs = ~A[19]; // connects to an EEPROM, but it isn't on the PCB
            2: if( A[19:18]==2'b01 ) begin // 0x24'???? DPS - display (?)
                case( A[15:13] )
                    0: fmode_cs  = 1; // 0x24'0000, cfg registers
                    1: fsft_cs   = 1; // 0x24'2000, col/row scroll
                    2: fmap_cs   = 1; // 0x24'4000, rest of VRAM
                    3: bmode_cs  = 1; // 0x24'6000, cfg registers
                    4: bsft_cs   = 1; // 0x24'8000, col/row scroll
                    5: bmap_cs   = 1; // 0x24'a000, rest of VRAM
                    6: nexrm0_cs = 1; // BAC06 chip on second PCB
                    default:;
                endcase
            end
            3: begin // RAMIO
                case( A[16:14] ) // 0x3?'????
                    0: nexrm1 = 1;
                    3: begin // 0x30'C0?0
                        if( RnW && !A[4] ) begin // 0x30'C000
                            case( A[3:1] )
                                0: read_cs[0] = 1; // cabinet IO
                                1: read_cs[1] = 1;
                                2: read_cs[2] = 1;
                                3: nexin_cs   = 1;
                                4: sec[1]     = 1;
                            endcase
                        end
                        if( !RnW && A[4] ) begin // 0x30'C010
                            case( A[3:1] )
                                0: prisel_cs  = 1;
                                1: dm_cs      = 1;
                                2: snreq      = 1;
                                3: sec[0]     = 1;
                                4: vint_clr   = 1;
                                5: mixpsel_cs = 1;
                                6: cblk       = 1; // coin block, unused
                                7: nexout     = 1;
                            endcase
                        end else begin
                    end
                    4: pal_cs[0] = 1; // 0x31'0000 called PSEL in the schematics
                    5: pal_cs[1] = 1; // 0x31'4000
                    6: sysram  = 1;   // 0x31'8000
                    7: mix     = 1;   // 0x31'C000 sprites
                endcase
            end
        endcase
    end
end

// global registers
reg LVBL_l, sec2_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        prisel  <= 0;
        mixpsel <= 0;
        vint    <= 0;
        secirq  <= 0;
        LVBL_l  <= 0;
        sec2_l  <= 0;
        snd_latch <= 0;
    end else begin

        LVBL_l <= LVBL;
        if( vint_clr )
            vint <= 0;
        else if( !LVBL && LVBL_l ) vint <= 1;

        sec2_l <= sec2;
        if( sec[1] )
            secirq <= 0;
        else if( !sec2_l && sec2 ) secirq <= 1;

        if( snreq )
            snd_latch <= cpu_dout[7:0];
    end
end

// Cabinet inputs
reg  [15:0] cab_dout;

always @(posedge clk) begin
    cab_dout <= 16'hffff;
    if( read_cs[0] )
        cab_dout <= { joystick2[7:0], joystick1[7:0] };
    if( read_cs[1] )
        cab_dout <= { 8'hff,
                        ~LVBL,
                        service,
                        coin_input,
                        start_button,
                        joystick2[8],
                        joystick1[8] };
    if( read_cs[2] )
        cab_dout <= { dipsw_b, dipsw_a };
end


jtframe_m68k u_cpu(
    .clk        ( clk         ),
    .rst        ( rst         ),
    .cpu_cen    ( cpu_cen     ),
    .cpu_cenb   ( cpu_cenb    ),

    // Buses
    .eab        ( A           ),
    .iEdb       ( cpu_din     ),
    .oEdb       ( cpu_dout    ),


    .eRWn       ( RnW         ),
    .LDSn       ( LDSn        ),
    .UDSn       ( UDSn        ),
    .ASn        ( ASn         ),
    .VPAn       ( VPAn        ),
    .FC         ( FC          ),

    .BERRn      ( BERRn       ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( BRn         ),
    .BGACKn     ( BGACKn      ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( { irqn, 2'b11 } ) // VBLANK
);


endmodule