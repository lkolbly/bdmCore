`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   18:58:50 03/25/2018
// Design Name:   bdm_interface
// Module Name:   /home/lane/rs08-programmer/bcd/bdm_interface_test.v
// Project Name:  bcd
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: bdm_interface
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module bdm_interface_test;

	// Inputs
	reg clk;
	reg rst_in;
	reg new_rx_data;
	reg [7:0] rx_data;
	reg tx_block;

	// Outputs
	wire new_tx_data;
	wire [7:0] tx_data;
	wire mcu_pwr;

	// Bidirs
	wire bkgd;

	// Instantiate the Unit Under Test (UUT)
	bdm_interface uut (
		.clk(clk), 
		.rst_in(rst_in), 
		.new_rx_data(new_rx_data), 
		.rx_data(rx_data), 
		.new_tx_data(new_tx_data), 
		.tx_data(tx_data), 
		.tx_block(tx_block),
		.bkgd(bkgd), 
		.mcu_pwr(mcu_pwr)
	);

	`define CLK clk=1; #10; clk=0; #10;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst_in = 1;
		new_rx_data = 0;
		rx_data = 0;
		tx_block = 0;

		// Wait 100 ns for global reset to finish
		`CLK; `CLK; `CLK;
		rst_in = 0;
		`CLK; `CLK; `CLK;
		
		// Load some echo test data
		new_rx_data = 1;
		rx_data = 8'h82;
		`CLK;
		rx_data = 8'h05;
		`CLK;
		rx_data = 8'd123;
		`CLK;
		rx_data = 8'h05;
		`CLK;
		rx_data = 8'd213;
		`CLK;
		new_rx_data = 0;
		`CLK;
		
		// Read the FIFO depth
		new_rx_data = 1;
		rx_data = 8'h04;
		`CLK;
		new_rx_data = 0;
		`CLK;
		
		// Start the BDM engine
		new_rx_data = 1;
		rx_data = 8'h01;
		`CLK;
		new_rx_data = 0;
		
		while (!new_tx_data) begin
			`CLK;
		end
		`CLK;
		tx_block = 1;
		repeat (20) begin
			`CLK;
		end
		tx_block = 0;
		
		repeat (20) begin
			`CLK;
		end
		
		// Test booting a chip
		new_rx_data = 1;
		rx_data = 8'h81;
		`CLK;
		rx_data = 8'h03;
		`CLK;
		rx_data = 8'h0;
		`CLK;
		new_rx_data = 0;
		
		repeat (10000) begin
			`CLK;
		end
		tgt_bkgd = 0;

		forever begin
			`CLK;
		end

	end
      
endmodule

