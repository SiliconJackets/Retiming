module full_adder(input a, b, cin, output s, c);
  assign s = a ^ b ^ cin;
  assign c = (a & b) | (b & cin) | (a & cin);
endmodule

module pipeline_stage #(
   parameter WIDTH = 32,
   parameter ENABLE = 1
) (
   input wire clk,
   input wire rst,
   input wire [WIDTH-1:0] data_in,
   output reg [WIDTH-1:0] data_out
);
   generate
       if (ENABLE) begin
           always @(posedge clk or posedge rst) begin
               if (rst)
                   data_out <= {WIDTH{1'b0}};
               else
                   data_out <= data_in;
           end
       end else begin : no_reg
           always @(*) begin
               data_out = data_in;
           end
       end
   endgenerate
endmodule

module AdderSubtractorPipelined #(
    parameter DATAWIDTH = 8,
    parameter NUM_PIPELINE_STAGES = 4,
    parameter INSTANCE_ID = 0
)(
    input  wire clk,
    input  wire rst,
    input  wire [DATAWIDTH-1:0] A,
    input  wire [DATAWIDTH-1:0] B,
    input  wire op, // 0 = add, 1 = subtract
    input  wire i_valid,
    output wire [DATAWIDTH-1:0] Result,
    output wire o_valid,
    output wire Overflow
);

    localparam STAGE_WIDTH = DATAWIDTH / NUM_PIPELINE_STAGES;
    localparam STAGE_MASK_WIDTH = DATAWIDTH + 1;

    wire [STAGE_MASK_WIDTH-1:0] PIPELINE_STAGE_MASK = {STAGE_MASK_WIDTH{1'b1}};

    wire [DATAWIDTH-1:0] A_stage [0:NUM_PIPELINE_STAGES-1];
    wire [DATAWIDTH-1:0] B_stage [0:NUM_PIPELINE_STAGES-1];
    wire [DATAWIDTH-1:0] Sum_stage [0:NUM_PIPELINE_STAGES-1];
    wire valid [0:NUM_PIPELINE_STAGES-1];
    wire carry_stage [0:NUM_PIPELINE_STAGES];

    assign carry_stage[0] = op;

    genvar i;
    generate
        for (i = 0; i < NUM_PIPELINE_STAGES; i = i + 1) begin : pipeline_stages
            logic [2*DATAWIDTH:0] input_stage, output_stage;

            if (i == 0) begin
                wire [DATAWIDTH-1:0] B_mod = B ^ {DATAWIDTH{op}};
                assign input_stage = {A, B_mod, i_valid};
            end else begin
                assign input_stage = {A_stage[i-1], B_stage[i-1], valid[i-1]};
            end

            assign {A_stage[i], B_stage[i], valid[i]} = output_stage;

            pipeline_stage #(
                .WIDTH($bits(input_stage)),
                .ENABLE(PIPELINE_STAGE_MASK[i])
            ) pipe_reg (
                .clk(clk),
                .rst(rst),
                .data_in(input_stage),
                .data_out(output_stage)
            );

            wire [STAGE_WIDTH:0] carry_internal;
            assign carry_internal[0] = carry_stage[i];

            genvar b;
            for (b = 0; b < STAGE_WIDTH; b = b + 1) begin : bit_loop
                localparam IDX = i * STAGE_WIDTH + b;

                wire a_bit = A_stage[i][IDX];
                wire b_bit = B_stage[i][IDX];
                wire cin   = carry_internal[b];

                wire sum, cout;
                full_adder fa (
                    .a(a_bit),
                    .b(b_bit),
                    .cin(cin),
                    .s(sum),
                    .c(cout)
                );

                assign Sum_stage[i][IDX] = sum;
                assign carry_internal[b+1] = cout;
            end

            assign carry_stage[i+1] = carry_internal[STAGE_WIDTH];
        end
    endgenerate

    wire [DATAWIDTH-1:0] SumFinal = Sum_stage[NUM_PIPELINE_STAGES-1];
    wire actual_carry_out = carry_stage[NUM_PIPELINE_STAGES];
    wire carry_into_last  = carry_stage[NUM_PIPELINE_STAGES - 1];

    wire overflow_flag = (op == 0 && actual_carry_out != carry_into_last);

    assign Overflow = overflow_flag;
    assign Result = (overflow_flag && op == 0) ? {DATAWIDTH{1'b1}} :
                    (overflow_flag && op == 1) ? {DATAWIDTH{1'b0}} :
                    SumFinal;

    assign o_valid = valid[NUM_PIPELINE_STAGES-1];
endmodule
