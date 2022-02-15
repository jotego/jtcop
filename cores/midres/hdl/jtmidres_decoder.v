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

module jtcop_decoder(
    input       [23:1] A,
    input              ASn,
    input              RnW,
    input              sec2,
    input              service,
    input       [ 1:0] coin_input,
    output reg         rom_cs,
    output reg         eep_cs,
    output reg         prisel_cs,
    output reg         mixpsel_cs,
    output reg         nexin_cs,       // this pin C15 of connector 2. It's unconnected in all games
    output reg         nexout_cs,      // Connector 2, pin A16: unused
    output reg         nexrm1,         // used on Heavy Barrel PCB for the track balls
    output reg         disp_cs,
    output reg         sysram_cs,
    output reg         vint_clr,
    output reg         cblk,
    output reg  [ 2:0] read_cs,
    // BAC06 chips
    output reg         fmode_cs,
    output reg         fsft_cs,
    output reg         fmap_cs,
    output reg         bmode_cs,
    output reg         bsft_cs,
    output reg         bmap_cs,
    output reg         nexrm0_cs,
    output reg         cmode_cs,
    output reg         csft_cs,
    output reg         cmap_cs,
    // Object
    output reg         obj_cs,       // called MIX in the schematics
    output reg         obj_copy,     // called *DM in the schematics
    // Palette
    output reg [ 1:0]  pal_cs,
    // HuC6820 protection
    output reg         huc_cs,      // shared memory with HuC6820
    // sound
    output reg         snreq,
    // MCU/SUB CPU
    output reg [5:0]   sec          // bit 2 is unused
);

always @(*) begin
    rom_cs     = 0;
    eep_cs     = 0;
    // fist BAC06 chip
    fmode_cs   = 0;
    fsft_cs    = 0;
    fmap_cs    = 0;
    // second BAC06 chip
    bmode_cs   = 0;
    bsft_cs    = 0;
    bmap_cs    = 0;
    // third BAC06 chip
    nexrm0_cs  = 0;
    cmode_cs   = 0;
    csft_cs    = 0;
    cmap_cs    = 0;
    nexrm1     = 0;
    prisel_cs  = 0;
    obj_copy   = 0;
    snreq      = 0;
    vint_clr   = 0;
    mixpsel_cs = 0;
    cblk       = 0;
    nexout_cs  = 0;
    read_cs    = 0;
    nexin_cs   = 0;
    pal_cs     = 0;
    sysram_cs  = 0;
    obj_cs     = 0;
    sec[5:3]   = { service, coin_input };
    sec[2]     = sec2;
    sec[1:0]   = 0;
    disp_cs    = 0;
    huc_cs     = 0;

    if( !ASn ) begin
        case( A[21:20] )
            0: rom_cs = A[19:16]<8 && RnW;
            1:
                case( A[19:17] )
                    0: sysram_cs = 1;
                    1: obj_cs    = 1;
                    2: pal_cs[0] = 1; // 0x14'0000
                    3: prisel_cs = 1; // 0x16'0000
                    4: // 0x18'0000
                        if( !A[4] ) begin
                            case( A[3:1] )
                                0: read_cs[0] = 1; // cabinet IO
                                1: read_cs[2] = 1; // DIP sw
                                2: nexrm1     = 1; // rotary 1P
                                4: read_cs[1] = 1; // system I/O
                                5: vint_clr   = 1; // sure ?
                                6: obj_copy   = 1; // sure? what about mixpsel_cs ?
                                default:;
                            endcase
                        end
                    5: snreq = 1;   // 0x1A'0000
                    default:;
                endcase
            2: begin
                disp_cs = 1;
                case( A[19:17] )
                    0: bmode_cs = 1;
                    1: bmap_cs  = 1;
                    2: bsft_cs  = 1;
                    4: cmode_cs = 1;
                    5: cmap_cs  = 1;
                    6: csft_cs  = 1;
                    default:;
                endcase
            end
            3: begin
                disp_cs = 1;
                case( A[19:17] )
                    0: fmode_cs  = 1;   // cfg registers
                    1: fmap_cs   = 1;   // tilemap
                    2: fsft_cs   = 1;   // col/row scroll
                    default:;
                endcase
            end
        endcase
    end
end

endmodule