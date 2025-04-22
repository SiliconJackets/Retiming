module top_mult_addertree #(
    parameter DATAWIDTH = 4,
    parameter NUM_PIPELINE_STAGES_MUL = 2,      
    parameter NUM_PIPELINE_STAGES_ADDT = 1
)
(
    input clk,
    input rst,
    input logic i_valid,
    input logic [DATAWIDTH-1:0] A, //Input: fixed-point 8.8 format
    input logic [DATAWIDTH-1:0] B, //Input: fixed-point 8.8 format 
    input logic [DATAWIDTH-1:0] C, //Input: fixed-point 8.8 format
    input logic [DATAWIDTH-1:0] D, //Input: fixed-point 8.8 format
    output logic o_valid_final,
    output logic [2*DATAWIDTH+1:0] output_final
);
logic [DATAWIDTH*2-1:0] A_mul;
logic [DATAWIDTH*2-1:0] B_mul;
logic [DATAWIDTH*2-1:0] C_mul;
logic [DATAWIDTH*2-1:0] D_mul;
logic o_valid_A_mul;
logic o_valid_B_mul;
logic o_valid_C_mul;
logic o_valid_D_mul;

array_multiplier #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_MUL),
    .INSTANCE_ID(0)
  )
  mul_A (
    .A(A),
    .B(A),
    .Z_final(A_mul),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid_A_mul)
  );

array_multiplier #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_MUL),
    .INSTANCE_ID(1)
  )
  mul_B (
    .A(B),
    .B(B),
    .Z_final(B_mul),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid_B_mul)
  );

array_multiplier #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_MUL),
    .INSTANCE_ID(2)
  )
  mul_C (
    .A(C),
    .B(C),
    .Z_final(C_mul),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid_C_mul)
  );

array_multiplier #(
    .DATAWIDTH(DATAWIDTH),
    .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_MUL),
    .INSTANCE_ID(3)
  )
  mul_D (
    .A(D),
    .B(D),
    .Z_final(D_mul),
    .clk(clk),
    .rst(rst),
    .i_valid(i_valid),
    .o_valid(o_valid_D_mul)
  );

logic [3:0][DATAWIDTH * 2-1:0] adder_in_data;
assign adder_in_data[0] = A_mul;
assign adder_in_data[1] = B_mul;
assign adder_in_data[2] = C_mul;
assign adder_in_data[3] = D_mul;

adder_tree #(
  .DATAWIDTH(DATAWIDTH * 2),
  .NUM_INPUTS(4), 
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_ADDT),
  .INSTANCE_ID(0)
)
adder_tree0 (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_A_mul& o_valid_B_mul& o_valid_C_mul& o_valid_D_mul),
  .in_data(adder_in_data), 
  .o_valid(o_valid_final),
  .sum_reg(output_final)
  );

endmodule