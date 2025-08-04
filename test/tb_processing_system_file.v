`timescale 1ns/1ns
`default_nettype none

module tb_processing_system_file;

    // ---------------------------------------------------------
    // Parameters
    // ---------------------------------------------------------
    localparam NUM_UNITS  = 4;
    localparam DATA_WIDTH = 16;
    localparam CLK_PERIOD = 10;

    // DUT Signals
    reg clk = 0;
    reg rst = 1;
    reg [DATA_WIDTH-1:0] sample_in = 0;
    reg write_sample_in = 0;
    wire [NUM_UNITS-1:0] spike_detection_array;
    wire [2*NUM_UNITS-1:0] event_out_array;

    // Instantiate the DUT
    processing_system #(
        .NUM_UNITS(NUM_UNITS),
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
    integer int_in;
    integer sample_count = 0;
    integer max_samples  = 250000;
    integer i;

    initial begin
        data_file = $fopen("test/20170420/20170420_slice01_01_CTRL1_0006_43_unsigned.txt", "r");
        if (data_file == 0) begin
            $display("ERROR: cannot open data file."); $finish;
        end
        ev_file = $fopen("output/event_out_log.txt", "w");
        if (ev_file == 0) begin
            $display("ERROR: cannot open event log."); $finish;
        end
    end

    // Stimulus
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_processing_system_file);

        #100;
        rst = 0;
        $display("*** Feeding samples ***");

        while ((!$feof(data_file)) && (sample_count < max_samples)) begin
            // Read one value from the file
            code = $fscanf(data_file, "%d\n", int_in);
            if (code > 0) begin
                sample_in = int_in[15:0];

                // Send this same sample 4 times to fill RAM
                for (i = 0; i < NUM_UNITS; i = i + 1) begin
                    @(posedge clk);
                    write_sample_in <= 1;
                    @(posedge clk);
                    write_sample_in <= 0;
                end

                sample_count = sample_count + 1;

                // Wait for read and output
                @(posedge clk);
                // $display("Sample %0d => Spike = %b, Event = %b",
                //     sample_count, spike_detection_array, event_out_array);
            end
        end

        $display("*** Finished after %0d samples ***", sample_count);
        #100;
        $fclose(data_file);
        $fclose(ev_file);
        $finish;
    end

endmodule
