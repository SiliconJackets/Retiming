module sqrt_stage #(
    parameter DATAWIDTH = 8
)(
    input  logic [DATAWIDTH+1:0] ac,      
    input  logic [DATAWIDTH-1:0] x,       
    input  logic [DATAWIDTH-1:0] q,       
    output logic [DATAWIDTH+1:0] ac_next, 
    output logic [DATAWIDTH-1:0] x_next,  
    output logic [DATAWIDTH-1:0] q_next   
);
    logic [DATAWIDTH+1:0] test_res;
    
    always_comb begin
        test_res = ac - {q, 2'b01};
        if (test_res[DATAWIDTH+1] == 0) begin
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
    input  wire logic rst,
    input  wire logic i_valid,
    output      logic o_valid,
    input  wire logic [DATAWIDTH-1:0] rad,
    output      logic [DATAWIDTH-1:0] root,
    output      logic [DATAWIDTH-1:0] rem
);
    localparam ITERATIONS = DATAWIDTH >> 1;

    localparam STAGE_MASK_WIDTH = ITERATIONS + 2;
    localparam PIPELINE_STAGE_MASK = { {STAGE_MASK_WIDTH-NUM_PIPELINE_STAGES{1'b0}},{NUM_PIPELINE_STAGES{1'b1}} };
    
    // Register arrays for pipeline stages
    logic [DATAWIDTH-1:0] x [ITERATIONS:0];
    logic [DATAWIDTH-1:0] q [ITERATIONS:0];
    logic [DATAWIDTH+1:0] ac [ITERATIONS:0];

    logic [DATAWIDTH-1:0] x_stage [ITERATIONS:0];
    logic [DATAWIDTH-1:0] q_stage [ITERATIONS:0];
    logic [DATAWIDTH+1:0] ac_stage [ITERATIONS:0];

    logic [DATAWIDTH-1:0] rad_reg;

    genvar i, j;

    logic valid [STAGE_MASK_WIDTH-1:0];

    assign {ac[0], x[0]} = (valid[0]) ? {{DATAWIDTH{1'b0}}, rad_reg, 2'b0} : '0;
    assign q[0] = '0;

    // Generate intermediate squareroot modules
    generate
        for (i = 1; i < STAGE_MASK_WIDTH - 1; i = i + 1) begin : sqrt_module
            sqrt_stage #(
                .DATAWIDTH(DATAWIDTH)  
            ) stage_inst (
                .ac(ac[i-1]),
                .x(x[i-1]),
                .q(q[i-1]),
                .ac_next(ac_stage[i]),
                .x_next(x_stage[i]),
                .q_next(q_stage[i])
            );
        end
    endgenerate

    // Generate pipeline stages
    generate
        for (i = 0; i < STAGE_MASK_WIDTH; i = i + 1) begin : sqrt_pipeline_stage
            
            if (i == 0) begin

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

            end else if (i == STAGE_MASK_WIDTH - 1) begin

                logic [2*DATAWIDTH:0] input_stage, output_stage;

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
                
                logic [3*DATAWIDTH + 2:0] input_stage, output_stage;

                assign input_stage = {x_stage[i], q_stage[i], ac_stage[i], valid[i-1]};
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