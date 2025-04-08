`timescale 1ns / 1ps
 
module array_multiplier_top #(
  parameter DATAWIDTH = 4,
  parameter NUM_PIPELINE_STAGES = 2,           // For now, have stages refer to pp sums (seventh row is reg out)
  parameter INSTANCE_ID = 0 
  )
  (
  input logic clk,
  input logic rst,
  input logic i_valid,
  input logic [DATAWIDTH-1:0] A,
  input logic [DATAWIDTH-1:0] B,
  output logic o_valid,
  output logic [DATAWIDTH*2-1:0] Z_final
);
 

  logic [DATAWIDTH*2-1:0] Z1, Z2;
  // Instantiate the 8-bit array multiplier
  array_multiplier #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES),
    .INSTANCE_ID(0)
  )
  mul0 (
    .A(A),
    .B(B),
    .Z_final(Z1),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid)
  );

/*
  // Instantiate the 8-bit array multiplier
  array_multiplier #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(3),
    .INSTANCE_ID(1)
  )
  mul1 (
    .A(A),
    .B(B),
    .Z_final(Z2),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid)
  ); 
*/
  assign Z_final = Z1;
endmodule