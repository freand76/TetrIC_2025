// SPI NOR flash model (W25Q64-like, 8 MB), for simulation only.
//
// A plain behavioural model of the commands the TetrIC designs and test
// benches use, so the downloaded vendor model is not needed:
//
//   03 READ            24 bit address, then data until CS goes high
//   0B FAST READ       24 bit address, 8 dummy clocks, then data
//   9F JEDEC ID        EF 40 17 (Winbond W25Q64)
//   90 MANUFACTURER/ID 3 address bytes, then EF 16 repeated
//   AB RELEASE POWER-DOWN / DEVICE ID   3 dummy bytes, then 16 repeated
//   B9 POWER-DOWN      ignores all commands but AB until released
//   05 / 35 / 15 READ STATUS 1 / 2 / 3, repeated until CS goes high
//   06 / 04 WRITE ENABLE / DISABLE
//   02 PAGE PROGRAM    24 bit address, data bytes (wraps in the 256 byte
//                      page; bits can only be cleared, as in a real flash)
//   20 / 52 / D8 SECTOR (4 kB) / BLOCK (32 kB, 64 kB) ERASE, 24 bit address
//   C7 / 60 CHIP ERASE
//   66, 99 RESET ENABLE / RESET
// Other commands are ignored (DO stays high impedance). Program and erase
// need WRITE ENABLE first and complete when CS goes high (no busy time is
// modelled: the BUSY bit of status 1 always reads 0, WEL is cleared).
//
// SPI mode 0 or 3: data in is sampled on the rising CLK edge, data out
// changes on the falling edge (MSB first). DO is high impedance while CSn
// is high.
//
// The contents are read at time 0 from MEM_FILE, in $readmemh style: hex
// bytes separated by whitespace (e.g. "00 1f 3c 04" per line), "@<hex>"
// sets the address of the next byte. The rest of the flash is erased
// (FF). Same ports as the vendor model.
`timescale 1ns/1ps
module spi_flash_model
    #(
        parameter SIZE     = 8 * 1024 * 1024,   // bytes
        parameter MEM_FILE = "MEM.TXT"
    )
        (
            input      CSn,
            input      CLK,
            input      DIO,          // data in (IO0)
            output     DO,           // data out (IO1)
            input      WPn,          // not used
            input      HOLDn,        // not used
            input      RESETn
        );

    localparam AW = $clog2(SIZE);

    reg [7:0]  mem [0:SIZE-1];
    integer         i, fd;
    initial
        begin
            for (i = 0; i < SIZE; i = i + 1)
                mem[i] = 8'hff;
            fd = $fopen(MEM_FILE, "r");
            if (fd == 0)
                $display("spi_flash_model: no %0s, the flash is erased", MEM_FILE);
            else
                begin
                    // $readmemh handles @address lines; bytes not in the file stay erased
                    $fclose(fd);
                    $readmemh(MEM_FILE, mem);
                end
        end

    // ---- command decoder (rising CLK edge) ----
    reg [7:0]    cmd, inb;
    reg [2:0]    bitn;
    integer      nbytes;              // bytes of this command received
    reg [23:0]   addr;
    reg [AW-1:0] rd_addr;
    reg          wel, powered_down, reset_enable;
    reg          pend_program, pend_erase;
    reg [AW-1:0] erase_addr;
    integer      erase_size;

    // data out
    reg [7:0]    outb;                // byte being shifted out
    reg          out_en;
    reg          do_r;
    reg [2:0]    obit;

    assign DO = (!CSn && out_en) ? do_r : 1'bz;

    wire active = !CSn && RESETn;

    task chip_reset;
        begin
            wel = 0;
            powered_down = 0;
            reset_enable = 0;
        end
    endtask

    initial
        begin
            chip_reset;
            cmd = 0; inb = 0; bitn = 0; nbytes = 0; addr = 0; rd_addr = 0;
            pend_program = 0; pend_erase = 0; erase_addr = 0; erase_size = 0;
            outb = 8'hff; out_en = 0; do_r = 1; obit = 7;
        end

    always @(negedge RESETn)
        chip_reset;

    // the byte to send after `nbytes` bytes were received
    function [7:0] next_out(input integer n);
        begin
            next_out = 8'hff;
            case (cmd)
                8'h03:        next_out = mem[rd_addr];
                8'h0b:        next_out = mem[rd_addr];
                8'h9f:        next_out = (n == 1) ? 8'hef : (n == 2) ? 8'h40 : 8'h17;
                8'h90:        next_out = ((n - 4) % 2 == 0) ? 8'hef : 8'h16;
                8'hab:        next_out = 8'h16;
                8'h05:        next_out = {6'd0, wel, 1'b0};
                8'h35, 8'h15: next_out = 8'h00;
                default: ;
            endcase
        end
    endfunction

    function sends(input [7:0] c, input integer n);   // DO active after n bytes
        begin
            case (c)
                8'h03: sends = n >= 4;
                8'h0b: sends = n >= 5;
                8'h9f: sends = n >= 1 && n <= 3;
                8'h90: sends = n >= 4;
                8'hab: sends = n >= 4;
                8'h05, 8'h35, 8'h15: sends = n >= 1;
                default: sends = 0;
            endcase
        end
    endfunction

    always @(posedge CLK)
        if (active)
        begin
            inb = {inb[6:0], DIO};
            if (bitn == 3'd7)
                begin
                    bitn = 0;
                    nbytes = nbytes + 1;
                    byte_received(inb);
                end
            else
                bitn = bitn + 1'b1;
        end

    task byte_received(input [7:0] b);
        begin
            if (nbytes == 1)
                begin
                    cmd = powered_down && b != 8'hab ? 8'h00 : b;
                    case (cmd)
                        8'h06: wel = 1;
                        8'h04: wel = 0;
                        8'hb9: powered_down = 1;
                        8'hab: powered_down = 0;
                        8'h66: reset_enable = 1;
                        8'h99: if (reset_enable) chip_reset;
                        default: ;
                    endcase
                    if (cmd != 8'h66)
                        reset_enable = (cmd == 8'h66);
                end
            else if (nbytes <= 4)
                begin
                    addr = {addr[15:0], b};
                    if (nbytes == 4)
                        begin
                            rd_addr = addr[AW-1:0];
                            case (cmd)
                                8'h20: begin erase_addr = addr[AW-1:0] & ~(4096 - 1);  erase_size = 4096;  pend_erase = wel; end
                                8'h52: begin erase_addr = addr[AW-1:0] & ~(32768 - 1); erase_size = 32768; pend_erase = wel; end
                                8'hd8: begin erase_addr = addr[AW-1:0] & ~(65536 - 1); erase_size = 65536; pend_erase = wel; end
                                default: ;
                            endcase
                        end
                end
            else if (cmd == 8'h02 && wel)
                begin
                    // page program: clear bits, wrap inside the page
                    mem[rd_addr] = mem[rd_addr] & b;
                    rd_addr = {rd_addr[AW-1:8], rd_addr[7:0] + 8'd1};
                    pend_program = 1;
                end
            if (nbytes == 1 && (cmd == 8'hc7 || cmd == 8'h60))
                begin
                    erase_addr = 0;
                    erase_size = SIZE;
                    pend_erase = wel;
                end
        end
    endtask

    // ---- data out (falling CLK edge) ----
    always @(negedge CLK)
        if (active)
        begin
            if (bitn == 3'd0)
                begin
                    // a byte boundary: start the next output byte
                    out_en = sends(nbytes == 0 ? 8'h00 : cmd, nbytes);
                    if (out_en)
                        begin
                            outb = next_out(nbytes);
                            if (cmd == 8'h03 || (cmd == 8'h0b && nbytes >= 5))
                                rd_addr = rd_addr + 1'b1;      // wraps at the end
                        end
                    obit = 7;
                end
            do_r = outb[obit];
            obit = obit - 1'b1;
        end

    // ---- end of a command (CS high) ----
    always @(posedge CSn)
        begin
            if (pend_erase)
                for (i = 0; i < erase_size; i = i + 1)
                mem[erase_addr + i] = 8'hff;
            if (pend_erase || pend_program)
                wel = 0;
            pend_erase = 0;
            pend_program = 0;
            bitn = 0;
            nbytes = 0;
            out_en = 0;
            do_r = 1;
        end

    always @(negedge CSn)
        begin
            bitn = 0;
            nbytes = 0;
            out_en = 0;
        end

endmodule // spi_flash_model
