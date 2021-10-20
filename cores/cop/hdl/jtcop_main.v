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

    input              LVBL,
    input              LHBL,
    // external interrupts
    input              nexirq,

    // Bus signals
    output      [15:0] cpu_dout,
    output      [18:1] cpu_addr,
    output             UDSWn,
    output             LDSWn,
    output             RnW,

    // BA register reads
    input       [15:0] ba0_dout,
    input       [15:0] ba1_dout,
    input       [15:0] ba2_dout,

    // MCU/SUB CPU
    input       [15:0] mcu_dout,
    output reg  [15:0] mcu_din,
    output reg [5:0]   sec,         // bit 2 is unused
    input              sec2,        // this is the bit 2!

    // sound
    output reg         snreq,
    output reg [7:0]   snd_latch,

    // Palette
    output reg [ 2:0]  prisel,
    output reg [ 1:0]  pal_cs,
    input      [15:0]  pal_dout,

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

    // Objects
    output reg         obj_cs,       // called MIX in the schematics
    output reg         obj_copy,     // called *DM in the schematics
    output reg         mixpsel,      // related to the OBJ buffer DMA function
    input       [15:0] obj_dout,

    // cabinet I/O
    input       [ 8:0] joystick1,
    input       [ 8:0] joystick2,
    input       [15:0] joyana1,
    input       [15:0] joyana2,

    input       [ 1:0] start_button,
    input       [ 1:0] coin_input,
    input              service,

    // RAM access
    output             ram_cs,
    input       [15:0] ram_data,   // coming from VRAM or RAM
    input              ram_ok,

    output reg         rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,

    // DIP switches
    input              dip_pause,
    input              dip_test,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b
);

wire [23:1] A;
wire        BERRn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
wire        BRn, BGACKn, BGn;
wire        ASn, UDSn, LDSn, BUSn, VPAn;
reg  [15:0] cpu_din;
reg         disp_cs, sysram_cs,
            secirq, vint, vint_clr,
            cblk, ok_dly;
wire        pre_ram_cs;
wire        cpu_cen, cpu_cenb;
reg  [ 2:0] read_cs;
wire [ 7:0] track_dout;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

reg         eep_cs,
            prisel_cs, mixpsel_cs,
            nexin_cs,       // this pin C15 of connector 2. It's unconnected in all games
            nexout_cs,      // Connector 2, pin A16: unused
            nexrm1;         // used on Heavy Barrel PCB for the track balls

assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;
assign BUSn  = ASn | (LDSn & UDSn);
assign VPAn  = ~&{ FC, ~ASn };
assign cpu_addr = A[18:1];

assign pre_ram_cs = sysram_cs | fsft_cs | fmap_cs |
                                bsft_cs | bmap_cs |
                                cmap_cs | csft_cs;
assign ram_cs   = ~BUSn & pre_ram_cs;

always @(*) begin
    if( vint )
        IPLn = ~3'd6;   // 001 = 1
    else if( secirq )   // active high
        IPLn = ~3'd5;   // 010 = 2
    else if( !nexirq )  // active low
        IPLn = ~3'd4;   // 011 = 3
    else
        IPLn = ~3'd0;
