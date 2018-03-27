`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   10:07:37 03/25/2018
// Design Name:   bdc_clk_pulse_generator
// Module Name:   /home/lane/rs08-programmer/bcd/bdc_clk_pulse_generator_test.v
// Project Name:  bcd
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: bdc_clk_pulse_generator
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module bdc_clk_pulse_generator_test;

	// Inputs
	reg clk;
	reg rst;
	reg [31:0] sync_length;
	reg set_sync_length;

	// Outputs
	wire bdc_clk_pulse;

	// Instantiate the Unit Under Test (UUT)
	bdc_clk_pulse_generator uut (
		.clk(clk), 
		.rst(rst), 
		.bdc_clk_pulse(bdc_clk_pulse), 
		.sync_length(sync_length), 
		.set_sync_length(set_sync_length)
	);
	
	`define CLK clk=1; #10; clk=0; #10;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 1;
		sync_length = 0;
		set_sync_length = 0;

		// Wait 100 ns for global reset to finish
		`CLK;
		rst = 0;
		`CLK; `CLK;
		
		sync_length = 1475;
		set_sync_length = 1;
		`CLK;
		set_sync_length = 0;
		`CLK;
		
		forever begin
			`CLK;
		end
        
		// Add stimulus here

	end
      
endmodule

