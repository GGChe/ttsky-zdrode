/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
 module neo (
    input wire clk,
    input wire rst,
    input wire [15:0] data_in,
    input wire [15:0] threshold_in,
    output reg spike_detected
);

// State encoding
localparam TRAINING  = 1'b0;
localparam OPERATION = 1'b1;

reg state;

// Internal signals
reg signed [15:0] x1, x2, x3;
reg signed [15:0] neo;
reg signed [15:0] threshold;

reg signed [31:0] mult_x2_x2;
reg signed [31:0] mult_x3_x1;
reg signed [31:0] diff_result;

// Absolute value function
function signed [31:0] abs_val;
    input signed [31:0] val;
    begin
        abs_val = (val < 0) ? -val : val;
    end
endfunction

always @(posedge clk or posedge rst) begin
    if (rst) begin
        x1 <= 16'sd0;
        x2 <= 16'sd0;
        x3 <= 16'sd0;
        neo <= 16'sd0;
        threshold <= 16'sd10000;
        state <= TRAINING;
        spike_detected <= 1'b0;
    end else begin
        // Shift input samples
        x1 <= x2;
        x2 <= x3;
        x3 <= $signed(data_in);

        case (state)
            TRAINING: begin
                threshold <= 16'sd10000;
                state <= OPERATION;
            end

            OPERATION: begin
                threshold <= $signed(threshold_in);

                // Calculate NEO = |x2^2 - x3 * x1|
                mult_x2_x2 <= x2 * x2;
                mult_x3_x1 <= x3 * x1;
                diff_result <= abs_val(mult_x2_x2 - mult_x3_x1);

                // Resize diff_result to 16-bit neo (clipping if needed)
                neo <= diff_result[15:0];  // Simple truncation; saturation logic can be added

                // Spike detection
                spike_detected <= (neo > threshold) ? 1'b1 : 1'b0;
            end
        endcase
    end
end

endmodule
