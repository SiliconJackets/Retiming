`timescale 1ns / 1ps
 
module array_multiplier_tb;
  localparam TESTDATAWIDTH = 16;

  logic [TESTDATAWIDTH-1:0] A, B;  // Test inputs
  logic [2*TESTDATAWIDTH-1:0] Z;   // Output product
  logic rst;
  logic clk;
  logic i_vld;
  logic o_vld;
 
  // Instantiate the 8-bit array multiplier
  array_multiplier #(
    .DATAWIDTH(TESTDATAWIDTH),
    .NUM_PIPELINE_STAGES(2),
    .INSTANCE_ID(0)
  )
  mul0 (
    .A(A),
    .B(B),
    .Z_final(Z),
    .clk(clk),
    .rst(rst),
    .i_valid(i_vld),
    .o_valid(o_vld)
  );
 
  always #5 clk = ~clk;
 
  initial begin
        // Configure FSDB dumping
        $fsdbDumpon;
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, array_multiplier_tb, "+mda", "+all", "+trace_process");
        $fsdbDumpMDA;
    end
 
   // Initialize signals
  initial begin
    // Set initial values
    clk = 0;
    rst = 1;
    i_vld = '0;
    A = '0;
    B = '0;
    #15 rst = 0;  // Release reset after a few clock cycles
    #10;
    @(posedge clk);
    i_vld = '1;
    A = 255; B = 255;  // 255 * 255 = 65025
    //i_vld = '0;
    @(posedge clk);
    A = 255; B = 10;  // 255 * 255 = 65025
    @(posedge clk);
    A = 234; B = 232;  // 255 * 255 = 65025
    // End simulation
    @(posedge clk);
    i_vld = '0;
    #10000 $finish;
 
  end
 
  initial @(posedge clk) begin
    $monitor("Time=%0t | A=%b (%d) | B=%b (%d) | Z=%b (%d)  | Valid=%b",
             $time, A, A, B, B, Z, Z, o_vld);
  end
endmodule