`timescale 1ns/1ns
`default_nettype none

module tb_processing_system_file;

    // ---------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------
    localparam integer NUM_UNITS  = 2;
    localparam integer DATA_WIDTH = 16;
    localparam integer CLK_PERIOD = 10;   // 100 MHz

    // DUT Signals
    reg  clk = 0;
    reg  rst = 1;
    reg  [DATA_WIDTH-1:0] sample_in = 0;
    reg  write_sample_in = 0;
    wire [NUM_UNITS-1:0]    spike_detection_array;
    wire [2*NUM_UNITS-1:0]  event_out_array;  // 2 bits per unit packed

    // Instantiate the DUT
    processing_system #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .sample_in(sample_in),
        .write_sample_in(write_sample_in),
        .spike_detection_array(spike_detection_array),
        .event_out_array(event_out_array)
    );

    // Clock generation
    always #(CLK_PERIOD/2) clk = ~clk;

    // File I/O
    integer data_file;
    integer ev_file;
    integer code;
    integer sample_count = 0;
    integer max_rows     = 250000;  // limit on CSV rows (each row = 2 samples)
    integer ch;

    // Per-row channel samples
    reg [DATA_WIDTH-1:0] sample [0:NUM_UNITS-1];

    initial begin
        // Open 2-channel CSV: two integers per line
        data_file = $fopen("test/input_data_2ch.csv", "r");
        if (data_file == 0) begin
            $display("ERROR: cannot open input_data_2ch.csv."); 
            $finish;
        end
        // Optional event log
        ev_file = $fopen("output/event_out_log.txt", "w");
        if (ev_file == 0) begin
            $display("ERROR: cannot open output/event_out_log.txt."); 
            $finish;
        end
    end

    // Stimulus
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_processing_system_file);
        $dumpvars(1, dut);

        // Reset
        #(10*CLK_PERIOD);
        rst = 0;
        $display("*** Feeding 2-channel samples from input_data_2ch.csv ***");

        // Each CSV row provides two channel samples
        while ((!$feof(data_file)) && (sample_count < max_rows)) begin
            // Read exactly two integers per line
            code = $fscanf(data_file, "%d,%d\n", sample[0], sample[1]);
            if (code == NUM_UNITS) begin
                // Write both channels once per row (one write per channel)
                for (ch = 0; ch < NUM_UNITS; ch = ch + 1) begin
                    @(posedge clk);
                    sample_in       <= sample[ch][15:0];
                    write_sample_in <= 1'b1;
                    @(posedge clk);
                    write_sample_in <= 1'b0;
                end

                sample_count = sample_count + 1;

                // Allow DUT to process before logging (adjust if your DUT needs more latency)
                @(posedge clk);

                // Log spike/event vectors (packed) per input row
                $fwrite(ev_file,
                        "row=%0d spike=%b event=%b\n",
                        sample_count, spike_detection_array, event_out_array);

                // Optional console trace
                // $display("Row %0d : ch0=%0d ch1=%0d -> spike=%b event=%b",
                //          sample_count, sample[0], sample[1],
                //          spike_detection_array, event_out_array);
            end
            else begin
                $display("WARNING: malformed CSV line at row %0d (code=%0d)",
                         sample_count+1, code);
            end
        end

        $display("*** Finished after %0d rows ***", sample_count);
        #(10*CLK_PERIOD);
        $fclose(data_file);
        $fclose(ev_file);
        $finish;
    end

endmodule
