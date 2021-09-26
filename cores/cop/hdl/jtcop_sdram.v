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
    input            vram_cs,
    input            ram_cs,
    input     [18:1] main_addr,
    output    [15:0] main_data,
    output    [15:0] ram_data,
    output           main_ok,
    output           ram_ok,
    input     [ 1:0] dsn,
    input     [15:0] main_dout,
    input            main_rnw,

    // PROM
    output           mcu_we,
    output           prio_we,

    // Sound CPU
    input            snd_cs,
    output           snd_ok,
    input     [15:0] snd_addr,
    output    [ 7:0] snd_data,

    // ADPCM ROM
    output  reg      dec_en,
    output  reg      dec_type,
    input     [16:0] pcm_addr,
    input            pcm_cs,
    output    [ 7:0] pcm_data,
    output           pcm_ok,

    // Scroll 0
    output           scr0_ok,
    input    [16:0]  scr0_addr, 
    output   [31:0]  scr0_data,    

    // Scroll 1
    output           scr1_ok,
    input    [16:0]  scr1_addr, 
    output   [31:0]  scr1_data,    

    // Scroll 2
    output           scr2_ok,
    input    [16:0]  scr2_addr, 
    output   [31:0]  scr2_data,        

    // Obj
    output           obj_ok,
    input            obj_cs,
    input    [19:0]  obj_addr,
    output   [15:0]  obj_data,

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
    output   [21:0]  prog_addr,
    output   [15:0]  prog_data,
    output   [ 1:0]  prog_mask,
    output   [ 1:0]  prog_ba,
    output           prog_we,
    output           prog_rd,
    input            prog_ack,
    input            prog_rdy
);

/* verilator lint_off WIDTH */
localparam [24:0] BA1_START   = `BA1_START,
                  MCU_START   = `MCU_START,
                  PCM_START   = `PCM_START,
                  BA2_START   = `BA2_START,
                  GFX2_START  = `GFX2_START,
                  GFX3_START  = `GFX3_START,
                  BA3_START   = `BA3_START,
                  PROM_START  = `PROM_START;

jtframe_dwnld #(
    .BA1_START ( BA1_START ), // sound
    .BA2_START ( BA2_START ), // tiles
    .BA3_START ( BA3_START ), // obj
    .PROM_START( MCU_PROM  ), // PCM MCU
    .SWAB      ( 1         )
) u_dwnld(
    .clk          ( clk            ),
    .downloading  ( downloading    ),
    .ioctl_addr   ( ioctl_addr     ),
    .ioctl_dout   ( ioctl_dout     ),
    .ioctl_wr     ( ioctl_wr       ),
    .prog_addr    ( prog_addr      ),
    .prog_data    ( prog_data      ),
    .prog_mask    ( prog_mask      ), // active low
    .prog_we      ( prog_we        ),
    .prog_rd      ( prog_rd        ),
    .prog_ba      ( prog_ba        ),
    .prom_we      ( prom_we        ),
    .header       (                ),
    .sdram_ack    ( prog_ack       )
);


endmodule