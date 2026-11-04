module regbank(clk, n_reset, r1_sel, r2_sel, rd_sel, w_enable, w_data, r1_data, r2_data);

    input        clk, n_reset;

    input [4:0]  r1_sel, r2_sel, rd_sel;
    input        w_enable;
    input [31:0] w_data;

    output [31:0] r1_data, r2_data;

    reg [31:0]        register_bank[32];

    // write-through: a register written this cycle (WB) reads as the new value
    // (as the register file of the original VHDL design, reg.vhd)
    assign r1_data = (r1_sel == 0) ? 0 :
        (w_enable && rd_sel == r1_sel) ? w_data : register_bank[r1_sel];
    assign r2_data = (r2_sel == 0) ? 0 :
        (w_enable && rd_sel == r2_sel) ? w_data : register_bank[r2_sel];

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
                    if ((w_enable) && (rd_sel != 0))
                        register_bank[rd_sel] = w_data;
                end
        end

endmodule
