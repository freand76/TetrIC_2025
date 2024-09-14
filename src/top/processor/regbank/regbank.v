module regbank(clk, n_reset, rSelA, rSelB, wSel, wEnable, wData, rDataA, rDataB);

   input        clk, n_reset;

   input [4:0]  rSelA, rSelB, wSel;
   input        wEnable;
   input [31:0] wData;

   output [31:0]  rDataA, rDataB;

   reg [31:0]     register_bank[32];

   always @ (rSelA)
     begin
        rDataA = register_bank[rSelA];
     end

   always @ (rSelB)
     begin
        rDataB = register_bank[rSelB];
     end

   always @(posedge clk or negedge n_reset)
     begin
        if (!n_reset)
          begin
             register_bank[0] = 0;
             register_bank[1] = 0;
             register_bank[2] = 0;
             register_bank[3] = 0;
             register_bank[4] = 0;
             register_bank[5] = 0;
             register_bank[6] = 0;
             register_bank[7] = 0;
             register_bank[8] = 0;
             register_bank[9] = 0;
             register_bank[10] = 0;
             register_bank[11] = 0;
             register_bank[12] = 0;
             register_bank[13] = 0;
             register_bank[14] = 0;
             register_bank[15] = 0;
             register_bank[16] = 0;
             register_bank[17] = 0;
             register_bank[18] = 0;
             register_bank[19] = 0;
             register_bank[20] = 0;
             register_bank[21] = 0;
             register_bank[22] = 0;
             register_bank[23] = 0;
             register_bank[24] = 0;
             register_bank[25] = 0;
             register_bank[26] = 0;
             register_bank[27] = 0;
             register_bank[28] = 0;
             register_bank[29] = 0;
             register_bank[30] = 0;
             register_bank[31] = 0;
         end
        else
          begin
             if ((wEnable) && (wSel != 0))
               register_bank[wSel] = wData;
          end
     end

endmodule
