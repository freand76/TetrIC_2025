// Clock domain crossing helpers

// Reset synchroniser: asynchronous assert, synchronous release
module reset_sync(
                  input  clk,
                  input  rst_n_in,
                  output rst_n_out
                  );
   reg [2:0] sync;
   always @(posedge clk or negedge rst_n_in)
     if (!rst_n_in) sync <= 3'b000;
     else           sync <= {sync[1:0], 1'b1};
   assign rst_n_out = sync[2];
endmodule // reset_sync

// Single bit level synchroniser
module sync_bit(
                input      clk,
                input      rst_n,
                input      d,
                output     q
                );
   reg [1:0] sync;
   always @(posedge clk or negedge rst_n)
     if (!rst_n) sync <= 2'b00;
     else        sync <= {sync[0], d};
   assign q = sync[1];
endmodule // sync_bit

// Toggle synchroniser: one pulse in clk for every change of `toggle`
// (toggle is driven from another clock domain)
module sync_toggle(
                   input  clk,
                   input  rst_n,
                   input  toggle,
                   output pulse
                   );
   reg [2:0] sync;
   always @(posedge clk or negedge rst_n)
     if (!rst_n) sync <= 3'b000;
     else        sync <= {sync[1:0], toggle};
   assign pulse = sync[2] ^ sync[1];
endmodule // sync_toggle
