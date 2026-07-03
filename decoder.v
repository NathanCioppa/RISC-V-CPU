
`timescale 1ns/1ps

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
output reg [XLEN-1:0] pass_opcode,
output reg [2:0] pass_funct3,
output reg [4:0] pass_funct5,
output reg [6:0] pass_funct7
);

localparam R_TYPE = 7'b0110011
localparam I_TYPE = 7'b0010011
localparam S_TYPE = 7'b0100011
localparam U_TYPE = 7'b0110111

reg [XLEN-1:0] x [XREG_COUNT-1:0]; // CPU Registers, the RISC-V x-registers
reg [XREG_COUNT-1:0] mem_holds;
reg blocking;

wire opcode [6:0];
wire [$clog(XREG_COUNT)-1:0] rd, rs1, rs2;
wire [XLEN-1:0] rs1_data, rs2_data;
wire hazard, hazard_rs1, hazard_rs2, hazard_rd;
wire [XLEN-1:0] imm;

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

always @(*)
	//decode immediate and detect hazard for the current instrucion
	case (opcode)
		R_TYPE: begin
			imm = 0;
			hazard = hazard_rs1 || hazard_rs2 || hazard_rd;
		end
		I_TYPE: begin 
			imm = { {(XLEN-12){instruction[31]}} , instruction[31:20]}; 
			hazard = hazard_rs1 || hazard_rd;
		end
		S_TYPE: begin 
			imm = { {(XLEN-12){instruction[31]}}, instruction[31:25], instruction[11:7] };
			hazard = hazard_rs1 || hazard_rs2;
		end
		U_TYPE: begin 
			imm = { {(XLEN_20){instruction[31]}}, instruction[31:20] };
			hazard = hazard_rd;
		end 
		default: begin
			imm = 0;
			hazard = 0;
		end
	endcase
end

always @(posedge clk) begin

	// WRITEBACK
	mem_holds[writeback_reg] <= writeback_data

	// DECODE
	if (hazard) begin
		blocking <= 1;
	end
	else begin
		case (opcode)
			R_TYPE: begin 
				blocking <= 0;
				mem_holds[rd] <= 1;
				operand_buf[0] <= rs1_data;
				operand_buf[1] <= rs2_data;
			end
			I_TYPE: begin 
				blocking <= 0;
				mem_holds[rd] <= 1;
				operand_buf[0] <= rs1_data;
				operand_buf[1] <= imm; 
			end
			S_TYPE: begin
			       // stores value of rs2 to address rs1+imm
				blocking <= 0;
				operand_buf[0] <= rs1_data;
				operand_buf[1] <= imm;
			end
			U_TYPE: begin 
				blocking <= 0;
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

endmodule
