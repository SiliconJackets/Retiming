module square_root #(parameter DATAWIDTH = 32) (
    input wire logic clk,
    input wire logic i_valid,
    input logic [DATAWIDTH-1:0] radicand,
    output logic o_valid,
    output logic [DATAWIDTH-1:0] root,
    output logic [DATAWIDTH-1:0] remainder
);

    genvar i;
    generate
        for (i = 0; i < DATAWIDTH >> 2; i++) begin

        end
    endgenerate

endmodule

module sqrt_step #(parameter DATAWIDTH = 32)(
    input wire logic i_clk,
    input wire logic i_valid,
    input logic [DATAWIDTH-1:0] i_x,
    input logic [DATAWIDTH-1:0] i_a,
    input logic [DATAWIDTH+1:0] i_t,
    input logic [DATAWIDTH+1:0] i_q,
    output wire logic o_valid,
    output logic [DATAWIDTH-1:0] o_x,
    output logic [DATAWIDTH-1:0] o_a,
    output logic [DATAWIDTH+1:0] o_t,
    output logic [DATAWIDTH+1:0] o_q,
);

    logic [DATAWIDTH-1:0] temp_x;
    logic [DATAWIDTH-1:0] temp_a, temp_a2;
    logic [DATAWIDTH+1:0] temp_t;
    logic [DATAWIDTH+1:0] temp_q, temp_q2;

    always_ff @(posedge i_clk) begin
        o_x <= temp_x;
        o_a <= temp_a;
        o_t <= temp_t;
        o_q <= temp_q;
        o_valid <= i_valid;
    end

    always_comb begin
        if (i_valid) begin
            {temp_a2, temp_x} = {i_t[DATAWIDTH-1:0], x, 2'b01};
            temp_t = temp_a2 - {i_q[DATAWIDTH-3:0], 1'b01};
            temp_q2 = {i_q[DATAWIDTH-2:0], 1'b0};
            temp_a = (temp_t[DATAWIDTH+1]) ? temp_a2 : temp_t;
            temp_q = (temp_t[DATAWIDTH+1]) ? temp_q : temp_q + 1;
        end else begin
            temp_x = 0;
            temp_a = 0;
            temp_t = 0;
            temp_q = 0;
        end
    end

endmodule