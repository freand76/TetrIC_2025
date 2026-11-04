module flash_reader(
    input             clk,
    input             n_reset,
    input             start,
    input [23:0]      address,
    input [23:0]      word_count,
    output reg [23:0] mem_address,
    output reg        strobe,
    output reg        done,
    output reg [31:0] data_out,
    output reg        spi_cs,
    output reg        spi_clk,
    output reg        spi_mosi,
    input             spi_miso
);
    reg                                last_spi_clk;

    reg [2:0]                          state;
    reg [15:0]                         bitcnt;
    reg [23:0]                         wcount;

    reg [31:0]                         mosi_shift;
    reg [31:0]                         miso_shift;

    reg                                load_cmd_addr;
    reg                                shifter_active;

    // SPI MOSI MISO
    always @ (posedge clk, negedge n_reset)
        begin
            if (!n_reset)
                begin
                    spi_mosi <= 1'b0;
                    mosi_shift <= 32'h00000000;
                    miso_shift <= 32'h00000000;
                end
            else
                begin
                    spi_mosi <= mosi_shift[31];

                    if (load_cmd_addr)
                        mosi_shift <= { 8'h03, address };
                    else
                        begin
                            if (shifter_active)
                                begin
                                    if (last_spi_clk && !spi_clk)
                                        mosi_shift <= { mosi_shift[30:0], 1'b0 };

                                    if (!last_spi_clk && spi_clk)
                                        miso_shift <= { miso_shift[30:0], spi_miso };
                                end
                        end
                end
        end

    // SPI CLK
    always @ (posedge clk, negedge n_reset)
        begin
            if (!n_reset)
                begin
                    spi_clk <= 1'b1;
                    last_spi_clk <= 1'b1;
                end
            else
                begin
                    if (shifter_active)
                        begin
                            last_spi_clk <= spi_clk;
                            spi_clk <= ~spi_clk;
                        end
                end
        end

    // CTRL

    parameter HALT             = 0;
    parameter INIT             = 1;
    parameter CS_LOW           = 2;
    parameter CS_LOW_TO_CLK    = 3;
    parameter SHIFT            = 4;
    parameter SHIFT_AND_STROBE = 5;
    parameter DONE             = 6;

    always @ (posedge clk, negedge n_reset)
        begin
            if (!n_reset)
                begin
                    load_cmd_addr <= 0;
                    state <= HALT;
                    wcount <= 0;
                    spi_cs <= 1;
                    shifter_active <= 0;
                    bitcnt <= 8192;
                    data_out <= 0;
                    strobe <= 0;
                    done <= 0;
                end
            else
                begin
                    case(state)
                        HALT : // WAIT FOR SOMETHING...
                            begin
                                if (start)
                                    state <= INIT;
                            end
                        INIT : // PRE START CYCLES
                            begin
                                bitcnt <= bitcnt - 1;
                                if (bitcnt == 0)
                                    state <= CS_LOW;
                            end
                        CS_LOW: // CS LOW
                            begin
                                spi_cs <= 0;
                                load_cmd_addr <= 1;
                                wcount <= word_count;
                                bitcnt <= 20;
                                state <= CS_LOW_TO_CLK;
                            end
                        CS_LOW_TO_CLK: // CS LOW ==> SPI_CLK delay
                            begin
                                load_cmd_addr <= 0;
                                bitcnt <= bitcnt - 1;
                                if (bitcnt == 0)
                                    begin
                                        state <= SHIFT;
                                        bitcnt <= 131;
                                    end
                            end
                        SHIFT: // Start shifting
                            begin
                                strobe <= 0;
                                shifter_active <= 1;
                                bitcnt <= bitcnt - 1;
                                if (bitcnt == 0)
                                    begin
                                        data_out <= miso_shift;
                                        state <= SHIFT_AND_STROBE;
                                        bitcnt <= 63;
                                        wcount <= wcount - 1;
                                    end
                            end
                        SHIFT_AND_STROBE: // Word Strobe
                            begin
                                strobe <= 1;
                                shifter_active <= 1;
                                bitcnt <= bitcnt - 1;
                                if (wcount == 0)
                                    state <= DONE;
                                else
                                    state <= SHIFT;
                            end
                        DONE: // Done
                            begin
                                spi_cs <= 1;
                                shifter_active <= 0;
                                done <= 1;
                                strobe <= 0;
                            end

                    endcase // case (state)
                end
        end

    always@(posedge clk or negedge n_reset)
        begin
            if(!n_reset)
                mem_address <= 0;
            else
                if (strobe)
                begin
                    mem_address <= mem_address + 1;
                end
        end

endmodule // flash_reader
