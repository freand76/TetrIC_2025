module processor(clk, n_reset, n_ext_stall,
                 data_in,
                 imem_ack, dmem_ack,
                 dmem_req_r, dmem_req_w,
                 dmem_pre_r, dmem_pre_w,
                 imem_addr_out, dmem_addr_out,
                 data_out,
                 debug_pc,
                 debug_data,
                 );

   input        clk, n_reset, n_ext_stall;

   input [31:0] data_in;
   input        imem_ack, dmem_ack;

   output       dmem_req_r, dmem_req_w;
   output       dmem_pre_r, dmem_pre_w;

   output [31:0] imem_addr_out, dmem_addr_out;
   output [31:0] data_out;

   output [31:0] debug_pc;
   output [31:0] debug_data;

   wire          n_stall;

   wire          s_if_ctrl2, s_if_imem_ack;

   wire [31:0]   s_if_pc1, s_if_pc2, s_if_pc3, s_if_pc4, s_if_pc5, s_if_pc6;
   wire [31:0]   s_if_instr, s_id_instr;

   wire [31:0]   s_id_pc1;

   wire [1:0]    s_id_ctrl_id;
   wire [7:0]    s_id_ex_ctrl;
   wire [4:0]    s_id_mem_ctrl;
   wire [2:0]    s_id_wb_ctrl;

   wire [15:0]   s_id_immediate;
   wire [31:0]   s_id_data3;

   wire          s_ex_n_zero;
   wire          s_ex_overflow;
   wire [31:0]   s_ex_data3;
   wire [31:0]   s_ex_pc1, s_ex_pc7;
   wire [4:0]    s_ex_mem_ctrl;

   wire          s_mem_n_zero;
   wire          s_mem_overflow;
   wire          s_mem_ctrl2;
   wire [4:0]    s_mem_mem_ctrl;
   wire [31:0]   s_mem_pc7;
   wire [31:0]   s_mem_res;

   assign s_ex_n_zero = 0;
   assign s_ex_overflow = 0;
   assign s_if_pc5 = 0;

   assign dmem_addr_out = 0;

   assign n_stall = n_ext_stall;

   assign dmem_req_r = 0;

   assign dmem_req_w = 0;
   assign dmem_pre_r = 0;
   assign dmem_pre_w = 0;

   mux2 pcmux1(.A(s_if_pc1),
               .B(s_if_pc6),
               .sel(s_if_ctrl1),
               .O(s_if_pc4));

   mux2 pcmux2(.A(s_if_pc4),
               .B(s_if_pc5),
               .sel(s_if_ctrl2),
               .O(s_if_pc3));

   mux2 pcmux3(.A(s_mem_pc7),
               .B(s_mem_res),
               .sel(s_mem_ctrl2),
               .O(s_if_pc6));

   instr_or_nop instr_or_nop_inst(.n_stall(n_stall),
                                  .imem_ack(imem_ack),
                                  .instr_in(data_in),
                                  .instr_out(s_if_instr));

   // IF REGISTERS
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

   // IFID REGISTERS
   pipereg #( .WIDTH(32) ) ifid_pc(.clk(clk),
                                   .n_reset(n_reset),
                                   .D(s_if_pc1),
                                   .enable(n_stall),
                                   .Q(s_id_pc1));

   pipereg #( .WIDTH(32) ) ifidreg1(.clk(clk),
                                    .n_reset(n_reset),
                                    .D(s_if_instr),
                                    .enable(n_stall),
                                    .Q(s_id_instr));

   ctrl ctrl(.instr(s_id_instr),
             .ife_ctrl(s_if_ctrl2),
             .id_ctrl(s_id_ctrl_id),
             .ex_ctrl(s_id_ex_ctrl),
             .mem_ctrl(s_id_mem_ctrl),
             .wb_ctrl(s_id_wb_ctrl));

   assign s_id_immediate = s_id_instr[15:0];

   signext signext(.A(s_id_immediate),
                   .ctrl(s_id_ctrl_id),
                   .O(s_id_data3));


   // IDEX REGISTERS
   pipereg #( .WIDTH(32) ) idex_data(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(s_id_data3),
                                     .enable(n_stall),
                                     .Q(s_ex_data3));

   pipereg #( .WIDTH(5) ) idex_mem_ctrl(.clk(clk),
                                        .n_reset(n_reset),
                                        .D(s_id_mem_ctrl),
                                        .enable(n_stall),
                                        .Q(s_ex_mem_ctrl));

   // EXMEM REGISTERS
   pipereg #( .WIDTH(32) ) exmem_pc(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(s_ex_pc7),
                                     .enable(n_stall),
                                     .Q(s_mem_pc7));

   pipereg #( .WIDTH(1) ) exmem_n_zero(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(s_ex_n_zero),
                                     .enable(n_stall),
                                     .Q(s_mem_n_zero));

   pipereg #( .WIDTH(1) ) exmem_overflow(.clk(clk),
                                         .n_reset(n_reset),
                                         .D(s_ex_overflow),
                                         .enable(n_stall),
                                         .Q(s_mem_overflow));

   pipereg #( .WIDTH(5) ) exmem_mem_ctrl(.clk(clk),
                                         .n_reset(n_reset),
                                         .D(s_ex_mem_ctrl),
                                         .enable(n_stall),
                                         .Q(s_mem_mem_ctrl));

   branchlogic branchlogic(.n_zero(s_mem_n_zero),
                           .overflow(s_mem_overflow),
                           .ctrl(s_mem_mem_ctrl[4:2]),
                           .pcmux1_ctrl(s_if_ctrl1),
                           .pcmux3_ctrl(s_mem_ctrl2));

   // PC ADD1
   always @ (n_stall, s_if_imem_ack, s_if_pc2)
     begin
        if (n_stall && s_if_imem_ack)
          s_if_pc1 <= s_if_pc2 + 1;
        else
          s_if_pc1 <= s_if_pc2;
     end

   // PC ADD2
   always @ (s_ex_pc1, s_ex_data3)
     begin
        s_ex_pc7 <= s_ex_pc1 + s_ex_data3;
    end

   assign imem_addr_out = s_if_pc2;
   assign debug_pc = s_if_pc2;
   assign debug_data = s_ex_data3;
   assign data_out = s_if_instr;

endmodule
