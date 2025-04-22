module adder_subtractor_tb;
    parameter N = 8;

    reg [N-1:0] A, B;
    reg op; // 0 = Add, 1 = Subtract
    wire [N-1:0] Result;
    wire CarryOut;
    wire Overflow;

    AdderSubtractor #(.N(N)) uut (
        .A(A),
        .B(B),
        .op(op),
        .Result(Result),
        .CarryOut(CarryOut),
        .Overflow(Overflow)
    );

    initial begin
        // Test Case 1: Simple Addition (5 + 3)
        A = 8'd5; B = 8'd3; op = 0;
        #10;
        $display("A=%d, B=%d, op=%b -> Result=%d, CarryOut=%b, Overflow=%b", A, B, op, Result, CarryOut, Overflow);

        $stop;
    end
endmodule