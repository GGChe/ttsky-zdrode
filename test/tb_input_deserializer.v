`timescale 1ns/1ps

module tb_input_deserializer;

    reg clk = 0;
    always #5 clk = ~clk;

    reg rst;
    reg valid;
    reg byte_select;
    reg [7:0] data_byte;

    wire [15:0] word_out;
    wire        word_valid;

    reg [15:0] expected_value_0 = 16'h04BF; // 1215
    reg [15:0] expected_value_1 = 16'hABCD; // 43981
    reg [15:0] received_value_0;
    reg [15:0] received_value_1;

    integer received_count;
    integer timeout;
    reg pass;

    // DUT instantiation
    input_deserializer dut (
        .clk(clk),
        .rst(rst),
        .valid(valid),
        .byte_select(byte_select),
        .data_byte(data_byte),
        .word_out(word_out),
        .word_valid(word_valid)
    );

    // Task to send a 16-bit sample
    task send_sample(input [15:0] val);
        begin
            @(posedge clk);
            byte_select = 0;
            data_byte = val[7:0];
            valid = 1;
            @(posedge clk);
            valid = 0;

            @(posedge clk);
            byte_select = 1;
            data_byte = val[15:8];
            valid = 1;
            @(posedge clk);
            valid = 0;
        end
    endtask

    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_input_deserializer);

        $display("=== Begin Deserializer Test ===");

        // Init
        rst = 1;
        valid = 0;
        byte_select = 0;
        data_byte = 0;
        pass = 1;
        received_count = 0;
        timeout = 0;

        @(posedge clk);
        rst = 0;

        // Send samples
        send_sample(expected_value_0);
        send_sample(expected_value_1);

        // Wait for output (with timeout)
        while (received_count < 2 && timeout < 100) begin
            @(posedge clk);
            timeout = timeout + 1;
            if (word_valid) begin
                if (received_count == 0) begin
                    received_value_0 = word_out;
                    $display("Received word 0: 0x%04X", word_out);
                end else if (received_count == 1) begin
                    received_value_1 = word_out;
                    $display("Received word 1: 0x%04X", word_out);
                end
                received_count = received_count + 1;
            end
        end

        if (timeout >= 100) begin
            $display("⏰ Timeout! Did not receive expected number of outputs.");
            pass = 0;
        end

        // Check results
        if (received_value_0 !== expected_value_0) begin
            $display("❌ Word 0 mismatch: got 0x%04X, expected 0x%04X", received_value_0, expected_value_0);
            pass = 0;
        end
        if (received_value_1 !== expected_value_1) begin
            $display("❌ Word 1 mismatch: got 0x%04X, expected 0x%04X", received_value_1, expected_value_1);
            pass = 0;
        end

        if (pass) begin
            $display("🎉✅ Test PASSED!");
        end else begin
            $display("💥❌ Test FAILED!");
        end

        $finish;
    end

endmodule
