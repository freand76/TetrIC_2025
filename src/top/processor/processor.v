module processor(clk, n_reset, n_ext_stall,
                 data_in,
                 imem_ack, dmem_ack,
                 dmem_req_r, dmem_req_w,
                 dmem_pre_r, dmem_pre_w,
                 imem_addr_out, dmem_addr_out,
                 data_out,
                 debug_pc,
                 );

   input        clk, n_reset, n_ext_stall;

   input [31:0] data_in;
   input        imem_ack, dmem_ack;

   output       dmem_req_r, dmem_req_w;
   output       dmem_pre_r, dmem_pre_w;

   output [31:0] imem_addr_out, dmem_addr_out;
   output [31:0] data_out;

   output [31:0] debug_pc;

   wire          n_stall;

   wire          s_if_ctrl2, s_if_imem_ack;

   wire [31:0]   s_if_pc1, s_if_pc2, s_if_pc3, s_if_pc4, s_if_pc5, s_if_pc6;
   wire [31:0]   s_if_instr;

   wire [31:0]   s_id_pc1;

   assign s_if_ctrl1 = 0;
   assign s_if_ctrl2 = 0;
   assign s_if_pc5 = 0;
   assign s_if_pc6 = 0;

   assign dmem_addr_out = 0;

   assign n_stall = n_ext_stall;

   assign dmem_req_r = 0;

   assign dmem_req_w = 0;
   assign dmem_pre_r = 0;
   assign dmem_pre_w = 0;

   instr_or_nop instr_or_nop_inst(.n_stall(n_stall),
                                  .imem_ack(imem_ack),
                                  .instr_in(data_in),
                                  .instr_out(s_if_instr));

   mux2 pcmux1(.A(s_if_pc1),
               .B(s_if_pc6),
               .sel(s_if_ctrl1),
               .O(s_if_pc4));

   mux2 pcmux2(.A(s_if_pc4),
               .B(s_if_pc5),
               .sel(s_if_ctrl2),
               .O(s_if_pc3));

   pipereg #( .WIDTH(1) ) preififreg(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(imem_ack),
                                     .enable(1),
                                     .Q(s_if_imem_ack));

   pipereg #( .WIDTH(32) ) pc(.clk(clk),
                              .n_reset(n_reset),
                              .D(s_if_pc3),
                              .enable(1),
                              .Q(s_if_pc2));

   pipereg #( .WIDTH(32) ) ifid_pc(.clk(clk),
                                   .n_reset(n_reset),
                                   .D(s_if_pc1),
                                   .enable(n_stall),
                                   .Q(s_id_pc1));

   // PC ADD1
   always @ (n_stall, s_if_imem_ack, s_if_pc2)
     begin
        if (n_stall && s_if_imem_ack)
          s_if_pc1 <= s_if_pc2 + 1;
        else
          s_if_pc1 <= s_if_pc2;
     end


   assign imem_addr_out = s_if_pc2;
   assign debug_pc = s_if_pc2;
   assign data_out = s_if_instr;

endmodule
