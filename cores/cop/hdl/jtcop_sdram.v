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

module jtcop_sdram(
    input           rst,
    input           clk,

    // Main CPU

    input            main_cs,
    input     [18:1] main_addr,
    output    [15:0] main_data,
    output           main_ok,

    input            ram_cs,
    output           ram_ok,
    output    [15:0] ram_data,

    input     [ 1:0] dsn,
    input     [15:0] main_dout,
    input            main_rnw,

    // Video RAM
    input            fsft_cs,
    input            fmap_cs,
    input            bsft_cs,
    input            bmap_cs,
    input            csft_cs,
    input            cmap_cs,

    // ROM banks
    input     [ 2:1] sndflag,
    input     [ 2:1] b1flg,
    input     [ 2:1] mixflg,
    input     [ 2:0] crback,
    input            b0flg,
    input            sndbank,

    // PROM
    output           mcu_we,
    output           prio_we,

    // Sound CPU
    input            snd_cs,
    output           snd_ok,
    input     [15:0] snd_addr,
    output    [ 7:0] snd_data,

    // ADPCM ROM
    input     [17:0] adpcm_addr,
    input            adpcm_cs,
    output    [ 7:0] adpcm_data,
    output           adpcm_ok,

    // Scroll B0 - RAM
    input            b0ram_cs,
    input     [12:0] b0ram_addr,
    output    [15:0] b0ram_data,
    output           b0ram_ok,
    //        B0 - ROM
    output           b0rom_ok,
    input    [16:0]  b0rom_addr,
    input            b0rom_cs,
    output   [31:0]  b0rom_data,

    // Scroll B1 - RAM
    input            b1ram_cs,
    input     [10:0] b1ram_addr,
    output    [15:0] b1ram_data,
    output           b1ram_ok,
    //        B1 - ROM
    output           b1rom_ok,
    input    [16:0]  b1rom_addr,
    input            b1rom_cs,
    output   [31:0]  b1rom_data,

    // Scroll B2 - RAM
    input            b2ram_cs,
    input     [10:0] b2ram_addr,
    output    [15:0] b2ram_data,
    output           b2ram_ok,
    //        B2 - ROM
    output           b2rom_ok,
    input    [16:0]  b2rom_addr,
    input            b2rom_cs,
    output   [31:0]  b2rom_data,

    // Obj
    output           obj_ok,
    input            obj_cs,
    input    [13:0]  obj_addr,
    output   [31:0]  obj_data,

    // Bank 0: allows R/W
    output    [21:0] ba0_addr,
    output    [21:0] ba1_addr,
    output    [21:0] ba2_addr,
    output    [21:0] ba3_addr,
    output    [ 3:0] ba_rd,
    output           ba_wr,
    output    [15:0] ba0_din,
    output    [ 1:0] ba0_din_m,  // write mask
    input     [ 3:0] ba_ack,
    input     [ 3:0] ba_dst,
    input     [ 3:0] ba_dok,
    input     [ 3:0] ba_rdy,

    input     [15:0] data_read,

    // ROM LOAD
    input            downloading,
    output           dwnld_busy,

    input    [24:0]  ioctl_addr,
    input    [ 7:0]  ioctl_dout,
    input            ioctl_wr,
    output reg [21:0] prog_addr,
    output   [15:0]  prog_data,
    output   [ 1:0]  prog_mask,
    output   [ 1:0]  prog_ba,
    output           prog_we,
    output           prog_rd,
    input            prog_ack,
    input            prog_rdy
);

parameter BANKS=0;

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START   = `BA1_START,
                  MCU_START   = `MCU_START,
                  MCU_END     = MCU_START + 25'h1000,
                  BA2_START   = `BA2_START,
                  GFX2_START  = `GFX2_START,
                  GFX3_START  = `GFX3_START,
                  BA3_START   = `BA3_START,
                  PROM_START  = `PROM_START,
                  PRIO_START  = PROM_START+25'h200,
                  PRIO_END    = PRIO_START+25'h200;

localparam [21:0] RAM_OFFSET  = 22'h10_0000,
                  B0_OFFSET   = 22'h10_2000,
                  B1_OFFSET   = 22'h10_4000,
                  B2_OFFSET   = 22'h10_6000,
                  PCM_OFFSET  = (`PCM_START-BA1_START)>>1,
                  ZERO_OFFSET = 0,
                  GFX2_OFFSET = 22'h10_0000,
                  GFX3_OFFSET = 22'h20_0000,
                  GFX1_LEN    = 22'h1_0000,
                  GFX2_LEN    = 22'h4_0000,
                  GFX3_LEN    = 22'h2_0000;

wire        prom_we, is_gfx1, is_gfx2, is_gfx3;
wire [21:0] pre_prog, gfx2_offset, gfx3_offset;

