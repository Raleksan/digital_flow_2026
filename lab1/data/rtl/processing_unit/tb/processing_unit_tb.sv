module processing_unit_tb;
    import processing_pkg::*;

    localparam int unsigned CLOCK_PERIOD = 10;
    localparam int unsigned RESET_DELAY  = 100;

    logic        clk;
    logic        rst_n;

    logic        valid_in;
    logic [15:0] data_a;
    logic [15:0] data_b;
    logic [ 1:0] operation;

    logic        valid_out;
    logic [31:0] result;

    // ------------------------------------------
    // DUT connection
    // ------------------------------------------

    processing_unit_wrapper DUT (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .data_a    (data_a),
        .data_b    (data_b),
        .operation (operation),
        .valid_out (valid_out),
        .result    (result)
    );

    // ------------------------------------------
    // Clock
    // ------------------------------------------

    initial begin
        clk = 0;
        forever #(CLOCK_PERIOD / 2) clk = ~clk;
    end

    // ------------------------------------------
    // Monitor
    // ------------------------------------------

    initial begin
        $monitor(
            $time,
            " | data_a = 'h%h, data_b = 'h%h, operation = 'b%b",
            " | valid_in = %b, valid_out = %b, result = 'h%h",
            data_a,
            data_b,
            operation,
            valid_in,
            valid_out,
            result
        );
    end

    // ------------------------------------------
    // Reset
    // ------------------------------------------

    initial begin
        rst_n      = 1'b0;
        valid_in   = 1'b0;
        data_a     = '0;
        data_b     = '0;
        operation  = '0;

        #(RESET_DELAY);

        rst_n = 1'b1;
    end

    // ------------------------------------------
    // Reference model
    // ------------------------------------------

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

    // ------------------------------------------
    // Test operation
    // ------------------------------------------

    task test_operation(
        input int unsigned num,
        input operation_e  op
    );

        bit        rand_valid;
        bit [15:0] rand_data_a;
        bit [15:0] rand_data_b;

        logic [31:0] expected_result;

        $display("");
        $display("==========================================");
        $display("Testing %s operation (num = %0d)", op.name(), num);
        $display("==========================================");

        for (int i = 0; i < num; i++) begin

            assert(std::randomize(
                rand_valid,
                rand_data_a,
                rand_data_b
            ) with {
                rand_valid dist {
                    1'b1 := 50,
                    1'b0 := 50
                };
            })
            else begin
                $fatal(1, "Randomization failed");
            end

            expected_result = calculate_result(
                rand_data_a,
                rand_data_b,
                op
            );

            // Drive inputs on the falling edge so that
            // they are stable before the next rising edge.
            @(negedge clk);

            valid_in  <= rand_valid;
            data_a    <= rand_data_a;
            data_b    <= rand_data_b;
            operation <= op;

            repeat(2) @(posedge clk);

            if (valid_out !== rand_valid) begin
                $error(
                    "valid_out mismatch: expected = %b, actual = %b",
                    rand_valid,
                    valid_out
                );
            end

            if (rand_valid && (result !== expected_result)) begin
                $error(
                    "%s result mismatch: a = 'h%h, b = 'h%h, " +
                    "expected = 'h%h, actual = 'h%h",
                    op.name(),
                    rand_data_a,
                    rand_data_b,
                    expected_result,
                    result
                );
            end

        end

    endtask : test_operation

    // ------------------------------------------
    // Reset test
    // ------------------------------------------

    task test_reset();

        $display("");
        $display("==========================================");
        $display("Testing reset");
        $display("==========================================");

        @(negedge clk);

        rst_n     <= 1'b0;
        valid_in  <= 1'b0;
        data_a    <= '0;
        data_b    <= '0;
        operation <= '0;

        repeat(2) @(posedge clk);

        if (valid_out !== 1'b0) begin
            $error(
                "Reset failed: valid_out = %b, expected = 0",
                valid_out
            );
        end

        if (result !== 32'b0) begin
            $error(
                "Reset failed: result = 'h%h, expected = 0",
                result
            );
        end

        @(negedge clk);
        rst_n <= 1'b1;

    endtask : test_reset

    // ------------------------------------------
    // MAIN
    // ------------------------------------------

    initial begin
        wait (rst_n === 1'b1);

        @(posedge clk);

        test_reset();

        test_operation(100, SUM);
        test_operation(100, SUB);
        test_operation(100, XOR);
        test_operation(100, MUL);

        $display("");
        $display("==========================================");
        $display("ALL TESTS FINISHED");
        $display("==========================================");

        $finish;
    end
endmodule