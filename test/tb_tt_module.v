`timescale 10ns/10ns
`default_nettype none

module tb_tt_module;

    // ------------------------------------------------------------------
    // DUT interface (passive: cocotb will drive these)
    // ------------------------------------------------------------------
    reg        clk    = 1'b0;
    reg        rst_n  = 1'b0;
    reg        ena    = 1'b0;

    reg  [7:0] ui_in  = 8'h00;   // [1:0] selector, [2] byte_valid
    reg  [7:0] uio_in = 8'h00;   // data byte stream (MSB first)

    wire [7:0] uo_out;           // [0]=spike, [2:1]=event (selected unit)
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ------------------------------------------------------------------
    // Optional power pins for GL sims (kept inert if GL_TEST is not set)
    // If your GL netlist uses different names (e.g., vccd1/vssd1),
    // rename the two connections below to match.
    // ------------------------------------------------------------------
`ifdef GL_TEST
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
`endif

    // ------------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------------
    tt_um_top_layer #(
        .NUM_UNITS  (2),     // keep in sync with your Python test
        .DATA_WIDTH (16)
    ) dut (
`ifdef GL_TEST
        .VPWR   (VPWR),      // adjust if your GL netlist uses vccd1/vssd1
        .VGND   (VGND),
`endif
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );

    // ------------------------------------------------------------------
    // Waves (no $finish here — cocotb owns the simulation lifetime)
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
    end

    // No clock generator here (cocotb starts the clock)
    // No stimulus here (cocotb drives everything)
    // No $finish here (cocotb decides when to end)

endmodule
