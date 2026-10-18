module processing_unit_wrapper (
	input  logic        clk,
    input  logic        rst_n,

    input  logic        valid_in,
    input  logic [15:0] data_a,
    input  logic [15:0] data_b,
    input  logic [1:0]  operation,

    output logic        valid_out,
    output logic [31:0] result
);

	logic        valid_in_ff;
	logic [15:0] data_a_ff;
	logic [15:0] data_b_ff;
	logic [ 1:0] operation_ff;

	always_ff @(posedge clk) begin : start_ff
		if (!rst_n) begin
			valid_in_ff  <= '0;
			data_a_ff    <= '0;
			data_b_ff    <= '0;
			operation_ff <= '0;
		end else begin
			valid_in_ff  <= valid_in;
			data_a_ff    <= data_a;
			data_b_ff    <= data_b;
			operation_ff <= operation;
		end
	end

	processing_unit inst_processing_unit (
   		.clk       (clk),
    	.rst_n     (rst_n),

    	.valid_in  (valid_in_ff),
    	.data_a    (data_a_ff),
		.data_b    (data_b_ff),
    	.operation (operation_ff),

		.valid_out (valid_out),
    	.result    (result)
	);

endmodule : processing_unit_wrapper