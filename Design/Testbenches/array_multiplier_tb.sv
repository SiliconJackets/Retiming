`timescale 1ns / 1ps

module array_multiplier_tb;
  logic [7:0] A, B;  // Test inputs
  logic [15:0] Z_final;   // Output product
  logic [15:0] Z;
  logic [15:0] Z_reg [8:0];
  logic rst;
  logic clk;
  logic i_vld;
  logic o_vld;
  parameter INSTANCE_ID = 4'b1;

  // Instantiate the 8-bit array multiplier
  array_multiplier #(
    .INSTANCE_ID(INSTANCE_ID)
  ) mul0 (
    .A(A),
    .B(B),
    .Z_final(Z_final),
    .clk(clk),
    .rst(rst),
    .i_valid(i_vld),
    .o_valid(o_vld)
  );

  always #5 clk = ~clk;

  initial begin
        // Configure FSDB dumping
        $fsdbDumpon;
        $fsdbDumpfile("simulation.fsdb");
        $fsdbDumpvars(0, array_multiplier_tb, "+mda", "+all", "+trace_process");
        $fsdbDumpMDA;
    end

   // Initialize signals
  initial begin
    // Set initial values
    clk = 0;
    rst = 1;
    i_vld = '0;
    A = '0;
    B = '0;
    #15 rst = 0;  // Release reset after a few clock cycles
    #10;
    i_vld = '1;

    A = 8'b11111111; B = 8'b11111111; #10; // 255 * 255 = 65025
    // A = 8'b00001111; B = 8'b00001111; #50; // 15 * 15 = 225
    @(posedge o_vld);
    i_vld = '0; #10;

    // End simulation
    $finish;

  end

  // initial begin
  //   // Apply test cases
  //   // A = 8'b00000001; B = 8'b00000001; #10; // 1 * 1 = 1
  //   // A = 8'b00000010; B = 8'b00000010; #10; // 2 * 2 = 4
  //   // A = 8'b00001111; B = 8'b00001111; #10; // 15 * 15 = 225
  //   // A = 8'b10101010; B = 8'b00000011; @(posedge clk); // 170 * 3 = 510
  //   // @(posedge clk);
  //   // $display("15 * 15 is %d", Z);
  //   // @(posedge clk);
  //   // $display("170 * 3 is %d", Z);
  //   // A = 8'b11111111; B = 8'b00000010; #10; // 255 * 2 = 510
  //   A = 8'b11111111; B = 8'b11111111; #10; // 255 * 255 = 65025

  //   // End simulation
  //   #10000 $finish;
  // end

  // Monitor outputs
  initial @(posedge clk) begin
    // $monitor("Time=%0t | A=%b (%d) | B=%b (%d) | Z=%b (%d) | Z_f=%b (%d) | Z_r=%b (%d) | Valid=%b", 
    //          $time, A, A, B, B, Z, Z, Z_final, Z_final, Z_reg[2], Z_reg[2], o_vld);
    $monitor("Time=%0t | A=%b (%d) | B=%b (%d) | Z=%b (%d) | Valid=%b", 
             $time, A, A, B, B, Z_final, Z_final, o_vld);
  end
endmodule