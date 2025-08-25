`default_nettype none
`timescale 1ns/1ps

/* Simple wrapper around the processing_system so that external test-code
   (cocotb, VUnit, etc.) can drive its ports and observe the results.
*/
module ps_tb ();

    initial begin
        $dumpfile("ps_tb.vcd");
        $dumpvars(0, ps_tb);
        #1;
    end

    parameter int NUM_UNITS  = 2;
    parameter int DATA_WIDTH = 16;

    reg                     clk;
    reg                     rst;
    reg  [DATA_WIDTH-1:0]   sample_in;
    reg                     write_sample_in;

    wire [NUM_UNITS-1:0]    spike_detection_array;
    wire [2*NUM_UNITS-1:0]  event_out_array;

    processing_system #(
        .NUM_UNITS (NUM_UNITS),
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk                   (clk),
        .rst                   (rst),
        .sample_in             (sample_in),
        .write_sample_in       (write_sample_in),
        .spike_detection_array (spike_detection_array),
        .event_out_array       (event_out_array),
    );

endmodule
