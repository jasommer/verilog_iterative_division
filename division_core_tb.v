`timescale 1ns/1ps


module division_core ();
   reg clk = 1'b0;
   reg [31:0] dividend = 'd5421;  //'d113;
   reg [31:0] divisor = 'd3;      //'d2;
   reg [31:0] result;
   // Instantiate the Unit Under Test (UUT)
   core divider 
   (    
      .i_clk(clk_internal),
      .i_dividend(dividend),
      .i_divisor(divisor),
      .result(result)
   );
   
   always #42 clk_internal <= !clk_internal;

endmodule
