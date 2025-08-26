`timescale 10ns/10ns
`default_nettype none

module tb_tt_module;

    // ------------------------------------------------------------------
    // Passive DUT interface (cocotb will drive these)
    // ------------------------------------------------------------------
    reg        clk    = 1'b0;
    reg        rst_n  = 1'b0;
    reg        ena    = 1'b0;

    reg  [7:0] ui_in  = 8'h00;   // [1:0]=selector, [2]=byte_valid
    reg  [7:0] uio_in = 8'h00;   // data byte stream (MSB first)

    wire [7:0] uo_out;           // [0]=spike, [2:1]=event (selected unit)
    wire [7:0] uio_out;
    wire [7:0] uio_oe;

    // ------------------------------------------------------------------
    // Optional power pins for GL sims
    // ------------------------------------------------------------------
`ifdef GL_TEST
    // Most TinyTapeout GL netlists use VPWR/VGND. If yours uses vccd1/vssd1,
    // rename the two connections below to match the GL netlist port names.
    wire VPWR = 1'b1;
    wire VGND = 1'b0;
`endif

    // ------------------------------------------------------------------
    // DUT instantiation
    //  - RTL: pass parameters (module in src/project.v has params)
    //  - GL : DO NOT pass parameters (netlist has no params), wire power pins
    // ------------------------------------------------------------------
`ifndef GL_TEST
    // ---------- RTL build (with parameters) ----------
    tt_um_top_layer #(
        .NUM_UNITS  (2),     // keep in sync with your Python test
        .DATA_WIDTH (16)
    ) dut (
        .ui_in  (ui_in),
        .uo_out (uo_out),
        .uio_in (uio_in),
        .uio_out(uio_out),
        .uio_oe (uio_oe),
        .ena    (ena),
        .clk    (clk),
        .rst_n  (rst_n)
    );
`else
    // ---------- Gate-level build (no parameters) ----------
    tt_um_top_layer dut (
        // Power pins first if your GL netlist has them
`ifdef USE_POWER_PINS
        .VPWR   (VPWR),   // change to .vccd1/.vssd1 if your netlist uses those names
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
`endif

    // ------------------------------------------------------------------
    // Waves (no $finish — cocotb controls lifetime)
    // ------------------------------------------------------------------
    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_tt_module);
    end

    // No clock generator, no stimulus here. Cocotb drives everything.

endmodule
