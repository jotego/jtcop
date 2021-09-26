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
    Date: 25-9-2021 */

module jtcop_game(
    input           rst,
    input           clk,
    // input           rst24,
    // input           clk24,
    output          pxl2_cen,   // 12   MHz
    output          pxl_cen,    //  6   MHz
    output   [7:0]  red,
    output   [7:0]  green,
    output   [7:0]  blue,
    output          LHBL_dly,
    output          LVBL_dly,
    output          HS,
    output          VS,
    // cabinet I/O
    input   [ 1:0]  start_button,
    input   [ 1:0]  coin_input,
    input   [ 7:0]  joystick1,
    input   [ 7:0]  joystick2,

    // SDRAM interface
    input           downloading,
    output          dwnld_busy,

    // Bank 0: allows R/W
    output   [21:0] ba0_addr,
    output   [21:0] ba1_addr,
    output   [21:0] ba2_addr,
    output   [21:0] ba3_addr,
    output   [ 3:0] ba_rd,
    output          ba_wr,
    output   [15:0] ba0_din,
    output   [ 1:0] ba0_din_m,  // write mask
    input    [ 3:0] ba_ack,
    input    [ 3:0] ba_dst,
    input    [ 3:0] ba_dok,
    input    [ 3:0] ba_rdy,

    input    [15:0] data_read,

    // RAM/ROM LOAD
    input   [24:0]  ioctl_addr,
    input   [ 7:0]  ioctl_dout,
    input           ioctl_wr,
    output  [ 7:0]  ioctl_din,
    input           ioctl_ram, // 0 - ROM, 1 - RAM(EEPROM)
    output  [21:0]  prog_addr,
    output  [15:0]  prog_data,
    output  [ 1:0]  prog_mask,
    output  [ 1:0]  prog_ba,
    output          prog_we,
    output          prog_rd,
    input           prog_ack,
    input           prog_dok,
    input           prog_dst,
    input           prog_rdy,
    // DIP switches
    input   [31:0]  status,
    input   [31:0]  dipsw,
    input           service,
    input           dip_pause,
    input           dip_flip,
    input           dip_test,
    input   [ 1:0]  dip_fxlevel, // Not a DIP on the original PCB
    // Sound output
    output  signed [15:0] snd,
    output          sample,
    output          game_led,
    input           enable_psg,
    input           enable_fm,
    // Debug
    input   [3:0]   gfx_en
    // input   [7:0]   debug_bus,
    // status dump
    // input   [ 7:0]  st_addr,
    // output reg [ 7:0]  st_dout
);


// clock enable signals
wire    cpu_cen, cpu_cenb,
        cen_fm,  cen_fm2, cen_snd,
        cen_pcm, cen_pcmb;

// video signals
wire        HB, VB, LVBL;
wire [ 8:0] vrender;
wire        hstart, vint;
wire        colscr_en, rowscr_en;

// SDRAM interface
wire        main_cs, vram_cs, ram_cs;
wire [18:1] main_addr;
wire [15:0] main_data, ram_data;
wire        main_ok, ram_ok;

wire        char_ok;
wire [12:0] char_addr;
wire [31:0] char_data;

wire        scr0_ok, scr1_ok, scr2_ok;
wire [16:0] scr0_addr, scr1_addr, scr2_addr;
wire [31:0] scr0_data, scr1_data, scr2_data;

wire        obj_ok, obj_cs;
wire [19:0] obj_addr;
wire [15:0] obj_data;

// CPU interface
wire [12:1] cpu_addr;
wire [15:0] main_dout, char_dout, pal_dout, obj_dout;
wire [ 1:0] dsn;
wire        UDSWn, LDSWn, main_rnw;
wire        char_cs, scr1_cs, pal_cs, objram_cs;

// Sound CPU
wire [15:0] snd_addr;
wire [ 7:0] snd_data;
wire        snd_cs, snd_ok;

wire [ 7:0] snd_latch;
wire        snd_irqn;

// PCM
wire [17:0] adpcm_addr;
wire        adpcm_cs;
wire [ 7:0] adpcm_data;
wire        adpcm_ok;

wire        flip, video_en, sound_en;

// Cabinet inputs
wire [ 7:0] dipsw_a, dipsw_b;
//wire [ 7:0] game_id;

// Status report
wire [7:0] st_video, st_main;

assign { dipsw_b, dipsw_a } = dipsw[15:0];
assign dsn = { UDSWn, LDSWn };


