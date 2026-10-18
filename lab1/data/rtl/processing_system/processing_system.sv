module processing_system (
    input  logic        clk,
    input  logic        rst_n,

    input  logic        valid_in,
    input  logic [15:0] data_a,
    input  logic [15:0] data_b,
    input  logic [ 1:0] operation,

    input  logic        clear,
    input  logic [31:0] range_limit,

    output logic        result_valid,
    output logic [31:0] result,

    output logic [15:0] count,
    output logic [31:0] sum,
    output logic [31:0] min,
    output logic [31:0] max,

    output logic [31:0] range,
    output logic        range_exceeded
);

	logic        proc_stat_valid;
	logic [31:0] proc_stat_data;

	processing_unit inst_processing_unit (
   		.clk       (clk),
    	.rst_n     (rst_n),

    	.valid_in  (valid_in),
    	.data_a    (data_a),
		.data_b    (data_b),
    	.operation (operation),

		.valid_out (proc_stat_valid),
    	.result    (proc_stat_data)
	);

	statistics_unit inst_statistics_unit (
		.clk      (clk),
    	.rst_n    (rst_n),

    	.clear    (clear),
    	.valid_in (proc_stat_valid),
    	.data_in  (proc_stat_data),

    	.count    (count),
    	.sum      (sum),
		.min      (min),
    	.max      (max)
	);
	
	assign result_valid   = proc_stat_valid;
	assign result         = proc_stat_data;

	assign range 		  = max - min;
	assign range_exceeded = range > range_limit;

endmodule : processing_system