module statistics_unit 
(
    input  logic        clk,
    input  logic        rst_n,

    input  logic        clear,
    input  logic        valid_in,
    input  logic [31:0] data_in,

    output logic [15:0] count,
    output logic [31:0] sum,
    output logic [31:0] min,
    output logic [31:0] max
);

    logic [31:0] counter;
    logic [32:0] summator_ext;
    logic [31:0] summator;
    logic [31:0] min;
    logic [31:0] max;

    always_ff @(posedge clk) begin : count_ff
        if (!rst_n) begin
            counter <= '0;
        end

        else if (clear) begin
            counter <= '0;
        end

        else if (valid_in) begin
            counter <= counter + 32'b1;
        end
    end

    always_comb begin : sum_ext
        summator_ext = summator + data_in
    end

    always_ff @(posedge clk) begin : sum_ff
        if (!rst_n) begin
            summator <= '0;
        end

        else if (clear) begin
            summator <= '0;
        end

        else if (valid_in) begin
            summator <= (summator_ext[32]) ? '1 : summator_ext[31:0];
        end
    end

    always_ff @(posedge clk) begin : max_ff
        if (!rst_n) begin
            max <= '0;
        end

        else if (clear) begin
            max <= '0;
        end

        else if (valid_in) begin
            max <= (max < data_in) ? data_in : max;
        end
    end

    always_ff @(posedge clk) begin : min_ff
        if (!rst_n) begin
            min <= '0;
        end

        else if (clear) begin
            min <= '0;
        end
        
        else if (valid_in) begin
            min <= (min < data_in) ? data_in : min;
        end
    end

endmodule
