module instr_or_nop(n_stall,
                    imem_ack,
                    instr_in,
                    instr_out);

   input n_stall, imem_ack;
   input [31:0] instr_in;
   output reg [31:0] instr_out;

   always @ (imem_ack, instr_in, n_stall)
     begin
        if (imem_ack && n_stall)
          instr_out <= instr_in;
        else
          instr_out <= 0;
     end

endmodule
