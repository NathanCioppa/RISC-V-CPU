
`timescale 1ns/1ps
`include "alu_codes.vh"

module decoder #(
	parameter XREG_COUNT = 32, 
	parameter XLEN = 32,
	parameter INSTRUCTION_LEN = 32
)(
	input clk,
	input [INSTRUCTION_LEN-1:0] instruction,
	input [XLEN-1:0] pc_data,
	input [XLEN-1:0] writeback_data,
	input [$clog(XREG_COUNT)-1:0] writeback_reg,
	output reg [XLEN-1:0] operand_buf [1:0],
	output reg [XLEN-1:0] pass_rd,
	output reg [$clog(ALU_CODES_COUNT)-1:0] alu_op,
);

reg [XLEN-1:0] x [XREG_COUNT-1:0]; // CPU Registers, the RISC-V x-registers
reg [XREG_COUNT-1:0] mem_holds;
reg blocking;

wire opcode [6:0];
wire [$clog(XREG_COUNT)-1:0] rd, rs1, rs2;
wire [XLEN-1:0] rs1_data, rs2_data;
wire hazard, hazard_rs1, hazard_rs2, hazard_rd;
wire R_hazard, I_hazard, S_hazard, U_hazard;
wire [XLEN-1:0] I_imm, S_imm, U_imm;
wire [$clog(ALU_CODES_COUNT)-1:0] alu_code;

assign opcode = instruction[6:0];
assign rd = instruction[11:7];
assign rs1 = instruction[19:15];
assign rs2 = instruction[24:20];

// x0 is hardwired to always output 0 when read
assign rs1_data = rs1 ? x[rs1] : 0;
assign rs2_data = rs2 ? x[rs2] : 0;

// ignore any hold placed on x0 when checking for hazards
assign hazard_rs1 = rs1 ? mem_holds[rs1] : 0;
assign hazard_rs2 = rs2 ? mem_holds[rs2] : 0;
assign hazard_rd = rd ? mem_holds[rd] : 0;

// hazards and immediates can be determined based off of just the format
assign R_hazard = hazard_rs1 || hazard_rs2 || hazard_rd;
assign I_hazard = hazard_rs1 || hazard_rd;
assign S_hazard = hazard_rs1 || hazard_rs2;
assign U_hazard = hazard_rd;

assign I_imm = { {(XLEN-12){instruction[31]}} , instruction[31:20]}; 
assign S_imm = { {(XLEN-12){instruction[31]}}, instruction[31:25], instruction[11:7] };
assign U_imm = { {(XLEN-20){instruction[31]}}, instruction[31:20] };


always @(posedge clk) begin

	// WRITEBACK
	mem_holds[writeback_reg] <= writeback_data

	// DECODE
	if (hazard) begin
		blocking <= 1;
	end
	else begin
		alu_op <= alu_code;
		blocking <= 0;
		case (opcode)
			R_TYPE: begin 
				mem_holds[rd] <= 1;
				operand_buf[0] <= rs1_data;
				operand_buf[1] <= rs2_data;
			end
			I_TYPE: begin 
				mem_holds[rd] <= 1;
				operand_buf[0] <= rs1_data;
				operand_buf[1] <= imm; 
			end
			S_TYPE: begin
				operand_buf[0] <= rs1_data;
				operand_buf[1] <= imm;
			end
			U_TYPE: begin 
				mem_holds[rd] <= 1;
				operand_buf[0] <= imm;
				operand_buf[1] <= pc;
			end
			default: begin 
				// handle case of invalid opcode, maybe an exception?
			end
		endcase
	end	
end

// Returns the ALU code that corresponds to the R Format with given functs
// Note this currently has no handling of malformed instructions
function [$clog(ALU_CODES_COUNT)-1:0] R_to_alu (input [2:0] funct3, input [6:0] funct7);
	case (funct3)
		0: R_to_alu = funct7 ? ALU_SUB : ALU_ADD;
		1: R_to_alu = ALU_SLL;
		2: R_to_alu = ALU_SLT;
		3: R_to_alu = ALU_SLTU;
		4: R_to_alu = ALU_XOR;
		5: R_to_alu = funct7 ? ALU_SRA : ALU_SRL
		6: R_to_alu = ALU_OR;
		7: R_to_alu = ALU_AND;
		default: 0;
	endcase
endfunction

function [$clog(ALU_CODES_COUNT)-1:0] I_to_alu (input [6:0] opcode, input [2:0] funct3, input [11:0] imm);
	case (opcode)
		k
	case (funct3)
		0: I_to_alu = ALU_ADD;
		1: I_to_alu = imm [11:5] ? ALU_SLL;
		2: I_to_alu = ALU_SLT;
		3: I_to_alu = ALU_SLTU;
		4: I_to_alu = ALU_XOR;
		5: I_to_alu = funct7 ? ALU_SRA : ALU_SRL
		6: I_to_alu = ALU_OR;
		7: I_to_alu = ALU_AND;

	endcase
endfunction

function [$clog(ALU_CODES_COUNT)-1:0] S_to_alu (input [2:0] funct3);

endfunction

function [$clog(ALU_CODES_COUNT)-1:0] U_to_alu (input [6:0] opcode);

endfunction

endmodule

