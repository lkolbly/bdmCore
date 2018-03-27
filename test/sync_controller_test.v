`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:49:40 03/20/2018
// Design Name:   sync_controller
// Module Name:   /home/lane/rs08-programmer/bcd/src/sync_controller_test.v
// Project Name:  bcd
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: sync_controller
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module sync_controller_test;

	// Inputs
	reg clk;
	reg rst;
	reg start_sync;
	reg bkgd_in;

	// Outputs
	wire bkgd;
	wire is_sending;
	wire [31:0] sync_length;
	wire sync_length_is_ready;

	// Instantiate the Unit Under Test (UUT)
	sync_controller #(16) uut (
		.clk(clk), 
		.rst(rst), 
		.bkgd(bkgd), 
		.bkgd_in(bkgd_in),
		.is_sending(is_sending), 
		.start_sync(start_sync), 
		.sync_length(sync_length), 
		.sync_length_is_ready(sync_length_is_ready)
	);

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;
		start_sync = 0;

		// Wait 100 ns for global reset to finish
		#100;
		
		start_sync = 1;
		clk = 1; #100; clk=0; #100;
		
		start_sync = 0;
		
		// Run the sync pulse
		while (is_sending) begin
			clk = 1; #100; clk = 0; #100;
		end
		
		// Hold bkgd low for a bit
		bkgd_in = 0;
		repeat (100) begin
			clk = 1; #100; clk = 0; #100;
		end

		// bkgd defaults back to high
		bkgd_in = 1;
		repeat (10) begin
			clk = 1; #100; clk = 0; #100;
		end

	end
      
endmodule

