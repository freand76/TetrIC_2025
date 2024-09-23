module alu(A, B, ctrl, O, n_zero, overflow, mfc0);

   input [31:0] A, B;
   input [4:0]  ctrl;

   output reg [31:0] O;
   output reg        n_zero;
   output reg        overflow;

   input [31:0]      mfc0;

   reg [31:0]        result;

   wire [32:0]       add_result;
   wire [32:0]       sub_result;

   wire [31:0]       fix_rshifter_out;
   wire [31:0]       var_rshifter_out;
   wire [31:0]       fix_lshifter_out;
   wire [31:0]       var_lshifter_out;


   rshifter fix_rshifter(.A(A),
                         .shift(B[10:6]),
                         .arithmetic(ctrl[0]),
                         .O(fix_rshifter_out));

   rshifter var_rshifter(.A(B),
                         .shift(A[4:0]),
                         .arithmetic(ctrl[0]),
                         .O(var_rshifter_out));

   lshifter fix_lshifter(.A(A),
                         .shift(B[10:6]),
                         .O(fix_lshifter_out));

   lshifter var_lshifter(.A(B),
                         .shift(A[4:0]),
                         .O(var_lshifter_out));

   assign add_result[32:0] = {1'b0, A[31:0]} + {1'b0, B[31:0]};
   assign sub_result[32:0] = {1'b0, A[31:0]} - {1'b0, B[31:0]};

   always @ (A, B, ctrl, var_rshifter_out, var_lshifter_out, fix_rshifter_out, fix_lshifter_out, add_result, sub_result)
     begin
        overflow <= "0";

        case(ctrl)
          5'b00000 : result <= 0;                       // ZERO
          5'b00011 : result <= A;                       // JR, JALR
          5'b00111 : result <= var_rshifter_out;        // SRAV
          5'b01000 : result <= fix_lshifter_out;        // SLL
          5'b01010 : result <= fix_rshifter_out;        // SRL
          5'b01011 : result <= fix_rshifter_out;        // SRA
          5'b01100 : result <= var_lshifter_out;        // SLLV
          5'b01110 : result <= var_rshifter_out;        // SRLV
          5'b01111 : result <= {B[15:0], {16{1'b0}}};   // LUI
          5'b10000 : result <= add_result[31:0];        // ADD, ADDI, LW, SW
          5'b10001 : result <= add_result[31:0];        // ADDU, ADDUI
          5'b10010 :                                    // SUB, BEQ, BNE, BGE, BGT
            begin
               result <= sub_result[31:0];
               overflow <= sub_result[32];
            end
          5'b10011 : result <= sub_result[31:0];        // SUBU
          5'b10100 : result <= A & B;                   // AND, ANDI
          5'b10101 : result <= A | B;                   // OR, ORI
          5'b10110 : result <= A ^ B;                   // XOR, XORI
          5'b10111 : result <= ~(A | B);                // NOR
          5'b11100 : result <= mfc0;
          5'b11101 : result <= 0;                       // WIP: MFC1 GFX Status register
          5'b11110 : result <= 0;                       // WIP: MFC2 Joystick Data
          5'b11111 : result <= 0;                       // WIP: MFC3 Modplayer
          default:   result <= 0;
        endcase // case (ctrl)

        O <= result;

        if (result == 0)
          n_zero <= 0;
        else
          n_zero <= 1;
     end

endmodule
