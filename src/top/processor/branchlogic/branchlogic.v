module branchlogic(n_zero, overflow, ctrl, pcmux1_ctrl, pcmux3_ctrl);

   input n_zero;
   input overflow;
   input [2:0] ctrl;

   output      pcmux1_ctrl;
   output      pcmux3_ctrl;

   always @ (n_zero, overflow, ctrl)
     begin
        pcmux1_ctrl <= 0;
        pcmux3_ctrl <= 0;

        case(ctrl)
          3'b011 : // JR, JALR
            begin
               pcmux1_ctrl <= 1;
               pcmux3_ctrl <= 1;
            end
          3'b001 : // BEQ
            begin
               if (!n_zero)
                 pcmux1_ctrl <= 1;
            end
          3'b010 : // BNE
            begin
               if (n_zero)
                 pcmux1_ctrl <= 1;
            end
          3'b101 : // BGE
            begin
               if (!n_zero || !overflow)
                 pcmux1_ctrl <= 1;
            end
          3'b110 : // BGT
            begin
               if (n_zero && !overflow)
                 pcmux1_ctrl <= 1;
            end
        endcase
     end

endmodule
