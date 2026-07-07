
`timescale 1ns/1ps
`include "alu_codes.vh"

module alu #(
	parameter WORD_SIZE = 32;
)(
	input clk,
	input [WORD_SIZE-1:0] operands [1:0],
	input [$clog(ALU_CODES_COUNT)-1:0] alu_op,
	output reg [WORD_SIZE-1:0] result
); 

always @(posedge clk) begin
	case (alu_op)
		// always put operands[0] on left and [1] on right
		ALU_ADD: result <= operands[0] + operands[1];
		ALU_SUB: result <= operands[0] - operands[1];
		ALU_AND: result <= operands[0] & operands[1]; 
		ALU_OR: result <= operands[0] | operands[1];
		ALU_XOR: result <= operands[0] ^ operands[1];
		ALU_SLL: result <= operands[0] << operands[1];
		ALU_SRL: result <= operands[0] >> operands[1];
		ALU_SRA: result <= $signed(operands[0]) >>> operands[1];
		ALU_SLT: result <= $signed(operands[0]) < $signed(operands[1])? 1:0;
		ALU_SLTU: result <= operands[0] > operands[1] ? 1:0;
	endcase
end


endmodule