end

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

    if( !ASn ) begin
        case( A[21:20] )
            0: rom_cs = A[19:16]<6 && RnW;
            1: eep_cs = ~A[19]; // connects to an EEPROM, but it isn't on the PCB
            2: begin
                disp_cs = 1;
                if( A[19:18]==2'b01 ) begin // 0x24'???? DSP - DiSPlay (?)
                    case( A[15:13] )
                        0: fmode_cs  = 1;   // 0x24'0000, cfg registers
                        1: fsft_cs   = 1;   // 0x24'2000, col/row scroll
                        2: fmap_cs   = 1;   // 0x24'4000, tilemap
                        3: bmode_cs  = 1;   // 0x24'6000, cfg registers
                        4: bsft_cs   = 1;   // 0x24'8000, col/row scroll
                        5: bmap_cs   = 1;   // 0x24'a000, tilemap
                        6: begin
                            nexrm0_cs = 1; // BAC06 chip on second PCB
                            case( A[12:11])
                                0: cmode_cs = 1; // these signals could go
                                1: csft_cs  = 1; // in a different order
                                2: cmap_cs  = 1;
                                default:;
                            endcase
                        end
                        default:;
                    endcase
                end
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
                                1: obj_copy   = 1;
                                2: snreq      = 1;
                                3: sec[0]     = 1;
                                4: vint_clr   = 1;
                                5: mixpsel_cs = 1;
                                6: cblk       = 1; // coin block, unused
                                7: nexout_cs  = 1;
                            endcase
                        end
                    end
                    4: pal_cs[0] = 1; // 0x31'0000 called PSEL in the schematics
                    5: pal_cs[1] = 1; // 0x31'4000
                    6: sysram_cs = 1;   // 0x31'8000
                    7: obj_cs    = 1;   // 0x31'C000 sprites
                endcase
            end
        endcase
    end
end

// global registers
reg LVBL_l, sec2_l;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        vint    <= 0;
        secirq  <= 0;
        LVBL_l  <= 0;
        sec2_l  <= 0;
        snd_latch <= 0;
        mcu_din <= 0;
        ok_dly  <= 0;
        prisel  <= 0;
        mixpsel <= 0;
    end else begin
        ok_dly <= rom_ok;

        LVBL_l <= LVBL;
        if( vint_clr )
            vint <= 0;
        else if( !LVBL && LVBL_l ) vint <= 1;

        if( snreq )
            snd_latch <= cpu_dout[7:0];

        // MCU
        if( sec[0] )    // CPU writes
            mcu_din <= cpu_dout;

        sec2_l <= sec2; // CPU reads
        if( sec[1] ) // clear interrupt
            secirq <= 0;
        else if( !sec2_l && sec2 )
            secirq  <= 1;

        // Colour mixer
        if( prisel_cs ) prisel <= cpu_dout[2:0];

        // Object DMA
        if( mixpsel_cs ) mixpsel <= cpu_dout[0];
    end
end

// Cabinet inputs
reg  [15:0] cab_dout;

function [8:0] sort_joy( input [8:0] joy_in);
    sort_joy = { joy_in[8:4], joy_in[0], joy_in[1], joy_in[2], joy_in[3] };
endfunction

wire [8:0] sort1 = sort_joy(joystick1),
           sort2 = sort_joy(joystick2);

always @(posedge clk) begin
    cab_dout <= 16'hffff;
    if( read_cs[0] )
        cab_dout <= { sort2[7:0], sort1[7:0] };
    if( read_cs[1] )
        cab_dout <= { 8'hff,
                        ~LVBL,
                        service,
                        coin_input,
                        start_button,
                        sort2[8],
                        sort1[8] };
    if( read_cs[2] )
        cab_dout <= { dipsw_b, dipsw_a };
end

// input multiplexer
reg  [1:0] track_xrst, track_yrst;
wire [1:0] track_cf;
reg  [23:0] track_cs;
wire [7:0] track0_dout, track1_dout;
reg  [11:0] rotary1;

always @* begin
    rotary1 = 0;
    casez( joyana1[7:0] )
        8'b1111_110?: rotary1 = 12'b000_001_000_000;
        8'b1111_10??: rotary1 = 12'b000_010_000_000;
        8'b1111_0???: rotary1 = 12'b000_100_000_000;
        8'b1110_????: rotary1 = 12'b001_000_000_000;
        8'b110?_????: rotary1 = 12'b010_000_000_000;
        8'b10??_????: rotary1 = 12'b100_000_000_000;
        8'b01??_????: rotary1 = 12'b000_000_100_000;
        8'b001?_????: rotary1 = 12'b000_000_010_000;
        8'b0001_????: rotary1 = 12'b000_000_001_000;
        8'b0000_1???: rotary1 = 12'b000_000_000_100;
        8'b0000_01??: rotary1 = 12'b000_000_000_010;
        8'b0000_001?: rotary1 = 12'b000_000_000_001;
    endcase
end

always @(posedge clk) begin
    cpu_din <=  ram_cs    ? ram_data :
                rom_cs    ? rom_data :
                pal_cs!=0 ? pal_dout :
                obj_cs    ? obj_dout :
                read_cs!=0? cab_dout :
                fmode_cs  ? ba0_dout :
                bmode_cs  ? ba1_dout :
                cmode_cs  ? ba2_dout :
                sec[1]    ? mcu_dout :
                track_cs[0] ? {8'hff, track0_dout } :
                track_cs[1] ? {8'hff, track1_dout } :
                track_cs[2] ? {track_cf[0], track_cf[1], 2'b11, ~joyana2[7:0], ~4'd0 } :
                track_cs[3] ? { 4'hf, ~rotary1 } :
                16'hffff;
end


wire DTACKn;
reg  disp_busy;
wire bus_cs    = pal_cs!=0 || pre_ram_cs || rom_cs;
wire bus_busy  = |{ rom_cs & ~ok_dly, pre_ram_cs & ~ram_ok, disp_cs & disp_busy };
wire bus_legit = disp_cs;

// Memory access to the display area gets locked until a blank starts
// during a blank, each access has a 2 clock delay until DTACKn is generated
// in practice, this means that each access has a 1 clock penalty, as the
// 1st clock after /AS goes low is lost by the CPU anyway
wire       disp_blank = disp_cs & (~LVBL | ~LHBL);
reg        disp_blank_l, disp_cs_l;
reg  [1:0] disp_bs_cnt;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        disp_busy   <= 0;
        disp_bs_cnt <= 0;
    end else begin
        disp_blank_l <= disp_blank;
        disp_cs_l    <= disp_cs;
        // display request
        if( disp_cs & ~disp_cs_l )
            disp_busy    <= 1;

        // display ack
        if( disp_blank & ~disp_blank_l) begin
            disp_bs_cnt <= 2'b11;
        end else if( cpu_cen ) begin
            disp_bs_cnt <= disp_bs_cnt >> 1;
        end
        // display data good
        if( disp_bs_cnt==0 )
            disp_busy <= 0;
    end
end

// Track ball

always @* begin
    track_cs   = 0;
    track_xrst = 0;
    track_yrst = 0;
    if( nexrm1 ) begin
        if( RnW && !A[6] ) begin
            case( A[5:3] )
                0: track_cs[3] = 1; // rotary control
                1: track_cs[2] = 1; // 4701's flags read in bits 15:14
                2: track_cs[0] = 1;
                3: track_cs[1] = 1;
            endcase
        end else if( !RnW && A[6] ) begin
            case( A[5:3] )
                0: track_xrst[0]=1;
                1: track_yrst[0]=1;
                2: track_xrst[1]=1;
                3: track_yrst[1]=1;
            endcase
        end
    end
end

jt4701_dialemu_2axis u_track0(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .LHBL   ( LHBL          ),
    .inc    ( {1'b0, ~joystick1[6] } ),
    .dec    ( {1'b0, ~joystick1[7] } ),
    .x_rst  ( track_xrst[0] ),
    .y_rst  ( track_yrst[0] ),
    .uln    ( A[1]          ),
    .cs     ( track_cs[0]   ),
    .xn_y   ( A[2]          ),
    .cfn    ( track_cf[0]   ),
    .sfn    (               ),
    .dout   ( track0_dout   )
);

jt4701_dialemu_2axis u_track1(
    .rst    ( rst           ),
    .clk    ( clk           ),
    .LHBL   ( LHBL          ),
    .inc    ( {1'b0, joystick2[6] } ),
    .dec    ( {1'b0, joystick2[7] } ),
    .x_rst  ( track_xrst[1] ),
    .y_rst  ( track_yrst[1] ),
    .uln    ( A[1]          ),
    .cs     ( track_cs[1]   ),
    .xn_y   ( A[2]          ),
    .cfn    ( track_cf[1]   ),
    .sfn    (               ),
    .dout   ( track1_dout   )
);

jtframe_68kdtack #(.W(8)) u_dtack(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
    .bus_cs     ( bus_cs    ),
    .bus_busy   ( bus_busy  ),
    .bus_legit  ( bus_legit ),
    .ASn        ( ASn       ),
    .DSn        ({UDSn,LDSn}),
    .num        ( 7'd5      ),  // numerator
    .den        ( 8'd24     ),  // denominator
    .DTACKn     ( DTACKn    ),
    // Frequency report
    .fave       (           ),
    .fworst     (           ),
    .frst       (           )
);

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

    .BERRn      ( 1'b1        ),
    // Bus arbitrion
    .HALTn      ( dip_pause   ),
    .BRn        ( 1'b1        ),
    .BGACKn     ( 1'b1        ),
    .BGn        ( BGn         ),

    .DTACKn     ( DTACKn      ),
    .IPLn       ( IPLn        ) // VBLANK
);


endmodule