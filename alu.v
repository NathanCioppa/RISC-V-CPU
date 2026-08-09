
`timescale 1ns/1ps

`include "alu_codes.vh"
`include "mem_codes.vh"
`include "size_codes.vh"

module alu #(
	parameter XLEN = 32;
	parameter XREG_COUNT = 32;
)(
	input clk,
	
	input [$clog(ALU_CODES_COUNT)-1:0] alu_code,
	input [XLEN-1:0] op_lhs, op_rhs,
	input [$clog(XREG_COUNT)-1:0] rd,
	input [$clog(MEM_CODES_COUNT)-1:0] mem_code,
	input [$clog(SIZE_CODES_COUNT)-1:0] size_code, 

	input flush,

	output reg [XLEN-1:0] out_result,
	output reg [$clog(XREG_COUNT)-1:0] out_rd,
	output reg out_do_wb,
	output reg [$clog(SIZE_CODES_COUNT)-1:0] out_size_code, 
	output reg [$clog(MEM_CODES_COUNT)-1:0] out_mem_code,

	output reg force_rd_free // forces rd to be freed regardless of out_do_wb state
); 

wire do_wb;

assign do_wb = (alu_code != ALU_INVALID) && (mem_code == MEM_INVALID);

always @(posedge clk) begin
	case (alu_code)
		ALU_ADD: result <= op_lhs + op_rhs;
		ALU_SUB: result <= op_lhs - op_rhs;
		ALU_AND: result <= op_lhs & op_rhs; 
		ALU_OR: result <= op_lhs | op_rhs;
		ALU_XOR: result <= op_lhs ^ op_rhs;
		ALU_SLL: result <= op_lhs << op_rhs;
		ALU_SRL: result <= op_lhs >> alu_rsh;
		ALU_SRA: result <= $signed(op_lhs) >>> op_rhs;
		ALU_SLT: result <= $signed(op_lhs) < $signed(op_rhs)? 1:0;
		ALU_SLTU: result <= op_lhs > op_rhs ? 1:0;
		ALU_AUI: result <= op_lhs + (op_rhs << 12);
	endcase

	out_rd <= rd;
	out_force_rd_free <= flush;
	out_do_wb <= flush ? 0 : do_wb;
	out_size_code <= size_code;
	out_mem_code <= flush ? 0 : mem_code;
end

endmodule

