
`timescale 1ns/1ps

`include "mem_codes.vh"
`include "size_codes.vh"

// Module will be changed eventually, currently just needs to be suitable for
// simulating a memory access.

module mem_controller #(
	parameter XLEN = 32,
	parameter XREG_COUNT = 32,
	parameter QUEUE_LEN = 8,
	parameter QUEUE_ITEM_SIZE = (2*XLEN) + $clog(SIZE_CODES_COUNT) + 1
)(
	input clk,

	input [$clog(XREG_COUNT)-1:0] rd,
	input [$clog(MEM_CODES_COUNT)-1:0] mem_code,
	input [$clog(SIZE_CODES_COUNT)-1:0] size_code,
	input [XLEN-1:0] addr, store_payload,
	input advance_queue,

	output reg [XLEN-1:0] out_data,
	output reg [$clog(XREG_COUNT)-1:0] out_rd,
	output reg [$clog(SIZE_CODE_COUNT)-1:0] out_size_code,
	output reg queue_full,
	output [QUEUE_ITEM_SIZE-1:0] next_request
);

integer i;

reg [QUEUE_LEN:0] queue_mark;
reg [QUEUE_ITEM_SIZE-1:0] queue [QUEUE_LEN-1:0];

wire [QUEUE_ITEM_SIZE-1:0] incoming_request;
wire [XLEN-1:0] payload;
wire [XLEN-$clog(XREG_COUNT):0] upper_payload, upper_store_payload;
wire [$clog(XREG_COUNT):0] lower_payload, lower_store_payload;
wire type;

assign {upper_store_payload, lower_store_payload} = store_payload;

assign upper_payload = upper_store_payload;
always @(*) begin
	case (mem_code) begin
		MEM_STORE: lower_payload = lower_store_payload;
		MEM_LOAD: lower_payload = { rd, 1'b1 };
		default: lower_payload = { rd, 1'b0 };
	endcase
end
assign payload = { upper_payload, lower_payload };
assign type = mem_code == MEM_STORE ? 1:0;

assign incoming_request = {addr, size_code, payload, type};

endmodule

