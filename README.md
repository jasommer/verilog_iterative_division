# verilog_iterative_division
This module implements a 32-bit division method that significantly helps to save hardware resources. Compared to a hardware divider that is implemented using CLBs, this method uses five times less hardware resources. This comes at the expense of reduced speed: Depending on the inputs, this algorithm might take a significant amount of time to compute the quotient.

##Basic concept
In order to calculate the quotient of two numbers, this module uses the idea that the dividend is a multiple of the divisor. 
With each step, a variable is increased by the amount of the divisor. This is repeated until the value of the variable equals the value of the dividend.
                The amount of steps taken until then equals the quotient.
                   E.g. 28 divided by 4:
                   
                   Interim result | counter (steps taken)
                                4 | 1
                                8 | 2
                               12 | 3
                               16 | 4    
                               20 | 5
                               24 | 6
                               28 | 7

                               => 28/4 = 7 (7 iterations necessary)
                
The number of clock cycles needed to calculate the quotient is therefore equal to the value of the quotient itself.
This is impractical when calculating with big numbers.
To speed up the calculation, this alogrithm does not count linear (1,2,3,4,5) but exponential (1,2,4,8,16).
E.g 24 divided by 4:
                   
                   Interim result | exponential counter
                                4 | 1  
                                8 | 2  
                               16 | 4 <- restart exponential counting since the next step would be 32 | 8 
                               20 | 5  
                               28 | 7
                               
                               => 28/4 = 7 (5 iterations necessary)
                               

## Implementation statistics (on a Spartan 6 FPGA)
<br><b>32-Bit division using the iterative division method</b>
<br>Maximum Frequency:                         130 MHz
<br>Number of occupied Slices:                 110
<br>Number of Slice Registers:                 227
<br>Number of Slice LUTs:                      352

<br><b>32-Bit division using a single-cycle divider</b>
<br>Maximum Frequency:                         10 MHz
<br>Number of occupied Slices:                 469
<br>Number of Slice Registers:                 192
<br>Number of Slice LUTs:                      1,370
