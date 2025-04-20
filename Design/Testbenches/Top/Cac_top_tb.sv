`timescale 1ns/1ps

module tb_top;
  parameter int DATAWIDTH   = 8;
  parameter int NUM_TESTS   = 100;
  parameter int FRAC_BITS   = 8;
  parameter int PIPELINE_LATENCY = (DATAWIDTH + 2) + ($clog2(4 - 1) + 1 + 1) + ((DATAWIDTH >> 1) + 2) + (DATAWIDTH + 1 + FRAC_BITS);   // total # of stages
  logic clk;
  logic rst;
  wire i_valid;
  wire [DATAWIDTH-1:0] A, B, C, D;
  logic o_valid_final_A, o_valid_final_B, o_valid_final_C, o_valid_final_D;
  logic [DATAWIDTH+FRAC_BITS+1:0] output_final_A, output_final_B, output_final_C, output_final_D;

  // Clock generation: 10 ns period.
  initial begin
    clk = 1;
    forever #5 clk = ~clk;
  end

  // Drive reset signal.
    initial begin
        rst = 1;
        #20;
        rst = 0;
    end

initial begin
    // Configure FSDB dumping
    $fsdbDumpon;
    $fsdbDumpfile("simulation.fsdb");
    $fsdbDumpvars(0, tb_top, "+mda", "+all", "+trace_process");
    $fsdbDumpMDA;
end

// Test sequence.
initial begin
  $vcdpluson; //set up trace dump for DVE
  $vcdplusmemon;
end
top #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES_MUL(DATAWIDTH + 2),
    .NUM_PIPELINE_STAGES_DIV(DATAWIDTH + 1 + FRAC_BITS),
    .NUM_PIPELINE_STAGES_SQRT((DATAWIDTH >> 1) + 2),
    .NUM_PIPELINE_STAGES_ADDT($clog2(4 - 1) + 1 + 1)
  )
  top0 (
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .A(A),
    .B(B),
    .C(C),
    .D(D),
    .o_valid_final_A(o_valid_final_A),
    .o_valid_final_B(o_valid_final_B),
    .o_valid_final_C(o_valid_final_C),
    .o_valid_final_D(o_valid_final_D),
    .output_final_A(output_final_A),
    .output_final_B(output_final_B),
    .output_final_C(output_final_C),
    .output_final_D(output_final_D)
  );

tb_program #(DATAWIDTH, NUM_TESTS, FRAC_BITS, PIPELINE_LATENCY) tb_inst (
    .clk(clk), .rst(rst), .i_valid(i_valid),
    .A(A), .B(B), .C(C), .D(D),
    .o_valid_final_A(o_valid_final_A),
    .o_valid_final_B(o_valid_final_B),
    .o_valid_final_C(o_valid_final_C),
    .o_valid_final_D(o_valid_final_D),
    .output_final_A(output_final_A),
    .output_final_B(output_final_B),
    .output_final_C(output_final_C),
    .output_final_D(output_final_D)
  );
endmodule

// Program block
program automatic tb_program #(parameter int DW = 8, NTESTS = 10, FRAC = 8, PIPE = 2) (
  input logic clk, rst,
  inout wire i_valid,
  inout wire [DW-1:0] A, B, C, D,
  input logic o_valid_final_A, o_valid_final_B, o_valid_final_C, o_valid_final_D,
  input logic [15:0] output_final_A, output_final_B, output_final_C, output_final_D
);

  typedef struct {
  logic [DW-1:0] A, B, C, D;
  logic [DW+FRAC+1:0] exp_A, exp_B, exp_C, exp_D;
} test_vector_t;

  test_vector_t tests[NTESTS];
  int tidx = 0;

  initial begin
    real den;
    real a_real, b_real, c_real, d_real;
    int cycle = 0;
    logic [DW-1:0] a_test;

    for (int i = 0; i < NTESTS; i++) begin
        tests[i].A = $random / (2**DW);
        tests[i].B = $random / (2**DW);
        tests[i].C = $random / (2**DW);
        tests[i].D = $random / (2**DW);

        a_real = real'(tests[i].A);
        b_real = real'(tests[i].B);
        c_real = real'(tests[i].C);
        d_real = real'(tests[i].D);

        den = $rtoi($sqrt(a_real * a_real + b_real * b_real + c_real * c_real + d_real * d_real));

        tests[i].exp_A = $rtoi((a_real * 256.0) / den);
        tests[i].exp_B = $rtoi((b_real * 256.0) / den);
        tests[i].exp_C = $rtoi((c_real * 256.0) / den);
        tests[i].exp_D = $rtoi((d_real * 256.0) / den);

    end

  force i_valid = 0;
  @(negedge rst);
  force i_valid = 1;

  while (tidx < NTESTS + PIPE) begin
    if (tidx < NTESTS) begin
      force A = tests[tidx].A;
      force B = tests[tidx].B;
      force C = tests[tidx].C;
      force D = tests[tidx].D;
    end else begin
      force A = 0; force B = 0; force C = 0; force D = 0;
      force i_valid = 0;
    end

    @(posedge clk);
    cycle++;

    $display("Time=%0t | Cycle=%0d | i_valid=%b | A=%h B=%h C=%h D=%h | out_A=%h out_B=%h out_C=%h out_D=%h | valid={%b%b%b%b}",
             $time, cycle, i_valid, A, B, C, D,
             output_final_A, output_final_B, output_final_C, output_final_D,
             o_valid_final_A, o_valid_final_B, o_valid_final_C, o_valid_final_D);

    tidx++;

    if (tidx >= PIPE) begin
      int idx = tidx - PIPE;
      if (o_valid_final_A && o_valid_final_B && o_valid_final_C && o_valid_final_D) begin
        if (output_final_A == tests[idx].exp_A &&
            output_final_B == tests[idx].exp_B &&
            output_final_C == tests[idx].exp_C &&
            output_final_D == tests[idx].exp_D) begin
            $display("PASS: Test %0d", idx);
        end
        else begin
          $display("FAIL: Test %0d", idx);
          $display("Expected A=%h B=%h C=%h D=%h", tests[idx].exp_A, tests[idx].exp_B, tests[idx].exp_C, tests[idx].exp_D);
          $display("Got      A=%h B=%h C=%h D=%h", output_final_A, output_final_B, output_final_C, output_final_D);
        end
      end
    end
      
  end

  release A; release B; release C; release D; release i_valid;
  #10;
  $finish;
end

endprogram