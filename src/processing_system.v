/*
 * Copyright (c) 2024 Gabriel Galeote-Checa
 * SPDX-License-Identifier: Apache-2.0
 */
 module processing_system #(
        parameter integer NUM_UNITS  = 2,
        parameter integer DATA_WIDTH = 16
    )(
        input  wire                     clk,
        input  wire                     rst,

        input  wire [DATA_WIDTH-1:0]    sample_in,        
        input  wire                     write_sample_in,  
        output wire [NUM_UNITS-1:0]     spike_detection_array,
        output wire [2*NUM_UNITS-1:0]   event_out_array,
        output wire                     sample_valid   
    );

    localparam integer RAM_ADDR_W = $clog2(NUM_UNITS);

    wire ram_full_pulse;                
    wire [DATA_WIDTH-1:0] ram_dout;

    RAM16 #(.ADDR_WIDTH(RAM_ADDR_W)) u_ram16 (
        .CLK  (clk),
        .RST  (rst),
        .READ (read_en),
        .WRITE(write_sample_in),
        .FULL (ram_full_pulse),
        .A    (rd_addr),
        .Di   (sample_in),
        .Do   (ram_dout)
    );

    // ------------------------------------------------------------
    // 2. Read-out FSM
    // ------------------------------------------------------------
    reg                       read_en = 1'b0;
    reg [RAM_ADDR_W-1:0]      rd_addr = 0;
    reg [DATA_WIDTH-1:0]      proc_word_buf [0:NUM_UNITS-1];
    reg [31:0]                read_count;
    reg                       sample_valid_int = 1'b0;   

    assign sample_valid = sample_valid_int;

    always @(posedge clk) begin
        if (rst) begin
            read_en        <= 0;
            rd_addr        <= 0;
            read_count     <= 0;
            sample_valid_int <= 0;
        end else begin
            sample_valid_int <= 0;

            if (ram_full_pulse && !read_en) begin
                read_en        <= 1;
                rd_addr        <= 0;
                read_count     <= 0;
            end else if (read_en) begin

                if (read_count <= NUM_UNITS) begin
                    proc_word_buf[read_count - 1] <= ram_dout;
                end

                rd_addr    <= rd_addr + 1;
                read_count <= read_count + 1;

                if (read_count == NUM_UNITS) begin
                    read_en <= 0;
                    sample_valid_int <= 1;
                end
            end
        end
    end

    wire [NUM_UNITS-1:0]   spike_det_int;
    wire [2*NUM_UNITS-1:0] event_out_int;

    genvar gi;
    for (gi = 0; gi < NUM_UNITS; gi = gi + 1) begin : G_PU

        processing_unit u_proc (
            .clk                (clk),
            .rst                (rst),
            .data_in            (proc_word_buf[gi]),
            .threshold_in       (16'd200),
            .class_a_thresh_in  (8'd10),
            .class_b_thresh_in  (8'd3),
            .timeout_period_in  (16'd1000),
            .spike_detection    (spike_det_int[gi]),
            .event_out          (event_out_int[2*gi +: 2])
        );

    end

    assign spike_detection_array = spike_det_int;
    assign event_out_array       = event_out_int;

endmodule