assign mcu_we  = prom_we && pre_prog >= MCU_START  && pre_prog < MCU_END;
// priority PROM is meant to be the second one in the MRA file
assign prio_we = prom_we && pre_prog >= PRIO_START && pre_prog < PRIO_END;
assign is_gfx1 = prog_ba==2'd2 && pre_prog < GFX1_LEN;
assign is_gfx2 = prog_ba==2'd2 && pre_prog >= GFX1_LEN && gfx2_offset < GFX2_LEN;
assign is_gfx3 = prog_ba==2'd2 && !is_gfx1 && !is_gfx2;

// MSB bit moved to LSB position, so we get all four colour planes
// in a single 32-bit read
assign gfx2_offset = pre_prog - GFX1_LEN;
assign gfx3_offset = pre_prog - GFX1_LEN - GFX2_LEN;

always @* begin
    prog_addr = pre_prog;
    if( is_gfx1 ) begin
        prog_addr = { pre_prog[21:16], pre_prog[14:0], ~pre_prog[15] };
    end
    if( is_gfx2 ) begin
        prog_addr = { GFX2_OFFSET[21:18], gfx2_offset[16:0], gfx2_offset[17] };
    end
    if( is_gfx3 ) begin
        prog_addr = { GFX3_OFFSET[21:17], gfx3_offset[15:0], gfx3_offset[16] };
    end
end


`ifdef JTFRAME_DWNLD_PROM_ONLY
    assign dwnld_busy = downloading | prom_we; // keep the game in reset while
        // the short PROM download occurs
`else
    assign dwnld_busy = downloading;
