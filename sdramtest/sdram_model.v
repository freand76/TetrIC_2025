module sdram_model
  (
   // SDRAM MODEL INTERFACE
   input        in_CLK,
   input        in_CS, // CHIP SELECT
   input        in_write_en,
   input        in_CAS, //COLUMN ADRESS STROBE
   input        in_RAS, //ROW ADRESS STROBE
   input [1:0]  in_bank_select, // BANK SELECTION BITS
   input [10:0] in_sdram_addr,
   inout [31:0] inout_sdram_data
   // SDRAM MODEL INTERFACE END
   );

   parameter    DATA   = 32,
                ROW    = 2048,
                COLUMN = 256;

   wire         ACT,
                READ_CAS,
                WRITE_CAS,
                NOP;


   wire [31:0]  in_sdram_data;
   reg [31:0]   out_sdram_data;
   reg [31:0]   write_sdram_data;
   wire         oe_sdram_data;
   wire         write_store;

   reg [10:0]   registered_row     = 11'b0;
   reg [7:0]    registered_column   = 8'b0;
   reg [1:0]    registered_bank_sel = 2'b0;
   reg [2:0]    nop_counter         = 2'b0;

   reg          write_mode, read_mode;

   assign ACT         = ~in_CS && ~in_RAS && in_CAS && in_write_en;
   assign READ_CAS    = ~in_CS && in_RAS && ~in_CAS && in_write_en;
   assign WRITE_CAS   = ~in_CS && in_RAS && ~in_CAS && ~in_write_en;
   assign REFRESH     = ~in_CS && ~in_RAS && ~in_CAS && in_write_en;
   assign NOP         = ~in_CS && in_RAS && in_CAS && in_write_en;

   reg [DATA-1 : 0] bank0 [0 : ROW-1][0 : COLUMN-1];
   reg [DATA-1 : 0] bank1 [0 : ROW-1][0 : COLUMN-1];
   reg [DATA-1 : 0] bank2 [0 : ROW-1][0 : COLUMN-1];
   reg [DATA-1 : 0] bank3 [0 : ROW-1][0 : COLUMN-1];

   localparam       BANK0 = 2'b00,
                    BANK1 = 2'b01,
                    BANK2 = 2'b10,
                    BANK3 = 2'b11;

   initial
     begin
        read_mode <= 0;
        write_mode <= 0;
        nop_counter <= 3;
     end


   assign oe_sdram_data = (read_mode & (nop_counter == 3));
   assign inout_sdram_data = !oe_sdram_data ? 32'bzzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz_zzzz : out_sdram_data;
   assign in_sdram_data = inout_sdram_data;

   assign write_store = write_mode && (nop_counter == 2);

   always @(posedge in_CLK)
     begin
        if (NOP)
          begin
             nop_counter <= 7;
          end

        if (REFRESH)
          begin
`ifdef SDRAM_DEBUG
             $display("REFRESH");
`endif
             nop_counter <= 0;
          end
        if(ACT)
          begin
`ifdef SDRAM_DEBUG
             $display("ACT");
`endif
             read_mode <= 0;
             write_mode <= 0;
             nop_counter <= 0;
             registered_row[11:0]     <= in_sdram_addr[11:0];
             registered_bank_sel[1:0] <= in_bank_select[1:0];
          end

        if (WRITE_CAS)
          begin
`ifdef SDRAM_DEBUG
             $display("WRITE CAS");
`endif
             read_mode <= 0;
             write_mode <= 1;
             write_sdram_data <= inout_sdram_data;
             nop_counter <= 0;
             registered_column[8:0]   <= in_sdram_addr[8:0];
             registered_bank_sel[1:0] <= in_bank_select[1:0];
          end

        if (READ_CAS)
          begin
`ifdef SDRAM_DEBUG
             $display("READ CAS");
`endif
             write_mode <= 0;
             read_mode <= 1;
             nop_counter <= 0;
             registered_column[8:0]   <= in_sdram_addr[8:0];
             registered_bank_sel[1:0] <= in_bank_select[1:0];
          end

        if (nop_counter == 6)
          begin
             write_mode <= 0;
             read_mode <= 0;
          end

        if (nop_counter < 7)
          begin
             nop_counter <= nop_counter + 1;
          end
     end

   always @(posedge in_CLK)
     begin
        if(write_store)
          begin
`ifdef SDRAM_DEBUG
             $display("SDRAM Write Data %x (%d:%d:%d)", write_sdram_data, registered_bank_sel, registered_row, registered_column);
`endif
             case(registered_bank_sel)

               BANK0:begin
                  bank0[registered_row][registered_column] = write_sdram_data;
               end

               BANK1:begin
                  bank1[registered_row][registered_column] = write_sdram_data;
               end

               BANK2:begin
                  bank2[registered_row][registered_column] = write_sdram_data;
               end

               BANK3:begin
                  bank3[registered_row][registered_column] = write_sdram_data;
               end
             endcase
          end

        case(registered_bank_sel)

          BANK0:begin
             out_sdram_data <= bank0[registered_row][registered_column];
          end

          BANK1:begin
             out_sdram_data <= bank1[registered_row][registered_column];
          end

          BANK2:begin
             out_sdram_data <= bank2[registered_row][registered_column];
          end

          BANK3:begin
             out_sdram_data <= bank3[registered_row][registered_column];
          end
        endcase
     end
endmodule
