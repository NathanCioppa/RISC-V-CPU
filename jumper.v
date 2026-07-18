
`timescale 1ns/1ps;
`include "jumper_codes.vh"

module jumper #(
parameter XLEN = 32
) (
input clk,
input [XLEN-1:0] add_operands [1:0],
input [XLEN-1:0] cmp_operands [1:0],
input [$clog(JUMPER_CODES_COUNT)-1:0] cond
output reg [XLEN-1:0] pc;
);

wire [XLEN-1:0] sum;
wire do_assignment;

assign sum = add_operands[0] + add_operands[1];

assign do_assignment = (cond == JUMP_UNCOND) 
	|| ( (cond == JUMP_EQ) && (cmp_operands[0] == cmp_operands[1]) )
	|| ( (cond == JUMP_NEQ) && (cmp_operands[0] != cmp_operands[1]) )
	|| ( (cond == JUMP_LT) && ( $signed(cpm_operands[0]) < $signed(cmp_operands[1]) ) )
	|| ( (cond == JUMP_GTE) && ( $signed(cpm_operands[0]) >= $signed(cmp_operands[1]) ) )
	|| ( (cond == JUMP_U_LT) && (cpm_operands[0] < cmp_operands[1]) )
	|| ( (cond == JUMP_U_GTE) && (cpm_operands[0] >= cmp_operands[1]) );

always @(posedge clk) begin
	if(do_assignment)
		pc <= sum;
end



endmodule

