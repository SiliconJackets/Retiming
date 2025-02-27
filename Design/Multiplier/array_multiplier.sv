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
  parameter WIDTH = 8,
  parameter NUM_STAGES = 1,           // For now, have stages refer to pp sums (seventh row is reg out)
  parameter MASK = 7'h02,             // 1111111 -> pipeline each row sum
  parameter ENABLE = 1
)(
  input logic clk,
  input logic rst,
  input logic i_valid,
  input logic [WIDTH-1:0] A,
  input logic [WIDTH-1:0] B,
  output logic o_valid,
  output logic [WIDTH*2-1:0] Z_reg,
  output logic [WIDTH*2-1:0] Z
);

  // Keep it as seven for now
  // localparam NUM_STAGES = WIDTH - 1;
  localparam REG_IN = 1;
  localparam REG_OUT = 1;

  // Temp vars for implementation
  // logic [15:0] Z_temp[NUM_STAGES-1+REG_IN+REG_OUT:0];

  logic [WIDTH-1:0] A_reg;
  logic [WIDTH-1:0] B_reg;
  logic i_valid_r[NUM_STAGES-1+REG_IN+REG_OUT:0];   // Keep track of valid signal at each stage
  logic [WIDTH-1:0] P[WIDTH-1:0];  // Partial products for initial stage
  logic [WIDTH-1:0] P_reg[NUM_STAGES-1+REG_IN:0][WIDTH-1:0]; // Each stage acts as a row for now
  logic [54:0] C;      // Carry signals
  logic [43:0] S;      // Sum signals

  // Maybe use countones?
  generate
    if (ENABLE) begin
      // Row Zero
      if (MASK[0]) begin
        half_adder h0 (P_reg[0][0][1], P_reg[0][1][0], Z[1], C[0]);
        half_adder h1 (P_reg[0][1][1], P_reg[0][2][0], S[0], C[1]);
        half_adder h2 (P_reg[0][2][1], P_reg[0][3][0], S[1], C[2]);
        half_adder h3 (P_reg[0][3][1], P_reg[0][4][0], S[2], C[3]);
        half_adder h4 (P_reg[0][4][1], P_reg[0][5][0], S[3], C[4]);
        half_adder h5 (P_reg[0][5][1], P_reg[0][6][0], S[4], C[5]);
        half_adder h6 (P_reg[0][6][1], P_reg[0][7][0], S[5], C[6]);
      end else begin
        half_adder h0 (P[0][1], P[1][0], Z[1], C[0]);
        half_adder h1 (P[1][1], P[2][0], S[0], C[1]);
        half_adder h2 (P[2][1], P[3][0], S[1], C[2]);
        half_adder h3 (P[3][1], P[4][0], S[2], C[3]);
        half_adder h4 (P[4][1], P[5][0], S[3], C[4]);
        half_adder h5 (P[5][1], P[6][0], S[4], C[5]);
        half_adder h6 (P[6][1], P[7][0], S[5], C[6]);
      end
      // Row One
      if (MASK[1]) begin
        full_adder f0 (P_reg[$countones(MASK[0])][0][2], C[0], S[0], Z[2], C[7]);
        full_adder f1 (P_reg[$countones(MASK[0])][1][2], C[1], S[1], S[6], C[8]);
        full_adder f2 (P_reg[$countones(MASK[0])][2][2], C[2], S[2], S[7], C[9]);
        full_adder f3 (P_reg[$countones(MASK[0])][3][2], C[3], S[3], S[8], C[10]);
        full_adder f4 (P_reg[$countones(MASK[0])][4][2], C[4], S[4], S[9], C[11]);
        full_adder f5 (P_reg[$countones(MASK[0])][5][2], C[5], S[5], S[10], C[12]);
        full_adder f6 (P_reg[$countones(MASK[0])][6][2], C[6], P_reg[$countones(MASK[0])][7][1], S[11], C[13]);
      end else begin
        full_adder f0 (P[0][2], C[0], S[0], Z[2], C[7]);
        full_adder f1 (P[1][2], C[1], S[1], S[6], C[8]);
        full_adder f2 (P[2][2], C[2], S[2], S[7], C[9]);
        full_adder f3 (P[3][2], C[3], S[3], S[8], C[10]);
        full_adder f4 (P[4][2], C[4], S[4], S[9], C[11]);
        full_adder f5 (P[5][2], C[5], S[5], S[10], C[12]);
        full_adder f6 (P[6][2], C[6], P[7][1], S[11], C[13]);
      end
      // Row Two
      if (MASK[2]) begin
        full_adder f7  (P_reg[$countones(MASK[1:0])][0][3], C[7], S[6], Z[3], C[14]);
        full_adder f8  (P_reg[$countones(MASK[1:0])][1][3], C[8], S[7], S[12], C[15]);
        full_adder f9  (P_reg[$countones(MASK[1:0])][2][3], C[9], S[8], S[13], C[16]);
        full_adder f10 (P_reg[$countones(MASK[1:0])][3][3], C[10], S[9], S[14], C[17]);
        full_adder f11 (P_reg[$countones(MASK[1:0])][4][3], C[11], S[10], S[15], C[18]);
        full_adder f12 (P_reg[$countones(MASK[1:0])][5][3], C[12], S[11], S[16], C[19]);
        full_adder f13 (P_reg[$countones(MASK[1:0])][6][3], C[13], P_reg[$countones(MASK[1:0])][7][2], S[17], C[20]);
      end else begin
        full_adder f7  (P[0][3], C[7], S[6], Z[3], C[14]);
        full_adder f8  (P[1][3], C[8], S[7], S[12], C[15]);
        full_adder f9  (P[2][3], C[9], S[8], S[13], C[16]);
        full_adder f10 (P[3][3], C[10], S[9], S[14], C[17]);
        full_adder f11 (P[4][3], C[11], S[10], S[15], C[18]);
        full_adder f12 (P[5][3], C[12], S[11], S[16], C[19]);
        full_adder f13 (P[6][3], C[13], P[7][2], S[17], C[20]);
      end
      // Row Three
      if (MASK[3]) begin
        full_adder f14 (P_reg[$countones(MASK[2:0])][0][4], C[14], S[12], Z[4], C[21]);
        full_adder f15 (P_reg[$countones(MASK[2:0])][1][4], C[15], S[13], S[18], C[22]);
        full_adder f16 (P_reg[$countones(MASK[2:0])][2][4], C[16], S[14], S[19], C[23]);
        full_adder f17 (P_reg[$countones(MASK[2:0])][3][4], C[17], S[15], S[20], C[24]);
        full_adder f18 (P_reg[$countones(MASK[2:0])][4][4], C[18], S[16], S[21], C[25]);
        full_adder f19 (P_reg[$countones(MASK[2:0])][5][4], C[19], S[17], S[22], C[26]);
        full_adder f20 (P_reg[$countones(MASK[2:0])][6][4], C[20], P_reg[$countones(MASK[2:0])][7][3], S[23], C[27]);
      end else begin
        full_adder f14 (P[0][4], C[14], S[12], Z[4], C[21]);
        full_adder f15 (P[1][4], C[15], S[13], S[18], C[22]);
        full_adder f16 (P[2][4], C[16], S[14], S[19], C[23]);
        full_adder f17 (P[3][4], C[17], S[15], S[20], C[24]);
        full_adder f18 (P[4][4], C[18], S[16], S[21], C[25]);
        full_adder f19 (P[5][4], C[19], S[17], S[22], C[26]);
        full_adder f20 (P[6][4], C[20], P[7][3], S[23], C[27]);
      end
      // Row Four
      if (MASK[4]) begin
        full_adder f21 (P_reg[$countones(MASK[3:0])][0][5], C[21], S[18], Z[5], C[28]);
        full_adder f22 (P_reg[$countones(MASK[3:0])][1][5], C[22], S[19], S[24], C[29]);
        full_adder f23 (P_reg[$countones(MASK[3:0])][2][5], C[23], S[20], S[25], C[30]);
        full_adder f24 (P_reg[$countones(MASK[3:0])][3][5], C[24], S[21], S[26], C[31]);
        full_adder f25 (P_reg[$countones(MASK[3:0])][4][5], C[25], S[22], S[27], C[32]);
        full_adder f26 (P_reg[$countones(MASK[3:0])][5][5], C[26], S[23], S[28], C[33]);
        full_adder f27 (P_reg[$countones(MASK[3:0])][6][5], C[27], P_reg[$countones(MASK[3:0])][7][4], S[29], C[34]);
      end else begin
        full_adder f21 (P[0][5], C[21], S[18], Z[5], C[28]);
        full_adder f22 (P[1][5], C[22], S[19], S[24], C[29]);
        full_adder f23 (P[2][5], C[23], S[20], S[25], C[30]);
        full_adder f24 (P[3][5], C[24], S[21], S[26], C[31]);
        full_adder f25 (P[4][5], C[25], S[22], S[27], C[32]);
        full_adder f26 (P[5][5], C[26], S[23], S[28], C[33]);
        full_adder f27 (P[6][5], C[27], P[7][4], S[29], C[34]);
      end
      // Row Five
      if (MASK[5]) begin
        full_adder f28 (P_reg[$countones(MASK[4:0])][0][6], C[28], S[24], Z[6], C[35]);
        full_adder f29 (P_reg[$countones(MASK[4:0])][1][6], C[29], S[25], S[30], C[36]);
        full_adder f30 (P_reg[$countones(MASK[4:0])][2][6], C[30], S[26], S[31], C[37]);
        full_adder f31 (P_reg[$countones(MASK[4:0])][3][6], C[31], S[27], S[32], C[38]);
        full_adder f32 (P_reg[$countones(MASK[4:0])][4][6], C[32], S[28], S[33], C[39]);
        full_adder f33 (P_reg[$countones(MASK[4:0])][5][6], C[33], S[29], S[34], C[40]);
        full_adder f34 (P_reg[$countones(MASK[4:0])][6][6], C[34], P_reg[$countones(MASK[4:0])][7][5], S[35], C[41]);
      end else begin
        full_adder f28 (P[0][6], C[28], S[24], Z[6], C[35]);
        full_adder f29 (P[1][6], C[29], S[25], S[30], C[36]);
        full_adder f30 (P[2][6], C[30], S[26], S[31], C[37]);
        full_adder f31 (P[3][6], C[31], S[27], S[32], C[38]);
        full_adder f32 (P[4][6], C[32], S[28], S[33], C[39]);
        full_adder f33 (P[5][6], C[33], S[29], S[34], C[40]);
        full_adder f34 (P[6][6], C[34], P[7][5], S[35], C[41]);
      end
      // Row Six
      if (MASK[6]) begin
        full_adder f35 (P_reg[$countones(MASK[5:0])][0][7], C[35], S[30], Z[7], C[42]);
        full_adder f36 (P_reg[$countones(MASK[5:0])][1][7], C[36], S[31], S[36], C[43]);
        full_adder f37 (P_reg[$countones(MASK[5:0])][2][7], C[37], S[32], S[37], C[44]);
        full_adder f38 (P_reg[$countones(MASK[5:0])][3][7], C[38], S[33], S[38], C[45]);
        full_adder f39 (P_reg[$countones(MASK[5:0])][4][7], C[39], S[34], S[39], C[46]);
        full_adder f40 (P_reg[$countones(MASK[5:0])][5][7], C[40], S[35], S[40], C[47]);
        full_adder f41 (P_reg[$countones(MASK[5:0])][6][7], C[41], P_reg[$countones(MASK[5:0])][7][6], S[41], C[48]);
      end else begin
        full_adder f35 (P[0][7], C[35], S[30], Z[7], C[42]);
        full_adder f36 (P[1][7], C[36], S[31], S[36], C[43]);
        full_adder f37 (P[2][7], C[37], S[32], S[37], C[44]);
        full_adder f38 (P[3][7], C[38], S[33], S[38], C[45]);
        full_adder f39 (P[4][7], C[39], S[34], S[39], C[46]);
        full_adder f40 (P[5][7], C[40], S[35], S[40], C[47]);
        full_adder f41 (P[6][7], C[41], P[7][6], S[41], C[48]);
      end
      // Row Seven
      if (REG_OUT) begin
        half_adder h7 (C[42], S[36], Z[8], C[49]);
        full_adder f42 (C[49], C[43], S[37], Z[9], C[50]);
        full_adder f43 (C[50], C[44], S[38], Z[10], C[51]);
        full_adder f44 (C[51], C[45], S[39], Z[11], C[52]);
        full_adder f45 (C[52], C[46], S[40], Z[12], C[53]);
        full_adder f46 (C[53], C[47], S[41], Z[13], C[54]);
        full_adder f47 (C[54], C[48], P_reg[$countones(MASK[6:0])][7][7], Z[14], Z[15]);
      end else begin
        half_adder h7 (C[42], S[36], Z[8], C[49]);
        full_adder f42 (C[49], C[43], S[37], Z[9], C[50]);
        full_adder f43 (C[50], C[44], S[38], Z[10], C[51]);
        full_adder f44 (C[51], C[45], S[39], Z[11], C[52]);
        full_adder f45 (C[52], C[46], S[40], Z[12], C[53]);
        full_adder f46 (C[53], C[47], S[41], Z[13], C[54]);
        full_adder f47 (C[54], C[48], P[7][7], Z[14], Z[15]);
      end
    end
  endgenerate
  
  genvar i, j;
  
  // Generate Partial Products
  // This should be done combinationally, which is then
  // registered into P_reg[0] at the next clock cycle.
  // Make sure to use the registered inputs and valid signal checks!
  generate
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        assign P[i][j] = A_reg[i] & B_reg[j];
      end
    end
  endgenerate
  
  assign Z[0] = P[0][0];
  // assign Z_temp[0][0] = P[0][0];

  // Register the inputs
  // Track the valid signals
  always_ff @(posedge clk) begin
    i_valid_r[0] <= rst ? '0 : i_valid;
    if (i_valid) begin
      A_reg <= A;
      B_reg <= B;
    end else begin
      A_reg <= '0;
      B_reg <= '0;
    end
  end

  // Shifting the partial products from one stage to the next
  // Stage zero is simply registering the inputs
  // Stage one is registering the partial products
  // Stage two begins summing of partial products
  always_ff @(posedge clk) begin
    if (rst) begin
      // Reset the pipeline registers to zero
      for (int i = 0; i < NUM_STAGES+REG_IN+REG_OUT; i = i + 1) begin
        for (int j = 0; j < 8; j = j + 1) begin
          P_reg[i][j] <= 8'b0;  // Reset all rows of partial products to zero
        end
      end
    end else begin
      // Shift each row of partial products through the pipeline
      for (int stage = NUM_STAGES-1+REG_IN+REG_OUT; stage > 0; stage = stage - 1) begin
        for (int row = 0; row < 8; row = row + 1) begin
          P_reg[stage][row] <= P_reg[stage-1][row];  // Shift each row to the next stage
        end
      end

      // Load the first stage with newly computed partial products
      P_reg[0] <= P;  // The first stage holds the initial computed partial products
      
      // Shift the valid bit from each stage
      for (int i = NUM_STAGES-1+REG_IN+REG_OUT; i > 0; i = i - 1) begin
        i_valid_r[i] <= i_valid_r[i - 1];
      end

    end
  end

  // Register the outputs
  // If it is not valid, default to 'x (for now, can always change to zero)
  // Need to double check if this is the right index
  always_ff @(posedge clk) begin
    if (i_valid_r[NUM_STAGES-1+REG_IN+REG_OUT]) begin
      //Z_reg[15:1] <= Z;
      // Z_reg[0] <= P_reg[7][0][0];
      Z_reg <= Z;
      o_valid <= '1;
    end else begin
      Z_reg <= 'x;
      o_valid <= '0;
    end
  end

endmodule



