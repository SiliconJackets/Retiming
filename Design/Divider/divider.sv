module div_stage_comb #(
  parameter int WIDTH = 8,
  parameter int FRAC_BITS = 8,
  parameter int BIT_POS = 0
)(
  input  logic [WIDTH-1:0] in_rem,   
  input  logic [WIDTH+FRAC_BITS-1:0] D_in,       
  input  logic [WIDTH-1:0] in_quo,     
  input  logic [WIDTH-1:0] B_in,      
  output logic [WIDTH-1:0] out_rem,    
  output logic [WIDTH-1:0] out_quo    
);

  always_comb begin
    logic next_bit;
    logic [WIDTH-1:0] new_rem_concat;
    logic condition;

    next_bit = D_in[WIDTH-1 + FRAC_BITS - BIT_POS];
    new_rem_concat = { in_rem[WIDTH-2:0], next_bit };

    condition = (new_rem_concat >= B_in);

    out_rem = condition ? (new_rem_concat - B_in) : new_rem_concat;
    out_quo = { in_quo[WIDTH-2:0], condition };

  end
endmodule

module array_divider #(
  parameter DATAWIDTH = 4,
  parameter FRAC_BITS = 0,
  parameter NUM_PIPELINE_STAGES = 1,
  parameter INSTANCE_ID = 0
)(
  input  logic                     clk,
  input  logic                     rst,
  input  logic                     i_valid,
  input  logic [DATAWIDTH-1:0]         A,      
  input  logic [DATAWIDTH-1:0]         B,      
  output logic                     o_valid,
  output logic [DATAWIDTH-1:0]         Q_out,  
  output logic [DATAWIDTH-1:0]         R_out  
);

  logic [DATAWIDTH-1+FRAC_BITS:0] A_shift;
  assign A_shift = A << FRAC_BITS;
  localparam STAGE_MASK_WIDTH = DATAWIDTH + 1 + FRAC_BITS; 
  localparam PIPELINE_STAGE_MASK = {{STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}}, {NUM_PIPELINE_STAGES{1'b1}}};
  // localparam PIPELINE_STAGE_MASK = (INSTANCE_ID == 3) ? 27'b000000000000000000000001001 : (INSTANCE_ID == 2) ? 27'b000000000000000000000001001 : (INSTANCE_ID == 1) ? 27'b000000000000000000000001001 : (INSTANCE_ID == 0) ? 27'b000000000000000000000001001 : {{STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}}, {NUM_PIPELINE_STAGES{1'b1}}}; 

  logic i_valid_r [0:DATAWIDTH+FRAC_BITS];

  logic [DATAWIDTH-1+FRAC_BITS:0] D_pipe [0:DATAWIDTH+FRAC_BITS];
  logic [DATAWIDTH-1:0] B_pipe [0:DATAWIDTH+FRAC_BITS];

  logic [DATAWIDTH-1:0] partial_rem0 = 'b0;
  logic [DATAWIDTH-1:0] partial_quo0 = 'b0;

  logic [DATAWIDTH-1:0] partial_rem [0:DATAWIDTH+FRAC_BITS];
  logic [DATAWIDTH-1:0] partial_quo [0:DATAWIDTH+FRAC_BITS];

  logic [DATAWIDTH-1:0] comb_rem [0:DATAWIDTH+FRAC_BITS];
  logic [DATAWIDTH-1:0] comb_quo [0:DATAWIDTH+FRAC_BITS];
  
  logic [DATAWIDTH-1:0] Q_out_calc, R_out_calc;

  generate
      for (genvar i = 0; i < DATAWIDTH + FRAC_BITS; i = i + 1) begin : comb_stage_loop
        div_stage_comb #(.WIDTH(DATAWIDTH), .FRAC_BITS(FRAC_BITS), .BIT_POS(i)) stage_i (
          .in_rem    (partial_rem[i]),
          .D_in      (D_pipe[i]),
          .in_quo    (partial_quo[i]),
          .B_in      (B_pipe[i]),
          .out_rem   (comb_rem[i]),
          .out_quo   (comb_quo[i])
        );
    end
  endgenerate

  generate
    for (genvar i = 0; i < STAGE_MASK_WIDTH; i = i + 1) begin : divider_pipeline_stage
        if (i == 0) begin

          logic [4*DATAWIDTH + 1 + FRAC_BITS-1:0] input_stage, output_stage; 

          assign input_stage = {partial_rem0, partial_quo0, A_shift, B, i_valid};
          assign {partial_rem[0], partial_quo[0], D_pipe[0], B_pipe[0], i_valid_r[0]} = output_stage;

          pipeline_stage #(
                .WIDTH(4*DATAWIDTH + 1 + FRAC_BITS),
                .ENABLE(PIPELINE_STAGE_MASK[i])
              ) pipe_stage_inst (
                .clk(clk),
                .rst(rst),
                .data_in(input_stage),
                .data_out(output_stage)
              );
        end else if (i == STAGE_MASK_WIDTH - 1) begin
            logic [4*DATAWIDTH + 1 + FRAC_BITS-1:0] input_stage, output_stage; 

            assign input_stage = {comb_rem[i-1], comb_quo[i-1], D_pipe[i-1], B_pipe[i-1], i_valid_r[i-1]};
            assign {R_out_calc, Q_out_calc, D_pipe[i], B_pipe[i], o_valid} = output_stage;
            pipeline_stage #(
                .WIDTH(4*DATAWIDTH + 1 + FRAC_BITS),
                .ENABLE(PIPELINE_STAGE_MASK[i])
                ) pipe_stage_inst (
                .clk(clk),
                .rst(rst),
                .data_in(input_stage),
                .data_out(output_stage)
                );
            assign Q_out = (o_valid) ? Q_out_calc:'b0;
            assign R_out = (o_valid) ? R_out_calc:'b0;

        end else begin
            logic [4*DATAWIDTH + 1 + FRAC_BITS-1:0] input_stage, output_stage; 

            assign input_stage = {comb_rem[i-1], comb_quo[i-1], D_pipe[i-1], B_pipe[i-1], i_valid_r[i-1]};
            assign {partial_rem[i], partial_quo[i], D_pipe[i], B_pipe[i], i_valid_r[i]} = output_stage;

        pipeline_stage #(
              .WIDTH(4*DATAWIDTH + 1 + FRAC_BITS),
              .ENABLE(PIPELINE_STAGE_MASK[i])
            ) pipe_stage_inst (
              .clk(clk),
              .rst(rst),
              .data_in(input_stage),
              .data_out(output_stage)
            );
        end
    end
  endgenerate
  
endmodule