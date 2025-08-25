# SPDX-FileCopyrightText: © 2025 Gabriel Galeote Checa
# SPDX-License-Identifier: MIT
#
# cocotb test-bench that drives the TinyTapeout **`tb.v` wrapper** (signals
# `clk`, `rst_n`, `ui_in`, `uio_in`, …) with the very same CSV stimulus used by
# the reference Verilog bench.  Timing is cycle-accurate:
#
#   • 10-MHz clock (100-ns period)
#   • Per channel (CH0…CH3): 16-bit sample sent MSB first, LSB next
#       – `byte_valid` = ui_in[2] high for exactly one clock per byte
#       – no idle clock between LSB and PROCESS_CYCLES
#   • After the latency we set selector bits ui_in[1:0] to the same channel
#     index and capture `uo_out[0]` (spike) and `uo_out[2:1]` (event)
#
# At the end of the run a PNG (“spikes_events_plot.png”) is produced that shows
#   — the full-scale input waveform for every channel,
#   — vertical black lines where spikes occurred, and
#   — lightly-shaded coloured windows marking the four possible event codes.

from pathlib import Path
import csv
import matplotlib.pyplot as plt

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from collections import defaultdict

# ----------------------------- parameters ------------------------------------
CLK_PERIOD_NS  = 100      # 10-MHz
NUM_UNITS      = 2
PROCESS_CYCLES = 2
CSV_FILE       = "input_data_2ch.csv"
MAX_ROWS       = None        # None → run full file

# ----------------------------- test functions ----------------------------------


def extract_event_intervals(event_list):
    """
    Convert a sequence of event codes into a dictionary mapping each code
    to a list of [start, end] index intervals where the event is active.
    
    Parameters:
    - event_list: list of integers representing event codes
    
    Returns:
    - dict {event_code: list of [start, end] intervals}
    """
    intervals = defaultdict(list)
    
    if not event_list:
        return dict(intervals)
    
    current_event = event_list[0]
    start_idx = 0
    
    for idx in range(1, len(event_list)):
        if event_list[idx] != current_event:
            intervals[current_event].append([start_idx, idx - 1])
            current_event = event_list[idx]
            start_idx = idx
    
    # Append last interval
    intervals[current_event].append([start_idx, len(event_list) - 1])
    
    return dict(intervals)

# ----------------------------- helpers ---------------------------------------
async def send_byte(dut, byte: int):
    """Assert ui_in[2] for exactly one clock while driving uio_in with *byte*."""
    await RisingEdge(dut.clk)             # edge N
    dut.uio_in.value = byte & 0xFF
    dut.ui_in.value  = 0b0000_0100        # byte_valid
    await RisingEdge(dut.clk)             # edge N+1, sampled by DUT
    dut.ui_in.value  = 0                  # de-assert

async def send_sample(dut, word: int):
    """Send a 16-bit sample MSB first, LSB next, no idle afterwards."""
    await send_byte(dut, word >> 8)
    await send_byte(dut, word & 0xFF)

def spike(dut) -> int:
    """Return 1 if `uo_out[0]` asserted this cycle, 0 if unresolved."""
    val_str = str(dut.uo_out.value)
    if 'x' in val_str or 'z' in val_str:
        return 0 
    return int(dut.uo_out.value) & 1

def event_bits(dut) -> int:
    """Return the two-bit event code present on `uo_out[2:1]`, 0 if unresolved."""
    val_str = str(dut.uo_out.value)
    if 'x' in val_str or 'z' in val_str:
        return 0
    return (int(dut.uo_out.value) >> 1) & 0b11

async def hard_reset(dut):
    """Asynchronous active-low reset, held for five cycles."""
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

