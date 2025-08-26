`timescale 10ns/10ns
`default_nettype none

module tb_tt_module;

    // ------------------------------------------------------------
    // Parameters (2-channel test)
    // ------------------------------------------------------------
    parameter integer NUM_UNITS      = 2;
    parameter integer DATA_WIDTH     = 16;
    parameter integer PROCESS_CYCLES = 2;

    // ------------------------------------------------------------
    // DUT I/Os
    //   ui_in : [1:0]=unit select, [2]=byte_valid (MSB then LSB)
    //   uo_out: [0]=spike, [2:1]=event for selected unit
    // ------------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg        ena;

    reg  [7:0] ui_in;
    reg  [7:0] uio_in;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

`ifdef GL_TEST
    // Power rails for gate-level sims (Sky130 stdcells typically use VPWR/VGND).
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
`endif

    // ------------------------------------------------------------
    // DUT
    //   RTL: no power pins; GL: connect VPWR/VGND if present.
    //   If your GL netlist uses other names (e.g., vccd1/vssd1),
    //   change the two connections below accordingly.
    // ------------------------------------------------------------
    tt_um_top_layer #(
        .NUM_UNITS  (NUM_UNITS),
        .DATA_WIDTH (DATA_WIDTH)
    ) dut (
`ifdef GL_TEST
        .VPWR   (VPWR),   // adjust names if your GL netlist differs
        .VGND   (VGND),
`endif
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    // ------------------------------------------------------------
    // Wave dump
    // ------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
    end

    // ------------------------------------------------------------
    // Statistics
    // ------------------------------------------------------------
    integer spike_total;
    integer spike_per_unit [0:NUM_UNITS-1];
    integer event_histogram[0:3];

    // ------------------------------------------------------------
    // CSV stimulus state
    // ------------------------------------------------------------
    integer data_file, code;
    integer row, i, ch;
    reg [DATA_WIDTH-1:0] sample [0:NUM_UNITS-1];

    // ------------------------------------------------------------
    // Helpers (match the top’s 2-byte assembler: MSB then LSB)
    // ------------------------------------------------------------
    // Pulse byte_valid (ui_in[2]) for exactly one clk while driving uio_in.
    task automatic send_byte(input [7:0] b);
        begin
            @(posedge clk);
            uio_in   <= b;
            ui_in[2] <= 1'b1;   // byte_valid = 1
            @(posedge clk);
            ui_in[2] <= 1'b0;   // byte_valid = 0
        end
    endtask

    // Hold the unit selector on ui_in[1:0] throughout the transaction.
    task automatic set_selector(input [1:0] sel);
        begin
            ui_in[1:0] <= sel;
        end
    endtask

    // ------------------------------------------------------------
    // Clock / Reset
    // ------------------------------------------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;   // 100 MHz

    // ------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------
    initial begin
        // Pins
        ena    = 1'b1;
        ui_in  = 8'h00;
        uio_in = 8'h00;

        // Stats
        spike_total = 0;
        for (i = 0; i < NUM_UNITS; i = i + 1) spike_per_unit[i] = 0;
        for (i = 0; i < 4;         i = i + 1) event_histogram[i] = 0;

        // Reset
        rst_n = 0; repeat (8) @(posedge clk);
        rst_n = 1; repeat (8) @(posedge clk);

        // Open CSV (2 columns expected for this test)
        data_file = $fopen("input_data_2ch.csv", "r");
        if (data_file == 0) data_file = $fopen("test/input_data_2ch.csv", "r");
        if (data_file == 0) begin
            $display("FATAL: cannot open input_data_2ch.csv nor test/input_data_2ch.csv");
            $finish;
        end

        // Main loop
        row = 0;
        while (!$feof(data_file)) begin
            code = $fscanf(data_file, "%d,%d", sample[0], sample[1]);

            if (code == NUM_UNITS) begin
                // Per-channel transaction:
                //  1) hold selector
                //  2) send MSB then LSB (ui_in[2] pulsed per byte)
                //  3) wait PROCESS_CYCLES + 1
                //  4) sample outputs once for this channel
                for (ch = 0; ch < NUM_UNITS; ch = ch + 1) begin
                    set_selector(ch[1:0]);
                    send_byte(sample[ch][15:8]);    // MSB
                    send_byte(sample[ch][7:0]);     // LSB
                    repeat (PROCESS_CYCLES) @(posedge clk);
                    @(posedge clk);                 // settle

                    if (uo_out[0] === 1'b1) begin
                        spike_total        = spike_total + 1;
                        spike_per_unit[ch] = spike_per_unit[ch] + 1;
                    end
                    if (uo_out[2:1] !== 2'bxx && uo_out[2:1] !== 2'bzz)
                        event_histogram[uo_out[2:1]] =
                            event_histogram[uo_out[2:1]] + 1;
                end
            end
            else if (code == -1) begin
                // EOF mid-format; exit via !$feof
            end
            else begin
                // Malformed line: consume remainder and continue
                reg [8*128-1:0] dummy;
                $display("WARNING: malformed CSV line %0d (matched %0d fields)", row, code);
                void'($fgets(dummy, data_file));
            end

            row = row + 1;
        end

        $fclose(data_file);

        // Summary
        $display("\n==== SPIKE SUMMARY ====");
        for (i = 0; i < NUM_UNITS; i = i + 1)
            $display("unit %0d : %0d spikes", i, spike_per_unit[i]);
        $display("total    : %0d", spike_total);
        $display("events   : 00=%0d  01=%0d  10=%0d  11=%0d",
                 event_histogram[0], event_histogram[1],
                 event_histogram[2], event_histogram[3]);
        $display("rows processed: %0d", row);
        $finish;
    end

endmodule
