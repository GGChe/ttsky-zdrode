`timescale 10ns/10ns
`default_nettype none

module tb_tt_module;

    // ------------------------------------------------------------------
    // Parameters (testbench-local)
    // ------------------------------------------------------------------
    parameter integer NUM_UNITS      = 2;    // 2-channel test by default
    parameter integer DATA_WIDTH     = 16;
    parameter integer PROCESS_CYCLES = 2;

    // ------------------------------------------------------------------
    // Power nets for GL when USE_POWER_PINS is enabled
    // ------------------------------------------------------------------
`ifdef USE_POWER_PINS
    // Provide constant rails for the gate-level netlist
    supply1 VPWR;   // vccd1
    supply0 VGND;   // vssd1
`endif

    // ------------------------------------------------------------------
    // DUT I/Os (driven either by cocotb or the TB below)
    // ------------------------------------------------------------------
    reg        clk;
    reg        rst_n;
    reg        ena;

    reg  [7:0] ui_in;     // [1:0]=unit select, [2]=byte_valid
    reg  [7:0] uio_in;    // sample byte stream (MSB first)
    wire [7:0] uo_out;    // [0]=spike, [2:1]=event (selected unit)
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ------------------------------------------------------------------
    // DUT instantiation
    //  - RTL: keep parameters
    //  - GL : NO parameters; optionally connect power pins
    // ------------------------------------------------------------------
`ifdef GL_TEST
    // -------- Gate-level netlist (no parameters on the top) ----------
`ifdef USE_POWER_PINS
    tt_um_top_layer dut (
        .vccd1 (VPWR),
        .vssd1 (VGND),
        .clk    (clk),
        .rst_n  (rst_n),
        .ena    (ena),
        .ui_in  (ui_in),
        .uio_in (uio_in),
        .uo_out (uo_out),
        .uio_out(uio_out),
        .uio_oe (uio_oe)
    );
`else
    tt_um_top_layer dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .ena    (ena),
        .ui_in  (ui_in),
        .uio_in (uio_in),
        .uo_out (uo_out),
        .uio_out(uio_out),
        .uio_oe (uio_oe)
    );
`endif  // USE_POWER_PINS

`else
    // ------------------------- RTL (parameterized) --------------------
`ifdef USE_POWER_PINS
    tt_um_top_layer #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .vccd1 (VPWR),
        .vssd1 (VGND),
        .clk    (clk),
        .rst_n  (rst_n),
        .ena    (ena),
        .ui_in  (ui_in),
        .uio_in (uio_in),
        .uo_out (uo_out),
        .uio_out(uio_out),
        .uio_oe (uio_oe)
    );
`else
    tt_um_top_layer #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .ena    (ena),
        .ui_in  (ui_in),
        .uio_in (uio_in),
        .uo_out (uo_out),
        .uio_out(uio_out),
        .uio_oe (uio_oe)
    );
`endif  // USE_POWER_PINS
`endif  // GL_TEST

    // ------------------------------------------------------------------
    // Wave dump (always on)
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
    end

// ======================================================================
// ==========  COCOTB MODE (passive wrapper; Python drives)  ============
// ======================================================================
`ifdef COCOTB_SIM
    initial begin
        clk    = 1'b0;
        rst_n  = 1'b0;
        ena    = 1'b0;
        ui_in  = 8'h00;
        uio_in = 8'h00;
    end

// ======================================================================
// ==========  STANDALONE VERILOG TB (no cocotb)  =======================
// ======================================================================
`else

    // ---------------------- Stats & stimulus state ---------------------
    integer spike_total;
    integer spike_per_unit [0:NUM_UNITS-1];
    integer event_histogram[0:3];

    integer data_file, code;
    integer row, i, ch;
    reg [DATA_WIDTH-1:0] sample [0:NUM_UNITS-1];
    reg [8*128-1:0]      skip;   // to skip malformed line tails

    // ----------------------------- Helpers -----------------------------
    task automatic send_byte(input [7:0] b);
        begin
            @(posedge clk);
            uio_in   <= b;
            ui_in[2] <= 1'b1;
            @(posedge clk);
            ui_in[2] <= 1'b0;
        end
    endtask

    task automatic set_selector(input [1:0] sel);
        begin
            ui_in[1:0] <= sel;
        end
    endtask

    // ------------------------- Clock / Reset ---------------------------
    initial clk = 1'b0;
    always #5 clk = ~clk;                 // 100 MHz

    // --------------------------- Testbench -----------------------------
    initial begin
        // init pins
        ena    = 1'b1;
        ui_in  = 8'h00;
        uio_in = 8'h00;

        // init stats
        spike_total = 0;
        for (i = 0; i < NUM_UNITS; i = i + 1) spike_per_unit[i] = 0;
        for (i = 0; i < 4;         i = i + 1) event_histogram[i] = 0;

        // reset
        rst_n = 0; repeat (8) @(posedge clk);
        rst_n = 1; repeat (8) @(posedge clk);

        // open CSV (tries local then test/ fallback)
        if (NUM_UNITS == 2) begin
            data_file = $fopen("input_data_2ch.csv", "r");
            if (data_file == 0) data_file = $fopen("test/input_data_2ch.csv", "r");
        end else begin
            data_file = $fopen("input_data_4ch.csv", "r");
            if (data_file == 0) data_file = $fopen("test/input_data_4ch.csv", "r");
        end
        if (data_file == 0) begin
            $display("FATAL: cannot open CSV file");
            $finish;
        end

        // main loop
        row = 0;
        while (!$feof(data_file)) begin
            if (NUM_UNITS == 2)
                code = $fscanf(data_file, "%d,%d", sample[0], sample[1]);
            else if (NUM_UNITS == 4)
                code = $fscanf(data_file, "%d,%d,%d,%d",
                               sample[0], sample[1], sample[2], sample[3]);
            else
                code = $fscanf(data_file, "%d", sample[0]);

            if (code == NUM_UNITS) begin
                for (ch = 0; ch < NUM_UNITS; ch = ch + 1) begin
                    set_selector(ch[1:0]);
                    send_byte(sample[ch][15:8]);
                    send_byte(sample[ch][7:0]);
                    repeat (PROCESS_CYCLES) @(posedge clk);
                    @(posedge clk);  // settle

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
                // EOF mid-format
            end
            else begin
                $display("WARNING: malformed CSV line %0d (matched %0d fields)", row, code);
                void'($fgets(skip, data_file));
            end

            row = row + 1;
        end

        $fclose(data_file);

        // summary
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
`endif  // COCOTB_SIM

endmodule
