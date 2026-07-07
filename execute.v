
`timescale 1ns/1ps

module execute #(
parameter XLEN = 32,
parameter XREG_COUNT = 32
)(
input clk,
input [XLEN-1:0] operands [1:0],
input [6:0] opcode,
input [2:0] funct3,
input [6:0] funct7,
input [$clog(XREG_COUNT)-1:0] rd_in,
input stall_in,
output [XLEN-1:0] result,
output stall_out,
output rd_out,
output to_mem
);

localparam R_TYPE = 7'b0110011;
localparam I_TYPE = 7'b0010011;
localparam S_TYPE = 7'b0100011;
localparam U_TYPE = 7'b0x10111;

always @(posedge clk) begin
	case (opcode) begin
		R_TYPE: case (funct3) begin
			0: 
		endcase
		I_TYPE: case (funct3) begin

		endcase
		S_TYPE: case (funct3) begin

		endcase
		U_TYPE: case (opcode[5]) begin
		
		endcase	
	endcase
end

endmodule
