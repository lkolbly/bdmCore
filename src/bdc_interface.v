`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    08:56:46 03/25/2018 
// Design Name: 
// Module Name:    bdc_interface 
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
module bdc_interface(
	input clk,
	input rst,
	output reg is_sending,
	input bkgd_in,
	input tgt_clk_pulse,
	input [7:0] data_in,
	input send_data,
	output reg [7:0] data_out,
	input read_data,
	output ready
);

`define STATE_IDLE 0
`define STATE_SENDING 1
`define STATE_SEND_WAITING_FOR_NEXT_BITTIME 2
`define STATE_RECEIVING 3
`define STATE_RECEIVING_WAIT_FOR_REPLY 4
`define STATE_RECEIVING_WAIT_FOR_BITTIME 5

reg [3:0] state;
reg [7:0] tgt_clk_timer;

reg [7:0] data;
reg [3:0] bitsleft;

assign ready = state == `STATE_IDLE;

//assign data_out = 0;

always @(posedge clk) begin
	if (rst) begin
		state <= `STATE_IDLE;
	end else if (tgt_clk_timer > 0) begin
		if (tgt_clk_pulse) begin
			tgt_clk_timer <= tgt_clk_timer - 1;
		end
	end else begin
		case (state)
		`STATE_IDLE: begin
			if (send_data) begin
				state <= `STATE_SENDING;
				data <= data_in;
				bitsleft <= 8;
			end else if (read_data) begin
				state <= `STATE_RECEIVING;
				bitsleft <= 8;
			end
		end
		
		`STATE_SENDING: begin
			if (bitsleft > 0) begin
				state <= `STATE_SEND_WAITING_FOR_NEXT_BITTIME;
				is_sending <= 1;
				if (data[7]) begin
					tgt_clk_timer <= 4;
				end else begin
					tgt_clk_timer <= 14;
				end
			end else begin
				state <= `STATE_IDLE;
			end
		end
		
		`STATE_SEND_WAITING_FOR_NEXT_BITTIME: begin
			is_sending <= 0;
			if (data[7]) begin
				tgt_clk_timer <= 14;
			end else begin
				tgt_clk_timer <= 4;
			end
			state <= `STATE_SENDING;
			bitsleft <= bitsleft - 1;
			data <= {data[6:0], 1'd0};
		end
		
		`STATE_RECEIVING: begin
			if (bitsleft > 0) begin
				is_sending <= 1;
				tgt_clk_timer <= 3;
				state <= `STATE_RECEIVING_WAIT_FOR_REPLY;
			end else begin
				data_out <= data;
				state <= `STATE_IDLE;
			end
		end
		
		`STATE_RECEIVING_WAIT_FOR_REPLY: begin
			is_sending <= 0;
			tgt_clk_timer <= 7;
			state <= `STATE_RECEIVING_WAIT_FOR_BITTIME;
		end
		
		`STATE_RECEIVING_WAIT_FOR_BITTIME: begin
			data <= {data[6:0], bkgd_in};
			bitsleft <= bitsleft - 1;
			tgt_clk_timer <= 6;
			state <= `STATE_RECEIVING;
		end
		endcase
	end
end

endmodule
