/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
module processing_unit (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] data_in,
    input  wire [15:0] threshold_in,
    input  wire [7:0]  class_a_thresh_in,
    input  wire [7:0]  class_b_thresh_in,
    input  wire [15:0] timeout_period_in,
    output wire        spike_detection,
    output wire [1:0]  event_out
);
    wire spike_detected_internal;

    aso spike_detector_instance (
        .clk(clk),
        .rst(rst),
        .data_in(data_in),
        .threshold_in(threshold_in),
        .spike_detected(spike_detected_internal)
    );

    classifier classifier_instance (
        .clk(clk),
        .reset(rst),
        .current_detection(spike_detected_internal),
        .event_out(event_out),
        .class_a_thresh_in(class_a_thresh_in),
        .class_b_thresh_in(class_b_thresh_in),
        .timeout_period_in(timeout_period_in)
    );

    assign spike_detection = spike_detected_internal;

endmodule
