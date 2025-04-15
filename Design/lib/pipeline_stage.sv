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
    generate
       if (ENABLE) begin
           always @(posedge clk) begin
               if (rst)
                   data_out <= {WIDTH{1'b0}};
               else
                   data_out <= data_in;
           end
       end else begin
            assign data_out = data_in;
       end
    endgenerate
endmodule
