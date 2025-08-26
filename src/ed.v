/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
module ed (
    input wire clk,
    input wire rst,
    input wire [15:0] data_in,
    input wire [15:0] threshold_in,
    output reg spike_detected
);

// Delay constant
localparam integer k = 2;

// State encoding
localparam TRAINING  = 1'b0;
localparam OPERATION = 1'b1;

reg state;

// Delay buffer for input samples
reg signed [15:0] input_buffer [0:k];

// Internal signals
reg signed [31:0] squared_diff;
reg signed [15:0] threshold;

integer i;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        for (i = 0; i <= k; i = i + 1)
            input_buffer[i] <= 16'sd0;

        squared_diff <= 32'sd0;
        threshold <= 16'sd10000;  // Default threshold
        state <= TRAINING;
        spike_detected <= 1'b0;
    end else begin
        // Shift register operation
        for (i = k; i > 0; i = i - 1)
            input_buffer[i] <= input_buffer[i - 1];

        input_buffer[0] <= $signed(data_in);

        case (state)
            TRAINING: begin
                threshold <= 16'sd10000;
                state <= OPERATION;
            end

            OPERATION: begin
                threshold <= $signed(threshold_in);

                // Compute squared difference
                squared_diff <= (input_buffer[0] - input_buffer[k]) * 
                                (input_buffer[0] - input_buffer[k]);

                // Compare against threshold (promoted to 32 bits)
                spike_detected <= (squared_diff > {{16{threshold[15]}}, threshold}) ? 1'b1 : 1'b0;
            end
        endcase
    end
end

endmodule
