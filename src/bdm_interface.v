`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:56:04 03/25/2018 
// Design Name: 
// Module Name:    bdm_interface 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module bdm_interface(
	input clk,
	input rst_in,
	input new_rx_data,
	input [7:0] rx_data,
	output new_tx_data,
	output [7:0] tx_data,
	input tx_block,
	inout bkgd,
	output mcu_pwr,
	output mcu_vpp,
	output [7:0] debug
);

reg [7:0] programmatic_rst;

wire rst;
assign rst = rst_in || (programmatic_rst != 0);

wire [9:0] cmdbuf_data_count;
wire [15:0] cmdbuf_din, cmdbuf_dout;
wire cmdbuf_wr_en, cmdbuf_rd_en, cmdbuf_full, cmdbuf_empty, cmdbuf_read_ack, cmdbuf_underflow, cmdbuf_valid;
fifo_16x1024 command_buffer(
	.clk(clk),
	.rst(rst),
	.din(cmdbuf_din),
	.wr_en(cmdbuf_wr_en),
	.rd_en(cmdbuf_rd_en),
	.dout(cmdbuf_dout),
	.full(cmdbuf_full),
	.empty(cmdbuf_empty),
	.valid(cmdbuf_read_ack),
	.underflow(cmdbuf_underflow),
	.data_count(cmdbuf_data_count)
);

assign cmdbuf_valid = cmdbuf_read_ack && !cmdbuf_underflow;

reg misfire_cache_full;

wire [7:0] reply_din, reply_dout;
wire reply_wr_en, reply_full, reply_empty, reply_read_ack, reply_underflow, reply_valid;
fifo_8x128 reply_buffer(
	.clk(clk),
	.rst(rst),
	.din(reply_din),
	.wr_en(reply_wr_en),
	.rd_en(!tx_block && !misfire_cache_full),
	.dout(reply_dout),
	.full(reply_full),
	.empty(reply_empty),
	.valid(reply_read_ack),
	.underflow(reply_underflow)
);

assign reply_valid = reply_read_ack && !reply_underflow;

// A one-byte cache for when we pop the FIFO but can't send
reg [7:0] misfire_cache;

always @(posedge clk) begin
	if (rst) begin
		misfire_cache_full <= 0;
		misfire_cache <= 0;
	end else if (reply_valid && tx_block) begin
		misfire_cache_full <= 1;
		misfire_cache <= reply_dout;
	end else if (new_tx_data) begin
		misfire_cache_full <= 0;
	end
end

// Send the fifo contents back over the serial as fast as possible
reg [7:0] bytes_left_to_read;
wire has_immediate_serial_command = new_rx_data && (rx_data == 2 || rx_data == 4 || rx_data == 5) && (bytes_left_to_read == 0);

assign new_tx_data = !tx_block && (misfire_cache_full || reply_valid || has_immediate_serial_command);
assign tx_data =
	misfire_cache_full ? misfire_cache :
	(has_immediate_serial_command && rx_data == 2) ? 8'd55 :
	(has_immediate_serial_command && rx_data == 4) ? cmdbuf_data_count[7:0] :
	(has_immediate_serial_command && rx_data == 5) ? {6'd0, cmdbuf_data_count[9:8]} :
	reply_dout;

// The serial frontend to the FIFOs

reg is_running;
reg [15:0] incoming_data;
reg has_half_incoming_data;
reg has_new_incoming_data;

assign cmdbuf_wr_en = has_new_incoming_data;
assign cmdbuf_din = incoming_data;

always @(posedge clk) begin
	has_new_incoming_data <= 0;
	
	programmatic_rst <= (programmatic_rst != 0) ? programmatic_rst - 1 : 8'd0;

	if (rst) begin
		bytes_left_to_read <= 0;
		is_running <= 0;
		incoming_data <= 0;
		has_half_incoming_data <= 0;
		programmatic_rst <= 0;
	end else if (new_rx_data) begin
		if (bytes_left_to_read > 0) begin
			incoming_data <= {incoming_data[7:0], rx_data};

			if (has_half_incoming_data) begin
				has_new_incoming_data <= 1;
				bytes_left_to_read <= bytes_left_to_read - 1;
			end
			has_half_incoming_data <= ~has_half_incoming_data;
		end else if (rx_data[7]) begin
			bytes_left_to_read <= rx_data[6:0];
		end else if (rx_data == 0) begin
			is_running <= 0;
		end else if (rx_data == 1) begin
			is_running <= 1;
		end else if (rx_data == 2) begin
			// Serial comms test
		end else if (rx_data == 3) begin
			programmatic_rst <= 8'hff;
		end else if (rx_data == 4) begin
			// Retrieve command fifo size (low byte)
		end else if (rx_data == 5) begin
			// Retrieve command fifo size (high byte)
		end
	end
end


// The BDM code

`define BDM_CMD_NONE 0
`define BDM_CMD_READ 1
`define BDM_CMD_WRITE 2
`define BDM_CMD_START_MCU 3
`define BDM_CMD_STOP_MCU 4
`define BDM_CMD_ECHO_TEST 5
`define BDM_CMD_DELAY 6
`define BDM_CMD_ENABLE_VPP 7
`define BDM_CMD_DISABLE_VPP 8
`define BDM_CMD_ECHO_SYNC_VALUE 9
`define BDM_CMD_RESYNC 10

wire [3:0] bdm_cmd;
wire [7:0] bdm_data_in, bdm_data_out;

wire bdm_bkgd, bdm_bkgd_is_high_z, bdm_ready, bdm_valid;
wire [3:0] bdm_debug;

assign bkgd = bdm_bkgd_is_high_z ? 1'dz : bdm_bkgd;

bdm bdm(
	.clk(clk),
	.rst(rst),
	
	.bkgd_in(bkgd),
	.bkgd_out(bdm_bkgd),
	.bkgd_is_high_z(bdm_bkgd_is_high_z),
	.mcu_pwr(mcu_pwr),
	.mcu_vpp(mcu_vpp),
	
	.do_read(bdm_cmd == `BDM_CMD_READ),
	.do_write(bdm_cmd == `BDM_CMD_WRITE),
	.do_start_mcu(bdm_cmd == `BDM_CMD_START_MCU),
	.do_stop_mcu(bdm_cmd == `BDM_CMD_STOP_MCU),
	.do_delay(bdm_cmd == `BDM_CMD_DELAY),
	.do_echo_test(bdm_cmd == `BDM_CMD_ECHO_TEST),
	.do_enable_vpp(bdm_cmd == `BDM_CMD_ENABLE_VPP),
	.do_disable_vpp(bdm_cmd == `BDM_CMD_DISABLE_VPP),
	.do_echo_sync_value(bdm_cmd == `BDM_CMD_ECHO_SYNC_VALUE),
	.do_resync(bdm_cmd == `BDM_CMD_RESYNC),
	
	.data_in(bdm_data_in),
	.data_out(bdm_data_out),
	
	.ready(bdm_ready),
	.valid(bdm_valid),
	
	.debug(bdm_debug)
);

assign debug = bdm_debug;

assign cmdbuf_rd_en = is_running && bdm_ready;

assign bdm_cmd =
	(!is_running || !cmdbuf_valid) ? `BDM_CMD_NONE :
	cmdbuf_dout[12:8];
assign bdm_data_in = cmdbuf_dout[7:0];

assign reply_din = bdm_data_out;
assign reply_wr_en = bdm_valid;

endmodule
