`timescale 1ns/1ps

module statistics_unit_tb;

    localparam int CLK_PERIOD  = 10;
    localparam int RAND_CYCLES = 10000;

    logic        clk;
    logic        rst_n;

    logic        clear;
    logic        valid_in;
    logic [31:0] data_in;

    logic [15:0] count;
    logic [31:0] sum;
    logic [31:0] min;
    logic [31:0] max;

    statistics_unit dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .clear    (clear),
        .valid_in (valid_in),
        .data_in  (data_in),
        .count    (count),
        .sum      (sum),
        .min      (min),
        .max      (max)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // VCD dump
    initial begin
        $dumpfile("statistics_unit_tb.vcd");
        $dumpvars(0, statistics_unit_tb);
    end

    // ========================================================
    // Reference model
    // ========================================================
    // Independent implementation: uses has_data flag instead of
    // initialising min/max with '1/'0 as the RTL does.

    logic [15:0] exp_count;
    logic [31:0] exp_sum;
    logic [31:0] exp_min;
    logic [31:0] exp_max;
    logic        has_data;

    logic [32:0] exp_sum_ext;

    assign exp_sum_ext = {1'b0, exp_sum} + {1'b0, data_in};

    always @(posedge clk) begin : ref_model
        if (!rst_n || clear) begin
            exp_count <= '0;
            exp_sum   <= '0;
            exp_min   <= '0;
            exp_max   <= '0;
            has_data  <= 1'b0;
        end
        else if (valid_in) begin
            exp_count <= (exp_count == 16'hFFFF)  ? 16'hFFFF      : exp_count + 16'd1;
            exp_sum   <= (exp_sum_ext[32])        ? 32'hFFFF_FFFF : exp_sum_ext[31:0];

            if (!has_data || data_in < exp_min) exp_min <= data_in;
            if (!has_data || data_in > exp_max) exp_max <= data_in;

            has_data <= 1'b1;
        end
    end

    // ========================================================
    // Checker: compares DUT with the model on every cycle
    // ========================================================

    int    errors    = 0;
    int    checks    = 0;
    bit    check_en  = 0;   // enabled after the first reset
    string test_name = "init";

    task automatic report_error(string what, logic [31:0] act, logic [31:0] exp);
        errors++;
        $display("[ERROR] %0t ns | %s | %s: expected 0x%08h, got 0x%08h",
                 $time, test_name, what, exp, act);
    endtask

    always @(negedge clk) begin : cycle_checker
        if (check_en) begin
            checks++;

            if (count !== exp_count) report_error("count (model)", 32'(count), 32'(exp_count));
            if (sum   !== exp_sum)   report_error("sum (model)",   sum,         exp_sum);

            // min/max are meaningful only after the first accepted value
            if (has_data) begin
                if (min !== exp_min) report_error("min (model)", min, exp_min);
                if (max !== exp_max) report_error("max (model)", max, exp_max);
            end
        end
    end

    // Explicit check against hand-calculated values (cross-checks the model)
    task automatic expect_stats(
        input logic [15:0] e_count,
        input logic [31:0] e_sum,
        input logic [31:0] e_min,
        input logic [31:0] e_max,
        input bit          check_minmax = 1
    );
        if (count !== e_count) report_error("count", 32'(count), 32'(e_count));
        if (sum   !== e_sum)   report_error("sum",   sum,         e_sum);

        if (check_minmax) begin
            if (min !== e_min) report_error("min", min, e_min);
            if (max !== e_max) report_error("max", max, e_max);
        end
    endtask

    // ========================================================
    // Assertions
    // ========================================================

    task automatic assert_failed(string name);
        errors++;
        $display("[ERROR] %0t ns | %s | assertion %s failed", $time, test_name, name);
    endtask

    // min <= max whenever at least one value has been accepted
    a_min_le_max: assert property (
        @(posedge clk) disable iff (!check_en)
        (count != 0) |-> (min <= max)
    ) else assert_failed("a_min_le_max");

    // count never decreases without clear/reset
    a_count_monotonic: assert property (
        @(posedge clk) disable iff (!check_en)
        (rst_n && !clear) |=> (count >= $past(count))
    ) else assert_failed("a_count_monotonic");

    // saturated sum holds until clear/reset
    a_sum_sat_hold: assert property (
        @(posedge clk) disable iff (!check_en)
        (rst_n && !clear && sum == 32'hFFFF_FFFF) |=> (sum == 32'hFFFF_FFFF)
    ) else assert_failed("a_sum_sat_hold");

    // saturated count holds until clear/reset
    a_count_sat_hold: assert property (
        @(posedge clk) disable iff (!check_en)
        (rst_n && !clear && count == 16'hFFFF) |=> (count == 16'hFFFF)
    ) else assert_failed("a_count_sat_hold");

    // ========================================================
    // Driver tasks
    // ========================================================
    // Each task is called at negedge, sets inputs, and returns at the
    // next negedge, so the DUT outputs already reflect the operation.

    task automatic drive(bit v, bit c, logic [31:0] d, bit r = 1'b1);
        rst_n    = r;
        valid_in = v;
        clear    = c;
        data_in  = d;
        @(negedge clk);
    endtask

    task automatic send(logic [31:0] d);
        drive(1'b1, 1'b0, d);
    endtask

    task automatic idle(int n = 1);
        repeat (n) drive(1'b0, 1'b0, $urandom());
    endtask

    task automatic do_clear(bit v = 1'b0, logic [31:0] d = $urandom());
        drive(v, 1'b1, d);
    endtask

    task automatic do_reset(int n = 1, bit v = 1'b0, logic [31:0] d = $urandom());
        repeat (n) drive(v, 1'b0, d, 1'b0);
    endtask

    task automatic start_test(string name);
        test_name = name;
        $display("---- %s", name);
    endtask

    // Random data biased towards corner values
    function automatic logic [31:0] rand_data();
        int kind;
        kind = $urandom_range(0, 9);
        case (kind)
            0:       return 32'h0000_0000;
            1:       return 32'h0000_0001;
            2:       return 32'hFFFF_FFFF;
            3:       return 32'hFFFF_FFFE;
            4, 5:    return 32'($urandom_range(0, 255));
            6:       return {16'hFFFF, 16'($urandom())};
            default: return $urandom();
        endcase
    endfunction

    // ========================================================
    // Test sequence
    // ========================================================

    initial begin
        int err_before;

        rst_n    = 1'b0;
        clear    = 1'b0;
        valid_in = 1'b0;
        data_in  = '0;

        $display("========================================");
        $display("Starting statistics_unit test");
        $display("========================================");

        @(negedge clk);

        // ----------------------------------------------------
        // Test 1: Reset
        // ----------------------------------------------------
        start_test("T1 reset");
        do_reset(2);
        check_en = 1;
        expect_stats(0, 0, 0, 0, 0);

        // reset has priority over valid_in and clear
        send(32'd10);
        send(32'd20);
        expect_stats(2, 30, 10, 20);
        do_reset(1, 1'b1, 32'd99);
        expect_stats(0, 0, 0, 0, 0);
        drive(1'b1, 1'b1, 32'd99, 1'b0);
        expect_stats(0, 0, 0, 0, 0);

        // ----------------------------------------------------
        // Test 2: Accumulation of count and sum (back-to-back)
        // ----------------------------------------------------
        start_test("T2 count/sum accumulation");
        send(32'd10);  expect_stats(1, 10, 10, 10);
        send(32'd3);   expect_stats(2, 13,  3, 10);
        send(32'd7);   expect_stats(3, 20,  3, 10);
        send(32'd3);   expect_stats(4, 23,  3, 10);
        send(32'd20);  expect_stats(5, 43,  3, 20);

        // ----------------------------------------------------
        // Test 3: min / max detection
        // ----------------------------------------------------
        start_test("T3 min/max");
        do_clear();
        for (int i = 1; i <= 5; i++) send(32'(i * 100));     // rising
        expect_stats(5, 1500, 100, 500);

        do_clear();
        for (int i = 5; i >= 1; i--) send(32'(i * 100));     // falling
        expect_stats(5, 1500, 100, 500);

        do_clear();
        repeat (4) send(32'd42);                             // equal
        expect_stats(4, 168, 42, 42);

        do_clear();
        send(32'hDEAD_BEEF);                                 // single value
        expect_stats(1, 32'hDEAD_BEEF, 32'hDEAD_BEEF, 32'hDEAD_BEEF);

        // ----------------------------------------------------
        // Test 4: First value after clear / reset sets min and max
        // ----------------------------------------------------
        start_test("T4 first value after clear/reset");
        do_clear();
        send(32'd5);
        send(32'd100);
        expect_stats(2, 105, 5, 100);
        do_clear();
        expect_stats(0, 0, 0, 0, 0);
        send(32'd50);                                        // between old min and max
        expect_stats(1, 50, 50, 50);

        do_reset();
        send(32'd50);
        expect_stats(1, 50, 50, 50);

        // corner first values: 0 and all-ones
        do_clear();
        send(32'h0000_0000);
        expect_stats(1, 0, 0, 0);
        send(32'd5);
        expect_stats(2, 5, 0, 5);

        do_clear();
        send(32'hFFFF_FFFF);
        expect_stats(1, 32'hFFFF_FFFF, 32'hFFFF_FFFF, 32'hFFFF_FFFF);
        send(32'd7);
        expect_stats(2, 32'hFFFF_FFFF, 32'd7, 32'hFFFF_FFFF);

        // ----------------------------------------------------
        // Test 5: valid_in = 0 does not change statistics
        // ----------------------------------------------------
        start_test("T5 hold with valid_in = 0");
        do_clear();
        send(32'd100);
        send(32'd200);
        expect_stats(2, 300, 100, 200);
        drive(1'b0, 1'b0, 32'h0000_0000);                    // would update min
        drive(1'b0, 1'b0, 32'hFFFF_FFFF);                    // would update max
        idle(10);
        expect_stats(2, 300, 100, 200);

        // ----------------------------------------------------
        // Test 6: clear
        // ----------------------------------------------------
        start_test("T6 clear");
        do_clear();
        expect_stats(0, 0, 0, 0, 0);
        repeat (3) do_clear();                               // consecutive clears
        expect_stats(0, 0, 0, 0, 0);
        send(32'd8);
        idle(2);
        do_clear();
        idle(2);
        expect_stats(0, 0, 0, 0, 0);

        // ----------------------------------------------------
        // Test 7: clear has priority over valid_in
        // ----------------------------------------------------
        start_test("T7 clear priority over valid_in");
        send(32'd10);
        send(32'd20);
        do_clear(1'b1, 32'd1000);                            // data must be ignored
        expect_stats(0, 0, 0, 0, 0);
        send(32'd30);                                        // first value of new sequence
        expect_stats(1, 30, 30, 30);

        // ----------------------------------------------------
        // Test 8: sum saturation
        // ----------------------------------------------------
        start_test("T8 sum saturation");
        do_clear();
        send(32'hFFFF_FFF0);
        send(32'h0000_000F);                                 // exactly max, no overflow
        expect_stats(2, 32'hFFFF_FFFF, 32'h0000_000F, 32'hFFFF_FFF0);
        send(32'd0);                                         // +0 keeps max
        expect_stats(3, 32'hFFFF_FFFF, 32'd0, 32'hFFFF_FFF0);
        send(32'd1);                                         // overflow by 1
        expect_stats(4, 32'hFFFF_FFFF, 32'd0, 32'hFFFF_FFF0);
        send(32'h8000_0000);                                 // stays saturated
        expect_stats(5, 32'hFFFF_FFFF, 32'd0, 32'hFFFF_FFF0);

        do_clear();
        send(32'h8000_0000);
        send(32'h8000_0001);                                 // overflow from non-saturated state
        expect_stats(2, 32'hFFFF_FFFF, 32'h8000_0000, 32'h8000_0001);
        idle(3);
        expect_stats(2, 32'hFFFF_FFFF, 32'h8000_0000, 32'h8000_0001);

        do_clear();
        expect_stats(0, 0, 0, 0, 0);
        send(32'd1);
        expect_stats(1, 1, 1, 1);

        do_reset();
        send(32'hFFFF_FFFF);
        send(32'hFFFF_FFFF);
        do_reset();
        expect_stats(0, 0, 0, 0, 0);

        // ----------------------------------------------------
        // Test 9: count saturation
        // ----------------------------------------------------
        start_test("T9 count saturation");
        do_clear();
        $dumpoff;                                            // keep VCD small
        repeat (16'hFFFF - 2) send(32'd0);
        $dumpon;
        send(32'd0);
        expect_stats(16'hFFFE, 0, 0, 0);
        send(32'd0);                                         // reaches 0xFFFF
        expect_stats(16'hFFFF, 0, 0, 0);
        send(32'd3);                                         // stays 0xFFFF, sum still counts
        expect_stats(16'hFFFF, 3, 0, 3);
        repeat (5) send(32'd1);
        expect_stats(16'hFFFF, 8, 0, 3);
        idle(2);
        expect_stats(16'hFFFF, 8, 0, 3);
        do_clear();
        expect_stats(0, 0, 0, 0, 0);
        send(32'd4);
        expect_stats(1, 4, 4, 4);

        // count saturation then reset
        $dumpoff;
        repeat (16'hFFFF + 3) send(32'd0);
        $dumpon;
        expect_stats(16'hFFFF, 4, 0, 4);
        do_reset();
        expect_stats(0, 0, 0, 0, 0);

        // ----------------------------------------------------
        // Test 10: random stimulus, checked against the model
        // ----------------------------------------------------
        start_test($sformatf("T10 random (%0d cycles)", RAND_CYCLES));
        err_before = errors;
        for (int i = 0; i < RAND_CYCLES; i++) begin
            int r;
            r = $urandom_range(0, 999);
            if      (r < 10)  drive($urandom(), $urandom(), rand_data(), 1'b0);  // 1%  reset
            else if (r < 40)  drive($urandom(), 1'b1,       rand_data());        // 3%  clear
            else if (r < 740) drive(1'b1,       1'b0,       rand_data());        // 70% valid
            else              drive(1'b0,       1'b0,       rand_data());        // 26% idle
        end
        if (errors == err_before)
            $display("     random test: no mismatches");

        // ----------------------------------------------------
        // Test completed
        // ----------------------------------------------------
        idle(2);
        check_en = 0;

        $display("========================================");
        $display("Cycle checks performed: %0d", checks);
        if (errors == 0) begin
            $display("ALL TESTS PASSED");
        end
        else begin
            $display("TEST FAILED: %0d error(s)", errors);
        end
        $display("========================================");

        $finish;
    end

endmodule
