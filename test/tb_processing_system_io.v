`timescale 1ns / 1ps
`default_nettype none

module processing_system_tb;

    // Parameters
    localparam NUM_UNITS  = 4;
    localparam DATA_WIDTH = 16;
    localparam CLK_PERIOD = 10;
    localparam TOTAL_SAMPLES = 16;
    // DUT Signals
    reg clk;
    reg rst;
    reg [DATA_WIDTH-1:0] sample_in;
    reg write_sample_in;
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
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // Declare integer i for use in initial block
    integer i;

    // Stimulus
    initial begin
        $display("==== Starting Testbench ====");
        rst = 1;
        sample_in = 0;
        write_sample_in = 0;
        #(CLK_PERIOD);
        
        rst = 0;
        #(CLK_PERIOD);

        // Feed NUM_UNITS samples with incrementing sample_in
        for (i = 0; i < TOTAL_SAMPLES; i = i + 1) begin
            @(negedge clk);
            sample_in = i; // Incrementing sample data
            write_sample_in = 1;
            @(negedge clk);
            write_sample_in = 0;
            #(CLK_PERIOD);
        end

        @(posedge clk);
        $display("==== sample_valid_debug asserted ====");
        $display("Spike Detection Array = %b", spike_detection_array);
        $display("Event Output Array    = %b", event_out_array);

        #(10*CLK_PERIOD);
        $display("==== Simulation End ====");
        $finish;
    end

endmodule
