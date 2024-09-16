module hello;

   reg clk;
   reg n_reset;
   wire dmem_req_r, dmem_req_w;
   wire dmem_pre_r, dmem_pre_w;

   wire [31:0] imem_addr_out, dmem_addr_out, data_out, debug_pc, debug_data, debug_data2;


   processor processor(.clk(clk),
                       .n_reset(n_reset),
                       .n_ext_stall(1'b1),
                       .data_in(32'h24210003),
                       .imem_ack(1'b1),
                       .dmem_ack(1'b0),
                       .dmem_req_r(dmem_req_r),
                       .dmem_req_w(dmem_req_w),
                       .dmem_pre_r(dmem_pre_r),
                       .dmem_pre_w(dmem_pre_w),
                       .imem_addr_out(imem_addr_out),
                       .dmem_addr_out(dmem_addr_out),
                       .data_out(data_out),
                       .debug_pc(debug_pc),
                       .debug_data(debug_data),
                       .debug_data2(debug_data2));

   initial
     begin
        clk = 0;
        n_reset = 0;
        #9 n_reset = 1;
     end

   always #5 clk = ~clk;

   always @(posedge clk)
     begin
        if (n_reset)
          begin
             $display("Tick");
             $display(" - %x", debug_pc);
             $display(" - %x", debug_data);
             $display(" - %x", debug_data2);
          end
     end

   initial
     begin
        $display("Hello, World");
        #100
          $finish;
     end
endmodule // hello
