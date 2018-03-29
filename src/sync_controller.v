`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    18:45:39 03/20/2018 
// Design Name: 
// Module Name:    sync_controller 
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
module sync_controller(
	input clk,
	input rst,
	input bkgd_in,
	output is_sending,
	input start_sync,
	output [31:0] sync_length,
	output sync_length_is_ready,
	output reg ready,
	
	output [4:0] debug
);

parameter HIGHTIME = 32'd6500; // 6500 works! 2000 min

`define STATE_IDLE 0
`define STATE_SENDING_SYNC 1
`define STATE_WAITING_FOR_SETTLE 2
`define STATE_WAITING_FOR_PULL_LOW 3
`define STATE_COUNTING_SYNC 4

reg [2:0] state;

reg [31:0] sync_count;

assign debug = {2'd0, state};

assign is_sending = state == `STATE_SENDING_SYNC;
assign sync_length = sync_count;
assign sync_length_is_ready = (state != `STATE_SENDING_SYNC) && (state != `STATE_COUNTING_SYNC);

always @(posedge clk) begin
	sync_count <= sync_count;

	if (rst) begin
		state <= `STATE_IDLE;
		sync_count <= HIGHTIME; // The start sync pulse will be as long as possible
		ready <= 0;
	end else if (start_sync) begin
		state <= `STATE_SENDING_SYNC;
		sync_count <= HIGHTIME;
		ready <= 0;
	end else if (state == `STATE_SENDING_SYNC) begin
		// We're currently holding the bkgd line low for at least 128 cycles
		if (sync_count == 0) begin
			state <= `STATE_WAITING_FOR_SETTLE;
			sync_count <= 8'h0f;
		end else begin
			sync_count <= sync_count - 1;
		end
	end else if (state == `STATE_WAITING_FOR_SETTLE) begin
		// We're waiting for the bkgd line to settle high and then be pulled low by the target
		if (sync_count == 0) begin
			state <= `STATE_WAITING_FOR_PULL_LOW;
		end else begin
			sync_count <= sync_count - 1;
		end
	end else if (state == `STATE_WAITING_FOR_PULL_LOW) begin
		if (bkgd_in == 0) begin
			state <= `STATE_COUNTING_SYNC;
		end
	end else if (state == `STATE_COUNTING_SYNC) begin
		// We're counting the 128 target cycles that the device is holding the line low.
		if (bkgd_in == 1) begin
			// We're done! Send it off!
			state <= `STATE_IDLE;
			ready <= 1;
		end else begin
			sync_count <= sync_count + 1;
		end
	end
end

endmodule
