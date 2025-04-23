module top #(
    parameter DATAWIDTH = 4,
    parameter FRAC_BITS = 4,
    parameter NUM_PIPELINE_STAGES_MUL = 1,    
    parameter NUM_PIPELINE_STAGES_DIV = 3,    
    parameter NUM_PIPELINE_STAGES_SQRT = 1,    
    parameter NUM_PIPELINE_STAGES_ADDT = 0
)
(
    input clk,
    input rst,
    input logic i_valid,
    input logic [DATAWIDTH-1:0] A, //Input: fixed-point 8.8 format
    input logic [DATAWIDTH-1:0] B, //Input: fixed-point 8.8 format 
    input logic [DATAWIDTH-1:0] C, //Input: fixed-point 8.8 format
    input logic [DATAWIDTH-1:0] D, //Input: fixed-point 8.8 format
    output logic o_valid_final_A,
    output logic o_valid_final_B,
    output logic o_valid_final_C,
    output logic o_valid_final_D,
    output logic [2*DATAWIDTH+1:0]output_final_A,
    output logic [2*DATAWIDTH+1:0]output_final_B,
    output logic [2*DATAWIDTH+1:0]output_final_C,
    output logic [2*DATAWIDTH+1:0]output_final_D
);
localparam TOTAL_PIPELINE_STAGES = NUM_PIPELINE_STAGES_MUL + NUM_PIPELINE_STAGES_SQRT + NUM_PIPELINE_STAGES_ADDT;
logic [DATAWIDTH*2-1:0] A_mul;
logic [DATAWIDTH*2-1:0] B_mul;
logic [DATAWIDTH*2-1:0] C_mul;
logic [DATAWIDTH*2-1:0] D_mul;
logic [DATAWIDTH*2+1:0] A_dividend;
logic [DATAWIDTH*2+1:0] B_dividend;
logic [DATAWIDTH*2+1:0] C_dividend;
logic [DATAWIDTH*2+1:0] D_dividend;
logic o_valid_A_mul;
logic o_valid_B_mul;
logic o_valid_C_mul;
logic o_valid_D_mul;
logic o_valid_adder_tree;
logic o_valid_sqrt;
logic [2*DATAWIDTH+1:0] sqrt_out;
logic [2*DATAWIDTH+1:0] sqrt_rem;
logic [2*DATAWIDTH+1:0] R_out_divider_A,R_out_divider_B,R_out_divider_C,R_out_divider_D;
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

logic [4*DATAWIDTH * 2-1:0] adder_in_data;
assign adder_in_data = {D_mul,C_mul,B_mul,A_mul};

adder_tree #(
  .DATAWIDTH(DATAWIDTH * 2),
  .NUM_INPUTS(4), // Maximum is 32
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_ADDT),
  .INSTANCE_ID(0)
)
adder_tree0 (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_A_mul&o_valid_B_mul&o_valid_C_mul&o_valid_D_mul),
  .in_data(adder_in_data), 
  .o_valid(o_valid_adder_tree),
  .sum_reg(adderTree_out)
  );

sqrt_int #(
  .DATAWIDTH(DATAWIDTH*2 + 2),
  .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES_SQRT),
  .INSTANCE_ID(0)
)
sqrt_inst (
  .clk(clk),
  .rst(rst),
  .i_valid(o_valid_adder_tree), 
  .o_valid(o_valid_sqrt),
  .rad(adderTree_out),
  .root(sqrt_out),
  .rem(sqrt_rem)
);

generate
  if (TOTAL_PIPELINE_STAGES == 0) begin
      assign A_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, A};
      assign B_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, B};
      assign C_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, C};
      assign D_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, D};
  end else begin
    wire [DATAWIDTH*4-1:0] stage_dividend_data [0:TOTAL_PIPELINE_STAGES-1];
    wire [DATAWIDTH-1:0] A_stage, B_stage, C_stage, D_stage;
    for (genvar s = 0; s < TOTAL_PIPELINE_STAGES; s++) begin
      logic [4*DATAWIDTH-1:0] input_stage, output_stage;

      if (s == 0) begin
        assign input_stage = {A, B, C, D};
      end else begin
        assign input_stage = stage_dividend_data[s-1];
      end

      pipeline_stage #(
        .WIDTH(DATAWIDTH * 4),
        .ENABLE(1)
      ) pipe_stage_input (
        .clk(clk),
        .rst(rst),
        .data_in(input_stage),
        .data_out(output_stage)
      );

      assign stage_dividend_data[s] = output_stage;
    end

    assign {A_stage, B_stage, C_stage, D_stage} = stage_dividend_data[TOTAL_PIPELINE_STAGES-1];

    assign A_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, A_stage};
    assign B_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, B_stage};
    assign C_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, C_stage};
    assign D_dividend = {{(2*DATAWIDTH+2-DATAWIDTH){1'b0}}, D_stage};
  end
endgenerate

array_divider #(
  .DATAWIDTH(2*DATAWIDTH + 2),
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
  .DATAWIDTH(2*DATAWIDTH + 2),
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
  .DATAWIDTH(2*DATAWIDTH + 2),
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
  .DATAWIDTH(2*DATAWIDTH + 2),
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