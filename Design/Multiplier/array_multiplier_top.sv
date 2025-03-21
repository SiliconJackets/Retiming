`timescale 1ns / 1ps
 
module array_multiplier_top(
  input logic clk,
  input logic rst,
  input logic i_valid,
  input logic [DATAWIDTH-1:0] A,
  input logic [DATAWIDTH-1:0] B,
  output logic o_valid,
  output logic [DATAWIDTH*2-1:0] Z_final
);
  localparam TESTDATAWIDTH = 16;

  // logic [TESTDATAWIDTH-1:0] A, B;  // Test inputs
  // logic [2*TESTDATAWIDTH-1:0] Z;   // Output product
  // logic rst;
  // logic clk;
  // logic i_vld;
  // logic o_vld;
 
  // Instantiate the 8-bit array multiplier
  array_multiplier #(
    .DATAWIDTH(TESTDATAWIDTH),
    .NUM_PIPELINE_STAGES(2),
    .INSTANCE_ID(0)
  )
  mul0 (
    .A(A),
    .B(B),
    .Z_final(Z_final),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid)
  );
 

endmodule