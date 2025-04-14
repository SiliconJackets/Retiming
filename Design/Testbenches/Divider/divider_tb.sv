`timescale 1ns/1ps

module tb_array_divider;

  // Parameters for the divider
  parameter int WIDTH     = 18;
  parameter int NUM_TESTS = 25;
  parameter int FRAC_BITS = 8;
  parameter int INSTANCE_ID = 0;
  parameter int NUM_PIPELINE_STAGES = 0;
  // parameter logic [WIDTH-1:0] MASK = 8'b0110_0000;
  // parameter bit ENABLE = 1;

  // Clock, reset, and valid signals
  logic clk;
  logic rst;
  logic i_valid;

  // 3-bit unsigned inputs (dividend and divisor)
  logic [WIDTH-1+FRAC_BITS:0] A;
  logic [WIDTH-1+FRAC_BITS:0] B;

  // Outputs from the divider
  logic o_valid;
  logic [WIDTH-1:0] Q_out;  // Registered quotient
  logic [WIDTH-1:0] R_out;  // Registered remainder
  logic [WIDTH-1:0] Q;      // Combinational quotient
  logic [WIDTH-1:0] R;      // Combinational remainder
  logic [WIDTH-1+FRAC_BITS:0] exp_Q;
  logic [WIDTH-1+FRAC_BITS:0] exp_R;

  // Instantiate the unsigned array divider (Unit Under Test)
  array_divider #(
    .DATAWIDTH(WIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES),
    .FRAC_BITS(FRAC_BITS),
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
    logic [WIDTH-1+FRAC_BITS:0] A;
    logic [WIDTH-1+FRAC_BITS:0] B;
    logic [WIDTH-1+FRAC_BITS:0] exp_Q;
    logic [WIDTH-1+FRAC_BITS:0] exp_R;
  } test_vector_t;
    logic [WIDTH+FRAC_BITS-1:0] A_shifted;
  // Define test vectors (all positive)
  test_vector_t tests [NUM_TESTS];
  initial begin
  for (int i = 0; i < NUM_TESTS; i++) begin
    tests[i].A = $urandom_range(0, (1 << (WIDTH-1)) - 1);
    // tests[i].B = $urandom_range(0, (1 << (WIDTH-1)) - 1); 
    tests[i].B = $urandom_range(tests[i].A + 1, (1 << (WIDTH-1)) - 1); 
    A_shifted = (tests[i].A << FRAC_BITS); 
    tests[i].exp_Q = (A_shifted) / tests[i].B;
    tests[i].exp_R = (A_shifted) - (tests[i].B * tests[i].exp_Q);
    $display("Test %0d: A = %0h, B = %0h, A_shifted = %0h, exp_Q = %0h, exp_R = %0h", 
             i, tests[i].A, tests[i].B, A_shifted, tests[i].exp_Q, tests[i].exp_R);
  end
end

  // Queue to store expected results for each input.
  test_vector_t pipeline_queue[$];
  int test_index = 0;
  int count = 0;
  int isPass;
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
    @(posedge clk);
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
        i_valid = 0;
      end
      
      @(posedge clk);
      $display("Cycle %0d: Input A=%0d, B=%0d | Q_out=%0d (hex:%0h), R_out=%0d (hex:%0h), o_valid=%0d",
               count, A, B, Q_out, Q_out, R_out, R_out, o_valid);
      if (Q_out  == tests[count-NUM_PIPELINE_STAGES].exp_Q && R_out  == tests[count-NUM_PIPELINE_STAGES].exp_R) begin
        $display("Pass!");
      end
      else if (o_valid) begin
        $display("Not pass: exp_Q = %0d (hex:%0h), exp_R = %0d (hex:%0h)",
               tests[count-NUM_PIPELINE_STAGES].exp_Q, tests[count-NUM_PIPELINE_STAGES].exp_Q, tests[count-NUM_PIPELINE_STAGES].exp_R, tests[count-NUM_PIPELINE_STAGES].exp_R);
      end
      count = count + 1;
    end
  end

  initial begin
    #350;
    $finish;
  end

  // Dump waveforms (optional)
  initial begin
    $fsdbDumpfile("unsigned_divider.fsdb");
    $fsdbDumpvars(0, tb_array_divider);
  end

endmodule