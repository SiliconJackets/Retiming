`timescale 1ns/1ps

module tb_top;
  parameter int DATAWIDTH   = 16;
  logic clk;
  logic rst;
  logic i_valid;
  logic [DATAWIDTH-1:0] A, B, C, D; 
  // logic [DATAWIDTH-1+8:0]Dividend;
  logic o_valid_final_A, o_valid_final_B, o_valid_final_C, o_valid_final_D;
  logic [DATAWIDTH:0] output_final_A, output_final_B, output_final_C, output_final_D;

  // Clock generation: 10 ns period.
  initial begin
    clk = 1;
    forever #5 clk = ~clk;
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
    .DATAWIDTH(16),
    .FRAC_BITS(8),
    .NUM_PIPELINE_STAGES_MUL(10),
    .NUM_PIPELINE_STAGES_DIV(0),
    .NUM_PIPELINE_STAGES_SQRT(0),
    .NUM_PIPELINE_STAGES_ADDT(0)
  )
  top0 (
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .A(A),
    .B(B),
    .C(C),
    .D(D),
    // .Dividend(Dividend),
    .o_valid_final_A(o_valid_final_A),
    .o_valid_final_B(o_valid_final_B),
    .o_valid_final_C(o_valid_final_C),
    .o_valid_final_D(o_valid_final_D),
    .output_final_A(output_final_A),
    .output_final_B(output_final_B),
    .output_final_C(output_final_C),
    .output_final_D(output_final_D)
  );


// always @(posedge clk) begin
initial begin
  $monitor("Time=%0t | rst=%b | i_valid=%b | A=%h | B=%h | C=%h | D=%h | \
           output_final_A=%h | output_final_B=%h | output_final_C=%h | output_final_D=%h | valid=%b",
           $time, rst, i_valid, A, B, C, D,
          //  o_valid_final_A, o_valid_final_B, o_valid_final_C, o_valid_final_D,
           output_final_A, output_final_B, output_final_C, output_final_D,
           {o_valid_final_A, o_valid_final_B, o_valid_final_C, o_valid_final_D});
end


  
// Monitor outputs.
initial begin
    rst = 1;
    i_valid = 0;
    // Dividend = 24'h040000;
    @(posedge clk);
    rst = 0;
    A = 16'h0000;
    B = 16'h0000;
    C = 16'h0000;
    D = 16'h0000;
    @(posedge clk);
    i_valid = 1;
    // Dividend = 24'h040000;
    A = 16'h0100;
    B = 16'h0200;
    C = 16'h0300;
    D = 16'h0400;

    @(posedge clk);
    A = 16'h0100;
    B = 16'h0100;
    C = 16'h0100;
    D = 16'h0100;
    
    @(posedge clk);
    A = 16'h0100;
    B = 16'h0500;
    C = 16'h0500;
    D = 16'h0800;

    @(posedge clk);

    A = 16'h0100;
    B = 16'h0200;
    C = 16'h0300;
    D = 16'h0400;

    @(posedge clk);
    A = 16'h1100;
    B = 16'h1500;
    C = 16'h2500;
    D = 16'h8800;
    
    // i_valid = 0;

    @(posedge clk);

    A = 16'h0100;
    B = 16'h0200;
    C = 16'h0300;
    D = 16'h0400;

    // Fractional numbers
    @(posedge clk);

    A = 16'h0180;
    B = 16'h0240;
    C = 16'h0320;
    D = 16'h0410;

    @(posedge clk);

    i_valid = 0;

    A = 16'h0000;
    B = 16'h0000;
    C = 16'h0000;
    D = 16'h0000;

    repeat (30) @(posedge clk);
    $finish;
end

endmodule
