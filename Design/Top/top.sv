module top #(
    parameter DATAWIDTH = 16,
    parameter FRAC_BITS = 8,
    parameter NUM_PIPELINE_STAGES_MUL = 2,    
    parameter NUM_PIPELINE_STAGES_DIV = 2,    
    parameter NUM_PIPELINE_STAGES_SQRT = 2,    
    parameter NUM_PIPELINE_STAGES_ADDT = 2
)
(
    input logic clk,
    input logic rst,
    input logic i_valid,
    input logic [DATAWIDTH-1:0] A, //Input: fixed-point 8.8 format
    input logic [DATAWIDTH-1:0] B, //Input: fixed-point 8.8 format 
    input logic [DATAWIDTH-1:0] C, //Input: fixed-point 8.8 format
    input logic [DATAWIDTH-1:0] D, //Input: fixed-point 8.8 format
    // input logic [DATAWIDTH-1+8:0] Dividend, //Input: fixed-point 8.16 format
    output logic o_valid_final_A,
    output logic o_valid_final_B,
    output logic o_valid_final_C,
    output logic o_valid_final_D,
    output logic [DATAWIDTH:0]output_final_A,
    output logic [DATAWIDTH:0]output_final_B,
    output logic [DATAWIDTH:0]output_final_C,
    output logic [DATAWIDTH:0]output_final_D
);

logic [DATAWIDTH*2-1:0] A_mul;
logic [DATAWIDTH*2-1:0] B_mul;
logic [DATAWIDTH*2-1:0] C_mul;
logic [DATAWIDTH*2-1:0] D_mul;
logic [DATAWIDTH-1:0] A_dividend;
logic [DATAWIDTH-1:0] B_dividend;
logic [DATAWIDTH-1:0] C_dividend;
logic [DATAWIDTH-1:0] D_dividend;
logic o_valid_A_mul;
logic o_valid_B_mul;
logic o_valid_C_mul;
logic o_valid_D_mul;
logic o_valid_adder_tree;
logic o_valid_sqrt;
logic [DATAWIDTH:0] sqrt_out;
logic [DATAWIDTH:0] sqrt_rem;
logic [DATAWIDTH:0] R_out_divider_A,R_out_divider_B,R_out_divider_C,R_out_divider_D;
logic [DATAWIDTH*2+1:0] adderTree_out;

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
  .NUM_INPUTS(4), // Maximum is 32
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_ADDT),
  .INSTANCE_ID(0)
)
adder_tree0 (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_A_mul),
  .in_data(adder_in_data), 
  .o_valid(o_valid_adder_tree),
  .sum_reg(adderTree_out)
  );



sqrt_int #(
  .DATAWIDTH(DATAWIDTH * 2 + 2),
  .INSTANCE_ID(0)
)
sqrt_inst (
  .clk(clk),
  .i_valid(o_valid_adder_tree), 
  .o_valid(o_valid_sqrt),
  .rad(adderTree_out),
  .root(sqrt_out),
  .rem(sqrt_rem)
);

logic [DATAWIDTH*4-1:0] stage_dividend_data [0:NUM_PIPELINE_STAGES_MUL + NUM_PIPELINE_STAGES_SQRT + NUM_PIPELINE_STAGES_ADDT - 1];
generate 
  for (genvar s = 0; s < NUM_PIPELINE_STAGES_MUL + NUM_PIPELINE_STAGES_SQRT +NUM_PIPELINE_STAGES_ADDT; s++) begin : Dividend_pipeline_stage
    if (s == 0) begin
      pipeline_stage #(
          .WIDTH(DATAWIDTH * 4),
          .ENABLE(1)
        ) pipe_stage_input (
          .clk(clk), 
          .rst(rst),
          .data_in({A, B, C, D}),
          .data_out({stage_dividend_data[0]})
        );
    end
    else if (s == NUM_PIPELINE_STAGES_MUL + NUM_PIPELINE_STAGES_SQRT + NUM_PIPELINE_STAGES_ADDT - 1) begin
      pipeline_stage #(
          .WIDTH(DATAWIDTH * 4),
          .ENABLE(1)
        ) pipe_stage_input (
          .clk(clk), 
          .rst(rst),
          .data_in({stage_dividend_data[s-1]}),
          .data_out({A_dividend, B_dividend, C_dividend, D_dividend})
        );
    end
    else begin
      pipeline_stage #(
          .WIDTH(DATAWIDTH * 4),
          .ENABLE(1)
        ) pipe_stage_input (
          .clk(clk), 
          .rst(rst),
          .data_in({stage_dividend_data[s-1]}),
          .data_out({stage_dividend_data[s]})
        );
    end
  end
endgenerate 



array_divider #(
  .DATAWIDTH(DATAWIDTH + 1),
  .FRAC_BITS(FRAC_BITS),
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_DIV),
  .INSTANCE_ID(0)
)
array_div_inst_A (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_sqrt), 
  .A(A_dividend),
  .B(sqrt_out),
  .o_valid(o_valid_final_A),
  .Q_out(output_final_A),
  .R_out(R_out_divider_A)
);

array_divider #(
  .DATAWIDTH(DATAWIDTH + 1),
  .FRAC_BITS(FRAC_BITS),
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_DIV),
  .INSTANCE_ID(1)
)
array_div_inst_B (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_sqrt), 
  .A(B_dividend),
  .B(sqrt_out),
  .o_valid(o_valid_final_B),
  .Q_out(output_final_B),
  .R_out(R_out_divider_B)
);

array_divider #(
  .DATAWIDTH(DATAWIDTH + 1),
  .FRAC_BITS(FRAC_BITS),
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_DIV),
  .INSTANCE_ID(2)
)
array_div_inst_C (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_sqrt), 
  .A(C_dividend),
  .B(sqrt_out),
  .o_valid(o_valid_final_C),
  .Q_out(output_final_C),
  .R_out(R_out_divider_C)
);

array_divider #(
  .DATAWIDTH(DATAWIDTH + 1),
  .FRAC_BITS(FRAC_BITS),
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_DIV),
  .INSTANCE_ID(3)
)
array_div_inst_D (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_sqrt), 
  .A(D_dividend),
  .B(sqrt_out),
  .o_valid(o_valid_final_D),
  .Q_out(output_final_D),
  .R_out(R_out_divider_D)
);

endmodule