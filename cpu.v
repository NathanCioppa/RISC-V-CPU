
`timescale 1ns/1ps

module cpu #(
parameter XREG_COUNT = 32; // Number of x registers, including the hardwired x0 register
parameter XLEN = 32; // 32 for RV32I
)(
input [31:0] instruction,
input clk,
output reg [XLEN-1:0] operand_buf [1:0]
output reg [XLEN-1:0] opcode,
output reg [XLEN-1:0] funct3,
output reg [XLEN-1:0] funct7,
);

// ############### RISC-V Required Specs ###############

reg [XLEN-1:0] x [XREG_COUNT-1:0]; // x registers
reg [XLEN-1:0] pc; // additional program counter register

assign x[0] = 0; // register x0 is hardwired with all bits equal to 0

// #####################################################

reg [XREG_COUNT-1:0] mem_holds;
reg blocking;

always @(posedge clk) begin


end

endmodule
