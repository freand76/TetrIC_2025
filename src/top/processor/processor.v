module processor(clk, n_reset, n_ext_stall,
                 data_in,
                 imem_ack, dmem_ack,
                 dmem_req_r, dmem_req_w,
                 dmem_pre_r, dmem_pre_w,
                 imem_addr_out, dmem_addr_out,
                 data_out,
                 debug_pc,
                 debug_data,
                 debug_data2,
                 );

   input        clk, n_reset, n_ext_stall;

   input [31:0] data_in;
   input        imem_ack, dmem_ack;

   output       dmem_req_r, dmem_req_w;
   output       dmem_pre_r, dmem_pre_w;

   output [31:0] imem_addr_out, dmem_addr_out;
   output [31:0] data_out;

   output [31:0] debug_pc, debug_data, debug_data2;

   wire          n_stall;

   wire          s_if_ctrl2, s_if_imem_ack;

   wire [31:0]   s_if_pc1, s_if_pc2, s_if_pc3, s_if_pc4, s_if_pc5, s_if_pc6;
   wire [31:0]   s_if_instr, s_id_instr;

   wire [31:0]   s_id_pc1;
   wire [31:0]   s_id_data1, s_id_data2;


   wire [1:0]    s_id_ctrl_id;
   wire [7:0]    s_id_ex_ctrl;
   wire [4:0]    s_id_mem_ctrl;
   wire [2:0]    s_id_wb_ctrl;
   wire [1:0]    s_id_sel1, s_id_sel2;

   wire [15:0]   s_id_immediate;
   wire [4:0]    s_id_r1_sel, s_id_r2_sel, s_id_rd_sel;
   wire [31:0]   s_id_data3;

   wire          s_ex_n_zero;
   wire          s_ex_overflow;
   wire [4:0]    s_ex_r1_sel, s_ex_r2_sel, s_ex_rd_sel;
   wire [31:0]   s_ex_data3;
   wire [31:0]   s_ex_pc1, s_ex_pc7;
   wire [7:0]    s_ex_ex_ctrl;
   wire [4:0]    s_ex_mem_ctrl;
   wire [4:0]    s_ex_regdest;
   wire [2:0]    s_ex_wb_ctrl;
   wire [31:0]   s_ex_res;
   wire [31:0]   s_ex_alu0, s_ex_pre_alu1, s_ex_alu1;
   wire [1:0]    s_ex_sel1, s_ex_sel2;

   wire          s_mem_n_zero;
   wire          s_mem_overflow;
   wire          s_mem_ctrl2;
   wire [4:0]    s_mem_mem_ctrl;
   wire [4:0]    s_mem_regdest;
   wire [2:0]    s_mem_wb_ctrl;
   wire [31:0]   s_mem_pc1, s_mem_pc7;
   wire [31:0]   s_mem_res;

   wire [2:0]    s_wb_wb_ctrl;
   wire [4:0]    s_wb_regdest2;
   wire [31:0]   s_wb_data;
   wire [31:0]   s_wb_pc1;
   wire [31:0]   s_wb_res;


   // TOP OUTPUTS
   assign dmem_addr_out = 0;
   assign dmem_req_r = 0;
   assign dmem_req_w = 0;
   assign dmem_pre_r = 0;
   assign dmem_pre_w = 0;

   // STALL
   assign n_stall = n_ext_stall;

   mux4 fwmux1(.A(s_ex_data1),
               .B(s_wb_data),
               .C(s_mem_res),
               .D({32{1'b0}}),
               .sel(s_ex_sel1),
               .O(s_ex_alu0));

   mux4 fwmux2(.A(s_ex_data2),
               .B(s_wb_data),
               .C(s_mem_res),
               .D({32{1'b0}}),
               .sel(s_ex_sel2),
               .O(s_ex_pre_alu1));

   mux2 immux(.A(s_ex_pre_alu1),
               .B(s_ex_data3),
               .sel(s_ex_ex_ctrl[5]),
               .O(s_ex_alu1));

   alu alu(.A(s_ex_alu0),
           .B(s_ex_alu1),
           .ctrl(s_ex_ex_ctrl[4:0]),
           .O(s_ex_res),
           .n_zero(s_ex_n_zero),
           .overflow(s_ex_overflow));

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

   // IF->ID REGISTERS
   pipereg #( .WIDTH(32) ) ifid_pc(.clk(clk),
                                   .n_reset(n_reset),
                                   .D(s_if_pc1),
                                   .enable(n_stall),
                                   .Q(s_id_pc1));

   pipereg #( .WIDTH(32) ) ifid_instr(.clk(clk),
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

   assign s_if_pc5 = {{6{1'b0}}, s_id_instr[25:0]};

   assign s_id_r1_sel = s_id_instr[25:21];
   assign s_id_r2_sel = s_id_instr[20:16];

   assign s_id_immediate = s_id_instr[15:0];

   signext signext(.A(s_id_immediate),
                   .ctrl(s_id_ctrl_id),
                   .O(s_id_data3));


   // ID->EX REGISTERS
   pipereg #( .WIDTH(32) ) ifid_pc1(.clk(clk),
                                   .n_reset(n_reset),
                                   .D(s_id_pc1),
                                   .enable(n_stall),
                                   .Q(s_ex_pc1));

   pipereg #( .WIDTH(32) ) idex_data(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(s_id_data3),
                                     .enable(n_stall),
                                     .Q(s_ex_data3));

   pipereg #( .WIDTH(5) ) idex_r1_sel(.clk(clk),
                                      .n_reset(n_reset),
                                      .D(s_id_r1_sel),
                                      .enable(n_stall),
                                      .Q(s_ex_r1_sel));

   pipereg #( .WIDTH(5) ) idex_r2_sel(.clk(clk),
                                      .n_reset(n_reset),
                                      .D(s_id_r2_sel),
                                      .enable(n_stall),
                                      .Q(s_ex_r2_sel));

   pipereg #( .WIDTH(5) ) idex_rd_sel(.clk(clk),
                                      .n_reset(n_reset),
                                      .D(s_id_rd_sel),
                                      .enable(n_stall),
                                      .Q(s_ex_rd_sel));

   pipereg #( .WIDTH(5) ) idex_mem_ctrl(.clk(clk),
                                        .n_reset(n_reset),
                                        .D(s_id_mem_ctrl),
                                        .enable(n_stall),
                                        .Q(s_ex_mem_ctrl));

   pipereg #( .WIDTH(8) ) idex_ex_ctrl(.clk(clk),
                                       .n_reset(n_reset),
                                       .D(s_id_ex_ctrl),
                                       .enable(n_stall),
                                       .Q(s_ex_ex_ctrl));

   pipereg #( .WIDTH(3) ) idex_wb_ctrl(.clk(clk),
                                       .n_reset(n_reset),
                                       .D(s_id_wb_ctrl),
                                       .enable(n_stall),
                                       .Q(s_ex_wb_ctrl));

   pipereg #( .WIDTH(2) ) idex_sel1(.clk(clk),
                                    .n_reset(n_reset),
                                    .D(s_id_sel1),
                                    .enable(n_stall),
                                    .Q(s_ex_sel1));

   pipereg #( .WIDTH(2) ) idex_sel2(.clk(clk),
                                    .n_reset(n_reset),
                                    .D(s_id_sel2),
                                    .enable(n_stall),
                                    .Q(s_ex_sel2));

   // EX->MEM REGISTERS
   pipereg #( .WIDTH(32) ) exmem_pc7(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(s_ex_pc7),
                                     .enable(n_stall),
                                     .Q(s_mem_pc7));

   pipereg #( .WIDTH(32) ) exmem_pc1(.clk(clk),
                                   .n_reset(n_reset),
                                   .D(s_ex_pc1),
                                   .enable(n_stall),
                                   .Q(s_mem_pc1));

   pipereg #( .WIDTH(32) ) exmem_alu_res(.clk(clk),
                                         .n_reset(n_reset),
                                         .D(s_ex_res),
                                         .enable(n_stall),
                                         .Q(s_mem_res));

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

   pipereg #( .WIDTH(3) ) exmem_wb_ctrl(.clk(clk),
                                        .n_reset(n_reset),
                                        .D(s_ex_wb_ctrl),
                                        .enable(n_stall),
                                        .Q(s_mem_wb_ctrl));

   pipereg #( .WIDTH(5) ) exmem_regdest(.clk(clk),
                                        .n_reset(n_reset),
                                        .D(s_ex_regdest),
                                        .enable(n_stall),
                                        .Q(s_mem_regdest));

   branchlogic branchlogic(.n_zero(s_mem_n_zero),
                           .overflow(s_mem_overflow),
                           .ctrl(s_mem_mem_ctrl[4:2]),
                           .pcmux1_ctrl(s_if_ctrl1),
                           .pcmux3_ctrl(s_mem_ctrl2));

   // MEM->WB REGISTERS
   pipereg #( .WIDTH(32) ) memwb_pc1(.clk(clk),
                                     .n_reset(n_reset),
                                     .D(s_mem_pc1),
                                     .enable(n_stall),
                                     .Q(s_wb_pc1));


   pipereg #( .WIDTH(32) ) memwb_data(.clk(clk),
                                       .n_reset(n_reset),
                                       .D(s_mem_data4),
                                       .enable(n_stall),
                                       .Q(s_wb_data4));

   pipereg #( .WIDTH(32) ) memwb_alu_res(.clk(clk),
                                         .n_reset(n_reset),
                                         .D(s_mem_res),
                                         .enable(n_stall),
                                         .Q(s_wb_res));

   pipereg #( .WIDTH(3) ) memwb_wb_ctrl(.clk(clk),
                                        .n_reset(n_reset),
                                        .D(s_mem_wb_ctrl),
                                        .enable(n_stall),
                                        .Q(s_wb_wb_ctrl));

   pipereg #( .WIDTH(5) ) memwb_regdest(.clk(clk),
                                        .n_reset(n_reset),
                                        .D(s_mem_regdest),
                                        .enable(n_stall),
                                        .Q(s_wb_regdest2));

   mux4 datamux(.A(s_wb_res),
                .B(s_wb_data4),
                .C(s_wb_pc1),
                .D({32{1'b0}}),
                .sel(s_wb_wb_ctrl[2:1]),
                .O(s_wb_data));

   mux4 regdestmux(.A(s_ex_r2_sel),
                   .B(s_ex_rd_sel),
                   .C(5'b1111),
                   .D(5'b11111),
                   .sel(s_ex_ex_ctrl[7:6]),
                   .O(s_ex_regdest));

   regbank regbank(.clk(clk),
                   .n_reset(n_reset),
                   .r1_sel(s_id_r1_sel),
                   .r2_sel(s_id_r2_sel),
                   .rd_sel(s_wb_regdest2),
                   .w_enable(s_wb_wb_ctrl[0]),
                   .w_data(s_wb_data),
                   .r1_data(s_id_data1),
                   .r2_data(s_id_data2));

   fwunit fwunit(.r1_sel(s_id_r1_sel),
                 .r2_sel(s_id_r2_sel),
                 .mem_rd_sel(s_ex_regdest),
                 .wb_rd_sel(s_mem_regdest),
                 .mem_w_enable(s_ex_wb_ctrl[0]),
                 .wb_w_enable(s_mem_wb_ctrl[0]),
                 .sel1(s_id_sel1),
                 .sel2(s_id_sel2));

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
   assign debug_data = s_wb_data;
   assign debug_data2 = { 11'b0, s_wb_regdest2, 13'b0, s_wb_wb_ctrl };
   assign data_out = s_if_instr;

endmodule
