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

  localparam STAGE_MASK_WIDTH = DATAWIDTH + 2;
  localparam PIPELINE_STAGE_MASK = (INSTANCE_ID == 0) ? 18'b000000111000000010 : { {STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}},{NUM_PIPELINE_STAGES{1'b1}} };
  logic [DATAWIDTH-1:0] A_reg, B_reg,A_reg_wire, B_reg_wire;

  // Figure out a way to reduce this for now keeping this as is 
  logic [DATAWIDTH*DATAWIDTH-1:0] P [DATAWIDTH:0];  // Two pipeline stages
  logic [DATAWIDTH-2:0] C [2*DATAWIDTH-2:0];
  logic [DATAWIDTH-3:0] S [2*DATAWIDTH-3:0];
  logic [2*DATAWIDTH-1:0] Z [2*DATAWIDTH:0];// [2*DATAWIDTH]
  logic valid [STAGE_MASK_WIDTH-1];

  genvar i, j;

  // Assign A_reg_wire and B_reg_wire based on valid 
  assign A_reg_wire = (valid[0]) ? A_reg : '0;
  assign B_reg_wire = (valid[0]) ? B_reg : '0; 

  // Generate all partial products 
  generate
    for (i = 0; i < DATAWIDTH; i = i + 1) begin
      for (j = 0; j < DATAWIDTH; j = j + 1) begin
        assign P[0][i*DATAWIDTH + j] = A_reg_wire[i] & B_reg_wire[j];
      end
    end
  endgenerate

  assign Z[0][0] = P[0][0*DATAWIDTH + 0]; 

  // Generate first HA array 
  generate
    for (i = 0; i < DATAWIDTH - 1; i = i + 1) begin : HA_only_row
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

  // Generate multiple rows and columns of full adders only 
  generate
      for (i = 0; i < DATAWIDTH - 2; i = i + 1) begin : FA_only_col
          for (j = 0; j < DATAWIDTH - 1; j = j + 1) begin : FA_only_row
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
  
  // Generate the last row 
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

  assign Z[2*DATAWIDTH][DATAWIDTH - 1 : 0] = Z[2*(DATAWIDTH-1)+1][DATAWIDTH -1 : 0];
  assign Z[2*DATAWIDTH][2*DATAWIDTH - 1] = C[2*(DATAWIDTH - 2) + 2][DATAWIDTH - 2];

  // Generate all pipeline stages 
  generate
    for (i = 0; i < STAGE_MASK_WIDTH; i = i + 1) begin : multiplier_pipeline_stage
      
      if (i == 0) begin 

        logic [2*DATAWIDTH:0] input_stage, output_stage; 

        assign input_stage = {A,B,i_valid};
        assign {A_reg,B_reg,valid[0]} = output_stage;

        pipeline_stage #(
          .WIDTH($bits(input_stage)),
          .ENABLE(PIPELINE_STAGE_MASK[i])
        )
        pipeline_inst (
          .clk(clk),
          .rst(rst),
          .data_in(input_stage),
          .data_out(output_stage) 
        );   

      end else if (i == 1) begin
        logic [DATAWIDTH*DATAWIDTH + 2*DATAWIDTH + 1 - 1:0] input_stage, output_stage; 
        
        assign input_stage = {P[0],Z[0],valid[0]};
        assign {P[1], Z[1], valid[1]} = output_stage; 
      
        pipeline_stage #(
          .WIDTH($bits(input_stage)),
          .ENABLE(PIPELINE_STAGE_MASK[i])
        )
        pipeline_inst (
          .clk(clk),
          .rst(rst),
          .data_in(input_stage),
          .data_out(output_stage) 
        );  
      
      end else if (i == STAGE_MASK_WIDTH - 1) begin

        logic [2*DATAWIDTH + 1 - 1:0] input_stage, output_stage; 
        
        assign input_stage = {Z[2*DATAWIDTH],valid[i-1]};
        assign {Z_final, o_valid} = output_stage; 
      
        pipeline_stage #(
          .WIDTH($bits(input_stage)),
          .ENABLE(PIPELINE_STAGE_MASK[i])
        )
        pipeline_inst (
          .clk(clk),
          .rst(rst),
          .data_in(input_stage),
          .data_out(output_stage) 
        ); 

      end else begin
        logic [DATAWIDTH*DATAWIDTH + 2*DATAWIDTH + 1 + DATAWIDTH - 1 + DATAWIDTH - 2 - 1:0] input_stage, output_stage; 
        
        assign input_stage = {P[i-1], C[2*(i-2)], S[2*(i-2)], Z[2*(i-1)], valid[i-1]};
        assign {P[i], C[2*(i-2)+1], S[2*(i-2)+1], Z[2*(i-1) + 1], valid[i]} = output_stage; 
      
        pipeline_stage #(
          .WIDTH($bits(input_stage)),
          .ENABLE(PIPELINE_STAGE_MASK[i])
        )
        pipeline_inst (
          .clk(clk),
          .rst(rst),
          .data_in(input_stage),
          .data_out(output_stage) 
        );  
      end
         
    end
  endgenerate
endmodule