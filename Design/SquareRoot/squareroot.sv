// module square_root #(parameter DATADATAWIDTH = 32) (
//     input wire logic clk,
//     input wire logic i_o_valid,
//     input logic [DATADATAWIDTH-1:0] radicand,
//     output logic o_o_valid,
//     output logic [DATADATAWIDTH-1:0] root,
//     output logic [DATADATAWIDTH-1:0] remainder
// );

//     genvar i;
//     generate
//         for (i = 0; i < DATADATAWIDTH >> 2; i++) begin

//         end
//     endgenerate

// endmodule

// module sqrt_step #(parameter DATADATAWIDTH = 32)(
//     input wire logic i_clk,
//     input wire logic i_o_valid,
//     input logic [DATADATAWIDTH-1:0] i_x,
//     input logic [DATADATAWIDTH-1:0] i_a,
//     input logic [DATADATAWIDTH+1:0] i_t,
//     input logic [DATADATAWIDTH+1:0] i_q,
//     output wire logic o_o_valid,
//     output logic [DATADATAWIDTH-1:0] o_x,
//     output logic [DATADATAWIDTH-1:0] o_a,
//     output logic [DATADATAWIDTH+1:0] o_t,
//     output logic [DATADATAWIDTH+1:0] o_q,
// );

//     logic [DATADATAWIDTH-1:0] temp_x;
//     logic [DATADATAWIDTH-1:0] temp_a, temp_a2;
//     logic [DATADATAWIDTH+1:0] temp_t;
//     logic [DATADATAWIDTH+1:0] temp_q, temp_q2;

//     always_ff @(posedge i_clk) begin
//         o_x <= temp_x;
//         o_a <= temp_a;
//         o_t <= temp_t;
//         o_q <= temp_q;
//         o_o_valid <= i_o_valid;
//     end

//     always_comb begin
//         if (i_o_valid) begin
//             {temp_a2, temp_x} = {i_t[DATADATAWIDTH-1:0], x, 2'b01};
//             temp_t = temp_a2 - {i_q[DATADATAWIDTH-3:0], 1'b01};
//             temp_q2 = {i_q[DATADATAWIDTH-2:0], 1'b0};
//             temp_a = (temp_t[DATADATAWIDTH+1]) ? temp_a2 : temp_t;
//             temp_q = (temp_t[DATADATAWIDTH+1]) ? temp_q : temp_q + 1;
//         end else begin
//             temp_x = 0;
//             temp_a = 0;
//             temp_t = 0;
//             temp_q = 0;
//         end
//     end

// endmodule

// =========== Pipeline extension ===========
/*
Credit to https://projectf.io/posts/square-root-in-verilog/ for algorithm

*/
module sqrt_stage #(
    parameter DATAWIDTH = 8,
    parameter ENABLE = 1
)(
    input  logic clk,
    input  logic rst,
    input  logic vld,
    input  logic [DATAWIDTH+1:0] ac,      // Accumulator
    input  logic [DATAWIDTH-1:0] x,       // Remaining radicand
    input  logic [DATAWIDTH-1:0] q,       // Intermediate root
    output logic vld_next,
    output logic [DATAWIDTH+1:0] ac_next, 
    output logic [DATAWIDTH-1:0] x_next,  
    output logic [DATAWIDTH-1:0] q_next   
);
    logic [DATAWIDTH+1:0] test_res;

    logic [DATAWIDTH+1:0] ac_temp;
    logic [DATAWIDTH-1:0] x_temp, q_temp;
    
    always_comb begin
        test_res = ac - {q, 2'b01};
        if (test_res[DATAWIDTH+1] == 0) begin  // If test_res >= 0
            {ac_temp, x_temp} = {test_res[DATAWIDTH-1:0], x, 2'b0};
            q_temp = {q[DATAWIDTH-2:0], 1'b1};
        end else begin
            {ac_temp, x_temp} = {ac[DATAWIDTH-1:0], x, 2'b0};
            q_temp = q << 1;
        end
    end

    // Handle registered stages here
    logic [3*DATAWIDTH+2:0] input_stage, output_stage;

    assign input_stage = {ac_temp, x_temp, q_temp, vld};
    assign {ac_next, x_next, q_next, vld_next} = output_stage;

    pipeline_stage #(
        .WIDTH($bits(input_stage)),
        .ENABLE(ENABLE)
    )
    pipeline_inst (
        .clk(clk),
        .rst(rst),
        .data_in(input_stage),
        .data_out(output_stage)
    );

endmodule

module sqrt_int #(
    parameter DATAWIDTH = 8,
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
    localparam PIPELINE_STAGE_MASK [STAGE_MASK_WIDTH-1:0] = 6'b101101;  // Change by user
    
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

            // Whether we want to register the intermediate root computations
            end else begin
                
                // Need to pass ac, x, q, and valid
                // logic [3*DATAWIDTH + 1:0] input_stage, output_stage;

                // assign input_stage = {x[i-1], q[i-1], ac[i-1], valid[i-1]};
                // assign {x[i], q[i], ac[i], valid[i]} = output_stage;

                // pipeline_stage #(
                //     .WIDTH($bits(input_stage)),
                //     .ENABLE(PIPELINE_STAGE_MASK[i])
                // )
                // pipeline_inst (
                //     .clk(clk),
                //     .rst(rst),
                //     .data_in(input_stage),
                //     .data_out(output_stage)
                // );

                // ============= Moving instantiation of sqrt_stage to here ===========
                // Deferring the handling of pipeline stages to sqrt_stage module instead
                // to avoid potential multi-driver conflicts

                sqrt_stage #(
                    .DATAWIDTH(DATAWIDTH),
                    .ENABLE(PIPELINE_STAGE_MASK[i])
                ) stage_inst (
                    .clk(clk),
                    .rst(rst),
                    .vld(valid[i-1]),
                    .ac(ac[i-1]),
                    .x(x[i-1]),
                    .q(q[i-1]),
                    .vld_next(valid[i]),
                    .ac_next(ac[i]),
                    .x_next(x[i]),
                    .q_next(q[i])
                );

            end

        end

    endgenerate
    
endmodule
