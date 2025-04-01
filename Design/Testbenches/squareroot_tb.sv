`timescale 1ns / 1ps

module squareroot_tb;

    parameter CLK_PERIOD = 10;
    parameter DATAWIDTH = 8;

    logic clk;
    logic rst;
    logic i_valid;             // i_valid signal
    logic o_valid;             // root and rem are valid
    logic [DATAWIDTH-1:0] rad;   // radicand
    logic [DATAWIDTH-1:0] root;  // root
    logic [DATAWIDTH-1:0] rem;   // remainder

    sqrt_int #(.DATAWIDTH(DATAWIDTH)) sqrt_inst (.*);

    always #(CLK_PERIOD / 2) clk = ~clk;

    initial begin
        // Configure FSDB dumping
        $fsdbDumpon;
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, squareroot_tb, "+mda", "+all", "+trace_process");
        $fsdbDumpMDA;
    end

    initial begin
        $monitor("%d:\tsqrt(%d) =%d (rem =%d) (V=%b)", $time, rad, root, rem, o_valid);
    end

    initial begin
                clk = 1;
                rst = 1;
                i_valid = '0;
                rad = '0;

        #10     rst = 0;

        // Pipeline test
        #50     rad = 8'h01;    // 1
                i_valid = 1;
        #10     rad = 8'h04;    // 4
        #10     rad = 8'h09;    // 9
        #10     rad = 8'h0F;    // 15
        #10     rad = 8'hF0;    // 240
        #10     rad = 8'hFF;    // 255
        #10     i_valid = 0;

        #1000     $finish;
        
    end
endmodule
