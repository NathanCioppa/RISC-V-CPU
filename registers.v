module registers #(
parameter XLEN=32,
parameter REG_COUNT=32,
)(
input clk,
input [$clog(REG_COUNT)-1:0] writeback_reg,
input [XLEN-1:0] x_writeback_data,
input pc_writeback_data,
output reg [XLEN-1:0] x [REG_COUNT-1:0],
output reg [XLEN-1:0] pc
)

assign x[0] = 0;

always @(posedge clk) begin
	pc <= pc_writeback_data;
	if(writeback_reg) // since x0 is hardwired to 0
		x[writeback_reg] <= x_writeback_data;
end

endmodule
