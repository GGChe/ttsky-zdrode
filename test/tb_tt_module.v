`timescale 10ns/10ns
`default_nettype none

module tb_tt_module;

    //------------------------------------------------------------------
    // Parameters
    //------------------------------------------------------------------
    parameter integer NUM_UNITS      = 4;
    parameter integer DATA_WIDTH     = 16;
    parameter integer PROCESS_CYCLES = 2;

    //------------------------------------------------------------------
    // Clock / Reset
    //------------------------------------------------------------------
    reg clk = 0;
    always #5 clk = ~clk;           // 100 MHz

    reg rst_n = 0;
    reg ena   = 1;

    //------------------------------------------------------------------
    // DUT I/Os
    //------------------------------------------------------------------
    reg  [7:0] ui_in  = 8'h00;
    reg  [7:0] uio_in = 8'h00;
    wire [7:0] uo_out;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    tt_um_top_layer dut (
        .clk   (clk),
        .rst_n (rst_n),
        .ena   (ena),
        .ui_in (ui_in),
        .uio_in(uio_in),
        .uo_out(uo_out),
        .uio_out(uio_out),
        .uio_oe(uio_oe)
    );

    //------------------------------------------------------------------
    // Wave dump
    //------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
        $dumpvars(1, dut);
    end

    //------------------------------------------------------------------
    // Statistics
    //------------------------------------------------------------------
    integer spike_total;
    integer spike_per_unit [0:NUM_UNITS-1];
    integer event_histogram[0:3];

    //------------------------------------------------------------------
    // Stimulus data
    //------------------------------------------------------------------
    integer data_file, code;
    integer row;
    integer i, ch;

    reg [DATA_WIDTH-1:0] sample [0:NUM_UNITS-1];
    reg [1:0]            ch_sel;

    //------------------------------------------------------------------
    // Test-bench
    //------------------------------------------------------------------
    initial begin
        // zero stats
        spike_total = 0;
        for (i = 0; i < NUM_UNITS; i = i + 1) spike_per_unit[i] = 0;
        for (i = 0; i < 4;         i = i + 1) event_histogram[i] = 0;

        // reset sequence
        rst_n = 0; repeat (5) @(posedge clk);
        rst_n = 1; repeat (5) @(posedge clk);

        // open CSV
        data_file = $fopen("input_data_4ch.csv", "r");
        // data_file = $fopen("test/input_data_4ch.csv", "r");
        if (data_file == 0) begin
            $display("FATAL: cannot open input_data_4ch.csv");
            $finish;
        end

        // main loop
        row = 0;
        while (!$feof(data_file)) begin
            code = $fscanf(data_file,"%d,%d,%d,%d\n",
                           sample[0], sample[1], sample[2], sample[3]);

            if (code == NUM_UNITS) begin
                //------------------------------------------------------
                // normal row: feed CH0..CH3 and capture spike/event
                //------------------------------------------------------
                for (ch = 0; ch < NUM_UNITS; ch = ch + 1) begin
                    // MSB
                    @(posedge clk);
                    uio_in = sample[ch][15:8];
                    ui_in  = 8'b0000_0100;          // byte_valid
                    @(posedge clk) ui_in = 0;

                    // LSB
                    @(posedge clk);
                    uio_in = sample[ch][7:0];
                    ui_in  = 8'b0000_0100;
                    @(posedge clk) ui_in = 0;

                    // pipeline latency
                    repeat (PROCESS_CYCLES) @(posedge clk);

                    // select same unit and sample outputs
                    ch_sel = ch[1:0];
                    ui_in  = {6'b0, ch_sel};
                    @(posedge clk);

                    if (uo_out[0]) begin
                        spike_total        = spike_total + 1;
                        spike_per_unit[ch] = spike_per_unit[ch] + 1;
                    end
                    event_histogram[uo_out[2:1]] =
                        event_histogram[uo_out[2:1]] + 1;
                end
            end
            else begin
                $display("WARNING: malformed CSV line %0d", row);
            end

            row = row + 1;          // always advance row counter
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
endmodule
