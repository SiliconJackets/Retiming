module sqrt_stage #(
    parameter DATAWIDTH = 8
)(
    input  logic [DATAWIDTH+1:0] ac,      // Accumulator
    input  logic [DATAWIDTH-1:0] x,       // Remaining radicand
    input  logic [DATAWIDTH-1:0] q,       // Intermediate root
    output logic [DATAWIDTH+1:0] ac_next, 
    output logic [DATAWIDTH-1:0] x_next,  
    output logic [DATAWIDTH-1:0] q_next   
);
    logic [DATAWIDTH+1:0] test_res;
    
    always_comb begin
        test_res = ac - {q, 2'b01};
        if (test_res[DATAWIDTH+1] == 0) begin  // If test_res >= 0
            {ac_next, x_next} = {test_res[DATAWIDTH-1:0], x, 2'b0};
            q_next = {q[DATAWIDTH-2:0], 1'b1};
        end else begin
            {ac_next, x_next} = {ac[DATAWIDTH-1:0], x, 2'b0};
            q_next = q << 1;
        end
    end

endmodule

module sqrt_int #(
    parameter DATAWIDTH = 8,
    parameter NUM_PIPELINE_STAGES = 1,
    parameter INSTANCE_ID = 0
)(
    input  wire logic clk,
    input  wire logic i_valid,
    output      logic o_valid,
    input  wire logic [DATAWIDTH-1:0] rad,
    output      logic [DATAWIDTH-1:0] root,
    output      logic [DATAWIDTH-1:0] rem
);
    localparam ITERATIONS = DATAWIDTH >> 1;   // Always complete in N/2 ITERATIONS (not cycles necessarily)

    localparam STAGE_MASK_WIDTH = ITERATIONS + 2;     // N/2 ITERATIONS + reg in + reg out
    localparam PIPELINE_STAGE_MASK = { {STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}},{NUM_PIPELINE_STAGES{1'b1}} };
    
    // Register arrays for pipeline stages
    logic [DATAWIDTH-1:0] x [ITERATIONS:0];
    logic [DATAWIDTH-1:0] q [ITERATIONS:0];
    logic [DATAWIDTH+1:0] ac [ITERATIONS:0];

    logic [DATAWIDTH-1:0] rad_reg;

    genvar i, j;

    // Expand
    logic valid [STAGE_MASK_WIDTH-1:0];

    assign {ac[0], x[0]} = (valid[0]) ? {{DATAWIDTH{1'b0}}, rad_reg, 2'b0} : '0;
    assign q[0] = '0;

    // Generate pipeline stages
    generate
        for (i = 0; i < STAGE_MASK_WIDTH; i = i + 1) begin : sqrt_pipeline_stage
            
            // Whether we want to register the inputs
            if (i == 0) begin

                // rad is DATAWIDTH, valid is 1 bit, so need DATAWIDTH - 1 + 1 bits
                logic [DATAWIDTH:0] input_stage, output_stage;

                assign input_stage = {rad, i_valid};
                assign {rad_reg, valid[0]} = output_stage;

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

            // Whether we want to register the outputs
            end else if (i == STAGE_MASK_WIDTH - 1) begin

                // root and rem are DATAWIDTH, valid is 1 bit, so need 2*DATAWIDTH - 1 + 1 bits
                logic [2*DATAWIDTH:0] input_stage, output_stage;

                // Undo the final shift
                assign input_stage = {q[ITERATIONS], ac[ITERATIONS][DATAWIDTH+1:2], valid[i-1]};
                assign {root, rem, o_valid} = output_stage;

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

                logic [DATAWIDTH+1:0] ac_buff;
                logic [DATAWIDTH-1:0] q_buff;
                logic [DATAWIDTH-1:0] x_buff;

                sqrt_stage #(
                    .DATAWIDTH(DATAWIDTH)  
                ) stage_inst (
                    .ac(ac[i-1]),
                    .x(x[i-1]),
                    .q(q[i-1]),
                    .ac_next(ac_buff),
                    .x_next(x_buff),
                    .q_next(q_buff)
                );
                
                // Need to pass ac, x, q, and valid
                logic [3*DATAWIDTH + 2:0] input_stage, output_stage;

                assign input_stage = {x_buff, q_buff, ac_buff, valid[i-1]};
                assign {x[i], q[i], ac[i], valid[i]} = output_stage;

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
