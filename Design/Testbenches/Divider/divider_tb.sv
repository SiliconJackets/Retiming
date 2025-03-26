`timescale 1ns/1ps

module tb_array_divider;

  // Parameters for the divider
  parameter int WIDTH     = 16;
  parameter int NUM_TESTS = 10;
  parameter int INSTANCE_ID = 0;
  parameter int NUM_PIPELINE_STAGES = 17;
  // parameter logic [WIDTH-1:0] MASK = 8'b0110_0000;
  // parameter bit ENABLE = 1;

  // Clock, reset, and valid signals
  logic clk;
  logic rst;
  logic i_valid;

  // 3-bit unsigned inputs (dividend and divisor)
  logic [WIDTH-1:0] A;
  logic [WIDTH-1:0] B;

  // Outputs from the divider
  logic o_valid;
  logic [WIDTH-1:0] Q_out;  // Registered quotient
  logic [WIDTH-1:0] R_out;  // Registered remainder
  logic [WIDTH-1:0] Q;      // Combinational quotient
  logic [WIDTH-1:0] R;      // Combinational remainder
  logic [WIDTH-1:0] exp_Q;
  logic [WIDTH-1:0] exp_R;

  // Instantiate the unsigned array divider (Unit Under Test)
  array_divider #(
    .DATAWIDTH(WIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES),
    .INSTANCE_ID(INSTANCE_ID)
  ) uut (
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .A(A),
    .B(B),
    .o_valid(o_valid),
    .Q_out(Q_out),
    .R_out(R_out)
    // .Q(Q),
    // .R(R)
  );

  // Clock generation: 10 ns period (5 ns high, 5 ns low)
  always #5 clk = ~clk;

  //-------------------------------------------------------------------------
  // Test vector structure and queue for expected results.
  //-------------------------------------------------------------------------
  typedef struct {
    logic [WIDTH-1:0] A;
    logic [WIDTH-1:0] B;
    logic [WIDTH-1:0] exp_Q;
    logic [WIDTH-1:0] exp_R;
  } test_vector_t;

  // Define test vectors (all positive)
  test_vector_t tests [NUM_TESTS];
  initial begin
    // 7 / 3 = 2 remainder 1
    tests[0] = '{ A: 1024, B: 10, exp_Q: 102, exp_R: 4 };
    // 6 / 2 = 3 remainder 0
    tests[1] = '{ A: 2439, B:300, exp_Q: 8, exp_R: 39 };
    // 5 / 2 = 2 remainder 1
    tests[2] = '{ A: 5, B: 2, exp_Q: 2, exp_R: 1 };
    // 4 / 3 = 1 remainder 1
    tests[3] = '{ A: 4, B: 3, exp_Q: 1, exp_R: 1 };
    // 2 / 3 = 0 remainder 2
    tests[4] = '{ A: 2, B: 3, exp_Q: 0, exp_R: 2 };
    // 7 / 1 = 7 remainder 0
    tests[5] = '{ A: 50, B: 1, exp_Q: 50, exp_R: 0 };
    // 7 / 3 = 2 remainder 1
    tests[6] = '{ A: 7, B: 3, exp_Q: 2, exp_R: 1 };
    // 6 / 2 = 3 remainder 0
    tests[7] = '{ A: 30, B: 2, exp_Q: 15, exp_R: 0 };
    // 5 / 2 = 2 remainder 1
    tests[8] = '{ A: 5, B: 2, exp_Q: 2, exp_R: 1 };
    // 4 / 3 = 1 remainder 1
    tests[9] = '{ A: 4, B: 3, exp_Q: 1, exp_R: 1 };
  end

  // Queue to store expected results for each input.
  test_vector_t pipeline_queue[$];
  int test_index = 0;

  //-------------------------------------------------------------------------
  // Continuous input: On every rising edge, a new test vector is applied.
  //-------------------------------------------------------------------------
    initial begin
        // Configure FSDB dumping
        $fsdbDumpon;
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, tb_array_divider, "+mda", "+all", "+trace_process");
        $fsdbDumpMDA;
    end
  initial begin
    $vcdpluson; //set up trace dump for DVE
    $vcdplusmemon;
    clk = 0;
    rst = 1;
    i_valid = 0;
    A = '0;
    B = '0;
    #20; // Hold reset for 20 ns
    rst = 0;
    i_valid = 1; // Continuous valid

    forever begin
      // @(posedge clk);
      if (test_index < NUM_TESTS) begin
        A = tests[test_index].A;
        B = tests[test_index].B;
        exp_Q = tests[test_index].exp_Q;
        exp_R = tests[test_index].exp_R;
        // pipeline_queue.push_back(tests[test_index]);
        test_index++;
      end else begin
        // After tests are exhausted, hold the last test data.
        A = tests[NUM_TESTS-1].A;
        B = tests[NUM_TESTS-1].B;
        exp_Q = tests[NUM_TESTS-1].exp_Q;
        exp_R = tests[NUM_TESTS-1].exp_R;
      end
      
      @(posedge clk);
      $display("Time=%0t: Input A=%0d, B=%0d | Q_out=%0d, R_out=%0d, o_valid=%0d | exp_Q = %0d, exp_R = %0d",
               $time, A, B, Q_out, R_out, o_valid, exp_Q, exp_R);
    end
  end

  //-------------------------------------------------------------------------
  // Monitor output: When o_valid is asserted, pop the earliest expected result
  // from the queue and display the output versus the expected values.
  //-------------------------------------------------------------------------
  // always_ff @(posedge clk) begin
  //   // if (o_valid && pipeline_queue.size() > 0) begin
  //   if ( pipeline_queue.size() > 0) begin
  //     test_vector_t tv;
  //     // tv = pipeline_queue.pop_front();
  //     $display("Time=%0t: Input A=%0d, B=%0d | Q_out=%0d, R_out=%0d, o_valid=%0d",
  //              $time, A, B, Q_out, R_out, o_valid);
  //   end
  // end

  initial begin
    #300;
    $finish;
  end

  // Dump waveforms (optional)
  initial begin
    $fsdbDumpfile("unsigned_divider.fsdb");
    $fsdbDumpvars(0, tb_array_divider);
  end

endmodule
