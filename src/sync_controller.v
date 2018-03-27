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
	output bkgd, // TODO: This is a constant 0
	input bkgd_in,
	output is_sending,
	input start_sync,
	output [31:0] sync_length,
	output sync_length_is_ready,
	output reg ready,
	
	output [4:0] debug
);

parameter HIGHTIME = 32'd6500; // 6500 works! 2000 min

reg is_sending_sync, is_waiting_for_settle, is_waiting_for_pull_low, is_counting_sync;
reg [31:0] sync_count;

assign debug = {is_sending_sync, is_waiting_for_settle, is_waiting_for_pull_low, is_counting_sync};

assign bkgd = 1'd0;
assign is_sending = is_sending_sync;
assign sync_length = sync_count;
assign sync_length_is_ready = (!is_sending_sync) && (!is_counting_sync);

always @(posedge clk) begin
	is_pulsing_high <= is_pulsing_high;
	is_sending_sync <= is_sending_sync;
	is_waiting_for_settle <= is_waiting_for_settle;
	is_waiting_for_pull_low <= is_waiting_for_pull_low;
	is_counting_sync <= is_counting_sync;
	sync_count <= sync_count;

	if (rst) begin
		is_pulsing_high <= 0;
		is_sending_sync <= 0;
		is_waiting_for_settle <= 0;
		is_counting_sync <= 0;
		sync_count <= HIGHTIME; // The start sync pulse will be as long as possible
		ready <= 0;
	end else if (start_sync) begin
		is_sending_sync <= 1;
		sync_count <= HIGHTIME;
		ready <= 0;
	end else if (is_sending_sync == 1) begin
		// We're currently holding the bkgd line low for at least 128 cycles
		if (sync_count == 0) begin
			is_sending_sync <= 0;
			is_waiting_for_settle <= 1;
			sync_count <= 8'h0f;
		end else begin
			sync_count <= sync_count - 1;
		end
	end else if (is_waiting_for_settle == 1) begin
		// We're waiting for the bkgd line to settle high and then be pulled low by the target
		if (sync_count == 0) begin
			is_waiting_for_settle <= 0;
			is_waiting_for_pull_low <= 1;
		end else begin
			sync_count <= sync_count - 1;
		end
	end else if (is_waiting_for_pull_low == 1) begin
		if (bkgd_in == 0) begin
			is_waiting_for_pull_low <= 0;
			is_counting_sync <= 1;
		end
	end else if (is_counting_sync == 1) begin
		// We're counting the 128 target cycles that the device is holding the line low.
		if (bkgd_in == 1) begin
			// We're done! Send it off!
			is_counting_sync <= 0;
			ready <= 1;
		end else begin
			sync_count <= sync_count + 1;
		end
	end
end

endmodule
