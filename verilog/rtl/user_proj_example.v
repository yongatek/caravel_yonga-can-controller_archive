// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype none
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    wire [31:0] rdata; 
    wire [31:0] wdata;
    wire [BITS-1:0] count;

    wire valid;
    wire [3:0] wstrb;
    wire [31:0] la_write;

    // WB MI A
    assign valid = wbs_cyc_i && wbs_stb_i; 
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o = rdata;
    assign wdata = wbs_dat_i;

    // IRQ
    assign irq = 3'b000;    // Unused

    // IO
    assign io_out[`MPRJ_IO_PADS-1:5] = {(`MPRJ_IO_PADS-5){1'b0}};
    assign io_oeb[`MPRJ_IO_PADS-1:5] = {(`MPRJ_IO_PADS-5){1'b1}};

    wire rx_i;
    wire tx_o;
    wire bus_off_on;
    wire irq_on;
    wire clkout_o;

    assign rx_i = io_in[0];
    assign io_oeb[0] = 1'b0;

    assign io_out[1] = tx_o;
    assign io_oeb[1] = 1'b1;

    assign io_out[2] = bus_off_on;
    assign io_oeb[2] = 1'b1;

    assign io_out[3] = irq_on;
    assign io_oeb[3] = 1'b1;

    assign io_out[4] = clkout_o;
    assign io_oeb[4] = 1'b1;

    // LA
    assign la_data_out = {{(128){1'b0}}};
    // Assuming LA probes [63:32] are for controlling the count register  
    // assign la_write = ~la_oenb[63:32] & ~{BITS{valid}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    // assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    // assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    // counter #(
    //     .BITS(BITS)
    // ) counter(
    //     .clk(clk),
    //     .reset(rst),
    //     .ready(wbs_ack_o),
    //     .valid(valid),
    //     .rdata(rdata),
    //     .wdata(wbs_dat_i),
    //     .wstrb(wstrb),
    //     .la_write(la_write),
    //     .la_input(la_data_in[63:32]),
    //     .count(count)
    // );

    assign wbs_dat_o[31:24] = 24'h0;

    can_top inst_can_top(
        .wb_clk_i(wb_clk_i),
        .wb_rst_i(wb_rst_i),
        .wb_dat_i(wbs_dat_i[7:0]),
        .wb_dat_o(wbs_dat_o[7:0]),
        .wb_cyc_i(wbs_cyc_i),
        .wb_stb_i(wbs_stb_i),
        .wb_we_i(wbs_we_i),
        .wb_adr_i(wbs_adr_i[7:0]),
        .wb_ack_o(wbs_ack_o),

        .rx_i(rx_i),
        .tx_o(tx_o),
        .bus_off_on(bus_off_on),
        .irq_on(irq_on),
        .clkout_o(clkout_o)
    );

endmodule

module counter #(
    parameter BITS = 32
)(
    input clk,
    input reset,
    input valid,
    input [3:0] wstrb,
    input [BITS-1:0] wdata,
    input [BITS-1:0] la_write,
    input [BITS-1:0] la_input,
    output ready,
    output [BITS-1:0] rdata,
    output [BITS-1:0] count
);
    reg ready;
    reg [BITS-1:0] count;
    reg [BITS-1:0] rdata;

    always @(posedge clk) begin
        if (reset) begin
            count <= 0;
            ready <= 0;
        end else begin
            ready <= 1'b0;
            if (~|la_write) begin
                count <= count + 1;
            end
            if (valid && !ready) begin
                ready <= 1'b1;
                rdata <= count;
                if (wstrb[0]) count[7:0]   <= wdata[7:0];
                if (wstrb[1]) count[15:8]  <= wdata[15:8];
                if (wstrb[2]) count[23:16] <= wdata[23:16];
                if (wstrb[3]) count[31:24] <= wdata[31:24];
            end else if (|la_write) begin
                count <= la_write & la_input;
            end
        end
    end

endmodule
`default_nettype wire
