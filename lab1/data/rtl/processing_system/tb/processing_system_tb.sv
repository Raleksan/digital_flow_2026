module processing_system_tb;
    import processing_pkg::*;

    localparam int unsigned CLK_PERIOD = 10;
    localparam int unsigned RESET_DELAY  = 100;
    localparam int unsigned TEST_NUM   = 1000;

    int error_count;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

    logic        clk;
    logic        rst_n;

    logic        valid_in;
    logic [15:0] data_a;
    logic [15:0] data_b;
    logic [1:0]  operation;

    logic        clear;
    logic [31:0] range_limit;

    logic        result_valid;
    logic [31:0] result;

    logic [15:0] count;
    logic [31:0] sum;
    logic [31:0] min;
    logic [31:0] max;

    logic [31:0] range;
    logic        range_exceeded;

    processing_system dut (
        .clk            (clk),
        .rst_n          (rst_n),

        .valid_in       (valid_in),
        .data_a         (data_a),
        .data_b         (data_b),
        .operation      (operation),

        .clear          (clear),
        .range_limit    (range_limit),

        .result_valid   (result_valid),
        .result         (result),

        .count          (count),
        .sum            (sum),
        .min            (min),
        .max            (max),

        .range          (range),
        .range_exceeded (range_exceeded)
    );


    // ------------------------------------------------------------------------
    // Clock
    // ------------------------------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Reset
    // ------------------------------------------------------------------------

    initial begin
        rst_n = 1'b0;

        error_count = '0;
        valid_in    = 1'b0;
        data_a      = '0;
        data_b      = '0;
        operation   = '0;
        clear       = 1'b0;
        range_limit = 32'hFFFF_FFFF;
        reset_reference();

        #(RESET_DELAY);

        rst_n = 1'b1;
    end

    // ------------------------------------------------------------------------
    // Reference Model
    // ------------------------------------------------------------------------

    logic [15:0] ref_count;
    logic [31:0] ref_sum;
    logic [31:0] ref_min;
    logic [31:0] ref_max;
    logic [32:0] ref_sum_ext;

    function logic [31:0] calculate_result(
        input logic [15:0] a,
        input logic [15:0] b,
        input operation_e  op
    );
        case (op)
            SUM: calculate_result = a + b;
            SUB: calculate_result = a - b;
            XOR: calculate_result = a ^ b;
            MUL: calculate_result = a * b;

            default: calculate_result = '0;
        endcase
    endfunction : calculate_result

    task reset_reference();
        ref_count = '0;
        ref_sum   = '0;
        ref_min   = '1;
        ref_max   = '0;
    endtask : reset_reference

    task update_statistics(input logic [31:0] data);
        ref_sum_ext = {1'b0, ref_sum} + {1'b0, data};

        if (&ref_count) begin
            ref_count = 16'hFFFF;
        end else begin
            ref_count = ref_count + 16'd1;
        end

        if (ref_sum_ext[32]) begin
            ref_sum = 32'hFFFF_FFFF;
        end else begin
            ref_sum = ref_sum_ext[31:0];
        end

        if (ref_min > data) begin
            ref_min = data;
        end

        if (ref_max < data) begin
            ref_max = data;
        end
    endtask : update_statistics

    // ------------------------------------------------------------------------
    // Check statistics
    // ------------------------------------------------------------------------

    function void check_value (
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string name
    );
        if (actual !== expected) begin
            $error(
                "%s mismatch: actual=0x%0h expected=0x%0h",
                name,
                actual,
                expected
                );
            error_count++;
        end
    endfunction : check_value

    task check_statistics();
        logic        expected_range_exceeded;
        logic [31:0] expected_range;

        expected_range          = ref_max - ref_min;
        expected_range_exceeded = expected_range > range_limit;

        check_value(count, ref_count, "count");
        check_value(sum, ref_sum, "sum");
        check_value(min, ref_min, "min");
        check_value(max, ref_max, "max");
        check_value(range, expected_range, "range");
        check_value(range_exceeded, expected_range_exceeded, "range_exceeded");
    endtask : check_statistics

    // ------------------------------------------------------------------------
    // Randomized processing test
    // ------------------------------------------------------------------------

    task test_random_operations();
        logic        rand_valid;
        logic [15:0] rand_data_a;
        logic [15:0] rand_data_b;
        operation_e  rand_operation;
        logic        rand_clear;
        logic [31:0] rand_range_limit;

        logic [31:0] expected_result;

        // Step 1. Generate transaction
        assert(std::randomize(
            rand_valid,
            rand_data_a,
            rand_data_b,
            rand_operation,
            rand_clear,
            rand_range_limit
        ) with {
            rand_valid dist { 1'b1 := 50, 1'b0 := 50 };
        })
        else begin
            $fatal("Randomization failed");
        end

        // Calculate expected result
        expected_result = calculate_result(
            rand_data_a,
            rand_data_b,
            rand_operation
        );

        // Step 2. Drive inputs
        @(negedge clk);
        valid_in    = rand_valid;
        data_a      = rand_data_a;
        data_b      = rand_data_b;
        operation   = rand_operation;
        clear       = rand_clear;
        range_limit = rand_range_limit;

        // Step 3. Wait for processing result
        @(posedge clk);
        @(negedge clk);

        // Step 4. Compare
        check_value(result_valid, rand_valid, "result_valid");

        if (rand_valid) begin
            check_value(result, expected_result, "result");
        end

        // Update reference model
        if (rand_clear) begin
            reset_reference();
        end else if (rand_valid) begin
            update_statistics(expected_result);
        end

        // Check statistics
        check_statistics();

        // Step 5. End input pulse
        valid_in = 1'b0;
    endtask : test_random_operations

    // ------------------------------------------------------------------------
    // Direct tests
    // ------------------------------------------------------------------------

    task test_reset();
        @(negedge clk);
        rst_n = 1'b0;

        repeat (2) @(posedge clk);

        check_value(result_valid, 1'b0,          "result_valid");
        check_value(count,       16'h0000,       "count");
        check_value(sum,         32'h0000_0000,  "sum");
        check_value(min,         32'hFFFF_FFFF,  "min");
        check_value(max,         32'h0000_0000,  "max");

        rst_n = 1'b1;
    endtask : test_reset

    task test_clear();
        @(negedge clk);
        clear = 1'b1;

        @(negedge clk);
        clear = 1'b0;

        reset_reference();
        check_statistics();
    endtask : test_clear

    task test_clear_priority();
        @(negedge clk);

        valid_in  = 1'b1;
        data_a    = 16'd100;
        data_b    = 16'd200;
        operation = SUM;
        clear     = 1'b1;

        @(negedge clk);

        clear    = 1'b0;
        valid_in = 1'b0;

        // clear has priority over valid_in
        reset_reference();
        check_statistics();
    endtask : test_clear_priority

    // ------------------------------------------------------------------------
    // MAIN
    // ------------------------------------------------------------------------

    initial begin
        wait (rst_n === 1'b1);
        @(posedge clk);
        
        // Tests
        test_reset();
        test_random_operations();
        test_clear();
        test_clear_priority();
        
        // Finish
        @(negedge clk);

        if (error_count == 0) begin
            $display("");
            $display("==========================================");
            $display(" PROCESSING_SYSTEM TEST PASSED");
            $display(" RANDOM TESTS: %0d", TEST_NUM);
            $display("==========================================");
        end
        else begin
            $display("");
            $display("==========================================");
            $display(
                " PROCESSING_SYSTEM TEST FAILED: %0d errors",
                error_count
            );
            $display("==========================================");
        end
        $finish;
    end
endmodule : processing_system_tb