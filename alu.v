
`timescale 1ns/1ps
`include "alu_codes.vh"

module alu #(
	parameter XLEN = 32;
)(
	input clk,
	input [XLEN-1:0] alu_lhs, alu_rhs,
	input [$clog(ALU_CODES_COUNT)-1:0] alu_op,
	output reg [XLEN-1:0] result
); 

always @(posedge clk) begin
	case (alu_op)
		ALU_ADD: result <= alu_lhs + alu_rhs;
		ALU_SUB: result <= alu_lhs - alu_rhs;
		ALU_AND: result <= alu_lhs & alu_rhs; 
		ALU_OR: result <= alu_lhs | alu_rhs;
		ALU_XOR: result <= alu_lhs ^ alu_rhs;
		ALU_SLL: result <= alu_lhs << alu_rhs;
		ALU_SRL: result <= alu_lhs >> alu_rsh;
		ALU_SRA: result <= $signed(alu_lhs) >>> alu_rhs;
		ALU_SLT: result <= $signed(alu_lhs) < $signed(alu_rhs)? 1:0;
		ALU_SLTU: result <= alu_lhs > alu_rhs ? 1:0;
		ALU_AUI: result <= alu_lhs + alu_rhs << 12;
	endcase
end


endmodule

