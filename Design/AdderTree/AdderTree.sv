module adder_tree_comb #(
  parameter WIDTH_IN = 5,
  parameter STAGE_ID = 0    
)(
  input  logic [WIDTH_IN-1:0] inA,
  input  logic [WIDTH_IN-1:0] inB,
  output logic [WIDTH_IN:0]   outSum
);

  assign outSum = inA + inB;
endmodule

module adder_tree #(
  parameter DATAWIDTH  = 4,
  parameter NUM_INPUTS = 16,
  parameter NUM_PIPELINE_STAGES = 1,
  parameter INSTANCE_ID = 0
)(
  input  logic clk,
  input  logic rst,
  input  logic i_valid,
  input  logic [NUM_INPUTS-1:0][DATAWIDTH-1:0] in_data,
  output logic o_valid,
  output logic [DATAWIDTH + $clog2(NUM_INPUTS - 1) - 1:0] sum_reg
);

  localparam int NUM_STAGES = $clog2(NUM_INPUTS - 1) + 1;
  localparam STAGE_MASK_WIDTH = NUM_STAGES + 1;
  localparam PIPELINE_STAGE_MASK = {{STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}}, {NUM_PIPELINE_STAGES{1'b1}}}; 

  logic [DATAWIDTH+5:0] stage_data [0:NUM_STAGES][0:NUM_INPUTS-1];
  logic [DATAWIDTH+5:0] comb_result [0:NUM_STAGES][0:(NUM_INPUTS+1)/2];
  
  logic valid_r [0:NUM_STAGES];

  // Generate pipeline stages
  generate
    for (genvar s = 0; s < STAGE_MASK_WIDTH; s++) begin : AdderTree_pipeline_stage
      localparam CUR_INPUTS = NUM_INPUTS;
      localparam OUT_W = DATAWIDTH;
      if (s == 0) begin
          logic [CUR_INPUTS*OUT_W:0] input_stage, output_stage; 

          logic [CUR_INPUTS*OUT_W-1:0] bundle_in;
          logic [CUR_INPUTS*OUT_W-1:0] bundle_out;

          for (genvar i = 0; i < CUR_INPUTS; i++) begin
            assign bundle_in[i*OUT_W +: OUT_W] = in_data[i];
            assign stage_data[0][i] = bundle_out[i*OUT_W +: OUT_W];
          end

          assign input_stage = {bundle_in, i_valid};
          assign {bundle_out, valid_r[0]} = output_stage;

          pipeline_stage #(
            .WIDTH(CUR_INPUTS * OUT_W + 1),
            .ENABLE(PIPELINE_STAGE_MASK[s])
          ) pipe_stage_input (
            .clk(clk), .rst(rst),
            .data_in(input_stage),
            .data_out(output_stage)
          );
        end
      else if (s == STAGE_MASK_WIDTH-1) begin
        localparam int OUT_W = DATAWIDTH + s;
        logic [OUT_W :0] input_stage, output_stage; 

        assign input_stage = {comb_result[s-1][0], valid_r[s-1]};
        assign {sum_reg, o_valid} = output_stage;

        pipeline_stage #(
          .WIDTH(OUT_W + 1),
          .ENABLE(PIPELINE_STAGE_MASK[s])
        ) pipe_stage_input (
          .clk(clk), .rst(rst),
          .data_in(input_stage),
          .data_out(output_stage)
        );
      end else begin
        localparam int OUT_W = DATAWIDTH + s;
        localparam int CUR_INPUTS = ((NUM_INPUTS + (1 << (s-1)) - 1) >> (s-1));
        localparam int NUM_NEXT = (CUR_INPUTS + 1) / 2;

        logic [NUM_NEXT*OUT_W-1:0] bundle_in;
        logic [NUM_NEXT*OUT_W-1:0] bundle_out;

        for (genvar i = 0; i < NUM_NEXT; i++) begin
          assign bundle_in[i*OUT_W +: OUT_W] = comb_result[s-1][i];
          assign stage_data[s][i] = bundle_out[i*OUT_W +: OUT_W];
        end

        pipeline_stage #(
          .WIDTH(NUM_NEXT * OUT_W + 1),
          .ENABLE(PIPELINE_STAGE_MASK[s])
        ) pipe_stage_inst (
          .clk(clk), .rst(rst),
          .data_in({bundle_in, valid_r[s-1]}),
          .data_out({bundle_out, valid_r[s]})
        );
      end
    end
  endgenerate

  // Generate combinational adder stages
  generate
    for (genvar s = 0; s < NUM_STAGES; s++) begin : AdderTree_comb_stage
        localparam int IN_W  = DATAWIDTH + s;
        localparam int OUT_W = IN_W + 1;
        localparam int CUR_INPUTS = (s == 0) ? NUM_INPUTS : ((NUM_INPUTS + (1 << s) - 1) >> s);
        localparam int NUM_ADDERS = (CUR_INPUTS + 1) / 2;

        for (genvar i = 0; i < NUM_ADDERS; i++) begin : ADDERS_comb
          if (2*i + 1 < CUR_INPUTS) begin
            adder_tree_comb #(.WIDTH_IN(IN_W), .STAGE_ID(s)) add_inst (
              .inA(stage_data[s][2*i][IN_W-1:0]),
              .inB(stage_data[s][2*i+1][IN_W-1:0]),
              .outSum(comb_result[s][i])
            );
          end else begin
            assign comb_result[s][i] = stage_data[s][2*i];
          end
        end
    end
  endgenerate

endmodule