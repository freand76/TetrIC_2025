// PlayStation (DualShock type) gamepad controller, e.g. the gamepads of the
// Tang Nano 20K retro kit.
//
// Protocol: SPI mode 3 (clock idles high, data changes on the falling edge,
// is sampled on the rising edge), LSB first, ATT (cs) low during a poll.
//   command  01 42 00 00 00
//   response FF ID 5A B1 B2     ID = 41 (digital) / 73 (analog), B1/B2 active low
//   B1: 0 SELECT, 1 L3, 2 R3, 3 START, 4 UP, 5 RIGHT, 6 DOWN, 7 LEFT
//   B2: 0 L2, 1 R2, 2 L1, 3 R1, 4 TRIANGLE, 5 CIRCLE, 6 CROSS, 7 SQUARE
// The pad is polled ~60 times per second with a 125 kHz clock (some cheap
// pads cannot handle the nominal 250 kHz). Without a pad (or with a bad
// response) all buttons read as released.
//
// joy: TetrIC joystick bits as old_vhdl/joyctrl.vhd + TLib/Joy.s, active low
//   0 UP, 1 A (SQUARE), 2 DOWN, 3 RIGHT, 4 B (CROSS), 5 LEFT, 6 START, 7 C (CIRCLE)

module gamepad
    #(
        parameter FREQ = 25_200_000      // clk frequency
    )
        (
            input            clk,
            input            rst_n,

            output reg       ds_clk,
            output reg       ds_cs,
            output reg       ds_mosi,
            input            ds_miso,

            output reg [7:0] buttons1,       // B1, active low
            output reg [7:0] buttons2,       // B2, active low
            output [7:0]     joy             // TetrIC layout, active low
        );

    localparam HALF  = FREQ / 250_000;        // half period of 125 kHz
    localparam POLL  = FREQ / 60;             // poll interval
    localparam GAP   = 4 * HALF;              // cs to first clock, between bytes
    localparam NBYTES = 5;

    assign joy = { buttons2[5],      // 7 C     = CIRCLE
        buttons1[3],      // 6 START
        buttons1[7],      // 5 LEFT
        buttons2[6],      // 4 B     = CROSS
        buttons1[5],      // 3 RIGHT
        buttons1[6],      // 2 DOWN
        buttons2[7],      // 1 A     = SQUARE
        buttons1[4] };    // 0 UP

    // synchronise the input
    reg [1:0] miso_sync;
    always @(posedge clk or negedge rst_n)
        if (!rst_n) miso_sync <= 2'b11;
    else        miso_sync <= {miso_sync[0], ds_miso};

    localparam [2:0] S_IDLE = 3'd0, S_START = 3'd1, S_LOW = 3'd2, S_HIGH = 3'd3,
        S_GAP = 3'd4, S_DONE = 3'd5;

    reg [2:0]  state;
    reg [19:0] timer;
    reg [2:0]  bitn;
    reg [2:0]  byten;
    reg [7:0]  rx;
    reg [7:0]  r_id, r_5a, r_b1;

    wire [7:0] txb = (byten == 0) ? 8'h01 : (byten == 1) ? 8'h42 : 8'h00;

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
        begin
            state <= S_IDLE;
            timer <= 0;
            bitn <= 0;
            byten <= 0;
            rx <= 0;
            r_id <= 0;
            r_5a <= 0;
            r_b1 <= 8'hff;
            ds_clk <= 1;
            ds_cs <= 1;
            ds_mosi <= 1;
            buttons1 <= 8'hff;
            buttons2 <= 8'hff;
        end
    else
        begin
            if (timer != 0)
                timer <= timer - 1;

            case (state)
                S_IDLE:
                    if (timer == 0)
                    begin
                        ds_cs <= 0;
                        byten <= 0;
                        timer <= GAP;
                        state <= S_START;
                    end

                S_START, S_GAP:          // cs / ack time before a byte
                    if (timer == 0)
                    begin
                        bitn <= 0;
                        ds_clk <= 0;
                        ds_mosi <= txb[0];
                        timer <= HALF;
                        state <= S_LOW;
                    end

                S_LOW:                   // clock low, data out is set
                    if (timer == 0)
                    begin
                        ds_clk <= 1;       // rising edge: sample
                        rx <= {miso_sync[1], rx[7:1]};
                        timer <= HALF;
                        state <= S_HIGH;
                    end

                S_HIGH:
                    if (timer == 0)
                    begin
                        if (bitn == 3'd7)
                            begin
                                case (byten)
                                    3'd1: r_id <= rx;
                                    3'd2: r_5a <= rx;
                                    3'd3: r_b1 <= rx;
                                    default: ;
                                endcase
                                if (byten == NBYTES - 1)
                                    begin
                                        timer <= HALF;
                                        state <= S_DONE;
                                        // byte 4 (B2) is in rx now
                                        if (r_5a == 8'h5a && (r_id == 8'h41 || r_id == 8'h73))
                                            begin
                                                buttons1 <= r_b1;
                                                buttons2 <= rx;
                                            end
                                        else
                                            begin
                                                buttons1 <= 8'hff;
                                                buttons2 <= 8'hff;
                                            end
                                    end
                                else
                                    begin
                                        byten <= byten + 1;
                                        ds_mosi <= 1;
                                        timer <= GAP;
                                        state <= S_GAP;
                                    end
                            end
                        else
                            begin
                                bitn <= bitn + 1;
                                ds_clk <= 0;  // falling edge: next bit out
                                ds_mosi <= txb[bitn + 1];
                                timer <= HALF;
                                state <= S_LOW;
                            end
                    end

                S_DONE:
                    if (timer == 0)
                    begin
                        ds_cs <= 1;
                        ds_mosi <= 1;
                        timer <= POLL;
                        state <= S_IDLE;
                    end

                default:
                    state <= S_IDLE;
            endcase
        end

endmodule // gamepad