`endif

jtframe_dwnld #(
    .BA1_START ( BA1_START ), // sound
    .BA2_START ( BA2_START ), // tiles
    .BA3_START ( BA3_START ), // obj
    .PROM_START( MCU_START ), // MCU
    .SWAB      ( 1         )
) u_dwnld(
    .clk          ( clk            ),
    .downloading  ( downloading    ),
    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .prog_addr    ( pre_prog       ),
    .prog_data    ( prog_data      ),
    .prog_mask    ( prog_mask      ), // active low
    .prog_we      ( prog_we        ),
    .prog_rd      ( prog_rd        ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( prom_we        ),
    .header       (                ),
    .sdram_ack    ( prog_ack       )
);

// Sound
// adpcm_addr[16] is used as an /OE signal on the board
// I'm ignoring that connection here as it isn't relevant
wire [15:0] adpcm_eff;
wire [15:0] snd_eff;

assign adpcm_eff = { adpcm_addr[15] | sndflag[2], adpcm_addr[14:0] };
`ifdef MCU
assign snd_eff = BANKS ? { sndflag[1] | snd_addr[15],
                           (sndbank | snd_addr[15]) & snd_addr[14],
                           snd_addr[13:0] } :
                        { 1'b0, snd_addr[14:0] };
`else
assign snd_eff = { 1'b0, snd_addr[14:0] };
`endif

// RAM size
// 16kB   M68000 exclusive use
// 16kB   B0
//  4kB   B1
//  4kB   B2
// 40kB   Total -> AW=15, DW=16

reg  [14:0] ram_maddr; // merged address

always @* begin
    ram_maddr = {2'b0, main_addr[13:1]};
    // first BAC06 (16kB)
    if( fsft_cs )
        ram_maddr[14:12] = 3'b010;
    else if( fmap_cs )
        ram_maddr[14:12] = 3'b011;
    // second BAC06 (4kB)
    else if( bsft_cs )
        ram_maddr[14:10] = 5'b1000_0;
    else if( bmap_cs )
        ram_maddr[14:10] = 5'b1000_1;
    // third BAC06 (4kB)
    else if( csft_cs )
        ram_maddr[14:10] = 5'b1100_0;
    else if( cmap_cs )
        ram_maddr[14:10] = 5'b1100_1;
end

jtframe_ram_5slots #(
    // VRAM/RAM
    .SLOT0_DW(16),
    .SLOT0_AW(15),  // 64 kB (only 40 used)

    // Game ROM
    .SLOT1_DW(16),
    .SLOT1_AW(18),  // 512kB temptative value

    // VRAM access by B0
    .SLOT2_DW(16),
    .SLOT2_AW(13),

    // VRAM access by B1
    .SLOT3_DW(16),
    .SLOT3_AW(11),

    // VRAM access by B2
    .SLOT4_DW(16),
    .SLOT4_AW(11)
) u_bank0(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .offset0    ( RAM_OFFSET),
    .offset1    (ZERO_OFFSET),
    .offset2    ( B0_OFFSET ),
    .offset3    ( B1_OFFSET ),
    .offset4    ( B2_OFFSET ),

    .slot0_addr ( ram_maddr ),
    .slot1_addr ( main_addr ),
    .slot2_addr ( b0ram_addr),
    .slot3_addr ( b1ram_addr),
    .slot4_addr ( b2ram_addr),

    //  output data
    .slot0_dout ( ram_data  ),
    .slot1_dout ( main_data ),
    .slot2_dout ( b0ram_data),
    .slot3_dout ( b1ram_data),
    .slot4_dout ( b2ram_data),

    .slot0_cs   ( ram_cs    ),
    .slot1_cs   ( main_cs   ),
    .slot2_cs   ( b0ram_cs  ),
    .slot3_cs   ( b1ram_cs  ),
    .slot4_cs   ( b2ram_cs  ),

    .slot0_wen  ( ~main_rnw ),
    .slot0_din  ( main_dout ),
    .slot0_wrmask( dsn      ),

    .slot1_clr  ( 1'b0      ),
    .slot2_clr  ( 1'b0      ),
    .slot3_clr  ( 1'b0      ),
    .slot4_clr  ( 1'b0      ),

    .slot0_ok   ( ram_ok    ),
    .slot1_ok   ( main_ok   ),
    .slot2_ok   ( b0ram_ok  ),
    .slot3_ok   ( b1ram_ok  ),
    .slot4_ok   ( b2ram_ok  ),

    // SDRAM controller interface
    .sdram_ack   ( ba_ack[0] ),
    .sdram_rd    ( ba_rd[0]  ),
    .sdram_wr    ( ba_wr     ),
    .sdram_addr  ( ba0_addr  ),
    .data_dst    ( ba_dst[0] ),
    .data_rdy    ( ba_rdy[0] ),
    .data_write  ( ba0_din   ),
    .sdram_wrmask( ba0_din_m ),
    .data_read   ( data_read )
);

// Bank 1: Sound

jtframe_rom_2slots #(
    .SLOT0_DW(   8),
    .SLOT0_AW(  16),

    .SLOT1_DW(   8),
    .SLOT1_AW(  16),

    .SLOT1_OFFSET( PCM_OFFSET )
) u_bank1(
    .rst        ( rst       ),
    .clk        ( clk       ),

    .slot0_addr ( snd_eff   ),
    .slot0_dout ( snd_data  ),
    .slot0_cs   ( snd_cs    ),
    .slot0_ok   ( snd_ok    ),

    .slot1_addr (adpcm_eff  ),
    .slot1_dout (adpcm_data ),
    .slot1_cs   (adpcm_cs   ),
    .slot1_ok   (adpcm_ok   ),

    // SDRAM controller interface
    .sdram_addr ( ba1_addr  ),
    .sdram_req  ( ba_rd[1]  ),
    .sdram_ack  ( ba_ack[1] ),
    .data_dst   ( ba_dst[1] ),
    .data_rdy   ( ba_rdy[1] ),
    .data_read  ( data_read )
);

// Bank 2: BAC06 chips

jtframe_rom_3slots #(
    .SLOT0_DW(  32),
    .SLOT0_AW(  17),

    .SLOT1_DW(  32),
    .SLOT1_AW(  17),

    .SLOT2_DW(  32),
    .SLOT2_AW(  17),

    .SLOT1_OFFSET( GFX2_OFFSET ),
    .SLOT2_OFFSET( GFX3_OFFSET )
) u_bank2(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( b0rom_addr ),
    .slot0_dout ( b0rom_data ),
    .slot0_cs   ( b0rom_cs   ),
    .slot0_ok   ( b0rom_ok   ),

    .slot1_addr ( b1rom_addr ),
    .slot1_dout ( b1rom_data ),
    .slot1_cs   ( b1rom_cs   ),
    .slot1_ok   ( b1rom_ok   ),

    .slot2_addr ( b2rom_addr ),
    .slot2_dout ( b2rom_data ),
    .slot2_cs   ( b2rom_cs   ),
    .slot2_ok   ( b2rom_ok   ),

    // SDRAM controller interface
    .sdram_addr ( ba2_addr   ),
    .sdram_req  ( ba_rd[2]   ),
    .sdram_ack  ( ba_ack[2]  ),
    .data_dst   ( ba_dst[2]  ),
    .data_rdy   ( ba_rdy[2]  ),
    .data_read  ( data_read  )
);

// Bank 3: objects

jtframe_rom_3slots #(
    .SLOT0_DW(  32),
    .SLOT0_AW(  14)
) u_bank3(
    .rst        ( rst        ),
    .clk        ( clk        ),

    .slot0_addr ( obj_addr   ),
    .slot0_dout ( obj_data   ),
    .slot0_cs   ( obj_cs     ),
    .slot0_ok   ( obj_ok     ),

    // SDRAM controller interface
    .sdram_addr ( ba3_addr   ),
    .sdram_req  ( ba_rd[3]   ),
    .sdram_ack  ( ba_ack[3]  ),
    .data_dst   ( ba_dst[3]  ),
    .data_rdy   ( ba_rdy[3]  ),
    .data_read  ( data_read  )
);

endmodule