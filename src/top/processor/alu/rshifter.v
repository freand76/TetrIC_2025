module rshifter(A, shift, arithmetic, O);
   input [31:0] A;
   input [4:0]  shift;
   input        arithmetic;

   output [31:0] O;

   wire          shift_in;

   assign shift_in = A[31] & arithmetic;

   always @ (A, shift, arithmetic)
     begin
        case(shift)
          0 : O <= A[31:0];
          1 : O <= {{1{shift_in}}, A[31:1]};
          2 : O <= {{2{shift_in}}, A[31:2]};
          3 : O <= {{3{shift_in}}, A[31:3]};
          4 : O <= {{4{shift_in}}, A[31:4]};
          5 : O <= {{5{shift_in}}, A[31:5]};
          6 : O <= {{6{shift_in}}, A[31:6]};
          7 : O <= {{7{shift_in}}, A[31:7]};
          8 : O <= {{8{shift_in}}, A[31:8]};
          9 : O <= {{9{shift_in}}, A[31:9]};
          10 : O <= {{10{shift_in}}, A[31:10]};
          11 : O <= {{11{shift_in}}, A[31:11]};
          12 : O <= {{12{shift_in}}, A[31:12]};
          13 : O <= {{13{shift_in}}, A[31:13]};
          14 : O <= {{14{shift_in}}, A[31:14]};
          15 : O <= {{15{shift_in}}, A[31:15]};
          16 : O <= {{16{shift_in}}, A[31:16]};
          17 : O <= {{17{shift_in}}, A[31:17]};
          18 : O <= {{19{shift_in}}, A[31:18]};
          19 : O <= {{19{shift_in}}, A[31:19]};
          20 : O <= {{20{shift_in}}, A[31:20]};
          21 : O <= {{21{shift_in}}, A[31:21]};
          22 : O <= {{22{shift_in}}, A[31:22]};
          23 : O <= {{23{shift_in}}, A[31:23]};
          24 : O <= {{24{shift_in}}, A[31:24]};
          25 : O <= {{25{shift_in}}, A[31:25]};
          26 : O <= {{26{shift_in}}, A[31:26]};
          27 : O <= {{27{shift_in}}, A[31:27]};
          28 : O <= {{28{shift_in}}, A[31:28]};
          29 : O <= {{29{shift_in}}, A[31:29]};
          30 : O <= {{30{shift_in}}, A[31:30]};
          31 : O <= {{31{shift_in}}, A[31:31]};
          default: O <= A[31:0];
        endcase
     end
endmodule
   

                
   
