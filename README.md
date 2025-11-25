![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Super-Simple-SPI-CPU
## Authors: James Ashie Kotey, Bowen Shi, Mohammad Eissa

This repository contains a tiny **4‑bit microcoded CPU** designed for **TinyTapeout (GF180MCU)** that fetches its program over **SPI** from external memory (e.g. an RP2040 emulating 23LC512‑style RAM). The demo configuration runs a microcoded **4×4‑bit → 8‑bit multiplier**, mapping the TinyTapeout pins as:

- `ui_in[7:4]` → operand **A** (4‑bit)
- `ui_in[3:0]` → operand **B** (4‑bit)
- `uo_out[7:0]` → **A × B** (8‑bit result)

At a glance, this project showcases:

- A compact **microcoded datapath** (register file, ALU, shift register, accumulator)
- An instruction stream fetched from **external SPI memory**
- A complete **TinyTapeout‑ready top level** with tests and simulation setup

If you’re interested in TinyTapeout, open hardware, or learning how to build a simple CPU that boots from SPI, this repo is meant to be an approachable starting point.

---

## Quick start

- Clone the repo and install the simulation dependencies (Python, cocotb, Icarus Verilog).
- From the `test/` directory, run:

  ```sh
  cd test
  make -B results.xml
  ```

  This compiles the design, runs cocotb tests (including a full 4×4 multiplier sweep), and produces a `tb.fst` waveform for inspection.

- On real TinyTapeout hardware, connect the SPI pins to an RP2040 or similar microcontroller that emulates a simple 0x03‑READ‑only SPI RAM and loads the microcode.

---

## Full documentation

For full details on:

- Block diagram and module descriptions
- Instruction set and microcode layout
- Testbench structure and cocotb tests
- Expected external hardware setup (RP2040 SPI RAM emulation)
- Licensing (CERN‑OHL‑S‑2.0)

please [Read the documentation for project](docs/info.md)
