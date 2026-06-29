
`timescale 1ns/1ps

module decoder #(
parameter XREG_COUNT = 32, 
parameter XLEN = 32,
parameter INSTRUCTION_LEN = 32
)(
input clk,
input [INSTRUCTION_LEN-1:0] instruction,
input [XLEN-1:0] x [XREG_COUNT-1:0],
input [XLEN-1:0] pc,
output reg [XLEN-1:0] operand_buf [1:0],
);

localparam R_TYPE = 7'b0110011
localparam I_TYPE = 7'b0010011
localparam S_TYPE = 7'b0100011
localparam U_TYPE = 7'b0110111

reg [XREG_COUNT-1:0] mem_holds;
reg blocking;

wire opcode [6:0];
wire rd [4:0];
wire rs1 [4:0];
wire rs2 [4:0];
wire imm [XLEN-1:0];

assign opcode = instruction[6:0];
assign rd = instruction[11:7];
assign rs1 = instruction[19:15];
assign rs2 = instruction[24:20];

always @(*)
	//decode immediate
	case (opcode)
		I_TYPE: imm = { {(XLEN-12){instruction[31]}} , instruction[31:20]}; 
		S_TYPE: imm = { {(XLEN-12){instruction[31]}}, instruction[31:25], instruction[11:7] };
		U_TYPE: imm = { {(XLEN_20){instruction[31]}}, instruction[31:20] };
		default: imm = 0;
	endcase
end

always @(posedge clk) begin

	case (opcode)
		R_TYPE: begin 
			if(mem_holds[rd] || mem_holds[rs1] || mem_holds[rs2]) begin
				blocking <= 1;
			end
			else begin
				blocking <= 0;
				mem_holds[rd] <= 1;
				operand_buf[0] <= x[rs1];
				operand_buf[1] <= x[rs2];
			end
		end
		I_TYPE: begin 
			if(mem_holds[rd] || mem_holds[rs1]) begin
				blocking <= 1;
			end
			else begin
				blocking <= 0;
				mem_holds[rd] <= 1;
				operand_buf[0] <= x[rs1];
				operand_buf[1] <= imm; 
			end
		end
		S_TYPE: begin
		       // stores value of rs2 to address rs1+imm
			if(mem_holds[rs1] || mem_holds[rs2]) begin
				blocking <= 1;
			end
			else begin
				blocking <= 0;
				operand_buf[0] <= x[rs1];
				operand_buf[1] <= imm;
			end
		end
		U_TYPE: begin 
			if(mem_holds[rd]) begin
				blocking <= 1;
			end
			else begin
				blocking <= 0;
				mem_holds[rd] <= 1;
				operand_buf[0] <= imm;
				operand_buf[1] <= pc;
			end
		end

		default: begin 
			// handle case of invalid opcode, maybe an exception?
		end
	endcase

end

function 

endmodule
