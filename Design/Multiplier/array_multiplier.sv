/*
8-bit Array Multiplier with Pipeline Support

Notes:
- Registered inputs and outputs by default
  - Minimum of three stages
- If each row summation is pipelined, then max sum stages is WIDTH - 1
- If partial product generation is pipelined, then one stage
- Thus, max # of stages is RegIn + PP Gen + WIDTH - 1 + RegOut

Status:
- Partial products are fully pipelined
- Valid signal is fully pipelined
- Accepts variable number of pipeline stages (0-7)

ToDo:
  1. Fully pipeline Z_reg
  2. Fully pipeline carry C
  3. Fully piepline sum C
*/

module half_adder(input a, b, output s, c);
  assign s = a ^ b;
  assign c = a & b;
endmodule

module full_adder(input a, b, cin, output s, c);
  assign s = a ^ b ^ cin;
  assign c = (a & b) | (b & cin) | (a & cin);
endmodule

module array_multiplier #(
  parameter DATAWIDTH = 4,
  parameter NUM_PIPELINE_STAGES = 1,           // For now, have stages refer to pp sums (seventh row is reg out)
  parameter INSTANCE_ID = 0
)(
  input logic clk,
  input logic rst,
  input logic i_valid,
  input logic [DATAWIDTH-1:0] A,
  input logic [DATAWIDTH-1:0] B,
  output logic o_valid,
  output logic [DATAWIDTH*2-1:0] Z_final
);

  localparam PIPELINE_STAGE_MASK = 7'h0F;

  logic [DATAWIDTH-1:0] A0, B0, A1,B1;
  logic [DATAWIDTH*DATAWIDTH-1:0] P [10:0];  // Two pipeline stages
  logic [DATAWIDTH-2:0] C [10:0];
  logic [DATAWIDTH-3:0] S [10:0];
  logic [2*DATAWIDTH-1:0] Z [10:0];
  logic valid [10:0];

  assign A0 = (i_valid) ? A : '0;
  assign B0 = (i_valid) ? B : '0; 
  
  pipeline_stage #(
    .WIDTH($bits({A0,B0,i_valid})),
    .ENABLE(PIPELINE_STAGE_MASK[0])
  )
  pipeline0 (
    .clk(clk),
    .rst(rst),
    .data_in({A0,B0,i_valid}),
    .data_out({A1,B1,valid[0]}) 
  );

  genvar i, j;
  generate
    for (i = 0; i < DATAWIDTH; i = i + 1) begin
      for (j = 0; j < DATAWIDTH; j = j + 1) begin
        assign P[0][i*DATAWIDTH + j] = A1[i] & B1[j];
      end
    end
  endgenerate

  assign Z[0][0] = P[0][0*DATAWIDTH + 0] ; 
  
  pipeline_stage #(
    .WIDTH($bits({P[0],Z[0],valid[0]})),
    .ENABLE(PIPELINE_STAGE_MASK[1])
  )
  pipeline1 (
    .clk(clk),
    .rst(rst),
    .data_in({P[0],Z[0],valid[0]}),
    .data_out({P[1],Z[1],valid[1]}) 
  );
 
   
  generate
    for (i = 0; i < DATAWIDTH - 1; i = i + 1) begin : HA_INST_i
      logic s_wire_ha;
      if (i == 0)
          assign Z[2] = (Z[1] & ~(1'b1 << 1)) | (s_wire_ha << 1);
      else
          assign S[0][i-1] = s_wire_ha; 

      half_adder ha_inst (
        .a(P[1][i*DATAWIDTH + 1]),
        .b(P[1][(i+1)*DATAWIDTH + 0]),
        .s(s_wire_ha),
        .c(C[0][i]) 
      );
    end
  endgenerate

  generate
    for (i = 0; i < DATAWIDTH - 1; i = i + 1) begin : PIPE_INST_i
      pipeline_stage #(
        .WIDTH($bits({P[i+1],C[2*i],S[2*i],Z[2*(i+1)],valid[1+i]})),
        .ENABLE(PIPELINE_STAGE_MASK[i+2])
      )
      pipeline (
        .clk(clk),
        .rst(rst),
        .data_in({P[i+1],C[2*i],S[2*i],Z[2*(i+1)],valid[1+i]}),
        .data_out({{P[i+2],C[2*i+1],S[2*i+1],Z[2*(i+1)+1],valid[2+i]}}) 
      );
    end
  endgenerate

  generate
      for (i = 0; i < DATAWIDTH - 2; i = i + 1) begin : FA_INST_i
          for (j = 0; j < DATAWIDTH - 1; j = j + 1) begin : FA_INST_j
              logic cin_wire;
              logic s_wire_fa;

              if (j == DATAWIDTH - 2)
                  assign cin_wire = P[2+i][(j+1)*DATAWIDTH + (1+i)];
              else
                  assign cin_wire = S[2*i+1][j];

              if (j == 0)
                  assign Z[2*(i+1)+2] = (Z[2*(i+1)+1] & ~(1'b1 << (i+2))) | (s_wire_fa << (i+2));
              else
                  assign S[2*i+2][j-1] = s_wire_fa;

              full_adder fa_inst (
                .a(P[2+i][j*DATAWIDTH + (2+i)]), 
                .b(C[2*i + 1][j]),
                .cin(cin_wire),
                .s(s_wire_fa),
                .c(C[2*i + 2][j]));
          end
      end
  endgenerate

  assign Z[2*(DATAWIDTH-1)+2][DATAWIDTH -1 : 0] = Z[2*(DATAWIDTH-1)+1][DATAWIDTH -1 : 0];
  assign Z[2*(DATAWIDTH-1)+2][2*DATAWIDTH - 1] = C[2*(DATAWIDTH - 2) + 2][DATAWIDTH - 2];
  assign Z_final = Z[2*(DATAWIDTH-1)+2];
  assign o_valid = valid[DATAWIDTH];
  generate
    for (i = 0; i < DATAWIDTH - 1; i = i + 1) begin : HAFA_INST_i
      logic cin_wire_hafa;
      logic s_wire_hafa;
      if (i == DATAWIDTH - 2)
          assign cin_wire_hafa = P[DATAWIDTH][(i+1)*DATAWIDTH + (DATAWIDTH - 1)];
      else
          assign cin_wire_hafa = S[2*(DATAWIDTH-2)][i];

      assign Z[2*(DATAWIDTH-1)+2][DATAWIDTH+i] = s_wire_hafa;

      if (i == 0) begin
        half_adder ha_inst (
          .a(C[2*(DATAWIDTH - 2) + 1][i]),
          .b(cin_wire_hafa),
          .s(s_wire_hafa),
          .c(C[2*(DATAWIDTH - 2) + 2][i]) 
        );
      end else begin
        full_adder fa_inst (
          .a(C[2*(DATAWIDTH - 2) + 2][i-1]), 
          .b(C[2*(DATAWIDTH - 2) + 1][i]),
          .cin(cin_wire_hafa),
          .s(s_wire_hafa),
          .c(C[2*(DATAWIDTH - 2) + 2][i]));
      end
    end
  endgenerate

endmodule
