/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
 module input_deserializer (
    input  wire       clk,
    input  wire       rst,
    input  wire       valid,
    input  wire       byte_select,      // 0 = low byte, 1 = high byte
    input  wire [7:0] data_byte,        // 8-bit data input
    output reg  [15:0] word_out,        // Full 16-bit word
    output reg        word_valid        // Pulses high when a word is complete
);

    reg [7:0] low_byte;
    reg       low_byte_received;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            word_out          <= 16'd0;
            word_valid        <= 0;
            low_byte          <= 8'd0;
            low_byte_received <= 0;
        end else begin
            word_valid <= 0; // Default low

            if (valid) begin
                if (!byte_select) begin
                    low_byte <= data_byte;
                    low_byte_received <= 1;
                end else if (low_byte_received) begin
                    word_out <= {data_byte, low_byte};
                    word_valid <= 1;
                    low_byte_received <= 0;
                end
            end
        end
    end

endmodule
