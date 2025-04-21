`timescale 1ns / 1ps

module squareroot_tb;

    parameter CLK_PERIOD = 10;
    parameter DATAWIDTH = 8;
    parameter NUM_PIPELINE_STAGES = 2;

    logic clk;
    logic rst;
    logic i_valid;             // i_valid signal
    logic o_valid;             // root and rem are valid
    logic [DATAWIDTH-1:0] rad;   // radicand
    logic [DATAWIDTH-1:0] root;  // root
    logic [DATAWIDTH-1:0] rem;   // remainder

    sqrt_int #(.DATAWIDTH(DATAWIDTH), .NUM_PIPELINE_STAGES(NUM_PIPELINE_STAGES)) sqrt_inst (.*);

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

        @(posedge clk)     rst = 0;

        // Pipeline test
        @(posedge clk);     
                rad = 8'h01;    // 1
                i_valid = 1;
        @(posedge clk)     rad = 8'h04;    // 4
        @(posedge clk)     rad = 8'h09;    // 9
        @(posedge clk)     rad = 8'h0F;    // 15
        @(posedge clk)     rad = 8'hF0;    // 240
        @(posedge clk)     rad = 8'hFF;    // 255
        @(posedge clk)     i_valid = 0;

        #1000     $finish;
        
    end
endmodule