`ifndef NOMAIN
jtcop_main u_main(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .clk_rom    ( clk       ),  // same clock - at least for now
    .cpu_cen    ( cpu_cen   ),
    .cpu_cenb   ( cpu_cenb  ),
//    .game_id    ( game_id   ),
    // Video
    .vint       ( vint      ),
    .video_en   ( video_en  ),
    // Video circuitry
    .vram_cs    ( vram_cs   ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal_dout  ),
    .obj_dout   ( obj_dout  ),

    .flip       ( flip      ),
    .colscr_en  ( colscr_en ),
    .rowscr_en  ( rowscr_en ),
    // RAM access
    .ram_cs     ( ram_cs    ),
    .ram_data   ( ram_data  ),
    .ram_ok     ( ram_ok    ),
    // CPU bus
    .cpu_dout   ( main_dout ),
    .UDSWn      ( UDSWn     ),
    .LDSWn      ( LDSWn     ),
    .RnW        ( main_rnw  ),
    .cpu_addr   ( cpu_addr  ),
    // cabinet I/O
    .joystick1   ( joystick1  ),
    .joystick2   ( joystick2  ),
    .start_button(start_button),
    .coin_input  ( coin_input ),
    .service     ( service    ),
    // ROM access
    .rom_cs      ( main_cs    ),
    .rom_addr    ( main_addr  ),
    .rom_data    ( main_data  ),
    .rom_ok      ( main_ok    ),
    // Sound communication
    .snd_latch   ( snd_latch  ),
    .snd_irqn    ( snd_irqn   ),
    // DIP switches
    .dip_pause   ( dip_pause  ),
    .dip_test    ( dip_test   ),
    .dipsw_a     ( dipsw_a    ),
    .dipsw_b     ( dipsw_b    )
    // Status report
    //.debug_bus   ( debug_bus  ),
    //.st_addr     ( st_addr    ),
    //.st_dout     ( st_main    )
);
`else
    assign flip      = 0;
    assign main_cs   = 0;
    assign ram_cs    = 0;
    assign vram_cs   = 0;
    assign UDSWn     = 1;
    assign LDSWn     = 1;
    assign main_rnw  = 1;
    assign main_dout = 0;
    assign video_en  = 1;
    assign sound_en  = 0; // active low (?)
    `ifdef S16B
        reg aux_obf = 0;
        reg [7:0] aux_dout=0;
        assign sndmap_dout = aux_dout;
        assign sndmap_pbf  = aux_obf;
        integer framecnt=0, last_fcnt=0;

        always @(negedge LVBL) begin
            framecnt <= framecnt+1;
        end
        always @(negedge LHBL_dly) begin
            last_fcnt <= framecnt;
            aux_obf <= last_fcnt != framecnt && (framecnt==10
                || framecnt==12
                // || framecnt==32
                // || framecnt==72
                // || framecnt==112
            );
            if( framecnt == 11 ) aux_dout <= 8'h4b; //8'h48 Ok; 4c
            //if( framecnt == 31 ) aux_dout <= 8'h42;
            //if( framecnt == 71 ) aux_dout <= 8'h41;
            //if( framecnt ==111 ) aux_dout <= 8'h40;
        end
    `endif
    `ifdef SIMULATION
        reg [7:0] sim_def[0:1];

        initial begin
            $readmemh("tilebank.hex",sim_def);
            $display("Tile bank set to %X",sim_def[0]);
        end
        assign tile_bank = sim_def[0][5:0];
    `endif
`endif

jtcop_video u_video(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .pxl2_cen   ( pxl2_cen  ),
    .pxl_cen    ( pxl_cen   ),
    .gfx_en     ( gfx_en    ),

    .video_en   ( video_en  ),
//    .game_id    ( game_id   ),
    // CPU interface
    .cpu_addr   ( cpu_addr  ),
    .char_cs    ( char_cs   ),
    .pal_cs     ( pal_cs    ),
    .objram_cs  ( objram_cs ),
    .vint       ( vint      ),

    .cpu_dout   ( main_dout ),
    .dsn        ( dsn       ),
    .char_dout  ( char_dout ),
    .pal_dout   ( pal_dout  ),
    .obj_dout   ( obj_dout  ),

    .flip       ( flip      ),
    .ext_flip   ( dip_flip  ),

    // SDRAM interface
    .scr0_ok    ( scr0_ok   ),
    .scr0_addr  ( scr0_addr ),
    .scr0_data  ( scr0_data ),

    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),

    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),

    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Video signal
    .HS         ( HS        ),
    .VS         ( VS        ),
    .HB         ( HB        ),
    .VB         ( VB        ),
    .LVBL       ( LVBL      ),
    .LHBL_dly   ( LHBL_dly  ),
    .LVBL_dly   ( LVBL_dly  ),
    .red        ( red       ),
    .green      ( green     ),
    .blue       ( blue      )
    // debug
    //.debug_bus  ( debug_bus ),
    //.st_addr    ( st_addr   ),
    //.st_dout    ( st_video  )
);

`ifndef NOSOUND
    jtcop_snd u_snd(
        .rst        ( rst       ),
        .clk        ( clk       ),

        // From main CPU
        .snreq      ( snd_irqn  ),
        .latch      ( snd_latch ),

        // ROM
        .rom_addr   ( snd_addr  ),
        .rom_cs     ( snd_cs    ),
        .rom_data   ( snd_data  ),
        .rom_ok     ( snd_ok    ),

        // ADPCM ROM
        .adpcm_addr ( adpcm_addr),
        .adpcm_cs   ( adpcm_cs  ),
        .adpcm_data ( adpcm_data),
        .adpcm_ok   ( adpcm_ok  ),

        .snd        ( snd       ),
        .sample     ( sample    ),
        .peak       ( peak      )
    );
