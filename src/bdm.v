`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    15:49:09 03/25/2018 
// Design Name: 
// Module Name:    bdm 
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
module bdm(
	input clk,
	input rst,

	input bkgd_in,
	output bkgd_out,
	output bkgd_is_high_z,
	output mcu_pwr,
	output mcu_vpp,

	input do_read,
	input do_write,
	input do_start_mcu,
	input do_stop_mcu,
	input do_delay,
	input do_echo_test,
	input do_enable_vpp,
	input do_disable_vpp,
	input do_echo_sync_value,
	input do_resync,

	input [7:0] data_in,
	output [7:0] data_out,

	output ready,
	output reg valid,

	output [3:0] debug
);

reg [7:0] echo_data;

wire [31:0] sync_count;
wire sync_is_sending;
wire [4:0] sync_debug;
reg sync_start;
wire sync_ready;

wire startup_start;
reg startup_stop;
wire startup_is_sending, startup_ready;

wire bdc_is_sending, bdc_ready;
wire [7:0] bdc_data_out;
wire bdc_read_data, bdc_send_data;

wire hold_commands_in_reset;
assign hold_commands_in_reset = 1'd0; // TODO: Remove
wire bdc_clk_pulse;

// Idle could be either MCU on or MCU off
`define STATE_IDLE 0
`define STATE_BOOTING 1
`define STATE_SYNCING 2
`define STATE_READING 3
`define STATE_WRITING 4
`define STATE_ECHO_TEST 5
`define STATE_DELAYING 6
`define STATE_ECHO_SYNC 7
`define STATE_ECHO_SYNC_LO 8

reg [3:0] state;

reg [7:0] delay_counter;

// Startup controller
startup_controller startup_controller(
	.clk(clk),
	.rst(rst || hold_commands_in_reset),
	.start(startup_start),
	.stop(startup_stop),
	.mcu_pwr(mcu_pwr),
	.is_sending(startup_is_sending),
	.ready(startup_ready)
);

// SYNC state machine
sync_controller sync_controller(
	.clk(clk),
	.rst(rst || hold_commands_in_reset || do_stop_mcu || do_resync),
	.bkgd_in(bkgd_in),
	.is_sending(sync_is_sending),
	.start_sync(sync_start),
	.sync_length(sync_count),
	.sync_length_is_ready(),
	.ready(sync_ready),
	.debug(sync_debug)
);

// Generate the BDC clock pulses
reg set_bdc_pulse_gen;
bdc_clk_pulse_generator bdc_clk_pulse_generator(
	.clk(clk),
	.rst(rst || hold_commands_in_reset),
	.bdc_clk_pulse(bdc_clk_pulse),
	.sync_length(sync_count),
	.set_sync_length(set_bdc_pulse_gen)
);

// Module to talk the BDC protcol
bdc_interface bdc_interface(
	.clk(clk),
	.rst(rst || hold_commands_in_reset),
	.is_sending(bdc_is_sending),
	.bkgd_in(bkgd_in),
	.tgt_clk_pulse(bdc_clk_pulse),
	.data_in(data_in),
	.send_data(bdc_send_data),
	.data_out(bdc_data_out),
	.read_data(bdc_read_data),
	.ready(bdc_ready)
);

assign debug = sync_debug;//state;

// Bootup state machine

assign bkgd_out = 1'd0;

assign bkgd_is_high_z =
	(state == `STATE_BOOTING && startup_is_sending) ? 1'd0 :
	(state == `STATE_SYNCING && sync_is_sending) ? 1'd0 :
	(state == `STATE_READING && bdc_is_sending) ? 1'd0 :
	(state == `STATE_WRITING && bdc_is_sending) ? 1'd0 :
	1'd1;

assign startup_start = state == `STATE_IDLE && do_start_mcu;
assign bdc_read_data = state == `STATE_IDLE && do_read;
assign bdc_send_data = state == `STATE_IDLE && do_write;
assign data_out =
	state == `STATE_ECHO_TEST ? echo_data :
	state == `STATE_ECHO_SYNC ? sync_count[15:8] :
	state == `STATE_ECHO_SYNC_LO ? sync_count[7:0] :
	bdc_data_out;

assign ready = state == `STATE_IDLE && !do_start_mcu && !do_stop_mcu && !do_read && !do_write && !do_delay && !do_echo_test && !do_echo_sync_value && !do_resync;

reg vpp_enabled;

assign mcu_vpp = vpp_enabled;

always @(posedge clk) begin
	// These registers are strobes
	startup_stop <= 0;
	sync_start <= 0;
	set_bdc_pulse_gen <= 0;
	valid <= 0;

	if (rst) begin
		state <= `STATE_IDLE;
		vpp_enabled <= 0;
	end else if (state == `STATE_IDLE) begin
		if (do_start_mcu) begin
			state <= `STATE_BOOTING;
		end else if (do_stop_mcu) begin
			// Stopping is instantaneous, if that ever changes we need to create a state for it (and fiddle ready)
			startup_stop <= 1;
		end else if (do_read) begin
			state <= `STATE_READING;
		end else if (do_write) begin
			state <= `STATE_WRITING;
		end else if (do_delay) begin
			state <= `STATE_DELAYING;
			delay_counter <= {data_in, 4'd0};
		end else if (do_echo_test) begin
			state <= `STATE_ECHO_TEST;
			echo_data <= data_in;
			valid <= 1;
		end else if (do_enable_vpp) begin
			vpp_enabled <= 1;
		end else if (do_disable_vpp) begin
			vpp_enabled <= 0;
		end else if (do_echo_sync_value) begin
			state <= `STATE_ECHO_SYNC;
			valid <= 1;
		end else if (do_resync) begin
			state <= `STATE_SYNCING;
			sync_start <= 1;
		end
	end else if (state == `STATE_BOOTING) begin
		if (startup_ready) begin
			state <= `STATE_SYNCING;
			sync_start <= 1;
		end
	end else if (state == `STATE_SYNCING) begin
		if (sync_ready) begin
			set_bdc_pulse_gen <= 1;
			state <= `STATE_IDLE;
		end
	end else if (state == `STATE_READING) begin
		if (bdc_ready) begin
			state <= `STATE_IDLE;
			valid <= 1;
		end
	end else if (state == `STATE_WRITING) begin
		if (bdc_ready) begin
			state <= `STATE_IDLE;
		end
	end else if (state == `STATE_DELAYING) begin
		if (delay_counter == 0) begin
			state <= `STATE_IDLE;
		end else begin
			delay_counter <= delay_counter - 1;
		end
	end else if (state == `STATE_ECHO_TEST) begin
		state <= `STATE_IDLE;
	end else if (state == `STATE_ECHO_SYNC) begin
		state <= `STATE_ECHO_SYNC_LO;
		valid <= 1;
	end else if (state == `STATE_ECHO_SYNC_LO) begin
		state <= `STATE_IDLE;
	end
end

endmodule
