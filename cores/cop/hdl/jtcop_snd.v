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
    Date: 26-9-2021 */


module jtcop_snd(
    input                rst,
    input                clk,

    // From main CPU
    input                snreq,  // sound interrupt from main CPU
    input         [ 7:0] latch,

    // ROM
    output        [14:0] rom_addr,
    output    reg        rom_cs,
    input         [ 7:0] rom_data,
    input                rom_ok,

    // ADPCM ROM
    output        [17:0] adpcm_addr,
    output               adpcm_cs,
    input         [ 7:0] adpcm_data,
    input                adpcm_ok
);

wire        cen, cen_opl;
wire [15:0] cpu_addr;
wire [ 7:0] cpu_dout, opl_dout, opn_dout, ram_dout;
reg  [ 7:0] cpu_din, dev_mux;
reg         nmin, opl_cs, opn_cs, ram_cs,
            nmi_clr, oki_cs, dev_cs, cen_oki;
wire        irqn, ram_we, cpu_rnw, oki_wrn,
            oki_sample;
reg  [ 2:0] cen_sh=1;

wire signed [15:0] opl_snd, opn_snd;
wire signed [15:0] adpcm_snd;
wire signed [13:0] oki_pre;
wire        [ 9:0] psg_snd;

assign irqn   = opn_irqn & opl_irqn;
assign ram_we = ram_cs & ~cpu_rnw;
assign oki_wrn= ~(oki_cs & ~cpu_rnw);

always @(*) begin
    ram_cs  = 0;
    opn_cs  = 0;
    opl_cs  = 0;
    nmi_clr = 0;
    rom_cs  = cpu_addr[15];
    oki_cs  = 1;
    if(cpu_addr[15:14]==0) begin
        case( cpu_addr[13:11] )
            0: ram_cs  = 1;
            1: opn_cs  = 1;
            2: opl_cs  = 1;
            6: nmi_clr = cpu_rnw;
            7: oki_cs  = 1;
        endcase
    end
end

// 1 MHz clock enable
always @(posedge clk) begin
    if( cen_opl ) cen_sh <= { cen_sh[1:0], cen_sh[2] };
    cen_oki <= cen_sh[0] & cen_opl;
end

always @(posedge clk) begin
    dev_cs  <= opn_cs | opl_cs | oki_cs;
    dev_mux <= opn_cs  ? opn_dout :
               opl_cs  ? opl_dout : oki_dout;

    cpu_din <= rom_cs  ? rom_data :
               ram_cs  ? ram_dout :
               nmi_clr ? latch    :
               dev_cs  ? dev_mux :
               8'hff;
end

reg snreq_l;

always @(posedge clk) begin
    if( rst ) begin
        nmin    <= 1;
        snreq_l <= 0;
    end else begin
        snreq_l <= snreq;
        if( nmi_clr ) nmin <= 1;
        else if( snreq & ~snreq_l ) nmin <= 0;
    end
end

jtframe_cen48 u_cen(
    .clk    ( clk       ),
    .cen3   ( cen_opl   ),
    .cen1p5 ( cen       ),
    // unused
    .cen12(), .cen16(), .cen8(), .cen6(), .cen4(), .cen4_12(), 
    .cen3q(), .cen16b(), .cen12b(), .cen6b(), 
    .cen3b(), .cen3qb(), .cen1p5b()
);

MC6502 u_cpu(
    .rstn   ( ~rst      ),
    .clk    ( clk       ),
    .cen    ( cen       ),
    .i_rdy  ( rdy       ),
    .i_irqn ( irqn      ),
    .i_nmin ( nmin      ),
    .i_db   ( cpu_din   ),
    .o_db   ( cpu_dout  ),
    .o_sync (           ),
    .o_rw   ( cpu_rnw   ),
    .o_ab   ( cpu_addr  )
);

jtframe_ram #(.aw(10)) u_ram(
    .clk    ( clk           ),
    .cen    ( 1'b1          ),
    .data   ( cpu_din       ),
    .addr   ( cpu_addr[9:0] ),
    .we     ( ram_we        ),
    .q      ( ram_dout      )
);

jtopl u_opl(
    .rst    ( rst       ),   
    .clk    ( clk       ),   
    .cen    ( cen_opl   ),   
    .din    ( cpu_dout  ),
    .addr   (cpu_addr[0]),
    .cs_n   ( ~opl_cs   ),
    .wr_n   ( cpu_rnw   ),
    .dout   ( opl_dout  ),
    .irq_n  ( opl_irqn  ),
    .snd    ( opl_snd   ),
    .sample (           )
);

jt03 u_2203(
    .rst    ( rst       ),   
    .clk    ( clk       ),   
    .cen    ( cen       ),   
    .din    ( cpu_dout  ),
    .addr   (cpu_addr[0]),
    .cs_n   ( ~opn_cs   ),
    .wr_n   ( cpu_rnw   ),

    .dout   ( opn_dout  ),
    .irq_n  ( opn_irqn  ),
    // I/O pins used by YM2203 embedded YM2149 chip
    .IOA_in (           ),
    .IOB_in (           ),
    // 10 kOhm resistors
    .psg_A  (           ),
    .psg_B  (           ),
    .psg_C  (           ),
    .fm_snd ( opn_snd    ),
    .psg_snd( psg_snd   ),
    .snd    (           ),
    .snd_sample()
);

jt6295 #(.INTERPOL(1)) u_adpcm(
    .rst        ( rst       ),
    .clk        ( clk       ),
    .cen        ( cen_oki   ),  // 1MHz
    .ss         ( 1'b1      ),
    // CPU interface
    .wrn        ( oki_wrn   ),  // active low
    .din        ( cpu_dout  ),
    .dout       ( oki_dout  ),
    // ROM interface
    .rom_addr   ( adpcm_addr),
    .rom_data   ( adpcm_data),
    .rom_ok     ( adpcm_ok  ),
    // Sound output
    .sound      ( oki_pre   ),
    .sample     ( oki_sample)   // ~26kHz
);

jtframe_uprate2_fir u_fir1(
    .rst        ( rst            ),
    .clk        ( clk            ),
    .sample     ( oki_sample     ),
    .upsample   (                ), // ~52kHz, close to JT51's 55kHz
    .l_in       ({oki_pre,2'd0}  ),
    .r_in       (     16'd0      ),
    .l_out      ( adpcm_snd      ),
    .r_out      (                )
);

endmodule