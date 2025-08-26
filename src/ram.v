/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
 module RAM16 #(
    parameter ADDR_WIDTH = 3
)(
    input                   CLK,
    input                   RST,        // synchronous reset (active-high)
    input                   READ,       // read enable
    input                   WRITE,      // write strobe
    output reg              FULL,       // 1-cycle pulse when buffer fills
    input  [ADDR_WIDTH-1:0] A,          // read address
    input  [15:0]           Di,         // data in
    output reg [15:0]       Do          // data out
);

    // ------------------------------------------------------------
    localparam DEPTH = 1 << ADDR_WIDTH;

    reg [15:0] RAM [0:DEPTH-1];
    reg [ADDR_WIDTH-1:0] wr_addr;

    integer j;

    // ------------------------------------------------------------
    always @(posedge CLK) begin
        //--------------------- reset ------------------------------------
        if (RST) begin
            // $display("[RAM] DEBUG: @%0t RST=1, clearing RAM", $time);
            for (j = 0; j < DEPTH; j = j + 1)
                RAM[j] <= 16'h0000;
            wr_addr <= 0;
            FULL    <= 1'b0;
            Do      <= 16'h0000;
        end
        //--------------------- normal operation -------------------------
        else begin
            // ---------- write side -------------------------------------
            FULL <= 1'b0;                       // default: de-assert

            if (WRITE) begin
                RAM[wr_addr] <= Di;            // store incoming sample
                // $display("[RAM] DEBUG: @%0t WRITE=1, wr_addr=%0d, Di=0x%04h", $time, wr_addr, Di);

                if (wr_addr == DEPTH-1) begin   // last location just written
                    FULL    <= 1'b1;            // one-cycle flag
                    wr_addr <= 0;               // wrap for next frame
                end else begin
                    wr_addr <= wr_addr + 1'b1;  // advance pointer
                end
            end

            // ---------- read side --------------------------------------
            if (READ)
                Do <= RAM[A];
            else
                Do <= 16'h0000;
        end
    end
endmodule