`else
    assign snd_cs = 0;
    assign adpcm_cs = 0;
    assign snd = 0;
`endif

jtcop_sdram u_sdram(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .ioctl_ram  ( ioctl_ram ),

    .vrender    ( vrender   ),
    .LVBL       ( LVBL      ),
//    .game_id    ( game_id   ),

    // i8751 MCU / Sub CPU
    .mcu_we     ( mcu_we    ),
    .mcu_en     ( mcu_en    ),

    // Main CPU
    .main_cs    ( main_cs   ),
    .ram_cs     ( ram_cs    ),

    .main_addr  ( main_addr ),
    .main_data  ( main_data ),
    .ram_data   ( ram_data  ),

    .main_ok    ( main_ok   ),
    .ram_ok     ( ram_ok    ),

    .dsn        ( dsn       ),
    .main_dout  ( main_dout ),
    .main_rnw   ( main_rnw  ),

    // Sound CPU
    .snd_addr   ( snd_addr  ),
    .snd_cs     ( snd_cs    ),
    .snd_data   ( snd_data  ),
    .snd_ok     ( snd_ok    ),

    // ADPCM ROM
    .adpcm_addr (adpcm_addr ),
    .adpcm_cs   (adpcm_cs   ),
    .adpcm_data (adpcm_data ),
    .adpcm_ok   (adpcm_ok   ),

    // BG 0
    .scr0_ok    ( scr0_ok   ),
    .scr0_addr  ( scr0_addr ),
    .scr0_data  ( scr0_data ),

    // BG 1
    .scr1_ok    ( scr1_ok   ),
    .scr1_addr  ( scr1_addr ),
    .scr1_data  ( scr1_data ),

    // BG 2
    .scr2_ok    ( scr2_ok   ),
    .scr2_addr  ( scr2_addr ),
    .scr2_data  ( scr2_data ),

    // Sprite interface
    .obj_ok     ( obj_ok    ),
    .obj_cs     ( obj_cs    ),
    .obj_addr   ( obj_addr  ),
    .obj_data   ( obj_data  ),

    // Bank 0: allows R/W
    .ba0_addr    ( ba0_addr      ),
    .ba1_addr    ( ba1_addr      ),
    .ba2_addr    ( ba2_addr      ),
    .ba3_addr    ( ba3_addr      ),
    .ba_rd       ( ba_rd         ),
    .ba_wr       ( ba_wr         ),
    .ba_ack      ( ba_ack        ),
    .ba_dst      ( ba_dst        ),
    .ba_dok      ( ba_dok        ),
    .ba_rdy      ( ba_rdy        ),
    .ba0_din     ( ba0_din       ),
    .ba0_din_m   ( ba0_din_m     ),

    .data_read   ( data_read     ),

    // ROM load
    .downloading ( downloading   ),
    .dwnld_busy  ( dwnld_busy    ),

    .ioctl_addr ( ioctl_addr ),
    .ioctl_dout ( ioctl_dout ),
    .ioctl_wr   ( ioctl_wr   ),
    .prog_addr  ( prog_addr  ),
    .prog_data  ( prog_data  ),
    .prog_mask  ( prog_mask  ),
    .prog_ba    ( prog_ba    ),
    .prog_we    ( prog_we    ),
    .prog_rd    ( prog_rd    ),
    .prog_ack   ( prog_ack   ),
    .prog_rdy   ( prog_rdy   )
);

endmodule
