module processing_system_tb;

    // ------------------------------------------------------------------------
    // Parameters
    // ------------------------------------------------------------------------

    localparam int CLK_PERIOD  = 10;
    localparam int RESET_DELAY = 100;
    localparam int TEST_NUM    = 1000;

    // ------------------------------------------------------------------------
    // Operation encoding
    // ------------------------------------------------------------------------

    typedef enum logic [1:0] {
        SUM = 2'b00,
        SUB = 2'b01,
        XOR = 2'b10,
        MUL = 2'b11
    } operation_e;

    // ------------------------------------------------------------------------
    // DUT signals
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

    // ------------------------------------------------------------------------
    // Reference model
    // ------------------------------------------------------------------------

    logic [15:0] ref_count;
    logic [31:0] ref_sum;
    logic [31:0] ref_min;
    logic [31:0] ref_max;
    logic        ref_has_data;

    logic [31:0] ref_range;
    logic        ref_range_exceeded;

    integer error_count;

    // ------------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------------

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
    // Clock generation
    // ------------------------------------------------------------------------

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // ------------------------------------------------------------------------
    // Reference-model tasks
    // ------------------------------------------------------------------------

    task reset_reference();
        begin
            ref_count    = 16'h0000;
            ref_sum      = 32'h0000_0000;
            ref_min      = 32'hFFFF_FFFF;
            ref_max      = 32'h0000_0000;
            ref_has_data = 1'b0;
        end
    endtask


    task update_statistics(
        input logic [31:0] value
    );
        begin
            // Count saturates at 16'hFFFF.
            if (ref_count != 16'hFFFF)
                ref_count = ref_count + 1'b1;

            // Sum saturates at 32'hFFFF_FFFF.
            if (value > (32'hFFFF_FFFF - ref_sum))
                ref_sum = 32'hFFFF_FFFF;
            else
                ref_sum = ref_sum + value;

            // The first valid sample initializes both min and max.
            if (!ref_has_data) begin
                ref_min      = value;
                ref_max      = value;
                ref_has_data = 1'b1;
            end
            else begin
                if (value < ref_min)
                    ref_min = value;

                if (value > ref_max)
                    ref_max = value;
            end
        end
    endtask


    // ------------------------------------------------------------------------
    // Expected processing result
    // ------------------------------------------------------------------------

    function automatic logic [31:0] calculate_result(
        input logic [15:0] a,
        input logic [15:0] b,
        input operation_e  op
    );
        begin
            case (op)
                SUM: calculate_result = {16'b0, a} + {16'b0, b};
                SUB: calculate_result = {16'b0, a} - {16'b0, b};
                XOR: calculate_result = {16'b0, a} ^ {16'b0, b};
                MUL: calculate_result = {16'b0, a} * {16'b0, b};

                default: calculate_result = 32'b0;
            endcase
        end
    endfunction


    // ------------------------------------------------------------------------
    // Output checking
    // ------------------------------------------------------------------------

    task check_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string       signal_name
    );
        begin
            if (actual !== expected) begin
                error_count = error_count + 1;

                $error(
                    "[%0t] %s mismatch: actual = 0x%08h, expected = 0x%08h",
                    $time,
                    signal_name,
                    actual,
                    expected
                );
            end
        end
    endtask


    task check_statistics();
        begin
            // According to the specification, the range is zero until
            // the first valid sample has been accepted.
            if (ref_has_data)
                ref_range = ref_max - ref_min;
            else
                ref_range = 32'b0;

            ref_range_exceeded = (ref_range > range_limit);

            check_value(
                {16'b0, count},
                {16'b0, ref_count},
                "count"
            );

            check_value(
                sum,
                ref_sum,
                "sum"
            );

            check_value(
                min,
                ref_min,
                "min"
            );

            check_value(
                max,
                ref_max,
                "max"
            );

            check_value(
                range,
                ref_range,
                "range"
            );

            check_value(
                {31'b0, range_exceeded},
                {31'b0, ref_range_exceeded},
                "range_exceeded"
            );
        end
    endtask


    // ------------------------------------------------------------------------
    // Reset test
    // ------------------------------------------------------------------------

    task test_reset();
        begin
            $display("[%0t] Starting reset test", $time);

            // Assert synchronous reset away from the active clock edge.
            @(posedge clk);
            rst_n       = 1'b0;
            valid_in    = 1'b0;
            data_a      = 16'b0;
            data_b      = 16'b0;
            operation   = SUM;
            clear       = 1'b0;
            range_limit = 32'hFFFF_FFFF;

            reset_reference();

            // Allow the DUT to sample reset on a positive edge.
            @(posedge clk);

            check_value(
                {31'b0, result_valid},
                32'b0,
                "result_valid after reset"
            );

            check_statistics();

            // Release reset away from the active clock edge.
            @(posedge clk);
            rst_n = 1'b1;

            $display("[%0t] Reset test completed", $time);
        end
    endtask


    // ------------------------------------------------------------------------
    // Single transaction
    //
    // Inputs are driven using nonblocking assignments on a positive edge.
    // Therefore, the DUT samples those inputs on the NEXT positive edge.
    //
    // Timeline:
    //
    //   P0: Testbench schedules new input values using <=.
    //   P1: Processing unit accepts the inputs; clear is sampled.
    //   N1: Check processing result and the effect of clear.
    //   P2: Statistics unit consumes the registered processing result.
    //   N2: Check the updated statistics.
    //
    // No #1 delay or clocking block is required.
    // ------------------------------------------------------------------------

    task run_transaction(
        input logic        rand_valid,
        input logic [15:0] rand_data_a,
        input logic [15:0] rand_data_b,
        input operation_e  rand_operation,
        input logic        rand_clear,
        input logic [31:0] rand_range_limit
    );

        logic [31:0] expected_result;

        begin
            expected_result = calculate_result(
                rand_data_a,
                rand_data_b,
                rand_operation
            );

            // P0: Drive inputs. The DUT sees these values on the next
            // positive edge because these are nonblocking assignments.
            @(posedge clk);

            valid_in    <= rand_valid;
            data_a      <= rand_data_a;
            data_b      <= rand_data_b;
            operation   <= rand_operation;
            clear       <= rand_clear;
            range_limit <= rand_range_limit;

            // P1: The processing unit samples the new inputs.
            // The statistics unit samples clear on this same edge.
            @(posedge clk);

            // Deassert valid and clear after the DUT has sampled them.
            // The processing result remains registered and can be consumed
            // by the statistics unit on the following positive edge.
            valid_in <= 1'b0;
            clear    <= 1'b0;

            // N1: Registered processing outputs and statistics are stable.
            @(posedge clk);

            check_value(
                {31'b0, result_valid},
                {31'b0, rand_valid},
                "result_valid"
            );

            if (rand_valid) begin
                check_value(
                    result,
                    expected_result,
                    "result"
                );
            end

            // clear has priority over the statistics input at P1.
            // Update the reference model before checking the outputs.
            if (rand_clear)
                reset_reference();

            // At P1, statistics_unit sees the previous registered
            // processing result, not the result just produced at P1.
            check_statistics();

            // P2: statistics_unit consumes the processing result
            // registered at P1. clear is now low.
            @(posedge clk);

            if (rand_valid)
                update_statistics(expected_result);

            // N2: Check the statistics after their nonblocking updates.

            check_statistics();
        end
    endtask


    // ------------------------------------------------------------------------
    // Directed tests
    // ------------------------------------------------------------------------

    task test_directed_operations();
        begin
            $display("[%0t] Starting directed tests", $time);

            // Basic arithmetic operations.
            run_transaction(
                1'b1, 16'd10, 16'd5, SUM, 1'b0, 32'd100
            );

            run_transaction(
                1'b1, 16'd10, 16'd5, SUB, 1'b0, 32'd100
            );

            run_transaction(
                1'b1, 16'hAAAA, 16'h5555, XOR, 1'b0, 32'd100
            );

            run_transaction(
                1'b1, 16'd100, 16'd200, MUL, 1'b0, 32'd100
            );

            // Invalid input must not update statistics.
            run_transaction(
                1'b0, 16'd123, 16'd456, SUM, 1'b0, 32'd100
            );

            // Clear statistics while a new operation is accepted.
            // The operation's result should be counted on the following
            // statistics cycle after clear has been deasserted.
            run_transaction(
                1'b1, 16'd20, 16'd30, SUM, 1'b1, 32'd100
            );

            // Check range-limit comparison.
            run_transaction(
                1'b1, 16'd100, 16'd0, SUM, 1'b0, 32'd10
            );

            run_transaction(
                1'b1, 16'd1, 16'd1, SUM, 1'b0, 32'd1000
            );

            $display("[%0t] Directed tests completed", $time);
        end
    endtask


    // ------------------------------------------------------------------------
    // Random tests
    // ------------------------------------------------------------------------

    task test_random_operations();

        logic        rand_valid;
        logic [15:0] rand_data_a;
        logic [15:0] rand_data_b;
        operation_e  rand_operation;
        logic        rand_clear;
        logic [31:0] rand_range_limit;

        integer i;

        begin
            $display(
                "[%0t] Starting random tests: %0d transactions",
                $time,
                TEST_NUM
            );

            for (i = 0; i < TEST_NUM; i = i + 1) begin

                rand_valid      = $urandom_range(0, 1);
                rand_data_a     = $urandom;
                rand_data_b     = $urandom;
                rand_operation  = operation_e'($urandom_range(0, 3));

                // Approximately 10% of transactions request a clear.
                rand_clear      = ($urandom_range(0, 9) == 0);

                rand_range_limit = $urandom;

                run_transaction(
                    rand_valid,
                    rand_data_a,
                    rand_data_b,
                    rand_operation,
                    rand_clear,
                    rand_range_limit
                );
            end

            $display("[%0t] Random tests completed", $time);
        end
    endtask


    // ------------------------------------------------------------------------
    // Main test sequence
    // ------------------------------------------------------------------------

    initial begin
        error_count = 0;

        rst_n       = 1'b0;
        valid_in    = 1'b0;
        data_a      = 16'b0;
        data_b      = 16'b0;
        operation   = SUM;
        clear       = 1'b0;
        range_limit = 32'hFFFF_FFFF;

        reset_reference();

        // Hold reset for the specified duration.
        #(RESET_DELAY);

        // Release reset away from the active clock edge.
        @(posedge clk);
        rst_n = 1'b1;

        // Verify the reset state.
        @(posedge clk);
        check_value(
            {31'b0, result_valid},
            32'b0,
            "result_valid after initial reset"
        );
        check_statistics();

        // Run directed and randomized tests.
        test_directed_operations();
        test_random_operations();

        // Verify reset during operation of the testbench.
        test_reset();

        // Run a few transactions after reset to check recovery.
        run_transaction(
            1'b1, 16'd7, 16'd8, SUM, 1'b0, 32'd100
        );

        run_transaction(
            1'b1, 16'd3, 16'd2, MUL, 1'b0, 32'd100
        );

        // Final report.
        if (error_count == 0) begin
            $display("");
            $display("========================================");
            $display(" ALL TESTS PASSED");
            $display("========================================");
        end
        else begin
            $display("");
            $display("========================================");
            $display(" TESTS FAILED: %0d errors", error_count);
            $display("========================================");

            $fatal(1, "processing_system_tb failed");
        end

        $finish;
    end

endmodule
