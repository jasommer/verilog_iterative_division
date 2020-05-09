//  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
//  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
//  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
//  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
//  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
//  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
//  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE. 
//
// Copyright (C) 2020 Jan Sommer
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// Description  : This module implements a 32-bit division method that significantly helps to save hardware resources.
//                Compared to the / operator, this method uses five times less hardware resources. 
//                This comes at the expense of reduced speed: Depending on the inputs, this algorithm might take a significant amount of time to compute the quotient.
//                The worst case scenario (a very large dividend and a very small divisor), in this case 32'hFFFFFFFF/'d3 , takes around 280 clock cycles to compute. = 22.7 us @12.09 MHz
//                In general, the smaller the dividend and the bigger the divisor, the fewer clock cycles are required to calculate the quotient. 
//                However, due to the exponential incrementiation approach used in this method, this may not always be true. 
// 
// Basic concept: In order to calculate the quotient of two numbers, this module uses the idea that the dividend is a multiple of the divisor. 
//                With each step, a variable is increased by the amount of the divisor. This is repeated until the value of the variable equals the value of the dividend.
//                The amount of steps taken until then equals the quotient.
//                   E.g. 28 divided by 4:
//                   
//                   Interim result | counter (steps taken)
//                                4 | 1
//                                8 | 2
//                               12 | 3
//                               16 | 4    
//                               20 | 5
//                               24 | 6
//                               28 | 7
//
//                               => 28/4 = 7
//                 
//                The number of clock cycles needed to calculate the quotient is therefore equal to the value of the quotient itself.
//                This is impractical when calculating with big numbers.
//                To speed up the calculation, this alogrithm does not count linear (1,2,3,4,5) but exponential (1,2,4,8,16).
//                   E.g 24 divided by 4:
//                   
//                   Interim result | counter exponential (steps taken)
//                                4 | 1
//                                8 | 2
//                               16 | 4 
//
//                   -> the algorithm gets stuck at this part since the next step would be 32 | 8 which is way off.
//                      To solve this problem, the values of the counter and interim result get stored in two registers (Total interim result, Total counter exponential)
//                      the counter and the interim result are then set back to the start condtions.
//                      The total interim result ist then calculated by adding the interim result: total_interim_next = total_interim + interim_expo
//                      The total counter exponential is calculate in a similar fashion: total_counter_next = total_counter + counter
//                      
//                   Total interim result | Total counter exponential | Interim result |counter exponetial  
//                                     20 | 5                         |              4 | 1
//                                     28 | 7                         |              8 | 2
//                                          
//                                     => 28/4 = 7
//                
//-----------------------------------------------------------------------------

`timescale 1 ns / 1 ps

module division_core(
   input wire  [31:0] i_dividend,
   input wire  [31:0] i_divisor,
   input wire         i_clk,
   output wire [31:0] result
   );
   
   localparam WORD_WIDTH  = 32;
   localparam START       = 3'd0,
              EXPONENTIAL = 3'd1,
              CHECK       = 3'd2,
              END         = 3'd3;
   
   reg [WORD_WIDTH-1:0] dividend_static = 0;
   reg [WORD_WIDTH-1:0] divisor_static  = 0;
   reg [WORD_WIDTH-1:0] result_static   = 0;
   reg [WORD_WIDTH+2:0] counter         = 0; // might need more bits storage than the WORD-WIDTH. To prevent overflow, two more bits are added.
   reg [WORD_WIDTH+2:0] total_counter   = 0;
   reg [WORD_WIDTH+2:0] total_interim   = 0;
   reg [WORD_WIDTH+2:0] interim_expo    = 0;
   reg [2:0]            current_state   = 0;
                            
   wire [WORD_WIDTH+2:0] counter_expo_next;
   wire [WORD_WIDTH+2:0] interim_expo_next;
   wire [WORD_WIDTH+2:0] total_counter_next;
   wire [WORD_WIDTH+2:0] total_interim_next;
   
   assign result             = result_static;                    
   assign interim_expo_next  = interim_expo  + interim_expo;
   assign counter_expo_next  = counter       + counter;
   assign total_counter_next = total_counter + counter;
   assign total_interim_next = total_interim + interim_expo; 
   
   always @(posedge i_clk) begin
      dividend_static <= i_dividend;
      divisor_static  <= i_divisor;
   end
   
   always @(posedge i_clk) begin
       
      //catch null-division error
      if((dividend_static == 0) || (divisor_static == 0)) begin
         result_static <= 'hBAD1DEA; //Error Message (means 'bad idea' in Hex Speak)
         
      // e.g. 11/11 = 1
      end else if(divisor_static == dividend_static) begin
         result_static <= 1;
      
      // e.g. 12/1 = 12
      end else if(divisor_static == 1) begin
         result_static <= dividend_static;
         
      // cannot calculate floating point numbers, so values smaller than 1 are always 0. E.g. 5/8 = 0.625 = 0  
      end else if(divisor_static > dividend_static)begin
         result_static <= 0;
         
      // else begin calculating the result
      end else begin
      
         case(current_state) // state machine
            
            // reset to start conditionsW
            START: begin
                interim_expo  <= divisor_static;
                total_interim <= divisor_static;
                total_counter <= 1;
                counter       <= 1;
                current_state <= EXPONENTIAL;
            end
            
            // start increasing the counter and the interim result exponentially
            EXPONENTIAL: begin
               if(dividend_static >= total_interim_next)begin  // only increase the counter and the interim result if the interimresult is smaller than the dividend
                  interim_expo  <= interim_expo_next;
                  total_interim <= total_interim_next;
                  counter       <= counter_expo_next;    
                  total_counter <= total_counter_next;
               end else begin    
                  current_state <= CHECK;
               end 
            end 
            
            // Check if we can increase the interim result
            CHECK: begin
               // if yes, reset the counter and the interim result and jump back to the exponential state.
               if(dividend_static >= total_interim + divisor_static) begin
                  counter       <= 1;
                  interim_expo  <= divisor_static;
                  current_state <= EXPONENTIAL;
               end else begin
                  current_state <= END;
               end
            end 
            
           END: begin
              result_static <= total_counter;
              current_state <= START;
           end
   
         endcase
      end
    
   end
   
endmodule