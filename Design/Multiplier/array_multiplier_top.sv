`timescale 1ns / 1ps
 
module array_multiplier_top;
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
 
endmodule