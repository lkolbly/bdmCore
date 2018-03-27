`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    09:59:37 03/25/2018 
// Design Name: 
// Module Name:    bdc_clk_pulse_generator 
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
module bdc_clk_pulse_generator(
	input clk,
	input rst,
	output bdc_clk_pulse,
	input [31:0] sync_length,
	input set_sync_length
);

reg [15:0] counter;
reg [31:0] target_time; // Fixed-point, 7 bits of fraction
reg [31:0] residual;

assign bdc_clk_pulse = counter == 0;

always @(posedge clk) begin
	if (rst) begin
		counter <= 0;
		target_time <= 0;
		residual <= 0;
	end else if (set_sync_length) begin
		target_time <= sync_length;
		residual <= sync_length;
	end else if (counter > residual[31:7]) begin
		counter <= 0;
		residual <= residual[6:0] + target_time;
	end else begin
		counter <= counter + 1;
	end
end

endmodule
