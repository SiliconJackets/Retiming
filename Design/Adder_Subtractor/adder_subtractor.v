module full_adder(input a, b, cin, output s, c);
  assign s = a ^ b ^ cin;
  assign c = (a & b) | (b & cin) | (a & cin);
endmodule

module AdderSubtractor #(
    parameter N = 8 // Default bit-width
)(
    input  wire [N-1:0] A,  
    input  wire [N-1:0] B,  
    input  wire op, // 0 = Add, 1 = Subtract
    output reg  [N-1:0] Result,
    output wire CarryOut,
    output wire Overflow
);

    wire [N-1:0] B_mux;
    wire [N-1:0] Sum;
    wire [N:0] Carry; // Carry
    
    // Negate B if Subtraction
    assign B_mux = (op) ? ~B : B; 

    /*
    // Half Adder for First Bit 0
    half_adder HA (
        .a(A[0]), 
        .b(B_mux[0] ^ op),
        .s(Sum[0]), 
        .c(Carry[0]) // Carry Ahead - So Calculate p_0 and g_0, then Calcualte p_i and g_i then Generate Loop?
    );
    */

    // Full Adder for First Bit 0
    full_adder FA0 (
    .a(A[0]), 
    .b(B_mux[0] ^ op),
    .cin(op),  // op is cin
    .s(Sum[0]), 
    .c(Carry[0]) 
    );

    // Full Adder from 1:N
    genvar i;
    generate
        for (i = 1; i < N; i = i + 1) begin : FA_CHAIN
            full_adder FA (
                .a(A[i]), 
                .b(B_mux[i] ^ op),
                .cin(Carry[i-1]),
                .s(Sum[i]), 
                .c(Carry[i])
            );
        end
    endgenerate

    // CarryOut is the Last Carry
    assign CarryOut = Carry[N-1];

    // Overflow Detection
    assign Overflow = (A[N-1] == B_mux[N-1]) && (Sum[N-1] != A[N-1]);

    // Assign Result
    always @(*) begin
        if (Overflow) begin
            // If Overflow, return the Max or Min Value
            Result = (A[N-1]) ? {1'b1, {(N-1){1'b0}}} : {1'b0, {(N-1){1'b1}}};
        end else begin
            Result = Sum;
        end
    end

endmodule