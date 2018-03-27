`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   16:41:24 03/25/2018
// Design Name:   bdm
// Module Name:   /home/lane/rs08-programmer/bcd/bdm_test.v
// Project Name:  bcd
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: bdm
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module bdm_test;

	// Inputs
	reg clk;
	reg rst;
	reg bkgd_in;
	reg do_read;
	reg do_write;
	reg do_start_mcu;
	reg do_stop_mcu;
	reg do_delay;
	reg do_echo_test;
	reg [7:0] data_in;

	// Outputs
	wire bkgd_out;
	wire bkgd_is_high_z;
	wire mcu_pwr;
	wire [7:0] data_out;
	wire ready;
	wire valid;
	wire [3:0] debug;

	// Instantiate the Unit Under Test (UUT)
	bdm uut (
		.clk(clk), 
		.rst(rst), 
		.bkgd_in(bkgd_in), 
		.bkgd_out(bkgd_out), 
		.bkgd_is_high_z(bkgd_is_high_z), 
		.mcu_pwr(mcu_pwr), 
		.do_read(do_read), 
		.do_write(do_write), 
		.do_start_mcu(do_start_mcu), 
		.do_stop_mcu(do_stop_mcu), 
		.do_delay(do_delay), 
		.do_echo_test(do_echo_test),
		.data_in(data_in), 
		.data_out(data_out), 
		.ready(ready), 
		.valid(valid),
		.debug(debug)
	);
	
	`define CLK clk=1; #10; clk=0; #10;

	initial begin
		// Initialize Inputs
		clk = 0;
		rst = 0;
		bkgd_in = 0;
		do_read = 0;
		do_write = 0;
		do_start_mcu = 0;
		do_stop_mcu = 0;
		do_delay = 0;
		do_echo_test = 0;
		data_in = 0;

		// Wait 100 ns for global reset to finish
		`CLK;
		rst = 1;
		`CLK;
		rst = 0;
		`CLK; `CLK; `CLK;
		
		do_echo_test = 1;
		data_in = 8'h55;
		`CLK;
		do_echo_test = 0;
		`CLK; `CLK; `CLK;
		
		do_start_mcu = 1;
		
		forever begin
			`CLK;
		end
        
		// Add stimulus here

	end
      
endmodule

