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

	input do_read,
	input do_write,
	input do_start_mcu,
	input do_stop_mcu,
	input do_delay,
	input do_echo_test,

	input [7:0] data_in,
	output [7:0] data_out,

	output ready,
	output reg valid,

	output [3:0] debug
);

reg [7:0] echo_data;

wire [31:0] sync_count;
wire sync_bkgd, sync_is_sending;
wire [4:0] sync_debug;
reg sync_start;
wire sync_ready;

wire startup_start;
reg startup_stop;
wire startup_is_sending, startup_ready;

wire bdc_is_sending, bdc_ready;
wire [7:0] bdc_data_out;
wire bdc_read_data, bdc_send_data;
wire [7:0] bdc_data_in;

wire hold_commands_in_reset;
assign hold_commands_in_reset = 1'd0; // TODO: Remove
//reg is_booting_mcu, is_syncing_mcu, is_running_mcu;
wire bdc_clk_pulse;

// Idle could be either MCU on or MCU off
`define STATE_IDLE 0
`define STATE_BOOTING 1
`define STATE_SYNCING 2
`define STATE_READING 3
`define STATE_WRITING 4
`define STATE_ECHO_TEST 5
`define STATE_DELAYING 6

reg [3:0] state;

reg [7:0] delay_counter;

assign debug = state;

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
	.rst(rst || hold_commands_in_reset),
	.bkgd(sync_bkgd),
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

// Bootup state machine

//assign hold_commands_in_reset = !is_booting_mcu && !is_syncing_mcu && !is_running_mcu;

/*assign mcu_pwr =
	is_booting_mcu ? startup_mcu_pwr :
	is_syncing_mcu ? 1 :
	is_running_mcu ? 1 :
	0;*/
	
assign bkgd_out = 1'd0;

assign bkgd_is_high_z =
	(state == `STATE_BOOTING && startup_is_sending) ? 1'd0 :
	(state == `STATE_SYNCING && sync_is_sending) ? 1'd0 :
	(state == `STATE_READING && bdc_is_sending) ? 1'd0 :
	(state == `STATE_WRITING && bdc_is_sending) ? 1'd0 :
	//(is_running_mcu && bdc_is_sending) ? 1'd0 :
	1'd1;

// Start the MCU if we receive an "s" and we aren't currently running
//assign startup_start = trigger && !is_running_mcu;
//assign sync_start = is_booting_mcu && startup_ready;

//reg is_reading_status;

assign startup_start = state == `STATE_IDLE && do_start_mcu;
assign bdc_read_data = state == `STATE_IDLE && do_read;
assign bdc_send_data = state == `STATE_IDLE && do_write;
assign bdc_data_in = data_in;
assign data_out = state == `STATE_ECHO_TEST ? echo_data : bdc_data_out;

assign ready = state == `STATE_IDLE && !do_start_mcu && !do_stop_mcu && !do_read && !do_write && !do_delay && !do_echo_test;

always @(posedge clk) begin
	// These registers are strobes
	//startup_start <= 0;
	startup_stop <= 0;
	sync_start <= 0;
	//bdc_send_data <= 0;
	//bdc_read_data <= 0;
	set_bdc_pulse_gen <= 0;
	valid <= 0;

	if (rst) begin
		/*is_booting_mcu <= 0;
		is_syncing_mcu <= 0;
		is_running_mcu <= 0;*/
		state <= `STATE_IDLE;
		//ready <= 1;
	end else if (state == `STATE_IDLE) begin
		if (do_start_mcu) begin
			//is_booting_mcu <= 1;
			state <= `STATE_BOOTING;
			//startup_start <= 1;
			//ready <= 0;
		end else if (do_stop_mcu) begin
			// Stopping is instantaneous, if that ever changes we need to create a state for it (and fiddle ready)
			startup_stop <= 1;
		end else if (do_read) begin
			state <= `STATE_READING;
			//ready <= 0;
		end else if (do_write) begin
			state <= `STATE_WRITING;
			//ready <= 0;
		end else if (do_delay) begin
			state <= `STATE_DELAYING;
			delay_counter <= {data_in, 4'd0};
		end else if (do_echo_test) begin
			state <= `STATE_ECHO_TEST;
			echo_data <= data_in;
			valid <= 1;
		end
	end else if (state == `STATE_BOOTING) begin
		if (startup_ready) begin
			//is_booting_mcu <= 0;
			//is_syncing_mcu <= 1;
			state <= `STATE_SYNCING;
			sync_start <= 1;
		end
	end else if (state == `STATE_SYNCING) begin //is_syncing_mcu && (sync_ready || trigger)) begin
		if (sync_ready) begin
			//is_syncing_mcu <= 0;
			//is_running_mcu <= 1;
			set_bdc_pulse_gen <= 1;
			state <= `STATE_IDLE;
			//ready <= 1;
		end
	end else if (state == `STATE_READING) begin
		if (bdc_ready) begin
			state <= `STATE_IDLE;
			//ready <= 1;
			valid <= 1;
		end
	end else if (state == `STATE_WRITING) begin
		if (bdc_ready) begin
			state <= `STATE_IDLE;
			//ready <= 1;
		end
	end else if (state == `STATE_DELAYING) begin
		if (delay_counter == 0) begin
			state <= `STATE_IDLE;
		end else begin
			delay_counter <= delay_counter - 1;
		end
	end else if (state == `STATE_ECHO_TEST) begin
		state <= `STATE_IDLE;
	//end else if (do_stop_mcu) begin
		// Shutdown!
		//is_running_mcu <= 0;
	/*end else if (is_running_mcu) begin
		// Run the read_status state machine
		if (is_reading_status) begin
			// Waiting for the SS to reply
			if (bdc_ready) begin
				is_reading_status <= 0;
				bdc_data_in <= 8'he4;
				bdc_send_data <= 1;
			end
		end else begin
			// Waiting for the E4 to end
			if (bdc_ready) begin
				is_reading_status <= 1;
				bdc_read_data <= 1;
			end
		end*/
	end
end

endmodule