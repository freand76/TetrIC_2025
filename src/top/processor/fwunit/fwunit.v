module fwunit(r1_sel, r2_sel, mem_rd_sel, wb_rd_sel, mem_w_enable, wb_w_enable, sel1, sel2);
   input [4:0] r1_sel, r2_sel, mem_rd_sel, wb_rd_sel;
   input       mem_w_enable, wb_w_enable;

   output reg [1:0] sel1, sel2;

   wire             r1_is_mem_sel;
   wire             r2_is_mem_sel;
   wire             r1_is_wb_sel;
   wire             r2_is_wb_sel;


   assign r1_is_mem_sel = r1_sel == mem_rd_sel;
   assign r2_is_mem_sel = r2_sel == mem_rd_sel;

   assign r1_is_wb_sel = r1_sel == wb_rd_sel;
   assign r2_is_wb_sel = r2_sel == wb_rd_sel;


   always @ (r1_is_mem_sel, r2_is_mem_sel, r1_is_wb_sel, r2_is_wb_sel, mem_w_enable, wb_w_enable)
     begin
        sel1 <= 2'b00;
        sel2 <= 2'b00;

        if (mem_w_enable)
          begin
             sel1 <= { r1_is_mem_sel , 1'b0 };
             sel2 <= { r2_is_mem_sel , 1'b0 };
          end
        else
          if (wb_w_enable)
            begin
               sel1 <= { 1'b0, r1_is_mem_sel };
               sel2 <= { 1'b0, r2_is_mem_sel };
            end
     end

endmodule // fwunit
