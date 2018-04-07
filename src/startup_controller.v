`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:55:43 03/24/2018 
// Design Name: 
// Module Name:    startup_controller 
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
module startup_controller(
	input clk,
	input rst,
	input start,
	input stop,
	output reg mcu_pwr,
	output reg is_sending,
	output reg ready
);

// Startup sequence:
// - Pull bkgd low, wait 5us (or at least 3us)
// - Turn on power, wait 24us (or at least 12us) for MCU clock to stabilize
// - Release bkgd, wait 10us for bkgd to float high

reg is_pulling_low, is_waiting_for_clock, is_waiting_for_bkgd_stable;
reg [15:0] timer;

//assign ready = is_waiting_for_bkgd_stable && timer == 0;

always @(posedge clk) begin
	if (rst || stop) begin // For now, stopping is equivalent to holding rst
		is_pulling_low <= 0;
		is_waiting_for_clock <= 0;
		is_waiting_for_bkgd_stable <= 0;
		is_sending <= 0;
		mcu_pwr <= 0;
		ready <= 1;
	end else if (start) begin
		is_pulling_low <= 1;
		is_sending <= 1;
		timer <= 250; // 5us
		ready <= 0;
	end else if (is_pulling_low) begin
		if (timer == 0) begin
			mcu_pwr <= 1;

			is_pulling_low <= 0;
			is_waiting_for_clock <= 1;
			timer <= 1200; // 24us
		end else begin
			timer <= timer - 1;
		end
	end else if (is_waiting_for_clock) begin
		if (timer == 0) begin
			is_sending <= 0; // Release bkgd

			is_waiting_for_clock <= 0;
			is_waiting_for_bkgd_stable <= 1;
			timer <= 500; // 10us
		end else begin
			timer <= timer - 1;
		end
	end else if (is_waiting_for_bkgd_stable) begin
		if (timer == 0) begin
			is_waiting_for_bkgd_stable <= 0;
			ready <= 1;
		end else begin
			timer <= timer - 1;
		end
	end
end

endmodule
