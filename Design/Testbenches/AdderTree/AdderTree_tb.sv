`timescale 1ns/1ps

module tb_adder_tree;

  // Parameters for the adder tree.
  parameter int WIDTH      = 7;    // each input is 4 bits
  parameter int NUM_INPUTS = 32;   // maximum number of inputs
  // 5 pipeline stages (input stage + 4 adder stages)
  // MASK bits: 1 means register this stage, 0 means pass-through.
  parameter int NUM_PIPELINE_STAGES = 1;

  // Clock, reset, and valid signal.
  logic clk;
  logic rst;
  logic i_valid;

  // 16 input signals (each WIDTH bits).
  logic [WIDTH-1:0] in_data [0:NUM_INPUTS-1];

  // Outputs.
  logic o_valid;
  logic [32:0] sum_reg;  // final 8-bit sum

  // Instantiate the adder tree (top-level module).
  adder_tree #(
    .DATAWIDTH(WIDTH),
    .NUM_INPUTS(NUM_INPUTS),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES)
  ) uut (
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .in_data(in_data),
    .o_valid(o_valid),
    .sum_reg(sum_reg)
  );

  // Clock generation: 10 ns period.
  initial begin
    clk = 0;
    forever #5 clk = ~clk;
  end


initial begin
    // Configure FSDB dumping
    $fsdbDumpon;
    $fsdbDumpfile("simulation.fsdb");
    $fsdbDumpvars(0, tb_adder_tree, "+mda", "+all", "+trace_process");
    $fsdbDumpMDA;
end

  // Test sequence.
  initial begin
    $vcdpluson; //set up trace dump for DVE
    $vcdplusmemon;
    // Initialize reset and valid.
    rst = 1;
    i_valid = 0;
    // Initialize all inputs to zero.
    for (int i = 0; i < NUM_INPUTS; i++) begin
      in_data[i] = '0;
    end

    #20;   // Hold reset for 20 ns.
    rst = 0;
    #10;

    // ----------------------------
    // Test Vector 1: All ones.
    // ----------------------------
    i_valid = 1;
    for (int i = 0; i < NUM_INPUTS; i++) begin
      in_data[i] = 4'd1;  // each input is 1.
    end
    #20;  // wait 100 ns to observe output

    // ----------------------------
    // Test Vector 2: Increasing values (0, 1, 2, ... 15).
    // ----------------------------
    for (int i = 0; i < NUM_INPUTS; i++) begin
      in_data[i] = i % 16;  // in_data[0] = 0, in_data[1] = 1, ..., in_data[15] = 15.
    end
    #30;

    // ----------------------------
    // Test Vector 3: Maximum values (15).
    // ----------------------------
    for (int i = 0; i < NUM_INPUTS; i++) begin
      in_data[i] = 4'd15;  // each input is 15 (max 4-bit value).
    end
    #100;

    // End simulation.
    $finish;
  end

  // Monitor outputs.
  initial begin
    $display("Time\t i_valid\t sum_reg");
    forever begin
      @(posedge clk);
    //   if (o_valid)
        $display("%0t\t %b\t %0d", $time, i_valid, sum_reg);
    end
  end

endmodule
