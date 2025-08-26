`timescale 1ns / 1ps

module tb_processing_system;

  parameter integer NUM_UNITS = 4;
  reg         clk;
  reg         rst;
  reg  [7:0]  serial_data_in;
  wire [3:0]  spike_detection_array; 
  wire [7:0]  event_out_array;

  reg  [7:0]  class_a_thresh_in;
  reg  [7:0]  class_b_thresh_in;
  reg  [15:0] timeout_period_in;

  processing_system #(
    .NUM_UNITS(NUM_UNITS)
  ) uut (
    .clk                  (clk),
    .rst                  (rst),
    .serial_data_in       (serial_data_in),
    .class_a_thresh_in    (class_a_thresh_in),
    .class_b_thresh_in    (class_b_thresh_in),
    .timeout_period_in    (timeout_period_in),
    .spike_detection_array(spike_detection_array),
    .event_out_array      (event_out_array)
  );

  initial clk = 0;
  always #5 clk = ~clk;

  integer i;
  reg [7:0] test_data [0:7];

  initial begin
    $dumpfile("wave.vcd");
    $dumpvars(0, tb_processing_system);

    for (i = 0; i < 8; i = i + 1) begin
      test_data[i] = i * 8'h11;
    end

    class_a_thresh_in  = 8'd20;
    class_b_thresh_in  = 8'd40;
    timeout_period_in  = 16'd100;

    rst = 1'b1;
    serial_data_in = 8'b0;

    rst = 1'b0;

    $display("Feeding one 64-bit frame to processing_system:");
    for (i = 0; i < 8; i = i + 1) begin
      @(posedge clk);
      serial_data_in = test_data[i];
      $display("  Sending byte[%0d] = 0x%02h", i, test_data[i]);
    end

    @(posedge clk);
    serial_data_in = 8'h00;
    $display("Finished sending 64 bits. Waiting for system to process...");

    repeat (10) @(posedge clk);
    $display("\nFinal Outputs:");
    $display("  spike_detection_array = %b", spike_detection_array);
    $display("  event_out_array       = %b", event_out_array);
    $display("\nSimulation complete.\n");
    $finish;
  end

endmodule
