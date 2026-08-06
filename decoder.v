
`timescale 1ns/1ps
`include "alu_codes.vh"
`include "jumper_codes.vh"
`include "mem_codes.vh"
`include "size_codes.vh"

localparam OP = 7'b0110011; // ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND
localparam OP_IMM = 7'b0010011; // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
localparam LOAD = 7'b0000011; // LB, LH, LW, LBU, LHU
localparam STORE = 7'b0100011; // SB, SH, SW
localparam LUI = 7'b0110111;
localparam AUIPC = 7'b0010111;
localparam JAL = 7'b1101111;
localparam JALR = 7'b1100111;
localparam BRANCH = 7'b1100011; // BEQ, BNE, BLT, BGE, BLTU, BGEU
localparam FENCE = 7'b0001111;
localparam SYSTEM = 7'b1110011; // ECALL, EBREAK 

module decoder #(
	parameter XREG_COUNT = 32, 
	parameter XLEN = 32,
	parameter INSTRUCTION_LEN = 32
)(
	input clk,
	input [INSTRUCTION_LEN-1:0] instruction,

	input [XLEN-1:0] alu_writeback_data,
	input [$clog(XREG_COUNT)-1:0] alu_writeback_reg,
	input do_alu_writeback;
	input [XLEN-1:0] load_writeback_data,
	input [$clog(XREG_COUNT)-1:0] load_writeback_reg,
	input do_load_writeback;
	input [XLEN-1:0] pc_writeback_data,
	input do_pc_writeback,

	input mem_controller_queue_full,
	
	output reg [XLEN-1:0] out_operands [3:0],
	output reg [XLEN-1:0] out_rd,
	output reg [$clog(ALU_CODES_COUNT)-1:0] out_alu_code,
	output reg [1:0] out_mem_code,
	output reg [2:0] out_size_code,
	output reg [$clog(JUMPER_CODES_COUNT)-1:0] out_jumper_code,
	
	output reg out_add_to_mem_controller_queue
);

reg [XLEN-1:0] x [XREG_COUNT-1:0]; // CPU Registers, the RISC-V x-registers
reg [XREG_COUNT-1:0] mem_holds;
reg blocking;

wire opcode [6:0];
wire [$clog(XREG_COUNT)-1:0] rd, rs1, rs2;
wire [XLEN-1:0] rs1_data, rs2_data;
wire hazard, hazard_rs1, hazard_rs2, hazard_rd, hazard_mem;
wire R_hazard, I_hazard, S_hazard, U_hazard;
wire [XLEN-1:0] I_imm, S_imm, U_imm, J_imm, B_imm;
wire I_shift_arith;
wire opcode_illegal;
wire is_mem_instruction;

reg [XLEN-1:0] operands [3:0];
reg [$clog(ALU_CODES_COUNT)-1:0] alu_code;
reg [$clog(MEM_CODES_COUNT)-1:0] mem_code;
reg [2:0] size_code;
reg [$clog(JUMPER_CODES_COUNT)-1:0] jumper_code;



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

// these hazards can be determined off of format alone, as the depend only on
// register locations encoded in the instruction
assign R_hazard = hazard_rs1 || hazard_rs2 || hazard_rd;
assign I_hazard = hazard_rs1 || hazard_rd;
assign S_hazard = hazard_rs1 || hazard_rs2;
assign B_hazard = S_hazard;
assign U_hazard = hazard_rd;
assign J_hazard = U_hazard;

// need a hazard for mem instructions to check since they may need to block if
// the controller's queue is full
assign MEM_hazard = mem_controller_queue_full;

// _imm wires are set exactly as described in RISC-V Specifications for clarity
// (thats why for example I_imm doesnt just have instruction[30:20] after sign extension even though it is equivilent
// https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html#immtypes
assign I_imm = { {(XLEN-12){instruction[31]}}, instruction[30:25], instruction[24:21], instruction[20] }; 
assign S_imm = { {(XLEN-12){instruction[31]}}, instruction[30:25], instruction[11:8], instruction[7] };
assign B_imm = { {(XLEN-12){instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0 };
assign U_imm = { {(XLEN-31){instruction[31]}}, instruction[30:20], instruction[19:12], {12{0}} };
assign J_imm = { {(XLEN-20){instruction[31]}}, instruction[19:12], instruction[20], instruction[30:25], instruction[24:21], 1'b0 }

assign I_shift_arith = instruction[30];
assign is_mem_instruction = opcode == LOAD || opcode == STORE;

always @(*) begin
case (opcode)
        LUI: begin
		operands[0] = 0;
		operands[1] = U_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_AUI;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		hazard = U_hazard;
		opcode_illegal = 0;
        end
        AUIPC: begin
		operands[0] = pc;
		operands[1] = U_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_AUI;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALD;
		jumper_code = JUMP_INVALID;
		hazard = U_hazard;
		opcode_illegal = 0;
        end
        JAL: begin
		operands[0] = pc;
		operands[1] = 4;
		operands[2] = pc;
		operands[3] = J_imm;
		alu_code = ALU_ADD;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALD;
		jumper_code = JUMPER_UNCOND;
		hazard = J_hazard;
		opcode_illegal = 0;
        end
        JALR: begin
		operands[0] = pc;
		operands[1] = 4;
		operands[2] = rs1_data;
		operands[3] = I_imm;
		alu_code = ALU_ADD;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALD;
		jumper_code = JUMP_UNCOND;
		hazard = I_hazard;
		opcode_illegal = 0;
        end
        BRANCH: begin 
		operands[0] = rs1_data;
		operands[1] = rs2_data;
		operands[2] = pc;
		operands[3] = B_imm;
		alu_code = ALU_INVALID;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALD;
		jumper_code = BRANCH_jumper_code(funct3);
		hazard = B_hazard;
		opcode_illegal = 0;
        end
        LOAD: begin
		operands[0] = rs1_data;
		operands[1] = I_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_ADD;
		mem_code = MEM_LOAD;
		size_code = LOAD_size_hint(funct3);
		jumper_code = JUMP_INVALID;
		hazard = I_hazard || MEM_hazard;
		opcode_illegal = 0;
        end
        STORE: begin 
		operands[0] = rs1_data;
		operands[1] = S_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_ADD;
		mem_code = MEM_STORE;
		size_code = STORE_size_hint(funct3);
		jumper_code = JUMP_INVALID;
		hazard = S_hazard || MEM_hazard;
		opcode_illegal = 0;
        end
        OP_IMM: begin 
		operands[0] = rs1_data;
		operands[1] = funct3 == 1 || funct3 == 5 ? I_imm[4:0] : I_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = OP_IMM_alu_code(funct3, I_shift_arith);
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		hazard = I_hazard;
		opcode_illegal = 0;
        end
        OP: begin
		operands[0] = rs1_data;
		operands[1] = rs2_data;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = OP_alu_code(funct3, funct7);
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		hazard = R_hazard;
		opcode_illegal = 0;
        end
        FENCE: begin // NO OP since this is a single core CPU
		operands[0] = 0;
		operands[1] = 0;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_INVALID;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		hazard = 0;
		opcode_illegal = 0;
        end
        SYSTEM: begin // NO OP since this is an unprivilaged CPU
		operands[0] = 0;
		operands[1] = 0;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_INVALID;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		hazard = 0;
		opcode_illegal = 0;
        end
	default: begin 
		operands[0] = 0;
		operands[1] = 0;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_INVALID;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		hazard = 0;
		opcode_illegal = 1;
	end
    endcase
end

always @(posedge clk) begin

	// WRITEBACK
	if(do_alu_writeback) begin
		x[alu_writeback_reg] <= alu_writeback_data;
		mem_holds[alu_writeback_reg] <= 0;
	end
	if(do_load_writeback) begin
		x[load_writeback_reg] <= load_writeback_data;
		mem_holds[load_writeback_reg] <= 0;
	end
	if(do_pc_writeback) begin
		// wait on this until logic is done for regular pc increments
		// and jumps. 
	end

	// SEND INSTRUCTION INTO PIPELINE
	if (hazard) begin // start blocking and send no-op
		out_operands[0] <= 0;
		out_operands[1] <= 0;
		out_operands[2] <= 0;
		out_operands[3] <= 0;
		out_rd <= 0;

		out_alu_code <= ALU_INVALID;
		out_size_code <= SIZE_INVALID;
		out_mem_code <= MEM_INVALID;

		out_jumper_code <= JUMP_INVALID;

		out_add_to_mem_controller_queue <= 0;
		
		blocking <= 1;
	end
	else begin
		out_operands[0] <= operands[0];
		out_operands[1] <= operands[1];
		out_operands[2] <= operands[2];
		out_operands[3] <= operands[3];
		out_rd <= rd;

		out_alu_code <= alu_code;
		out_size_code <= size_hint;
		out_mem_code <= mem_hint;

		out_jumper_code <= jumper_code;
		
		out_add_to_mem_controller_queue <= is_mem_instruction;
		
		blocking <= 0;
	end
end


// ########## HELPER FUNCTIONS ##########

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
			default:
				OP_IMM_alu_code = ALU_INVALID;
		endcase
	end
endfunction

function [2:0] LOAD_size_code(input [2:0] funct3);
	begin
		case (funct3)
			0: LOAD_size_code = SIZE_BYTE;
			1: LOAD_size_code = SIZE_HALF;
			2: LOAD_size_code = SIZE_WORD;
			4: LOAD_size_code = SIZE_UBYTE;
			5: LOAD_size_code = SIZE_UHALF;
			default: LOAD_size_code = SIZE_INVALID;
		endcase
	end
endfunction

function [2:0] STORE_size_code(input [2:0] funct3);
	begin
		case (funct3)
			0: STORE_size_code = SIZE_BYTE;
			1: STORE_size_code = SIZE_HALF;
			2: STORE_size_code = SIZE_WORD;
			default: STORE_size_code = SIZE_INVALID;
		endcase
	end
endfunction

function [$clog(JUMPER_CODES_COUNT)-1:0] BRANCH_jumper_code(input [2:0] funct3);
	begin
		case(funct3)
			0: BRANCH_jumper_code = JUMP_EQ;
			1: BRANCH_jumper_code = JUMP_NEQ;
			4: BRANCH_jumper_code = JUMP_LT;
			5: BRANCH_jumper_code = JUMP_GTE;
			6: BRANCH_jumper_code = JUMP_U_LT;
			7: BRANCH_jumper_code = JUMP_U_GTE;
			default: BRANCH_jumper_code = JUMP_INVALID;
		endcase
	end
endfunction

endmodule

