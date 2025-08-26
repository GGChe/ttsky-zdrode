/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
 module ado (
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

    // Constants
    localparam integer SAMPLE_RATE_HZ     = 2000;
    localparam integer REFRACTORY_SAMPLES = SAMPLE_RATE_HZ / 8;   
    reg signed [15:0] x1, x2, x3, x4;
    reg signed [15:0] ado;
    reg signed [15:0] threshold;

    // Refractory logic
    reg [31:0] refractory_counter = 0;
    reg in_refractory = 0;

    // Absolute value (2's complement)
    function signed [15:0] abs_val;
        input signed [15:0] val;
        begin
            abs_val = (val < 0) ? -val : val;
        end
    endfunction

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            x1 <= 16'sd0;
            x2 <= 16'sd0;
            x3 <= 16'sd0;
            x4 <= 16'sd0;
            ado <= 16'sd0;
            threshold <= 16'sd500;
            state <= TRAINING;
            spike_detected <= 1'b0;
            refractory_counter <= 0;
            in_refractory <= 0;
        end else begin
            // Shift input samples
            x1 <= x2;
            x2 <= x3;
            x3 <= x4;
            x4 <= $signed(data_in);

            spike_detected <= 1'b0;

            // Refractory logic
            if (in_refractory) begin
                if (refractory_counter >= REFRACTORY_SAMPLES) begin
                    in_refractory <= 0;
                    refractory_counter <= 0;
                end else begin
                    refractory_counter <= refractory_counter + 1;
                end
            end

            // FSM
            case (state)
                TRAINING: begin
                    threshold <= 16'sd500;
                    state <= OPERATION;
                end

                OPERATION: begin
                    threshold <= $signed(threshold_in);
                    ado <= abs_val(x4 - x1);

                    if ((ado > threshold) && !in_refractory) begin
                        spike_detected <= 1'b1;
                        in_refractory <= 1;
                        refractory_counter <= 0;
                    end
                end
            endcase
        end
    end

endmodule
