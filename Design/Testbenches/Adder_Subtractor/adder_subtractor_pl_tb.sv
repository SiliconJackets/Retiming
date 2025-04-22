`timescale 1ns/1ps

// Top-level testbench module
module tb_add_subtractor_pl;

  // Parameters (configure as needed)
  parameter int DATAWIDTH           = 4;
  parameter int NUM_PIPELINE_STAGES = 5; // Match DUT parameter
  parameter int NUM_TESTS           = 30; // Number of random tests

  // Calculate latency based on DUT stages
  parameter int PIPELINE_LATENCY = NUM_PIPELINE_STAGES;

  // Testbench Signals
  logic clk;
  logic rst;

  // DUT Interface Signals
  wire [DATAWIDTH-1:0] A;
  wire [DATAWIDTH-1:0] B;
  wire op; // 0 = add, 1 = subtract
  wire i_valid;
  wire [DATAWIDTH-1:0] Result;
  wire o_valid;
  wire carry_borrow; // DUT's overflow flag

  // Clock generation: 10 ns period (5ns high, 5ns low)
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end

  // Reset generation: Assert reset for 20ns at the beginning
  initial begin
    rst = 1;
    #15;
    rst = 0;
  end

  // Waveform Dumping (using FSDB in this example)
  initial begin
    $fsdbDumpon;
    $fsdbDumpfile("simulation.fsdb");
    $fsdbDumpvars(0, tb_add_subtractor_pl, "+mda", "+all", "+trace_process"); 
    $fsdbDumpMDA;
  end
  initial begin
    $vcdpluson; //set up trace dump for DVE
    $vcdplusmemon;
  end
  // Instantiate the Device Under Test (DUT)
  AdderSubtractorPipelined #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES),
    .INSTANCE_ID(0) // Example instance ID
  ) dut (
    .clk(clk),
    .rst(rst),
    .A(A),
    .B(B),
    .op(op),
    .i_valid(i_valid),
    .Result(Result),
    .o_valid(o_valid),
    .carry_borrow(carry_borrow)
  );

  // Instantiate the Test Program Block
  tb_program #(
    .DW(DATAWIDTH),
    .NTESTS(NUM_TESTS),
    .PIPE(PIPELINE_LATENCY)
  ) test_prog (
    .clk(clk),
    .rst(rst),
    .A(A),
    .B(B),
    .op(op),
    .i_valid(i_valid),
    .Result(Result),
    .o_valid(o_valid),
    .carry_borrow(carry_borrow)
  );

endmodule

// Test Program Block
program automatic tb_program #(
  parameter int DW = 8,
  parameter int NTESTS = 50,
  parameter int PIPE = 4 // Pipeline latency
) (
  input logic clk, rst,
  // DUT outputs driven into the program
  input logic [DW-1:0] Result,
  input logic o_valid,
  input logic carry_borrow,
  // DUT inputs driven by the program
  inout wire [DW-1:0] A, B,
  inout wire op,
  inout wire i_valid
);

  // Structure to hold test case data
  typedef struct {
    logic [DW-1:0] A;
    logic [DW-1:0] B;
    logic op; // 0=add, 1=sub
    logic [DW-1:0] expected_Result; // Expected result (ignoring DUT overflow logic initially)
    logic          expected_oflow; // Expected mathematical overflow/borrow
  } test_vector_t;

  // Array to store test vectors
  test_vector_t tests[NTESTS];
  int test_idx = 0;
  int cycle = 0;
  int pass_count = 0;
  int fail_count = 0;
  logic [DW:0] temp_result;
  // Generate Test Vectors
  initial begin
    $display("--- Test Vector Generation ---");
    for (int i = 0; i < NTESTS; i++) begin
      tests[i].A = $urandom(); // Use urandom for better randomness
      tests[i].B = $urandom();
      tests[i].op = $urandom_range(0, 1);

      // Calculate expected result using wider intermediate value
    //   logic [DW:0] temp_result;
      if (tests[i].op == 0) begin // Addition
        temp_result = tests[i].A + tests[i].B;
        tests[i].expected_oflow = temp_result[DW]; // Capture carry-out
        $display("Gen %0d: A=%d, B=%d, op=ADD, Expected=%d (Ovf=%b)", i, tests[i].A, tests[i].B, temp_result[DW-1:0], tests[i].expected_oflow);
      end else begin // Subtraction
        // temp_result = tests[i].A - tests[i].B;
        // tests[i].expected_oflow = temp_result[DW]; // Capture borrow-out (represented as carry)
        temp_result = {1'b0, tests[i].A}
          + {1'b0, ~tests[i].B}
          + 1;
        // temp_result       = sum_ext; 
        tests[i].expected_oflow = temp_result[DW];
         $display("Gen %0d: A=%d, B=%d, op=SUB, Expected=%d (Bw=%b)", i, tests[i].A, tests[i].B, temp_result[DW-1:0], tests[i].expected_oflow);
      end
      tests[i].expected_Result = temp_result[DW-1:0]; // Store lower DW bits
    end
    $display("--- Starting Simulation ---");
  end

  // Test Execution and Checking
  initial begin
    // Initialize input drivers
    force i_valid = 0;
    force A = '0;
    force B = '0;
    force op = '0;

    // Wait for reset to deassert
    @(negedge rst);
    // @(posedge clk);
    $display("Time=%0t | Reset Released", $time);

    // Main test loop
    while (test_idx < NTESTS + PIPE) begin // Run NTESTS and flush pipeline

      // Drive inputs from test vectors or zeros for flushing
      if (test_idx < NTESTS) begin
        force i_valid = 1;
        force A = tests[test_idx].A;
        force B = tests[test_idx].B;
        force op = tests[test_idx].op;
      end else begin
        // Stop sending new data after NTESTS, allow pipeline to drain
        force i_valid = 0;
        force A = '0;
        force B = '0;
        force op = '0;
        if (test_idx == NTESTS) $display("Time=%0t | Input stimulus stopped, draining pipeline...", $time);
      end

      // Wait for the next positive clock edge
      @(posedge clk);
      cycle++;
      test_idx++;


      // Check outputs after pipeline latency
      if (test_idx >= PIPE) begin
        int check_idx = (PIPE == 0)? test_idx-1:test_idx - PIPE ; // Index of the test vector expected at the output
      
        if (o_valid) begin
            logic check_passed = 1'b1;
            logic [DW-1:0] current_expected_result = tests[check_idx].expected_Result;
            logic current_op = tests[check_idx].op;
            string op_str = current_op ? "SUB" : "ADD";

            // Basic Result Check
            if (Result !== current_expected_result) begin
                    // Genuine mismatch
                    $display("Cycle=%0d | FAIL: Test %0d (%s)", cycle, check_idx, op_str);
                    $display("       Inputs for current result: A=%d, B=%d", tests[check_idx].A, tests[check_idx].B);
                    $display("       Expected Result: %d (Math Oflo/Borrow: %b)", current_expected_result, tests[check_idx].expected_oflow);
                    $display("       Got Result:      %d (DUT Overflow Flag: %b)", Result, carry_borrow);
                    check_passed = 1'b0;
                //  end
            end


            // Report Pass
            if (check_passed) begin
                $display("Cycle=%0d | PASS: Test (%s)", cycle, op_str);
                pass_count++;
            end else begin
                fail_count++;
            end

        end else begin
           // If o_valid is unexpectedly low after latency for a valid input
           if (check_idx < NTESTS) begin // Only warn if it was a real test, not pipeline flush
             $display("Time=%0t | WARN: Test %0d - Expected o_valid=1, but got o_valid=0", $time, check_idx);
           end
        end
      end // End of checking block

      // Increment test index for the next cycle
      // test_idx++;
      // cycle++;
      

    end // End of while loop

    // Release forced signals
    release A; release B; release op; release i_valid;

    // Final Summary
    #10; // Wait a bit for final messages
    $display("--- Simulation Summary ---");
    $display("Total Tests Run: %0d", NTESTS);
    $display("Passed: %0d", pass_count);
    $display("Failed: %0d", fail_count);
    $display("--------------------------");

    // End simulation
    $finish;
  end

endprogram