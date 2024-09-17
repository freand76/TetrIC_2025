module hello;

   reg clk;
   reg n_reset;
   wire dmem_req, dmem_wr;

   wire [31:0] imem_addr_out, dmem_addr_out, data_out, debug_pc, debug_data, debug_data2;

   integer     i;
   reg [7:0]   byte_array[1024];
   reg [31:0]  word_array[1024/4];

   reg [31:0]  current_instruction;

   reg         dmem_ack;

   processor processor(.clk(clk),
                       .n_reset(n_reset),
                       .n_ext_stall(1'b1),
                       .imem_addr_out(imem_addr_out),
                       .imem_data_in(current_instruction),
                       .imem_ack(1'b1),
                       .dmem_addr_out(dmem_addr_out),
                       .dmem_data_in(32'hfedebeda),
                       .dmem_data_out(data_out),
                       .dmem_req(dmem_req),
                       .dmem_wr(dmem_wr),
                       .dmem_ack(dmem_ack),
                       .debug_pc(debug_pc),
                       .debug_data(debug_data),
                       .debug_data2(debug_data2));

   always @(posedge dmem_req)
     begin
        #40
          dmem_ack <= 1'b1;
     end


   always @(negedge dmem_req)
     begin
        dmem_ack <= 1'b0;
     end

   initial
     begin
        $readmemh("prg.hex", byte_array);

        for (i=0; i<1024;i=i+4)
          begin
             word_array[i/4] = { byte_array[i] , byte_array[i+1] , byte_array[i+2] , byte_array[i+3] };
             //$display("%d : %x", i, word_array[i/4]);
          end

        clk = 0;
        n_reset = 0;
        #9 n_reset = 1;
     end

   always #5 clk = ~clk;

   always @(negedge clk)
     begin
        // Use PC index from word_array
        current_instruction <= word_array[imem_addr_out];
     end

   always @(posedge clk)
     begin
        if (n_reset)
          begin
             $display("PC:%d ==> DMEM addr:%x:data:%x, D1:%x D2:%x (%d:%d)", imem_addr_out, dmem_addr_out, data_out, debug_data, debug_data2, dmem_req, dmem_wr);
          end
     end

   initial
     begin
        $display("Hello, World");
        #1000
          $finish;
     end
endmodule // hello
