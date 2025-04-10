/*
Unsigned Divider with Pipeline Support 
*/

//////////////////////////////////////////////////////////////////////////
// Combinational division stage (no registers inside)
// This stage extracts its next dividend bit from the full dividend (D_in) and passes D_in and B_in unchanged.
//////////////////////////////////////////////////////////////////////////
module div_stage_comb #(
  parameter int WIDTH = 8,
  parameter int FRAC_BITS = 8,
  parameter int BIT_POS = 0  // Determines which quotient bit is set.
)(
  // Pipeline data for dividend and divisor are passed through.
  input  logic [WIDTH-1:0] in_rem,   // Current partial remainder (WIDTH bits)
  input  logic [WIDTH+FRAC_BITS-1:0] D_in,       // Full dividend for this stage (unsigned)
  input  logic [WIDTH-1:0] in_quo,     // Current partial quotient
  input  logic [WIDTH-1:0] B_in,       // Divisor (unsigned)
  output logic [WIDTH-1:0] out_rem,    // Updated partial remainder (WIDTH bits)
  output logic [WIDTH-1:0] out_quo    // Updated partial quotient (WIDTH bits)
);
  always_comb begin
    // Declare local variables at the beginning of the block.
    logic next_bit;
    logic [WIDTH-1:0] new_rem_concat;
    logic condition;

    // Extract the next dividend bit from D_in.
    // For stage with BIT_POS, use bit at position (WIDTH-1 - BIT_POS).
    next_bit = D_in[WIDTH-1 + FRAC_BITS - BIT_POS];
    new_rem_concat = { in_rem[WIDTH-2:0], next_bit };

    condition = (new_rem_concat >= B_in);

    out_rem = condition ? (new_rem_concat - B_in) : new_rem_concat;
    out_quo = { in_quo[WIDTH-2:0], condition };

  end
endmodule

//////////////////////////////////////////////////////////////////////////
// Top-level array divider module (unsigned divider)
//////////////////////////////////////////////////////////////////////////
module array_divider #(
  parameter DATAWIDTH = 4,
  parameter FRAC_BITS = 0,
  parameter NUM_PIPELINE_STAGES = 1,
  parameter INSTANCE_ID = 0
)(
  input  logic                     clk,
  input  logic                     rst,
  // Continuous valid input is assumed.
  input  logic                     i_valid,
  input  logic [DATAWIDTH-1:0]         A,      // Dividend (unsigned)
  input  logic [DATAWIDTH-1:0]         B,      // Divisor (unsigned)
  output logic                     o_valid,
  output logic [DATAWIDTH-1:0]         Q_out,  // Registered quotient
  output logic [DATAWIDTH-1:0]         R_out  // Registered remainder
  // output logic [WIDTH-1:0]         Q,      // Combinational quotient
  // output logic [WIDTH-1:0]         R       // Combinational remainder
);

  logic [DATAWIDTH-1+FRAC_BITS:0] A_shift;// 
  assign A_shift = A << FRAC_BITS;
  localparam STAGE_MASK_WIDTH = DATAWIDTH + 1 + FRAC_BITS; // 2
  localparam PIPELINE_STAGE_MASK = {{STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}}, {NUM_PIPELINE_STAGES{1'b1}}}; 

  // Valid signal pipeline (indices 0 to WIDTH)
  logic i_valid_r [0:DATAWIDTH+FRAC_BITS];// 0:1



  // Pipeline registers for full dividend and divisor.
  // These are passed along the pipeline using the extra ports of the stage modules.
  logic [DATAWIDTH-1+FRAC_BITS:0] D_pipe [0:DATAWIDTH+FRAC_BITS];// 0:1
  logic [DATAWIDTH-1:0] B_pipe [0:DATAWIDTH+FRAC_BITS]; // 0:1

  // Partial remainder and partial quotient arrays (WIDTH bits each).
  // There are (WIDTH+1) stages (0 to WIDTH).
  logic [DATAWIDTH-1:0] partial_rem0 = 'b0;
  logic [DATAWIDTH-1:0] partial_quo0 = 'b0;

  logic [DATAWIDTH-1:0] partial_rem [0:DATAWIDTH+FRAC_BITS]; //0:1
  logic [DATAWIDTH-1:0] partial_quo [0:DATAWIDTH+FRAC_BITS]; //0:1

  logic [DATAWIDTH-1:0] comb_rem [0:DATAWIDTH+FRAC_BITS]; //0:1
  logic [DATAWIDTH-1:0] comb_quo [0:DATAWIDTH+FRAC_BITS]; //0:1
  
  
  generate
    // if (ENABLE) begin : row_stages  // only 0
      for (genvar i = 0; i < DATAWIDTH + FRAC_BITS; i = i + 1) begin : comb_stage_loop
        div_stage_comb #(.WIDTH(DATAWIDTH), .FRAC_BITS(FRAC_BITS), .BIT_POS(i)) stage_i (
          .in_rem    (partial_rem[i]),  // pr0
          .D_in      (D_pipe[i]),  // D0
          .in_quo    (partial_quo[i]), // qr0
          .B_in      (B_pipe[i]), // B0
          .out_rem   (comb_rem[i]), // cr0
          .out_quo   (comb_quo[i]) //cq0
        );


    end
  endgenerate


  generate// 0 , 1
    for (genvar i = 0; i < STAGE_MASK_WIDTH; i = i + 1) begin : divider_pipeline_stage
        if (i == 0) begin

          logic [4*DATAWIDTH + 1 + FRAC_BITS-1:0] input_stage, output_stage; 

          assign input_stage = {partial_rem0, partial_quo0, A_shift, B, i_valid};
          assign {partial_rem[0], partial_quo[0], D_pipe[0], B_pipe[0], i_valid_r[0]} = output_stage;

          pipeline_stage #(
                .WIDTH(4*DATAWIDTH + 1 + FRAC_BITS), //5 
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
            assign {R_out, Q_out, D_pipe[i], B_pipe[i], o_valid} = output_stage;
            pipeline_stage #(
                .WIDTH(4*DATAWIDTH + 1 + FRAC_BITS),
                .ENABLE(PIPELINE_STAGE_MASK[i])
                ) pipe_stage_inst (
                .clk(clk),
                .rst(rst),
                .data_in(input_stage),
                .data_out(output_stage)
                );
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