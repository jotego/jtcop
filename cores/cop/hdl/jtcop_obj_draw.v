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
    Date: 4-10-2021 */

module jtcop_obj_draw(
    input              rst,
    input              clk,
    input              pxl_cen,
    input              LHBL,

    output     [ 7:0]  hdump,

    // Object engine
    output     [ 9:0]  tbl_addr,
    input      [15:0]  tbl_dout,

    // ROM interface
    output reg         rom_cs,
    output reg [16:0]  rom_addr,
    input      [31:0]  rom_data,
    input              rom_ok,    

    output     [ 7:0]  pxl
);

reg  [7:0] buf_pxl;
reg  [8:0] buf_addr;

// Draw the tile
reg  [31:0] draw_data;
wire [ 3:0] draw_pxl;
reg  [ 3:0] draw_cnt;
reg         half;

assign draw_pxl  = hflip ? { draw_data[23], draw_data[31], draw_data[7], draw_data[15] } :
                           { draw_data[16], draw_data[24], draw_data[0], draw_data[ 8] };
assign buf_wdata = { tile_pal, draw_pxl };

always @(posedge clk, posedge rst) begin
    if( rst ) begin
        draw_busy <= 0;
        draw_cnt  <= 0;
        buf_waddr <= 0;
        rom_good  <= 0;
        buf_we    <= 0;
        rom_cs    <= 0;
        half      <= 0;
        get_hsub  <= 0;
    end else begin
        rom_good <= rom_ok;
        if( HSl && !HS ) get_hsub <= 1;
        if( draw ) begin
            draw_busy <= 1;
            half      <= 0;
            if( tile16_en )
                rom_addr <= { tile_id[10:0], 1'b1, veff[3:0], 1'b0 };
            else
                rom_addr <= { 2'd0, tile_id[10:0], veff[2:0], 1'b0 };
            draw_cnt <= 0;
            rom_cs   <= 1;
            rom_good <= 0;
            get_hsub <= 0;
            if( get_hsub ) begin // subtile scroll adjustment on first tile drawn
                if(tile16_en)
                    buf_waddr <= 9'd0 - {5'd0,hn[3:0]};
                else
                    buf_waddr <= 9'd0 - {6'd0,hn[2:0]};
            end
        end
        if( !buf_we && rom_cs && rom_good && rom_ok && draw_cnt==0 ) begin
            draw_data <= rom_data;
            rom_cs    <= 0;
            buf_we    <= 1;
            draw_cnt  <= 7;
        end
        if( buf_we ) begin
            draw_data <= hflip ? draw_data<<1 : draw_data>>1;
            draw_cnt <= draw_cnt-1'd1;
            buf_waddr<= buf_waddr+9'd1;
            if( draw_cnt==0 ) begin
                buf_we    <= 0;
                if( !tile16_en || half) begin
                    draw_busy <= 0;
                    rom_cs    <= 0;
                end else begin // second half of 16-pxl tile
                    rom_addr[5] <= ~rom_addr[5];
                    rom_cs      <= 1;
                    rom_good    <= 0;
                    half        <= 1;
                    draw_cnt    <= 0;
                end
            end
        end
    end
end

jtframe_obj_buffer #(.ALPHA  ( 4'H0  ))
u_buffer (
    .clk        ( clk       ),
    .LHBL       ( LHBL      ),
    // New data writes
    .wr_data    (           ),
    .wr_addr    (           ),
    .we         (           ),
    // Old data reads (and erases)
    .rd_addr    ({1'b0, hdump}),
    .rd         ( pxl_cen   ),
    .rd_data    ( pxl       )
);

endmodule 