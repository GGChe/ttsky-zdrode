# SPDX-FileCopyrightText: © 2025 Gabriel Galeote Checa
# SPDX-License-Identifier: MIT

from pathlib import Path
import csv
import matplotlib.pyplot as plt

import cocotb
from cocotb.clock    import Clock
from cocotb.triggers import RisingEdge, ClockCycles
from collections import defaultdict

# ----------------------------- parameters ------------------------------------
CLK_PERIOD_NS   = 100       # 10 MHz
NUM_UNITS       = 2
PROCESS_CYCLES  = 2
OBS_CYCLES      = 3         # observe a few cycles after selecting a unit
CSV_FILE        = "input_data_2ch.csv"
MAX_ROWS        = None

# ----------------------------- utilities -------------------------------------
def extract_event_intervals(event_list):
    intervals = defaultdict(list)
    if not event_list:
        return dict(intervals)
    cur = event_list[0]; start = 0
    for i in range(1, len(event_list)):
        if event_list[i] != cur:
            intervals[cur].append([start, i - 1])
            cur = event_list[i]; start = i
    intervals[cur].append([start, len(event_list) - 1])
    return dict(intervals)

def _bit_lsb0(binval, idx):
    """
    Return bit 'idx' (LSB=0) of 'binval' as 0/1, or None if X/Z.
    Uses string indexing so we don't depend on big-endian BinaryValue semantics.
    """
    s = binval.binstr  # MSB...LSB string
    if not s or idx < 0 or idx >= len(s):
        return None
    ch = s[-1 - idx]   # LSB at rightmost
    if ch in '01':
        return int(ch)
    return None

def _bits_lsb0(binval, lsb, msb):
    """
    Return integer composed from bits [msb:lsb] (inclusive), LSB=0 indexing.
    Returns None if any bit is X/Z.
    """
    val = 0
    for i in range(lsb, msb + 1):
        b = _bit_lsb0(binval, i)
        if b is None:
            return None
        val |= (b << (i - lsb))
    return val

# ----------------------------- helpers ---------------------------------------
async def send_byte(dut, byte: int):
    """Assert ui_in[2] for exactly one clock while driving uio_in with *byte*."""
    await RisingEdge(dut.clk)
    dut.uio_in.value = byte & 0xFF
    dut.ui_in.value  = 0b0000_0100
    await RisingEdge(dut.clk)
    dut.ui_in.value  = 0

async def send_sample(dut, word: int):
    """Send a 16-bit sample MSB first, then LSB."""
    await send_byte(dut, (word >> 8) & 0xFF)
    await send_byte(dut,  word        & 0xFF)

async def hard_reset(dut):
    """Asynchronous active-low reset, held for five cycles."""
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

