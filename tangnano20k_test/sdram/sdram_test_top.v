`timescale 1ns / 1ns

`ifdef IVERLOG
module sdram_test_top;
    `else
    module top(
        // Clock and Reset
        input         sys_clk,
        input         rst,

        // UART Tx
        output        uart_tx,

        // spi flash interface
        output        mspi_cs,
        output        mspi_clk,
        output        mspi_di,
        input         mspi_do,

        // SDRAM
        output        O_sdram_clk,
        output        O_sdram_cke,
        output        O_sdram_cs_n, // chip select
        output        O_sdram_cas_n, // columns address select
        output        O_sdram_ras_n, // row address select
        output        O_sdram_wen_n, // write enable
        inout [31:0]  IO_sdram_dq, // bidirectional data bus
        output [10:0] O_sdram_addr, // multiplexed address bus
        output [1:0]  O_sdram_ba, // two banks
        output [3:0]  O_sdram_dqm
    );
        `endif

        `ifdef IVERLOG
        parameter             FLASH_START = 24'h000000;
        parameter             COPY_WORD_COUNT  = 24'h000010;
        parameter             INTER_CHAR_WAIT = 10000;
        `else
        parameter             FLASH_START = 24'h600000;
        parameter             COPY_WORD_COUNT  = 24'h000010;
        parameter             INTER_CHAR_WAIT = 27000000/4;
        `endif

        `ifdef IVERLOG
        reg                   clk;
        reg                   rst_n;
        wire                  clk_sdram;

        wire                  O_sdram_clk, O_sdram_cs_n, O_sdram_wen_n, O_sdram_cas_n, O_sdram_ras_n;
        wire [1:0]            O_sdram_ba;
        wire [10:0]           O_sdram_addr;
        wire [31:0]           IO_sdram_dq;

        initial
            begin
                clk = 0;
                rst_n = 0;
                #9 rst_n = 1;
            end

        always #5 clk = ~clk;
        assign clk_sdram = !clk;
        `else

        wire clk = sys_clk;
        wire clk_sdram = sys_clk;
        wire rst_n = !rst;

        `endif

        wire [22:0] address;
        wire [31:0] din;
        wire [31:0] dout;
        wire        sel;
        wire        write;
        wire        read_ack;
        wire        write_ack;

        reg         read;
        reg [22:0]  ram_read_address;

        wire [23:0] flash_write_address;
        wire [31:0] flash_data_out;
        wire        flash_strobe;
        wire        flash_done;

        assign sel = 1;

        `ifdef IVERLOG
        initial
            begin
                $display("Hello, World");
                wait(flash_done);
                $display("Flash Done");
            end

        always @ (write_ack)
            begin
                if (write_ack)
                    $display("Write ACK");
            end

        always @ (read_ack)
            begin
                if (read_ack)
                    $display("Read ACK %x", dout);
            end

        `endif

        wire busy;

        sdram_wrap sdram_wrap
            (
                .SDRAM_DQ(IO_sdram_dq),
                .SDRAM_A(O_sdram_addr),
                .SDRAM_BA(O_sdram_ba),
                .SDRAM_nCS(O_sdram_cs_n),
                .SDRAM_nWE(O_sdram_wen_n),
                .SDRAM_nRAS(O_sdram_ras_n),
                .SDRAM_nCAS(O_sdram_cas_n),
                .SDRAM_CLK(O_sdram_clk),
                .SDRAM_CKE(O_sdram_cke),
                .SDRAM_DQM(O_sdram_dqm),

                .clk(clk),
                .clk_sdram(clk_sdram),
                .resetn(rst_n),
                .sel(sel),
                .read(read),
                .read_ack(read_ack),
                .write(write),
                .write_ack(write_ack),
                .addr(address),
                .din(din),
                .dout(dout),
                .busy(busy)
            );

        always @ (posedge flash_strobe)
            begin
                $display("FLASH %x %x", flash_write_address, flash_data_out);
            end

        assign din = flash_data_out;
        assign address = flash_done ? ram_read_address : { flash_write_address[20:0], 2'b00 };
        assign write = flash_strobe;

        flash_reader flash_reader(.clk(clk),
            .n_reset(rst_n),
            .start(!busy),
            .address(FLASH_START),
            .word_count(COPY_WORD_COUNT),
            .mem_address(flash_write_address),
            .strobe(flash_strobe),
            .done(flash_done),
            .data_out(flash_data_out),
            .spi_cs(mspi_cs),
            .spi_clk(mspi_clk),
            .spi_mosi(mspi_di),
            .spi_miso(mspi_do));

        reg [3:0] state;
        reg [23:0] wait_count;

        always @(posedge clk, negedge rst_n)
            begin
                if (!rst_n)
                    begin
                        ram_read_address <= 0;
                        read <= 0;
                        state <= 0;
                        wait_count <= 128;
                    end
                else
                    case(state)
                        0 :
                            begin
                                if (flash_done)
                                    wait_count <= wait_count - 1;

                                if (wait_count == 0)
                                    state <= 1;
                            end
                        1 :
                            begin
                                read <= 1;
                                state <= 2;
                            end
                        2 :
                            begin
                                read <= 0;
                                state <= 3;
                            end
                        3 :
                            begin
                                if (read_ack)
                                    begin
                                        ram_read_address <= ram_read_address + 4;
                                        state <= 4;
                                        wait_count <= INTER_CHAR_WAIT;
                                    end
                            end
                        4:
                            begin
                                wait_count <= wait_count - 1;
                                if (wait_count == 0)
                                    state <= 5;
                            end
                        5:
                            begin
                                if (ram_read_address[5:2] == 0)
                                    begin
                                        ram_read_address <= 0;
                                        `ifdef IVERLOG
                                        $finish;
                                        `endif
                                    end
                                state <= 1;
                            end
                    endcase // case (state)
            end

        uart_tx#
            (
                .CLK_FRE(27000000),
                .BAUD_RATE(115200)
            ) uart_tx_inst
            (
                .clk            (clk),
                .rst_n          (rst_n),
                .tx_data        (dout[7:0]),
                .tx_data_valid  (read_ack),
                .tx_pin         (uart_tx)
            );

        `ifdef IVERLOG
        spi_flash_model #(.MEM_FILE("MEM.TXT"))
            spi_flash(.CSn(mspi_cs),
                .CLK(mspi_clk),
                .DIO(mspi_di),
                .DO(mspi_do),
                .WPn(1'b1),
                .HOLDn(1'b1),
                .RESETn(rst_n));

        sdram_model sdram_model
            (
                .in_CLK(O_sdram_clk),
                .in_CS(O_sdram_cs_n),
                .in_write_en(O_sdram_wen_n),
                .in_CAS(O_sdram_cas_n),
                .in_RAS(O_sdram_ras_n),
                .in_bank_select(O_sdram_ba),
                .in_sdram_addr(O_sdram_addr),
                .inout_sdram_data(IO_sdram_dq)
            );

        `endif

    endmodule // sdram_test_top

    `ifdef IVERLOG
    module uart_tx
        #(
            parameter CLK_FRE = 50, //clock frequency(Mhz)
            parameter BAUD_RATE = 115200 //serial baud rate
        )
            (
                input       clk, //clock input
                input       rst_n, //asynchronous reset input, low active
                input [7:0] tx_data, //data to send
                input       tx_data_valid, //data to be sent is valid
                output reg  tx_data_ready, //send ready
                output      tx_pin            //serial data output
            );

        initial
            begin
                tx_data_ready <= 1;
            end

        always @ (posedge tx_data_valid)
            begin
                if ((tx_data >= 8'h20) && (tx_data < 8'h80))
                    $display("UART: %x [%c] (time is %0t)", tx_data, tx_data, $time);
                else
                    $display("UART: %x [0x%x] (time is %0t)", tx_data, tx_data, $time);
                tx_data_ready <= 0;
                #1000
                    tx_data_ready <= 1;
            end

    endmodule
    `endif
