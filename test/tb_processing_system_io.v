`timescale 1ns / 1ps
`default_nettype none

module processing_system_tb;

    // ------------------------------------------------------------------
    // Parameterisation
    // ------------------------------------------------------------------
    localparam int NUM_UNITS     = 4;
    localparam int DATA_WIDTH    = 16;
    localparam int CLK_PERIOD    = 10;           // ns
    localparam int TOTAL_SAMPLES = 16;

    // ------------------------------------------------------------------
    // DUT interface
    // ------------------------------------------------------------------
    reg  clk;
    reg  rst;
    reg  [DATA_WIDTH-1:0]   sample_in;
    reg  write_sample_in;
    wire [NUM_UNITS-1:0]    spike_detection_array;
    wire [2*NUM_UNITS-1:0]  event_out_array;

    processing_system #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk (clk),
        .rst (rst),
        .sample_in (sample_in),
        .write_sample_in (write_sample_in),
        .spike_detection_array(spike_detection_array),
        .event_out_array    (event_out_array)
    );

    // ------------------------------------------------------------------
    // Wave-form dumping for GTKWave
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");             // file expected by the Makefile
        $dumpvars(0, processing_system_tb);// depth-0 → dump every signal
        // Optional sanity message; comment out after first verification
        $display("*** dump block active: wave.vcd opened");
    end

    // ------------------------------------------------------------------
    // Clock generation
    // ------------------------------------------------------------------
    initial clk = 1'b0;
    always  #(CLK_PERIOD/2) clk = ~clk;

    // ------------------------------------------------------------------
    // Test stimulus
    // ------------------------------------------------------------------
    integer i;
    initial begin
        $display("==== Starting Testbench ====");
        rst            = 1'b1;
        sample_in      = '0;
        write_sample_in= 1'b0;
        #(CLK_PERIOD);

        rst = 1'b0;
        #(CLK_PERIOD);

        // Feed TOTAL_SAMPLES incrementing values to the DUT
        for (i = 0; i < TOTAL_SAMPLES; i = i + 1) begin
            @(negedge clk);
            sample_in       = i[DATA_WIDTH-1:0];
            write_sample_in = 1'b1;
            @(negedge clk);
            write_sample_in = 1'b0;
            #(CLK_PERIOD);
        end

        // Display final DUT outputs
        @(posedge clk);
        $display("==== sample_valid_debug asserted ====");
        $display("Spike Detection Array = %b", spike_detection_array);
        $display("Event Output Array    = %b", event_out_array);

        #(10*CLK_PERIOD);
        $display("==== Simulation End ====");
        $finish;
    end

endmodule