# ----------------------------- main test -------------------------------------
@cocotb.test()
async def tinytapeout_csv_stimulus(dut):
    """Drive TinyTapeout wrapper with NUM_UNITS-channel CSV stimulus and record results."""

    # Clock & reset
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units="ns").start())
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    await hard_reset(dut)

    # Statistics
    spike_total     = 0
    spike_per_unit  = [0] * NUM_UNITS
    event_histogram = [0] * 4

    # Traces for plotting
    sample_times  = [[] for _ in range(NUM_UNITS)]
    sample_values = [[] for _ in range(NUM_UNITS)]
    spike_times   = [[] for _ in range(NUM_UNITS)]
    event_times   = [[] for _ in range(NUM_UNITS)]
    event_types   = [[] for _ in range(NUM_UNITS)]

    # Stimulus loop
    csv_path = Path(__file__).with_name(CSV_FILE)
    if not csv_path.exists():
        raise FileNotFoundError(f"cannot open {CSV_FILE}")

    sample_idx = 0
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

            for ch, sample in enumerate(samples):
                # (1) record analogue trace point
                sample_times[ch].append(sample_idx)
                sample_values[ch].append(sample)

                # (2) send the sample
                await send_sample(dut, sample)

                # (3) DUT pipeline latency
                if PROCESS_CYCLES:
                    await ClockCycles(dut.clk, PROCESS_CYCLES)

                # (4) hold selector on ui_in[1:0]; ensure byte_valid=0
                dut.ui_in.value = (ch & 0b11)

                # (5) allow selector to propagate and observe for a few cycles
                await RisingEdge(dut.clk)   # settle
                saw_spike = False
                resolved_event = None
                for _ in range(OBS_CYCLES):
                    s = _bit_lsb0(dut.uo_out.value, 0)      # spike at bit 0 (LSB)
                    e = _bits_lsb0(dut.uo_out.value, 1, 2)  # event at bits [2:1]
                    if s == 1:
                        saw_spike = True
                    if e is not None:
                        resolved_event = e
                    await RisingEdge(dut.clk)

                # (6) accumulate stats and traces
                if saw_spike:
                    spike_total        += 1
                    spike_per_unit[ch] += 1
                    spike_times[ch].append(sample_idx)

                if resolved_event is not None:
                    event_histogram[resolved_event] += 1
                    event_times[ch].append(sample_idx)
                    event_types[ch].append(resolved_event)
                else:
                    # If never resolved, count as 00 (or skip if you prefer)
                    event_histogram[0] += 1
                    event_times[ch].append(sample_idx)
                    event_types[ch].append(0)

                sample_idx += 1
                if sample_idx % 1000 == 0:
                    dut._log.info("Processed %d samples", sample_idx)

            rows_read += 1

    # Summary
    dut._log.info("\n==== SPIKE SUMMARY (TinyTapeout wrapper) ====")
    for unit, cnt in enumerate(spike_per_unit):
        dut._log.info("unit %0d : %d spikes", unit, cnt)
    dut._log.info("total    : %d", spike_total)
    dut._log.info("events   : 00=%d  01=%d  10=%d  11=%d",
                  event_histogram[0], event_histogram[1],
                  event_histogram[2], event_histogram[3])
    dut._log.info("rows processed : %d", rows_read)
    dut._log.info("samples driven : %d", sample_idx)

    # Plot
    colours_ev = ['tab:blue', 'tab:orange', 'tab:green', 'tab:red']
    fig, axs = plt.subplots(NUM_UNITS, 1, figsize=(12, 2.5 * NUM_UNITS), sharex=True)
    if NUM_UNITS == 1:
        axs = [axs]
    for ch in range(NUM_UNITS):
        ax = axs[ch]
        ax.plot(sample_times[ch], sample_values[ch],
                linewidth=0.7, color='grey', label='Input sample', zorder=1)
        if spike_times[ch]:
            ymin = min(sample_values[ch]); ymax = max(sample_values[ch])
            ax.vlines(spike_times[ch], ymin=ymin, ymax=ymax,
                      linewidth=0.8, color='black', label='Spike', zorder=2)
        intervals_by_event = extract_event_intervals(event_types[ch])
        first_event_drawn = [False] * 4
        for ev, intervals in intervals_by_event.items():
            for start_idx, end_idx in intervals:
                start_time = event_times[ch][start_idx]
                end_time   = event_times[ch][end_idx]
                lbl = f'Event {ev:02b}' if not first_event_drawn[ev] else ""
                ax.axvspan(start_time - 0.5, end_time + 0.5,
                           color=colours_ev[ev], alpha=0.2, label=lbl, zorder=0)
                first_event_drawn[ev] = True
        ax.set_ylabel(f'CH{ch}')
        ax.tick_params(axis='y', labelsize='small')
        ax.legend(loc='upper right', fontsize='x-small', framealpha=0.9)
    axs[-1].set_xlabel('Sample index')
    plt.tight_layout()
    plt.savefig("spikes_events_plot.png", dpi=150)
    plt.close(fig)
