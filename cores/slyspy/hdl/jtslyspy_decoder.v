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
    Date: 28-2-2022 */

module jtcop_decoder(
    input              rst,
    input              clk,
    input       [23:1] A,
    input              ASn,
    input              RnW,
    input              LVBL,
    input              LVBL_l,
    input              sec2,
    input              service,
    input       [ 1:0] coin_input,
    output reg         rom_cs,
    output reg         eep_cs,
    output reg         prisel_cs,
    output reg         mixpsel_cs,
    output reg         nexin_cs,       // used as the counter control signals
    output reg         nexout_cs,      // used as the counter control signals
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
    output             obj_copy,     // called *DM in the schematics
    // Palette
    output reg [ 1:0]  pal_cs,
    // HuC6820 protection
    output reg         huc_cs,      // shared memory with HuC6820
    // sound
    output reg         snreq,
    // MCU/SUB CPU
    output reg [5:0]   sec          // bit 2 is unused
);

reg  [1:0] mapsel;
reg  nexinl, nexoutl;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        mapsel <= 0;
        nexinl <= 0;
        nexoutl<= 0;
    end else begin
        nexinl <= nexin_cs;
        nexoutl<= nexout_cs;
        if( nexin_cs & ~nexinl ) mapsel <= mapsel+2'd1;
        if( nexout_cs & ~nexoutl ) mapsel <= 0;
    end
end

// Triggering it once per frame, not sure if the
// CPU has it mapped to an address, like Robocop
assign obj_copy = !LVBL && LVBL_l;

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
    //obj_copy   = 0;
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

    // clear it automatically for now
    vint_clr   = LVBL && !LVBL_l;

    if( !ASn ) begin
        case( A[21:20] )
            0:  rom_cs = A[19:16]<8 && RnW; // although not all sockets are populated
            2:  if( A[19:18]==2'b01 ) begin // 24'0000
                    case( {A[15:13],1'b0} )
                        // map address control:
                        4'h4: nexin_cs  = RnW; // cnt up
                        4'ha: nexout_cs =!RnW; // cnt clr
                        // BA0 and BA1 chips
                        4'h0: begin
                            bmode_cs = mapsel==0;
                            bmap_cs  = mapsel==2;
                            fmap_cs  = mapsel==3;
                        end
                        4'h2: begin
                            bsft_cs  = mapsel==0;
                            fmap_cs  = mapsel==2;
                        end
                        4'h6: bmap_cs  = mapsel==0;
                        4'h8: begin
                            fmode_cs = mapsel==0;
                            fmap_cs  = mapsel==1;
                            bmap_cs  = mapsel==3;
                        end
                        4'hc: begin
                            fsft_cs  = mapsel==0;
                            bmap_cs  = mapsel==1;
                        end
                        4'he: fmap_cs = mapsel==0 || mapsel==2;
                        default:;
                    endcase
            end
            3: begin
                case( {A[19:14],2'd0} )
                    // BA2
                    8'h00: case(A[12:11])
                        0: cmode_cs  = 1;   // cfg registers
                        1: csft_cs   = 1;   // tilemap
                        2: cmap_cs   = 1;   // col/row scroll
                        default:;
                    endcase
                    8'h04: sysram_cs = 1;   // 0x30'4000
                    8'h08: obj_cs    = 1;   // 0x30'8000
                    8'h10: pal_cs[0] = 1;   // 0x31'0000
                    8'h14: case( A[3:1] )   // 0x31'4000
                        3'h0: snreq = 1;
                        3'h1: prisel_cs = 1; // 0x31'4002
                        3'h4: read_cs[2] = 1; // DIP sw
                        3'h5: read_cs[0] = 1; // cabinet IO
                        3'h6: read_cs[1] = 1; // system I/O
                        default:;
                    endcase
                    8'h1c: nexrm0_cs = 1; // protection
                    //sysram_cs = RnW; // fake it with RAM for now //
                    default:;
                endcase
            end
        endcase
        disp_cs = |{fmap_cs, bmap_cs, cmap_cs, fsft_cs, bsft_cs, csft_cs };
    end
end

endmodule