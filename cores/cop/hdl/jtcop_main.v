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
    output     [5:0]   sec,         // bit 2 is unused
    input              sec2,        // this is the bit 2!

    // sound
    output             snreq,
    output reg [7:0]   snd_latch,

    // Palette
    output reg [ 2:0]  prisel,
    output     [ 1:0]  pal_cs,
    input      [15:0]  pal_dout,

    // BAC06 chips
    output             fmode_cs,
    output             fsft_cs,
    output             fmap_cs,
    output             bmode_cs,
    output             bsft_cs,
    output             bmap_cs,
    output             cmode_cs,
    output             csft_cs,
    output             cmap_cs,

    // HuC6820 protection
    input       [ 7:0] huc_dout,
    output             huc_cs,      // shared memory with HuC6820

    // Objects
    output             obj_cs,       // called MIX in the schematics
    output             obj_copy,     // called *DM in the schematics
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

    output             rom_cs,
    input       [15:0] rom_data,
    input              rom_ok,

    // DIP switches
    input              dip_pause,
    input              dip_test,
    input    [7:0]     dipsw_a,
    input    [7:0]     dipsw_b,

    // Debug
    input    [7:0]     st_addr,
    output   [7:0]     st_dout
);

wire [23:1] A;
//wire        BERRn;
wire [ 2:0] FC;
reg  [ 2:0] IPLn;
wire        /*BRn, BGACKn,*/ BGn;
wire        ASn, UDSn, LDSn, BUSn, VPAn;
reg  [15:0] cpu_din;
wire        disp_cs, sysram_cs, cblk, vint_clr,
            eep_cs,
            prisel_cs, mixpsel_cs,
            nexin_cs,       // this pin C15 of connector 2. It's unconnected in all games
            nexout_cs,      // Connector 2, pin A16: unused
            nexrm1,         // used on Heavy Barrel PCB for the track balls
            nexrm0_cs;      // a signal on Robocop sch. unused. Reused for SlySpy for the protection IC
reg         secirq, vint,
            ok_dly;
wire        pre_ram_cs;
wire        cpu_cen, cpu_cenb;
wire [ 2:0] read_cs;
wire [ 7:0] track_dout;
wire [15:0] fave;
reg         LVBL_l, sec2_l;

`ifdef SIMULATION
wire [23:0] A_full = {A,1'b0};
`endif

assign UDSWn = RnW | UDSn;
assign LDSWn = RnW | LDSn;
assign BUSn  = ASn | (LDSn & UDSn);
assign VPAn  = ~&{ FC, ~ASn };
assign cpu_addr = A[18:1];

assign pre_ram_cs = sysram_cs | fsft_cs | fmap_cs |
                                bsft_cs | bmap_cs |
                                cmap_cs | csft_cs;
assign ram_cs   = ~BUSn & pre_ram_cs;

assign st_dout = st_addr[0] ? fave[15:8] : fave[7:0]; // 10,000kHz = 2710 in hex

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

// NB: this module is different for jtmidres
jtcop_decoder u_decoder(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .A          ( A         ),
    .ASn        ( ASn       ),
    .RnW        ( RnW       ),
    .LVBL       ( LVBL      ),
    .LVBL_l     ( LVBL_l    ),
    .sec2       ( sec2      ),
    .service    ( service   ),
    .coin_input ( coin_input),
    .rom_cs     ( rom_cs    ),
    .eep_cs     ( eep_cs    ),
    .prisel_cs  ( prisel_cs ),
    .mixpsel_cs ( mixpsel_cs),
    .nexin_cs   ( nexin_cs  ),      // this pin C15 of connector 2. It's unconnected in all games
    .nexout_cs  ( nexout_cs ),      // Connector 2, pin A16: unused
    .nexrm1     ( nexrm1    ),      // used on Heavy Barrel PCB for the track balls
    .disp_cs    ( disp_cs   ),
    .sysram_cs  ( sysram_cs ),
    .vint_clr   ( vint_clr  ),
    .cblk       ( cblk      ),
    .read_cs    ( read_cs   ),
    // BAC06 chips
    .fmode_cs   ( fmode_cs  ),
    .fsft_cs    ( fsft_cs   ),
    .fmap_cs    ( fmap_cs   ),
    .bmode_cs   ( bmode_cs  ),
    .bsft_cs    ( bsft_cs   ),
    .bmap_cs    ( bmap_cs   ),
    .nexrm0_cs  ( nexrm0_cs ),
    .cmode_cs   ( cmode_cs  ),
    .csft_cs    ( csft_cs   ),
    .cmap_cs    ( cmap_cs   ),
    // Object
    .obj_cs     ( obj_cs    ),      // called MIX in the schematics
    .obj_copy   ( obj_copy  ),      // called *DM in the schematics
    // Palette
    .pal_cs     ( pal_cs    ),
    // HuC6820 protection
    .huc_cs     ( huc_cs    ),      // shared memory with HuC6820
    // sound
    .snreq      ( snreq     ),
    // MCU/SUB CPU
    .sec        ( sec       )       // bit 2 is unused
);

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
reg  [11:0] rotary1, rotary2;

