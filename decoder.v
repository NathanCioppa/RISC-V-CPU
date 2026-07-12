
`timescale 1ns/1ps
`include "alu_codes.vh"

localparam OP = 7'b0110011; // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
localparam OP_IMM = 7'b0010011; // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI

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
	output reg [XLEN-1:0] out_operands [1:0],
	output reg [XLEN-1:0] out_rd,
	output reg [$clog(ALU_CODES_COUNT)-1:0] out_alu_code,
	output reg out_to_mem,
	output reg [2:0] out_size_hint
);

reg [XLEN-1:0] x [XREG_COUNT-1:0]; // CPU Registers, the RISC-V x-registers
reg [XREG_COUNT-1:0] mem_holds;
reg blocking;

wire opcode [6:0];
wire [$clog(XREG_COUNT)-1:0] rd, rs1, rs2;
wire [XLEN-1:0] rs1_data, rs2_data;
wire hazard, hazard_rs1, hazard_rs2, hazard_rd;
wire R_hazard, I_hazard, S_hazard, U_hazard;
wire [XLEN-1:0] I_imm, S_imm, U_imm, J_imm, B_imm;
wire I_shift_arith;
wire opcode_illegal;

wire [XLEN-1:0] operands [1:0];
wire [$clog(ALU_CODES_COUNT)-1:0] alu_code;
wire to_mem;
wire [2:0] size_hint;

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

// _imm wires are set exactly as described in RISC-V Specifications for clarity
// (thats why for example I_imm doesnt just have instruction[30:20] after sign extension even though it is equivilent
// https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html#immtypes
assign I_imm = { {(XLEN-12){instruction[31]}}, instruction[30:25], instruction[24:21], instruction[20] }; 
assign S_imm = { {(XLEN-12){instruction[31]}}, instruction[30:25], instruction[11:8], instruction[7] };
assign B_imm = { {(XLEN-12){instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 0 };
assign U_imm = { {(XLEN-31){instruction[31]}}, instruction[30:20], instruction[19:12], {12{0}} };
assign J_imm = { {(XLEN-20){instruction[31]}}, instruction[19:12], instruction[20], instruction[30:25], instruction[24:21], 0 }

assign I_shift_arith = instruction[30];

always @(*) begin
case (opcode)
        7'b0110111: begin // LUI
        end
        7'b0010111: begin // AUIPC
        end
        7'b1101111: begin // JAL
        end
        7'b1100111: begin // JALR
        end
        7'b1100011: begin // BRANCH (BEQ, BNE, BLT, BGE, BLTU, BGEU)
        end
        7'b0000011: begin // LOAD (LB, LH, LW, LBU, LHU)
        end
        7'b0100011: begin // STORE (SB, SH, SW)
        end
        OP_IMM: begin 
		operands[0] = rs1_data;
		operands[1] = funct3 == 1 || funct3 == 5 ? I_imm[4:0] : I_imm;
		alu_code = OP_IMM_alu_code(funct3, I_shift_arith);
		to_mem = 0;
		size_hint = 0;
        end
        OP: begin
		operands[0] = rs1_data;
		operands[1] = rs2_data;
		alu_code = OP_alu_code(funct3, funct7);
		to_mem = 0;
		size_hint = 0;
        end
        7'b0001111: begin // MISC-MEM (FENCE)
        end
        7'b1110011: begin // SYSTEM (ECALL, EBREAK)
        end
        default: opcode_illegal = 1;
    endcase	
end

always @(posedge clk) begin

	// WRITEBACK
	mem_holds[writeback_reg] <= writeback_data

	// Check hazards
	if (hazard) begin
		blocking <= 1;
	end
	else begin
		out_alu_code <= alu_code;
		blocking <= 0;
	end	
end

function [$clog(ALU_CODES_COUNT)-1:0] OP_alu_code(input [2:0] funct3, input [6:0] funct7);
	begin
		case (funct3)
			0: case (funct7) 
				0: OP_alu_code = ALU_ADD;
				32: OP_alu_code = ALU_SUB;
				default: OP_alu_code = ALU_INVALID;
			endcase

			1: case (funct7)
				0: OP_alu_code = ALU_SLL;
				default: OP_alu_code = ALU_INVALID;
			endcase

			2: case (funct7) 
				0: OP_alu_code = ALU_SLT;
				default: OP_alu_code = ALU_INVALID;
			endcase

			3: case (funct7)
				0: OP_alu_code = ALU_SLTU;
				default: OP_alu_code = ALU_INVALID;
			endcase
			
			4: case (funct7)
				0: OP_alu_code = ALU_XOR;
				default: OP_alu_code = ALU_INVALID;
			endcase
			
			5: case (funct7)
				0: OP_alu_code = ALU_SRL;
				32: OP_alu_code = ALU_SRA;
				default: OP_alu_code = ALU_INVALID;
			endcase
			
			6: case (funct7)
				0: OP_alu_code = ALU_OR;
				default: OP_alu_code = ALU_INVALID;
			endcase
			
			7: case (funct7) 
				0: OP_alu_code = ALU_AND;
				default: OP_alu_code = ALU_INVALID;
			endcase
			
			default: OP_alu_code = ALU_INVALID;
		endcase

	end
endfunction

function [XLEN-1:0] OP_IMM_alu_code(input [2:0] funct3, input I_shift_arith);
	begin
		case (funct3)
			0: OP_IMM_alu_code = ALU_ADD;
			1: OP_IMM_alu_code = ALU_SLL;
			2: OP_IMM_alu_code = ALU_SLT;
			3: OP_IMM_alu_code = ALU_SLTU;
			4: OP_IMM_alu_code = ALU_XOR;
			5: OP_IMM_alu_code = I_shift_arith ? ALU_SRA : ALU_SRL;
			6: OP_IMM_alu_code = ALU_OR;
			7: OP_IMM_alu_code = ALU_AND;
		endcase
	end
endfunction

endmodule

