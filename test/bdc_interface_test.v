`timescale 1ns / 1ps

////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer:
//
// Create Date:   09:12:37 03/25/2018
// Design Name:   bdc_interface
// Module Name:   /home/lane/rs08-programmer/bcd/bdc_interface_test.v
// Project Name:  bcd
// Target Device:  
// Tool versions:  
// Description: 
//
// Verilog Test Fixture created by ISE for module: bdc_interface
//
// Dependencies:
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
////////////////////////////////////////////////////////////////////////////////

module bdc_interface_test;

	reg [7:0] test_data;

	// Inputs
	reg clk;
	reg rst;
	reg bkgd_in;
	//reg tgt_clk_pulse;
	reg [7:0] data_in;
	reg send_data;
	reg read_data;

	// Outputs
	wire is_sending;
	wire [7:0] data_out;
	wire ready;
	
	reg [3:0] counter;
	wire tgt_clk_pulse;
	always @(posedge clk) counter <= counter + 1;
	assign tgt_clk_pulse = counter == 0;

	// Instantiate the Unit Under Test (UUT)
	bdc_interface uut (
		.clk(clk), 
		.rst(rst), 
		.is_sending(is_sending), 
		.bkgd_in(bkgd_in), 
		.tgt_clk_pulse(tgt_clk_pulse), 
		.data_in(data_in), 
		.send_data(send_data), 
		.data_out(data_out), 
		.read_data(read_data), 
		.ready(ready)
	);
	
	`define CLK clk=1; #20; clk=0; #20;

	initial begin
		// Initialize Inputs
		counter = 0;
		clk = 0;
		rst = 1;
		bkgd_in = 0;
		//tgt_clk_pulse = 0;
		data_in = 0;
		send_data = 0;
		read_data = 0;

		// Wait 100 ns for global reset to finish
		`CLK;
		rst = 0;
		`CLK;
		
		// Test sending a byte
		data_in = 8'h53;
		send_data = 1;
		`CLK;
		send_data = 0;
		repeat (4096) begin
			`CLK;
		end
        
		// Test reading a byte
		test_data = 8'h53;
		read_data = 1;
		`CLK;
		read_data = 0;
		`CLK; `CLK; // Let it start
		while (!ready) begin
			// Wait for bkgd to stop being low
			while (is_sending) begin
				`CLK;
			end
			
			// Wait another couple clocks
			repeat (20) begin
				`CLK;
			end
			
			// Send the bit we want to send
			bkgd_in = test_data[0];
			test_data = {1'd0, test_data[7:1]};
			
			// Wait for bkgd to go low
			while (!is_sending) begin
				`CLK;
			end
			
			// Unset the bit...
			bkgd_in = 1;
		end

	end
      
endmodule

