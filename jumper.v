
`timescale 1ns/1ps;
`include "jumper_codes.vh"

module jumper #(
parameter XLEN = 32
) (
input clk,
input [XLEN-1:0] add_lhs, add_rhs,
input [XLEN-1:0] cmp_lhs, cmp_rhs,
input [$clog(JUMPER_CODES_COUNT)-1:0] cond
output reg [XLEN-1:0] pc;
);

wire [XLEN-1:0] sum;
wire do_assignment;

assign sum = add_lhs + add_rhs;

assign do_assignment = (cond == JUMP_UNCOND) 
	|| ( (cond == JUMP_EQ) && (cmp_lhs == cmp_rhs) )
	|| ( (cond == JUMP_NEQ) && (cmp_lhs != cmp_rhs) )
	|| ( (cond == JUMP_LT) && ( $signed(cmp_lhs) < $signed(cmp_rhs) ) )
	|| ( (cond == JUMP_GTE) && ( $signed(cmp_lhs) >= $signed(cmp_rhs) ) )
	|| ( (cond == JUMP_U_LT) && (cmp_lhs < cmp_rhs) )
	|| ( (cond == JUMP_U_GTE) && (cmp_lhs >= cmp_rhs) );

always @(posedge clk) begin
	if(do_assignment)
		pc <= sum;
end



endmodule

