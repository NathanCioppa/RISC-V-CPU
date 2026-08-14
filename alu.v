
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
	input [$clog(XLEN)-1:0] xrs_lhs, xrs_rhs,
	input [$clog(XREG_COUNT)-1:0] rd,
	input [$clog(MEM_CODES_COUNT)-1:0] mem_code,
	input [$clog(SIZE_CODES_COUNT)-1:0] size_code, 

	input do_forward,
	input flush,

	output reg [XLEN-1:0] out_result,
	output reg [$clog(XREG_COUNT)-1:0] out_rd,
	output reg out_do_wb,
	output reg [$clog(SIZE_CODES_COUNT)-1:0] out_size_code, 
	output reg [$clog(MEM_CODES_COUNT)-1:0] out_mem_code,

	output reg force_rd_free // forces rd to be freed regardless of out_do_wb state
); 

wire do_wb;
wire [$clog(XLEN)-1:0] effective_op_lhs, effective_op_rhs;

assign do_wb = (alu_code != ALU_INVALID) && (mem_code == MEM_INVALID);
assign effective_op_lhs = (do_forward && (xrs_lhs == out_rd)) ? out_result ? op_lhs;
assign effective_op_rhs = (do_forward && (xrs_rhs == out_rd)) ? out_result ? op_rhs;

always @(posedge clk) begin
	case (alu_code)
		ALU_ADD: result <= effective_op_lhs + effective_op_rhs;
		ALU_SUB: result <= effective_op_lhs - effective_op_rhs;
		ALU_AND: result <= effective_op_lhs & effective_op_rhs; 
		ALU_OR: result <= effective_op_lhs | effective_op_rhs;
		ALU_XOR: result <= effective_op_lhs ^ effective_op_rhs;
		ALU_SLL: result <= effective_op_lhs << effective_op_rhs;
		ALU_SRL: result <= effective_op_lhs >> alu_rsh;
		ALU_SRA: result <= $signed(effective_op_lhs) >>> effective_op_rhs;
		ALU_SLT: result <= $signed(effective_op_lhs) < $signed(effective_op_rhs)? 1:0;
		ALU_SLTU: result <= effective_op_lhs > effective_op_rhs ? 1:0;
		ALU_AUI: result <= effective_op_lhs + (effective_op_rhs << 12);
	endcase

	out_rd <= rd;
	out_force_rd_free <= flush;
	out_do_wb <= flush ? 0 : do_wb;
	out_size_code <= size_code;
	out_mem_code <= flush ? 0 : mem_code;
end

endmodule