# ----------------------------- main test -------------------------------------
@cocotb.test()
async def tinytapeout_csv_stimulus(dut):
    """Feed the tb.v wrapper with a four-channel CSV stimulus and record results."""

    # ------------------------- clock & reset -------------------------------
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())

    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    await hard_reset(dut)

    # ------------------------- statistics ----------------------------------
    spike_total      = 0
    spike_per_unit   = [0] * NUM_UNITS
    event_histogram  = [0] * 4

    # ------------------------- tracing for plots ---------------------------
    sample_times   = [[] for _ in range(NUM_UNITS)]
    sample_values  = [[] for _ in range(NUM_UNITS)]
    spike_times    = [[] for _ in range(NUM_UNITS)]
    event_times    = [[] for _ in range(NUM_UNITS)]
    event_types    = [[] for _ in range(NUM_UNITS)]

    # ------------------------- stimulus loop -------------------------------
    csv_path = Path(__file__).with_name(CSV_FILE)
    if not csv_path.exists():
        raise FileNotFoundError(f"cannot open {CSV_FILE}")

    sample_idx = 0        # global sample counter across all channels
    rows_read  = 0

    with csv_path.open(newline="") as fh:
        reader = csv.reader(fh)
        for tokens in reader:

            if MAX_ROWS is not None and rows_read >= MAX_ROWS:
                break
            if not tokens or tokens[0].lstrip().startswith('#'):
                continue
            if len(tokens) < NUM_UNITS:
                dut._log.warning("malformed CSV line %d (ignored)", rows_read)
                continue

            try:
                samples = [int(tok, 10) & 0xFFFF for tok in tokens[:NUM_UNITS]]
            except ValueError:
                dut._log.warning("non-numeric CSV line %d (ignored)", rows_read)
                continue

            # ------------- CH0 … CH3 --------------------------------------
            for ch, sample in enumerate(samples):


                # store analogue trace point
                sample_times[ch].append(sample_idx)
                sample_values[ch].append(sample)

                await send_sample(dut, sample)

                # pipeline latency identical to Verilog bench
                if PROCESS_CYCLES:
                    await ClockCycles(dut.clk, PROCESS_CYCLES)

                # selector bits (ui_in[1:0]) – ensure byte_valid is 0
                dut.ui_in.value = ch & 0b11
                await RisingEdge(dut.clk)   # allow comb → seq transfer

                # capture
                if spike(dut):
                    spike_total         += 1
                    spike_per_unit[ch]  += 1
                    spike_times[ch].append(sample_idx)

                ev = event_bits(dut)
                event_histogram[ev] += 1
                event_times[ch].append(sample_idx)
                event_types[ch].append(ev)

                sample_idx += 1
                if sample_idx % 1000 == 0:
                    dut._log.info(f"Processed {sample_idx} samples")
            rows_read += 1

    # ----------------------------- summary ----------------------------------
    dut._log.info("\n==== SPIKE SUMMARY (TinyTapeout wrapper) ====")
    for unit, cnt in enumerate(spike_per_unit):
        dut._log.info("unit %0d : %0d spikes", unit, cnt)
    dut._log.info("total    : %d", spike_total)
    dut._log.info("events   : 00=%d  01=%d  10=%d  11=%d",
                  event_histogram[0], event_histogram[1],
                  event_histogram[2], event_histogram[3])
    dut._log.info("rows processed : %d", rows_read)
    dut._log.info("samples driven : %d", sample_idx)

   # ----------------------------- plotting ---------------------------------
    colours_ev = ['tab:blue', 'tab:orange', 'tab:green', 'tab:red']  # by event code

    fig, axs = plt.subplots(NUM_UNITS, 1, figsize=(12, 2.5 * NUM_UNITS), sharex=True)
    if NUM_UNITS == 1:
        axs = [axs]  # normalise to list

    for ch in range(NUM_UNITS):
        ax = axs[ch]

        # (1) raw 16-bit input waveform
        ax.plot(sample_times[ch], sample_values[ch],
                linewidth=0.7, color='grey', label='Input sample', zorder=1)

        # (2) spikes — thin vertical black lines
        if spike_times[ch]:
            ymin = min(sample_values[ch])
            ymax = max(sample_values[ch])
            ax.vlines(spike_times[ch], ymin=ymin, ymax=ymax,
                    linewidth=0.8, color='black', label='Spike', zorder=2)

        # (3) coloured event intervals
        intervals_by_event = extract_event_intervals(event_types[ch])
        first_event_drawn = [False] * 4  # to control one legend entry per code

        for ev, intervals in intervals_by_event.items():
            for start_idx, end_idx in intervals:
                start_time = event_times[ch][start_idx]
                end_time = event_times[ch][end_idx]
                lbl = f'Event {ev:02b}' if not first_event_drawn[ev] else ""
                ax.axvspan(start_time - 0.5, end_time + 0.5, color=colours_ev[ev],
                        alpha=0.2, label=lbl, zorder=0)
                first_event_drawn[ev] = True

        # cosmetics
        ax.set_ylabel(f'CH{ch}')
        ax.tick_params(axis='y', labelsize='small')
        ax.legend(loc='upper right', fontsize='x-small', framealpha=0.9)

    axs[-1].set_xlabel('Sample index')
    plt.tight_layout()
    plt.savefig("spikes_events_plot.png", dpi=150)
    plt.close(fig)

