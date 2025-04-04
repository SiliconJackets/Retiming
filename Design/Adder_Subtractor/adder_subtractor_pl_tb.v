`timescale 1ns / 1ps

module adder_subtractor_pipelined_tb;
    parameter N = 8;
    parameter STAGES = 4;

    reg clk, rst;
    reg [N-1:0] A, B;
    reg op; // 0 = Add, 1 = Subtract
    reg i_valid;
    wire [N-1:0] Result;
    wire o_valid, Overflow;

    // Instantiate the DUT
    AdderSubtractorPipelined #(
        .DATAWIDTH(N),
        .NUM_PIPELINE_STAGES(STAGES)
    ) uut (
        .clk(clk),
        .rst(rst),
        .A(A),
        .B(B),
        .op(op),
        .i_valid(i_valid),
        .Result(Result),
        .o_valid(o_valid),
        .Overflow(Overflow)
    );

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Task to apply an input
    task apply_input(input [N-1:0] a, input [N-1:0] b, input op_in);
        begin
            @(posedge clk);
            A <= a;
            B <= b;
            op <= op_in;
            i_valid <= 1;
            @(posedge clk);
            i_valid <= 0;
        end
    endtask

    initial begin
        rst = 1;
        A = 0; B = 0; op = 0; i_valid = 0;
        repeat (2) @(posedge clk);
        rst = 0;

        // Apply test vectors
        apply_input(8'd5, 8'd3, 0);  // 5 + 3
        apply_input(8'd10, 8'd7, 1); // 10 - 7
        apply_input(8'd127, 8'd1, 0); // Overflow case
        apply_input(8'd0, 8'd1, 1); // Underflow

        repeat (STAGES + 2) @(posedge clk);
        $finish;
    end

    always @(posedge clk) begin
        if (o_valid) begin
            $display("Time %0t: Result = %0d, Overflow = %b", $time, Result, Overflow);
        end
    end
endmodule