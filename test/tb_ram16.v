`timescale 1ns/1ns
`default_nettype none

module tb_RAM16;

    // Configuration
    localparam ADDR_WIDTH    = 3;
    localparam DEPTH         = 1 << ADDR_WIDTH;
    localparam TOTAL_WRITES  = 32;

    // Testbench signals
    reg  clk, rst, read, write;
    reg  [ADDR_WIDTH-1:0] addr;
    reg  [15:0]            din;
    wire [15:0]            dout;
    wire full;

    // DUT
    RAM16 #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .CLK   (clk),
        .RST   (rst),
        .READ  (read),
        .WRITE (write),
        .FULL  (full),
        .A     (addr),
        .Di    (din),
        .Do    (dout)
    );

    // Clock: 100 MHz  (period 10 ns)
    initial clk = 0;
    always  #5 clk = ~clk;

    // Reference shadow memory
    reg [15:0] shadow [0:DEPTH-1];

    // RAM dump helper
    task dump_ram;
        integer k;
        begin
            $display("── RAM dump ──");
            for (k = 0; k < DEPTH; k = k + 1)
                $display("  [%0d] = %h (expected %h)", k,
                         dut.RAM[k], shadow[k]);
            $display("────────────────");
        end
    endtask

    //  FULL-flag edge detector + counter
    reg full_prev;
    integer full_edge_cnt;
    initial begin
        full_prev      = 0;
        full_edge_cnt  = 0;
    end

    always @(posedge clk) begin
        if (!rst) begin
            if (full && !full_prev) begin
                full_edge_cnt = full_edge_cnt + 1;
            end
            full_prev <= full;
        end
    end

    // Test sequence
    integer i; reg [15:0] exp;
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_RAM16);

        // ---------- Reset ------------------------------------------------
        rst = 1; read = 0; write = 0; addr = 0; din = 0;
        for (i = 0; i < DEPTH; i = i + 1)
            shadow[i] = 16'h0000;
        #20;
        rst = 0;

        // ---------- Write + verify --------------------------------------
        for (i = 0; i < TOTAL_WRITES; i = i + 1) begin
            addr = i % DEPTH;
            din  = 16'hB000 + i;

            write = 1; #10; write = 0; #10;

            shadow[addr] = din;

            read = 1; #10; read = 0;
            exp = shadow[addr];

            $display("WRITE[%0d] → READ[%0d] = %h (expected %h)",
                     i, addr, dout, exp);

            if (dout !== exp)
                $error("❌ mismatch @addr %0d: got %h exp %h",
                       addr, dout, exp);

            #10;
        end

        // ---------- FULL-pulse count assertion --------------------------
        // Expect one pulse every DEPTH writes
        if (full_edge_cnt == (TOTAL_WRITES + DEPTH - 1) / DEPTH)
            $display("✔ FULL pulsed %0d times as expected.",
                     full_edge_cnt);
        else
            $error("❌ FULL pulse count wrong: got %0d, expected %0d",
                   full_edge_cnt,
                   (TOTAL_WRITES + DEPTH - 1) / DEPTH);

        dump_ram();
        $display("✅ Extended test complete.");
        #20 $finish;
    end
endmodule
