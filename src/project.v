/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */

module tt_um_top_layer (
    input  wire [7:0] ui_in,    // Dedicated inputs 
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: input path
    output wire [7:0] uio_out,  // Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // Always 1,this is to enable the project 
    input  wire       clk,      // Clock
    input  wire       rst_n     // Reset of the project (active-low)
);

    // Parameters
    parameter integer NUM_UNITS  = 2;
    parameter integer DATA_WIDTH = 16;

    // Reset / control
    wire rst = ~rst_n;

    // Channel select input from ui_in[1:0] (only 2 bits are available on UI)
    wire [1:0] selected_unit = ui_in[1:0];

    // Mark unused UI bits as used to avoid lint warnings (exclude bit[2] byte_valid)
    wire _unused_ui = &{ ui_in[7:3] };

    // Byte-valid strobe on ui_in[2]
    wire byte_valid = ui_in[2];

    // 2-byte sample assembler (MSB then LSB), synchronous to clk
    reg [DATA_WIDTH-1:0] sample_sr   = {DATA_WIDTH{1'b0}};
    reg                  byte_idx    = 1'b0;   // toggles 0 → 1 → 0
    reg                  sample_wr_en= 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            byte_idx     <= 1'b0;
            sample_sr    <= {DATA_WIDTH{1'b0}};
            sample_wr_en <= 1'b0;
        end
        else begin
            sample_wr_en <= 1'b0;

            if (byte_valid) begin
                if (byte_idx == 1'b0) begin
                    // First byte → MSB
                    sample_sr[15:8] <= uio_in;
                    byte_idx        <= 1'b1;
                end
                else begin
                    // Second byte → LSB
                    sample_sr[7:0]  <= uio_in;
                    byte_idx        <= 1'b0;
                    sample_wr_en    <= 1'b1;  // complete 16-bit sample
                end
            end
        end
    end

    // ------------------------------------------------------------------------
    // Processing system instance (flat buses only)
    // ------------------------------------------------------------------------
    wire                     sample_valid_unused;           // unused output
    wire [NUM_UNITS-1:0]     spike_bus;                     // 1 bit per unit
    wire [2*NUM_UNITS-1:0]   event_bus;                     // 2 bits per unit

    processing_system #(
        .NUM_UNITS  (NUM_UNITS),
        .DATA_WIDTH (DATA_WIDTH)
    ) u_processing (
        .clk                   (clk),
        .rst                   (rst),
        .sample_in             (sample_sr),
        .write_sample_in       (sample_wr_en),
        .spike_detection_array (spike_bus),
        .event_out_array       (event_bus),
        .sample_valid          (sample_valid_unused)
    );

    // Output mux: select event/spike data from the selected unit

    assign uo_out = {
        5'b00000,
        event_bus[2*selected_unit +: 2],
        spike_bus[selected_unit]
    };

    // ------------------------------------------------------------------------
    // Unused IOs
    // ------------------------------------------------------------------------
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;
    wire _unused_ena = &{ ena };

endmodule
