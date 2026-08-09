
`timescale 1ns/1ps;

`include "jumper_codes.vh"

module jumper #(
	parameter XLEN = 32
)(
	input clk,
	input [XLEN-1:0] add_lhs, add_rhs,
	input [XLEN-1:0] cmp_lhs, cmp_rhs,
	input [$clog(JUMPER_CODES_COUNT)-1:0] jumper_code,
	input flush_settling,

	output reg [XLEN-1:0] out_pc,
	output reg result_valid
);

wire [XLEN-1:0] sum;
wire do_assignment;

assign sum = add_lhs + add_rhs;

assign do_assignment = (jumper_code == JUMP_UNCOND) 
	|| ( (jumper_code == JUMP_EQ) && (cmp_lhs == cmp_rhs) )
	|| ( (jumper_code == JUMP_NEQ) && (cmp_lhs != cmp_rhs) )
	|| ( (jumper_code == JUMP_LT) && ( $signed(cmp_lhs) < $signed(cmp_rhs) ) )
	|| ( (jumper_code == JUMP_GTE) && ( $signed(cmp_lhs) >= $signed(cmp_rhs) ) )
	|| ( (jumper_code == JUMP_U_LT) && (cmp_lhs < cmp_rhs) )
	|| ( (jumper_code == JUMP_U_GTE) && (cmp_lhs >= cmp_rhs) );

always @(posedge clk) begin
	if(do_assignment && !flush_settling) begin
		out_pc <= sum;
		result_valid <= 1;
	end
	else
		result_valid <= 0;
end



endmodule

