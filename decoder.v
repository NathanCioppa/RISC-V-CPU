
`timescale 1ns/1ps

module decoder #(
parameter XREG_COUNT = 32, 
parameter XLEN = 32,
parameter INSTRUCTION_LEN = 32
)(
input clk,
input [INSTRUCTION_LEN-1:0] instruction,
input [XLEN-1:0] x [XREG_COUNT-1:0],
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

assign opcode = instruction[6:0];
assign rd = instruction[11:7];
assign rs1 = instruction[19:15];
assign rs2 = instruction[24:20];

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
		I_TYPE: begin end
		S_TYPE: begin end
		U_TYPE: begin end

		default: begin end
	endcase

end

function 

endmodule
