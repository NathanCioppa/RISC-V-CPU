
`timescale 1ns/1ps
`include "alu_codes.vh"
`include "jumper_codes.vh"
`include "mem_codes.vh"
`include "size_codes.vh"

localparam OPCODE_LEN = 7;
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
	input [INSTRUCTION_LEN-1:0] instruction_in,
	input next_inst_ready,

	input [XLEN-1:0] alu_writeback_data,
	input [$clog(XREG_COUNT)-1:0] alu_writeback_reg,
	input do_alu_writeback;
	input [XLEN-1:0] load_writeback_data,
	input [$clog(XREG_COUNT)-1:0] load_writeback_reg,
	input do_load_writeback;
	input [XLEN-1:0] pc_writeback_data,
	input do_pc_writeback,

	input mem_controller_closed,
	input jumper_did_branch,
	input force_alu_rd_free,
	
	output reg [XLEN-1:0] out_operands [3:0],
	output reg [XLEN-1:0] out_rd,
	output reg [$clog(ALU_CODES_COUNT)-1:0] out_alu_code,
	output reg [1:0] out_mem_code,
	output reg [2:0] out_size_code,
	output reg [$clog(JUMPER_CODES_COUNT)-1:0] out_jumper_code,
	output out_ready_for_next_inst,
	output reg out_do_forward,
	
	output reg out_add_to_mem_controller_queue
);

reg [XLEN-1:0] x [XREG_COUNT-1:0]; // CPU Registers, the RISC-V x-registers
reg [XREG_COUNT-1:0] mem_holds;
wire [INSTRUCTION_LEN-1:0] NO_OP;
wire [INSTRUCTION_LEN-1:0] real_instruction, effective_instruction;
wire [$clog(XREG_COUNT)-1:0] real_rd, effective_rd, real_rs1, effective_rs1, real_rs2, effective_rs2;
wire [XLEN-1:0] rs1_data, rs2_data;
wire [OPCODE_LEN-1:0] real_opcode, effective_opcode;

wire hazard_rs1, hazard_rs2, hazard_rd;
wire R_hazard, I_hazard, S_hazard, U_hazard, J_hazard, B_hazard;
wire HAZ_data_dep, HAZ_mem, HAZ_bad_branch, HAZ_inst_already_execed;
wire can_forward, do_forward;
wire inst_xreg_writeback_capable;

wire [XLEN-1:0] I_imm, S_imm, U_imm, J_imm, B_imm;
wire I_shift_arith;
wire opcode_illegal;
wire is_mem_instruction;

wire [XLEN-1:0] operands [3:0];
wire [$clog(ALU_CODES_COUNT)-1:0] alu_code;
wire [$clog(MEM_CODES_COUNT)-1:0] mem_code;
wire [$clog(SIZE_CODES_COUNT)-1:0] size_code;
wire [$clog(JUMPER_CODES_COUNT)-1:0] jumper_code;
wire add_to_mem_controller_queue;

reg inst_dead;
wire kill_inst;



assign instruction_NO_OP = { {(INSTRUCTION_LEN-OPCODE_LEN){1'b0}}, OP_IMM };
assign stall = HAZ_data_dep || HAZ_mem || HAZ_bad_branch || HAZ_inst_already_execed;
assign inst_did_exec = !(HAZ_data_dep || HAZ_mem || HAZ_bad_branch);
assign real_instruction = instruction_in;
assign effective_instruction = stall ? instruction_NO_OP : real_instruction;

assign effective_opcode = effective_instruction[6:0];
assign effective_rd = inst_xreg_writeback_capable ? effective_instruction[11:7] : 0;
assign effective_rs1 = effective_instruction[19:15];
assign effective_rs2 = effective_instruction[24:20];

// x0 is hardwired to always output 0 when read
assign rs1_data = effective_rs1 ? x[real_rs1] : 0;
assign rs2_data = effective_rs2 ? x[real_rs2] : 0;

assign can_forward = real_rd == out_rd;
assign do_forward = can_forward && out_rd;

// ignore any hold placed on x0 when checking for potential hazards
assign hazard_rs1 = real_rs1 ? mem_holds[real_rs1] : 0;
assign hazard_rs2 = real_rs2 ? mem_holds[real_rs2] : 0;
assign hazard_rd = !can_forward && (real_rd ? mem_holds[real_rd] : 0);

// these potential hazards can be determined off of format alone, as the depend only on
// register locations encoded in the instruction
assign R_hazard = hazard_rs1 || hazard_rs2 || hazard_rd;
assign I_hazard = hazard_rs1 || hazard_rd;
assign S_hazard = hazard_rs1 || hazard_rs2;
assign B_hazard = S_hazard;
assign U_hazard = hazard_rd;
assign J_hazard = U_hazard;

assign is_mem_instruction = opcode == LOAD || opcode == STORE;

// assign the actual hazards that are in effect based on the real instruction
assign HAZ_mem = is_mem_instruction && mem_controller_closed;
assign HAZ_bad_branch = jumper_did_branch;
assign HAZ_inst_invalid = !valid_instruction_in;
always @(*) begin
	case (real_opcode)
		OP : HAZ_data_dep = R_hazard;
		JALR, LOAD, OP_IMM : HAZ_data_dep = I_hazard;
		STORE : HAZ_data_dep = S_hazard;
		BRANCH : HAZ_data_dep = B_hazard; 
		LUI, AUIPC: HAZ_data_dep = U_hazard;
		JAL : HAZ_data_dep = J_hazard;
		default : HAZ_data_dep = 0;
	endcase

	case (effective_opcode)
		STORE, BRANCH: inst_xreg_writeback_capable = 0;
		default: inst_xreg_writeback_capable = 1;
	endcase
end

assign kill_inst = !(HAZ_data_dep || HAZ_mem || HAZ_bad_branch);
assign out_ready_for_next_inst = kill_inst || inst_dead;
assign HAZ_inst_already_execed = inst_dead;

// _imm wires are set exactly as described in RISC-V Specifications for clarity
// (thats why for example I_imm doesnt just have instruction[30:20] after sign extension even though it is equivilent
// https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html#immtypes
assign I_imm = { {(XLEN-12){effective_instruction[31]}}, effective_instruction[30:25], effective_instruction[24:21], effective_instruction[20] }; 
assign S_imm = { {(XLEN-12){effective_instruction[31]}}, effective_instruction[30:25], effective_instruction[11:8], effective_instruction[7] };
assign B_imm = { {(XLEN-12){effective_instruction[31]}}, effective_instruction[7], effective_instruction[30:25], effective_instruction[11:8], 1'b0 };
assign U_imm = { {(XLEN-31){effective_instruction[31]}}, effective_instruction[30:20], effective_instruction[19:12], {12{0}} };
assign J_imm = { {(XLEN-20){effective_instruction[31]}}, effective_instruction[19:12], effective_instruction[20], effective_instruction[30:25], effective_instruction[24:21], 1'b0 }

assign I_shift_arith = effective_instruction[30];


always @(*) begin
case (effective_opcode)
        LUI: begin
		operands[0] = 0;
		operands[1] = U_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = ALU_AUI;
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 1;
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
		add_to_mem_controller_queue = 1;
		opcode_illegal = 0;
        end
        OP_IMM: begin 
		operands[0] = rs1_data;
		operands[1] = (funct3 == 1 || funct3 == 5) ? I_imm[4:0] : I_imm;
		operands[2] = 0;
		operands[3] = 0;
		alu_code = OP_IMM_alu_code(funct3, I_shift_arith);
		mem_code = MEM_INVALID;
		size_code = SIZE_INVALID;
		jumper_code = JUMP_INVALID;
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
		add_to_mem_controller_queue = 0;
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
	else if(force_alu_rd_free)
		mem_holds[alu_writeback_reg] <= 0;
	if(do_load_writeback) begin
		x[load_writeback_reg] <= load_writeback_data;
		mem_holds[load_writeback_reg] <= 0;
	end
	if(do_pc_writeback)
		pc <= pc_writeback_data;
		
	// SEND INSTRUCTION INTO PIPELINE
	out_operands[0] <= operands[0];
	out_operands[1] <= operands[1];
	out_operands[2] <= operands[2];
	out_operands[3] <= operands[3];
	out_rd <= effective_rd;

	out_alu_code <= alu_code;
	out_size_code <= size_hint;
	out_mem_code <= mem_hint;

	out_jumper_code <= jumper_code;
		
	out_add_to_mem_controller_queue <= add_to_mem_controller_queue;
	
	mem_holds[effective_rd] <= 1;
	
	if(out_ready_for_next_inst && next_inst_ready) begin
		inst_dead <= 0;
		if(!do_pc_writeback)
			pc <= pc+1; // do regular increment if a jump is not being written
	end
	else if(kill_inst)
		inst_dead <= 1;

	out_do_forward <= do_forward;
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

