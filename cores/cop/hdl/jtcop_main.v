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

    // external interrupts
    input              LVBL,
    input              sec2,

    // Palette
    output reg [2:0]   prisel,

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

assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;
assign BUSn  = ASn | (LDSn & UDSn);
assign VPAn  = ~&{ FC, ~ASn };

reg eep_cs;

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
    if( !ASn ) begin
        case( A[21:20] )
            0: rom_cs = A[19:16]<6 && RnW;
            1: eep_cs = ~A[19]; // connects to an EEPROM, but it isn't on the PCB
            2: if( A[19:18]==2'b01 ) begin // DPS - display (?)
                case( A[15:13] )
                    0: fmode  = 1;
                    1: fsft   = 1;
                    2: fmap   = 1;
                    3: bmode  = 1;
                    4: bsft   = 1;
                    5: bmap   = 1;
                    6: nexrm0 = 1;
                    default:;
                endcase
            end
            3: begin // RAMIO
                case( A[16:14] )
                    0: nexrm1 = 1;
                    3: begin
                        if( !RnW && A[4] ) begin
                            case( A[3:1] )
                                0: prisel_cs  = 1;
                                1: dm_cs      = 1;
                                2: snreq      = 1;
                                3: sec[0]     = 1;
                                4: vint_clr   = 1;
                                5: mixpsel_cs = 1;
                                6: cblk       = 1;
                                7: nexout     = 1;
                            endcase
                        end else begin
                        if( RnW && !A[4] ) begin
                            case( A[3:1] )
                                0: read_cs[0] = 1; // cabinet IO
                                1: read_cs[1] = 1;
                                2: read_cs[2] = 1;
                                3: nexin_cs   = 1;
                                4: sec[1]     = 1;
                            endcase
                        end
                    end
                    4: psel[0] = 1;
                    5: psel[1] = 1;
                    6: sysram  = 1;
                    7: mix     = 1; // sprites

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
    end else begin

        LVBL_l <= LVBL;
        if( vint_clr )
            vint <= 0;
        else if( !LVBL && LVBL_l ) vint <= 1;

        sec2_l <= sec2;
        if( sec[1] )
            secirq <= 0;
        else if( !sec2_l && sec2 ) secirq <= 1;

    end
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