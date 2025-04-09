//(* keep_hierarchy = "yes" *)
module pipeline_stage #(
   parameter WIDTH = 32,
   parameter ENABLE = 1
) (
 
   input wire clk,
   input wire rst,
   input wire [WIDTH-1:0] data_in,
   output wire [WIDTH-1:0] data_out
 
);
 
    // Internal register declaration
    reg [WIDTH-1:0] data_reg;
    generate
       if (ENABLE) begin
           always @(posedge clk) begin
               if (rst)
                   data_reg <= {WIDTH{1'b0}};
               else
                   data_reg <= data_in;
           end
            assign data_out = data_reg;
       end else begin
            assign data_out = data_in;
       end
    endgenerate
endmodule
