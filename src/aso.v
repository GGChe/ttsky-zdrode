module aso (
    input  wire        clk,
    input  wire        rst,
    input  wire [15:0] data_in,
    input  wire [15:0] threshold_in,
    output reg         spike_detected
);

    // ------------------------------------------------------------------------
    // 1.  State encoding
    // ------------------------------------------------------------------------
    localparam TRAINING  = 1'b0;
    localparam OPERATION = 1'b1;

    reg state;

    // ------------------------------------------------------------------------
    // 2.  Constants (match ado)
    // ------------------------------------------------------------------------
    localparam integer SAMPLE_RATE_HZ     = 2000;
    localparam integer REFRACTORY_SAMPLES = SAMPLE_RATE_HZ / 4;  // 500 samples

    // ------------------------------------------------------------------------
    // 3.  Internal registers
    // ------------------------------------------------------------------------
    reg  signed [15:0] x1, x2, x3, x4;
    reg  signed [15:0] aso;
    reg  signed [15:0] threshold;

    // Refractory-period machinery
    reg        in_refractory    = 1'b0;
    reg [31:0] refractory_cnt   = 32'd0;   // Wide enough for long windows

    // ------------------------------------------------------------------------
    // 4.  Absolute value helper
    // ------------------------------------------------------------------------
    function signed [15:0] abs_val;
        input signed [15:0] val;
        begin
            abs_val = (val < 0) ? -val : val;
        end
    endfunction

    // ------------------------------------------------------------------------
    // 5.  Sequential logic
    // ------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // Sample shift regs
            x1 <= 16'sd0;
            x2 <= 16'sd0;
            x3 <= 16'sd0;
            x4 <= 16'sd0;

            // Core values
            aso        <= 16'sd0;
            threshold  <= 16'sd500;

            // FSM
            state <= TRAINING;

            // Output
            spike_detected <= 1'b0;

            // Refractory block
            in_refractory  <= 1'b0;
            refractory_cnt <= 32'd0;
        end
        else begin
            // -------------------------------------------------------------
            // Shift input samples each clock
            // -------------------------------------------------------------
            x1 <= x2;
            x2 <= x3;
            x3 <= x4;
            x4 <= $signed(data_in);

            // Default output each cycle
            spike_detected <= 1'b0;

            // -------------------------------------------------------------
            // Refractory countdown
            // -------------------------------------------------------------
            if (in_refractory) begin
                if (refractory_cnt >= REFRACTORY_SAMPLES) begin
                    in_refractory  <= 1'b0;
                    refractory_cnt <= 32'd0;
                end
                else begin
                    refractory_cnt <= refractory_cnt + 1;
                end
            end

            // -------------------------------------------------------------
            // Finite-state machine
            // -------------------------------------------------------------
            case (state)
                TRAINING: begin
                    threshold <= 16'sd500;   // Whatever you need while training
                    state     <= OPERATION;
                end

                OPERATION: begin
                    threshold <= $signed(threshold_in);
                    aso       <= abs_val(x4 - x1);

                    // Fire only when out of refractory
                    if ((aso > threshold) && !in_refractory) begin
                        spike_detected <= 1'b1;
                        in_refractory  <= 1'b0;  // Raise spike this cycle
                        in_refractory  <= 1'b1;  // and immediately enter refractory
                        refractory_cnt <= 32'd0;
                    end
                end
            endcase
        end
    end

endmodule
