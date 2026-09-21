module processing_unit 
	import processing_pkg::*;
(
	input  logic        clk,
	input  logic        rst_n,

	input  logic        valid_in,
	input  logic [15:0] data_a,
	input  logic [15:0] data_b,
	input  logic [ 1:0] operation,

	output logic        valid_out,
	output logic [31:0] result
);

	wire [31:0] sum_res = data_a + data_b;
	wire [31:0] sub_res = data_a - data_b;
	wire [31:0] mul_res = data_a * data_b;
	wire [31:0] xor_res = data_a ^ data_b;

	always_ff (posedge clk) begin : valid_ff
		if (!rst_n) begin
			valid_out <= '0;
		end else begin
			valid_out <= valid_in;
		end
	end

	always_ff (posedge clk) begin : valid_ff 
		if (!rst_n) begin
			result <= '0;
		end else if (valid_in) begin
			case (operation_e'(operation))
				SUM : result <= sum_res;
				SUB : result <= sub_res;
				XOR : result <= xor_res;
				MUL : result <= mul_res;
			endcase
		end
	end

endmodule : processing_unit