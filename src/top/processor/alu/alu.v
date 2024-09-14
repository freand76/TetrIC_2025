module alu(clk, nreset, A, B, ctrl, O, zero, overflow);

   input        clk, nreset;   

   input [31:0] A, B;
   input [4:0]  ctrl;

   output [31:0] O;
   output reg    zero;
   output reg    overflow;

   wire [32:0]   add_result;
   wire [32:0]   sub_result;
   wire          zero_set;
   wire          overflow_set;

   wire [31:0]   fix_rshifter_out;
   wire [31:0]   var_rshifter_out;
   wire [31:0]   fix_lshifter_out;
   wire [31:0]   var_lshifter_out;
   
   rshifter fix_rshifter(.A (A),
                         .shift (B[10:6]),
                         .arithmetic (ctrl[0]),
                         .O (fix_rshifter_out));

   rshifter var_rshifter(.A (B),
                         .shift (A[4:0]),
                         .arithmetic (ctrl[0]),
                         .O (var_rshifter_out));

   lshifter fix_lshifter(.A (A),
                         .shift (B[10:6]),
                         .O (fix_lshifter_out));

   lshifter var_lshifter(.A (B),
                         .shift (A[4:0]),
                         .O (var_lshifter_out));
                         
   assign add_result[32:0] = {1'b0, A[31:0]} + {1'b0, B[31:0]};
   assign sub_result[32:0] = {1'b0, A[31:0]} - {1'b0, B[31:0]};
   
   always @ (A, B, ctrl)
     begin
        case(ctrl)
          5'b00000 : O <= 0;                       // ZERO
          5'b00011 : O <= A;                       // JR, JALR
          5'b00111 : O <= var_rshifter_out;        // SRAV
          5'b01000 : O <= fix_lshifter_out;        // SLL
          5'b01010 : O <= fix_rshifter_out;        // SRL
          5'b01011 : O <= fix_rshifter_out;        // SRA
          5'b01100 : O <= var_lshifter_out;        // SLLV
          5'b01110 : O <= var_rshifter_out;        // SRLV
          5'b01111 : O <= {B[15:0], {16{1'b0}}};   // LUI
          5'b10000 : O <= add_result[31:0];        // ADD, ADDI, LW, SW
          5'b10001 : O <= add_result[31:0];        // ADDU, ADDUI
          5'b10010 : O <= sub_result[31:0];        // SUB, BEQ, BNE, BGE, BGT
          5'b10011 : O <= sub_result[31:0];        // SUBU
          5'b10100 : O <= A & B;                   // AND, ANDI
          5'b10101 : O <= A | B;                   // OR, ORI
          5'b10110 : O <= A ^ B;                   // XOR, XORI
          5'b10111 : O <= ~(A | B);                // NOR
          5'b11100 : O <= 0;                       // WIP: MFC0 ALU Status register
          5'b11101 : O <= 0;                       // WIP: MFC1 GFX Status register
          5'b11110 : O <= 0;                       // WIP: MFC2 Joystick Data
          5'b11111 : O <= 0;                       // WIP: MFC3 Modplayer
          default:   O <= 0;
        endcase
     end

   always @(posedge clk or posedge reset)
     begin
        if (reset)
          begin
             zero <= 0;
             overflow <= 0;
          end
        else
          begin
             if (zero_set)
               zero <= 1;
             if (overflow_set)
               overflow <= 1;
          end
     end

endmodule