`ifndef DEC1
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
`else
    function [6:0] sort_midres( input [8:0] joy_in);
        sort_midres = { joy_in[6:4], joy_in[0], joy_in[1], joy_in[2], joy_in[3] };
    endfunction

    function [11:0] torot( input [11:0] hotone );
        case( hotone )
            default: torot = 12'hffe;
            12'h1<< 1: torot = 12'hffd;
            12'h1<< 2: torot = 12'hffb;
            12'h1<< 3: torot = 12'hff7;
            12'h1<< 4: torot = 12'hfef;
            12'h1<< 5: torot = 12'hfdf;
            12'h1<< 6: torot = 12'hfbf;
            12'h1<< 7: torot = 12'hf7f;
            12'h1<< 8: torot = 12'heff;
            12'h1<< 9: torot = 12'hdff;
            12'h1<<10: torot = 12'hbff;
            12'h1<<11: torot = 12'h7ff;
        endcase
    endfunction

    always @(posedge clk) begin
        cab_dout <= 16'hffff;
        if( read_cs[0] )
            cab_dout <= {
                start_button[1], sort_midres(joystick2),
                start_button[0], sort_midres(joystick1)
            };
        if( read_cs[1] )
            cab_dout <= {   ~12'h0,
                            ~LVBL,
                            service,
                            coin_input };
        if( read_cs[2] )
            cab_dout <= { dipsw_b, dipsw_a };
        if( read_cs==7 ) begin
            cab_dout[15:12] <= 4'hf;
            cab_dout[11: 0] <= A[1] ? torot(rotary2) : torot(rotary1);
        end
        //joyana1 : joyana2;
    end
`endif

// input multiplexer
reg  [1:0] track_xrst, track_yrst;
wire [1:0] track_cf;
reg  [3:0] track_cs;
wire [7:0] track0_dout, track1_dout;
reg  [ 2:0] frame_cnt;

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        rotary1 <= 0;
        rotary2 <= 0;
        frame_cnt <= 0;
    end else if( LVBL_l && !LVBL ) begin
        frame_cnt <= frame_cnt+1'd1;
        if(frame_cnt==0) begin
            if( ~joystick1[6] )
                rotary1 <= rotary1==0 ? 12'd1 : (rotary1<<1);
            if( ~joystick1[7] )
                rotary1 <= rotary1==0 ? 12'h800 : (rotary1>>1);
            if( ~joystick2[6] )
                rotary2 <= rotary2==0 ? 12'd1 : (rotary2<<1);
            if( ~joystick2[7] )
                rotary2 <= rotary2==0 ? 12'h800 : (rotary2>>1);
        end
    end
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
                huc_cs    ? { 8'hff, huc_dout }  :
                track_cs[0] ? {8'hff, track0_dout } :
                track_cs[1] ? {8'hff, track1_dout } :
                track_cs[2] ? {track_cf[0], track_cf[1], 2'b11, ~rotary2 } :
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
`ifndef NOTRACKBALL
    always @* begin
        track_cs   = 0;
        track_xrst = 0;
        track_yrst = 0;
        if( nexrm1 ) begin
            if( RnW && !A[6] ) begin
                case( A[4:3] )
                    0: track_cs[3] = 1; // rotary control
                    1: track_cs[2] = 1; // 4701's flags read in bits 15:14
                    2: track_cs[0] = 1;
                    3: track_cs[1] = 1;
                endcase
            end else if( !RnW && A[6] ) begin
                case( A[4:3] )
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
        .inc    ( {1'b0, ~joystick2[6] } ),
        .dec    ( {1'b0, ~joystick2[7] } ),
        .x_rst  ( track_xrst[1] ),
        .y_rst  ( track_yrst[1] ),
        .uln    ( A[1]          ),
        .cs     ( track_cs[1]   ),
        .xn_y   ( A[2]          ),
        .cfn    ( track_cf[1]   ),
        .sfn    (               ),
        .dout   ( track1_dout   )
    );
`else
    assign track0_dout = 0;
    assign track1_dout = 0;
    assign track_cf    = 3;
    initial track_cs   = 0;
`endif

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
    .fave       ( fave      ),
    .fworst     (           ),
    .frst       (           )
);

`ifndef NOMAIN
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
`else
    jtframe_simwr_68k u_simwr(
        .rst    ( rst       ),
        .clk    ( clk       ),
        .DTACKn ( DTACKn    ),
        .A      ( A         ),
        .dout   ( cpu_dout  ),
        .dsn    ({UDSn,LDSn}),
        .wrn    ( RnW       ),
        .ASn    ( ASn       )
    );

    // assign obj_copy = !LVBL && LVBL_l;
`endif

endmodule