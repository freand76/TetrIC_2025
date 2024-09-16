module ctrl(instr, ife_ctrl, id_ctrl, ex_ctrl, mem_ctrl, wb_ctrl);

   input [31:0] instr;

   output reg   ife_ctrl;
   output reg [1:0] id_ctrl;
   output reg [7:0] ex_ctrl;
   output reg [4:0] mem_ctrl;
   output reg [2:0] wb_ctrl;

   wire [5:0]       opcode;
   wire [5:0]       func;

   assign opcode = instr[31:26];
   assign func = instr[5:0];

   reg [1:0]        f_id_ctrl;
   reg [7:0]        f_ex_ctrl;
   reg [4:0]        f_mem_ctrl;
   reg [2:0]        f_wb_ctrl;

   // IFE
   always @ (opcode)
     begin
        case(opcode)
          6'b000010 : ife_ctrl <= 1; // J
          6'b000011 : ife_ctrl <= 1; // JAL
          default   : ife_ctrl <= 0;
        endcase // case (opcode)
     end

   always @ (func)
     begin
        f_id_ctrl <= 2'b00;
        f_mem_ctrl <= 5'b00000;
        f_wb_ctrl <= 3'b001;
        f_ex_ctrl <= 8'b01101000;

        case(func)
          6'b000000 :    // nop,sll
            begin
               f_ex_ctrl <= 8'b01101000;
            end
          6'b100001 :    // addu
            begin
               f_ex_ctrl <= 8'b01010001;
            end
          6'b100100 :    // and
            begin
               f_ex_ctrl <= 8'b01010100;
            end
          6'b100000 :    // add
            begin
               f_ex_ctrl <= 8'b01010000;
            end
          6'b100111 :    // nor
            begin
               f_ex_ctrl <= 8'b01010111;
            end
          6'b100101 :    // or
            begin
               f_ex_ctrl <= 8'b01010101;
            end
          6'b000100 :    // sllv
            begin
               f_ex_ctrl <= 8'b01001100;
            end
          6'b000011 :    // sra
            begin
               f_id_ctrl <= 2'b11;
               f_ex_ctrl <= 8'b01101011;
            end
          6'b000111 :    // srav
            begin
               f_ex_ctrl <= 8'b01000111;
            end
          6'b000010 :    // srl
            begin
               f_id_ctrl <= 2'b11;
               f_ex_ctrl <= 8'b01101010;
            end
          6'b000110 :    // srlv
            begin
               f_ex_ctrl <= 8'b01001110;
            end
          6'b100010 :    // sub
            begin
               f_ex_ctrl <= 8'b01010010;
            end
          6'b100011 :    // subu
            begin
               f_ex_ctrl <= 8'b01010011;
            end
          6'b100110 :    // xor
            begin
               f_ex_ctrl <= 8'b01010110;
            end
          6'b101010 :    // slt
            begin
               f_ex_ctrl <= 8'b01011010;
            end
          6'b101011 :    // sltu
            begin
               f_ex_ctrl <= 8'b01011011;
            end
          6'b001001 :    // jalr
            begin
               f_ex_ctrl <= 8'b10000011;
               f_mem_ctrl <= 5'b01100;
               f_wb_ctrl <= 3'b101;
            end
          6'b001000 :    // jr
            begin
               f_ex_ctrl <= 8'b01000011;
               f_mem_ctrl <= 5'b01100;
               f_wb_ctrl <= 3'b000;
            end
        endcase
     end

   always @ (opcode, f_id_ctrl, f_ex_ctrl, f_mem_ctrl, f_wb_ctrl)
     begin
        id_ctrl <= 2'b00;
        ex_ctrl <= 8'b00110000;
        mem_ctrl <= 5'b00000;
        wb_ctrl <= 3'b000;

        case(opcode)
          6'b000000 :
            begin
               id_ctrl  <= f_id_ctrl;
               ex_ctrl  <= f_ex_ctrl;
               mem_ctrl <= f_mem_ctrl;
               wb_ctrl  <= f_wb_ctrl;
            end
          6'b001000 :   // addi
            begin
               ex_ctrl <= 8'b00110000;
               wb_ctrl <= 3'b001;
            end
          6'b001001 :   // addiu
            begin
               id_ctrl <= 2'b01;
               ex_ctrl <= 8'b00110001;
               wb_ctrl <= 3'b001;
            end
          6'b001100 :   // andi
            begin
               id_ctrl <= 2'b10;
               ex_ctrl <= 8'b00110100;
               wb_ctrl <= 3'b001;
            end
          6'b001101 :   // ori
            begin
               id_ctrl <= 2'b11;
               ex_ctrl <= 8'b00110101;
               wb_ctrl <= 3'b001;
            end
          6'b001110 :   // xori
            begin
               id_ctrl <= 2'b11;
               ex_ctrl <= 8'b00110110;
               wb_ctrl <= 3'b001;
            end
          6'b001111 :   // lui
            begin
               id_ctrl <= 2'b11;
               ex_ctrl <= 8'b00101111;
               wb_ctrl <= 3'b001;
            end
          6'b001010 :   // slti
            begin
               ex_ctrl <= 8'b00111010;
               wb_ctrl <= 3'b001;
            end
          6'b001011 :   // sltiu
            begin
               id_ctrl <= 2'b01;
               ex_ctrl <= 8'b00111011;
               wb_ctrl <= 3'b001;
            end
          6'b000100 :   // beq
            begin
               ex_ctrl <= 8'b00010010;
               mem_ctrl <= 5'b00100;
            end
          6'b000001 :   // bge
            begin
               ex_ctrl <= 8'b00010010;
               mem_ctrl <= 5'b10100;
            end
          6'b000111 :   // bgt
            begin
               ex_ctrl <= 8'b00010010;
               mem_ctrl <= 5'b11000;
            end
          6'b000101 :   // bne
            begin
               ex_ctrl <= 8'b00010010;
               mem_ctrl <= 5'b01000;
            end
          6'b000010 :  // j
            begin
               id_ctrl <= 2'b01;
               ex_ctrl <= 8'b00000000;
            end
          6'b000011 :  // jal
            begin
               id_ctrl <= 2'b01;
               ex_ctrl <= 8'b10000000;
               wb_ctrl <= 3'b101;
            end
          6'b010000 :    // mfc0
            begin
               ex_ctrl <= 8'b01011100;
               wb_ctrl <= 3'b001;
            end
          6'b010001 :           // mfc1
            begin
               ex_ctrl <= 8'b01011101;
               wb_ctrl <= 3'b001;
            end
          6'b010010 :           // mfc2
            begin
               ex_ctrl <= 8'b01011110;
               wb_ctrl <= 3'b001;
            end
          6'b010011 :           // mfc3
            begin
               ex_ctrl <= 8'b01011111;
               wb_ctrl <= 3'b001;
            end
          6'b100011 :   // lw
            begin
               id_ctrl <= 2'b01;
               ex_ctrl <= 8'b00110000;
               mem_ctrl <= 5'b00010;
               wb_ctrl <= 3'b011;
            end
          6'b101011 :   // sw
            begin
               id_ctrl <= 2'b01;
               ex_ctrl <= 8'b00110000;
               mem_ctrl <= 5'b00001;
            end

        endcase // case (opcode)
     end


endmodule // ctrl
