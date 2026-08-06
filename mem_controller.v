
`timescale 1ns/1ps

`include "mem_codes.vh"
`include "size_codes.vh"

// Module will be changed eventually, currently just needs to be suitable for
// simulating a memory access.

module mem_controller #(
	parameter XLEN = 32,
	parameter XREG_COUNT = 32,
	parameter MAX_QUEUE_SIZE = 8,
	parameter REQUEST_ITEM_SIZE = (2*XLEN) + $clog(SIZE_CODES_COUNT)
)(
	input clk,

	input [$clog(XREG_COUNT)-1:0] rd,
	input [$clog(MEM_CODES_COUNT)-1:0] mem_code,
	input [$clog(SIZE_CODES_COUNT)-1:0] size_code,
	input [XLEN-1:0] addr, store_payload,
	input request_read,
	input add_pending,

	output reg queue_full,
	output [REQUEST_ITEM_SIZE-1:0] out_request,
	output out_request_valid
);

reg [REQUEST_ITEM_SIZE-1:0] queue [MAX_QUEUE_SIZE-1:0];
reg [$clog(MAX_QUEUE_SIZE)-1:0] head, tail;
wire do_inc_head, do_inc_tail;
reg [$clog(MAX_QUEUE_SIZE):0] count_in_queue, count_pending add_to_count_in_queue, add_to_count_pending;
wire do_inc_count_in_queue, do_dec_count_in_queue, do_inc_count_pending, do_dec_count_pending;
wire queue_size;

wire [REQUEST_ITEM_SIZE-1:0] incoming_request;
wire [XLEN-1:0] payload;
wire [XLEN-$clog(XREG_COUNT):0] upper_payload, upper_store_payload;
wire [$clog(XREG_COUNT):0] lower_payload, lower_store_payload;
wire type;
wire incoming_request_valid;


assign queue_size = count_in_queue + count_pending;
assign queue_full = queue_size >= MAX_QUEUE_SIZE;

assign out_request = queue[head];
assign out_request_valid = count_in_queue != 0;

assign incoming_request_valid = mem_code != MEM_INVALID;

// figure out if the head needs to be incremented
assign do_inc_head = request_read;
// figure out how count_in_queue and count_pending should be modified
// ie. do they increment by 1, 0, or -1?
assign do_inc_count_in_queue = incoming_request_valid;
assign do_dec_count_in_queue = request_read;
assign do_inc_count_pending = add_pending;
assign do_dec_count_pending = incoming_request_valid;
// At the clock edge, the values of add_to_count_in_queue and
//  add_to_count_pending will always be added to count_in_queue and 
//  count_pending respectively.
always @(*) begin
	if(do_inc_count_in_queue && !do_dec_count_in_queue)
		add_to_count_in_queue = 1;
	else
	if(do_dec_count_in_queue && !do_inc_count_in_queue)
		add_to_count_in_queue = -1;
	else
		add_to_count_in_queue = 0;

	if(do_inc_count_pending && !do_dec_count_pending)
		add_to_count_pending = 1;
	else
	if(do_dec_count_pending && !do_inc_count_pending)
		add_to_count_pending = -1;
	else
		add_to_count_pending = 0;
end


// decode inputs to format the payload field
assign {upper_store_payload, lower_store_payload} = store_payload;
assign upper_payload = upper_store_payload;
assign lower_payload = mem_code == MEM_STORE ? lower_store_payload : rd;
assign payload = { upper_payload, lower_payload };
assign type = mem_code == MEM_STORE ? 1:0;
//encode the incoming request as a Queue Item
assign incoming_request = {addr, size_code, payload, type};

always @(posedge clk) begin
	if(do_inc_head)
		head <= head+1;

	if(incoming_request_valid) begin
		queue[tail] <= incoming_request;
		tail <= tail+1; // always increments when an item is added to queue
	end

	count_in_queue <= count_in_queue + add_to_count_in_queue;
	count_pending <= count_pending + add_to_count_pending;

end

endmodule

