![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Tiny Tapeout Factory Test (IHP)

- [Read the documentation for project](docs/info.md)

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more and get started, visit https://tinytapeout.com.

## Set up your Verilog project

1. Add your Verilog files to the `src` folder.
2. Edit the [info.yaml](info.yaml) and update information about your project, paying special attention to the `source_files` and `top_module` properties. If you are upgrading an existing Tiny Tapeout project, check out our [online info.yaml migration tool](https://tinytapeout.github.io/tt-yaml-upgrade-tool/).
3. Edit [docs/info.md](docs/info.md) and add a description of your project.
4. Adapt the testbench to your design. See [test/README.md](test/README.md) for more information.

The GitHub action will automatically build the ASIC files using [OpenLane](https://www.zerotoasiccourse.com/terminology/openlane/).

## Enable GitHub actions to build the results page

- [Enabling GitHub Pages](https://tinytapeout.com/faq/#my-github-action-is-failing-on-the-pages-part)

## Resources

- [FAQ](https://tinytapeout.com/faq/)
- [Digital design lessons](https://tinytapeout.com/digital_design/)
- [Learn how semiconductors work](https://tinytapeout.com/siliwiz/)
- [Join the community](https://tinytapeout.com/discord)
- [Build your design locally](https://www.tinytapeout.com/guides/local-hardening/)

## What next?

- [Submit your design to the next shuttle](https://app.tinytapeout.com/).
- Edit [this README](README.md) and explain your design, how it works, and how to test it.
- Share your project on your social network of choice:
  - LinkedIn [#tinytapeout](https://www.linkedin.com/search/results/content/?keywords=%23tinytapeout) [@TinyTapeout](https://www.linkedin.com/company/100708654/)
  - Mastodon [#tinytapeout](https://chaos.social/tags/tinytapeout) [@matthewvenn](https://chaos.social/@matthewvenn)
  - X (formerly Twitter) [#tinytapeout](https://twitter.com/hashtag/tinytapeout) [@tinytapeout](https://twitter.com/tinytapeout)


# Project interface

## tt_um_top_layer – Interface Specification

### Overview

`tt_um_top_layer` is the top layer entity of the architecture which implements the logic for data buffering and instantiate the processing system. It accepts data in 8-bit as specfied by tiny tapeout interface requirements. The processing units internally buffer the data into the RAM. When the RAM is full, th processing units are fed with the corresponding sample. After the processing of the data, the processing unit indicates if the current sample belongs to an ictal, interictal or baseline event. 

    ```verilog
    default_nettype none
    module tt_um_top_layer #(
        parameter integer NUM_UNITS  = 4,   // number of processing channels
        parameter integer DATA_WIDTH = 16   // sample word length (bits)
    ) ( ... );
    ```

---

## Parameters

| Parameter | Default | Notes |
|-----------|---------|-------|
| `NUM_UNITS`  | 4  | Number of independent processing channels (`≥ 1`). |
| `DATA_WIDTH` | 16 | Width of each assembled sample word (recommended 8 – 32 bits). |

---

## Ports

| Port | Dir | Width | Description |
|------|-----|-------|-------------|
| `ui_in`  | in  | 8 | Control bus.  bits [1:0] = `selected_unit` (0 … `NUM_UNITS-1`)  bit 2 = `byte_valid` (high for one cycle while `uio_in` is valid)  bits [7:3] = unused. More can be used if more processing units are needed. |
| `uo_out` | out | 8 | Status word.  bit 0 = spike flag of selected unit  bits [2:1] = 2-bit event code of selected unit  bits [7:3] = 0 |
| `uio_in` | in  | 8 | Serialised sample bytes (first MSB, then LSB). |
| `uio_out`| out | 8 | Unused; driven to `8'h00`. |
| `uio_oe` | out | 8 | Tristate enables for `uio_out`; always `8'h00` (input-only). |
| `ena`    | in  | 1 | Global user enable; ignored. |
| `clk`    | in  | 1 | Rising-edge system clock. |
| `rst_n`  | in  | 1 | Asynchronous reset, active low. |

---

## Data-Flow Timing

1. **Byte ingestion**  
   On each rising edge of `clk` with `byte_valid = 1`:  
   • first asserted cycle → byte latched into sample bits [15:8]  
   • second asserted cycle → byte latched into bits [7:0] and `sample_wr_en` pulses high for one cycle. This writes into RAM.

2. **Sample dispatch**  
   Completed 16-bit sample is broadcast to all `NUM_UNITS`; each unit processes it independently.

3. **Flag multiplexing**  
   Combinational logic selects spike/event flags of `selected_unit`, pads with zeros, and drives the 8-bit result on `uo_out`.

---

## Harden project

Congratulations, you are ready to harden your `ttihp-zdrode` project!

First, generate the OpenLane configuration file:

```sh
cd ~/ttihp-zdrode
export PDK_ROOT=~/ttsetup/pdk
export PDK=ihp-sg13g2
export OPENLANE_IMAGE_OVERRIDE=ghcr.io/tinytapeout/openlane2:ihp-v3.0.0.dev23
./tt/tt_tool.py --create-user-config --ihp
```

Then run the following command to harden the project locally. This requires Docker (or a compatible container engine) to be installed and running:

```sh
./tt/tt_tool.py --harden --ihp
```

It’s recommended to check for any synthesis or clock warnings:

```sh
./tt/tt_tool.py --print-warnings
```

### Rehardening

You can reharden at any time. Before running `tt_tool.py`, ensure your environment variables are set (as explained in step 1), and reactivate your Python virtual environment:

```sh
source ~/ttsetup/venv/bin/activate
```

If you change your project configuration (e.g., increase the number of processing units), update the OpenLane config:

```sh
./tt/tt_tool.py --create-user-config --ihp
```

Then reharden:

```sh
./tt/tt_tool.py --harden --ihp
```

### Running RTL tests

```sh
cd test
pip install -r requirements.txt
make -B
```

### Running gate-level tests

```sh
cd test
pip install -r requirements.txt
TOP_MODULE=$(cd .. && ./tt/tt_tool.py --print-top-module)
cp ../runs/wokwi/final/pnl/$TOP_MODULE.pnl.v gate_level_netlist.v
make -B GATES=yes
```

### Exporting the hardened design to PNG

Install required packages:

```sh
sudo apt install librsvg2-bin pngquant
```

Then generate a GDS render:

```sh
./tt/tt_tool.py --create-png
```

The optimized PNG file will be named `gds_render.png`.

### Speeding up Routing

For larger designs, routing can be slow. To use multiple CPU cores, add this line to your `config.json` (replace 8 with your core count):

```json
"ROUTING_CORES": 8,
```

**Note:** Do not commit this change to git.
