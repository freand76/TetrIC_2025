module instr_or_nop(nstall,
                    imem_ack,
                    instr_in,
                    instr_out);

   input nstall, imem_ack;
   input [31:0] instr_in;
   output [31:0] instr_out;

   always @ (imem_ack, instr_in, nstall)
     begin
        if (imem_ack && nstall)
          instr_out <= instr_in;
        else
          instr_out <= 0;
     end

endmodule
