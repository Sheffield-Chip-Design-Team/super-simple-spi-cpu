# TinyTapeout SPI Microcoded CPU

A tiny **4-bit microcoded CPU** for **TinyTapeout (GF180MCU)** that executes its program out of **external SPI RAM** (e.g. an RP2040 emulating a 23LC512-style memory).

The demo design implements a **4×4-bit → 8-bit hardware multiplier** as its “firmware”:

- `ui_in[7:4] = A` (4-bit)
- `ui_in[3:0] = B` (4-bit)
- `uo_out[7:0] = A × B` (8-bit product)

The project is intended to be:

- easy to read and hack on,
- a reference for **microcoded datapaths** in HDL, and
- a real, tapeout-ready TinyTapeout design that talks to **external SPI memory**.

---

## Block Overview

The design has three main parts:

1. **TinyTapeout wrapper**:  
   `tt_um_spi_cpu_top`  
   Handles TT pins (`ui_*`, `uo_*`, `uio_*`, `clk`, `rst_n`, `ena`), and exposes a local SPI interface to the CPU wrapper.

2. **CPU wrapper + SPI fetch**:  
   `spi_wrap`  
   Contains:
   - Program Counter (`pc`)
   - A small FSM to fetch **instruction bytes over SPI**
   - A **byte-oriented SPI engine** (`spi_read_byte`)
   - The **ExecutionUnit** (datapath/ALU)

3. **ExecutionUnit datapath**:  
   `ExecutionUnit` (in `cpu.v`)  
   Glue of:
   - Register file (A, B, O)
   - Shift register + flag
   - Accumulator (ACC)
   - ALU (add/sub + boolean ops)
   - InstructionDecoder and control muxes

The program (microcode) lives in external SPI RAM. On TinyTapeout, you’ll usually emulate this SPI RAM using an **RP2040** or similar microcontroller on the TinyTapeout board.

---

## How it works

### Top-level: `tt_um_spi_cpu_top`

TinyTapeout’s interface to the design:

```verilog
module tt_um_spi_cpu_top (
    input  wire [7:0] ui_in,    // A,B operands
    output wire [7:0] uo_out,   // product
    input  wire [7:0] uio_in,   // SPI MISO + unused
    output wire [7:0] uio_out,  // SPI CS/MOSI/SCK + valid
    output wire [7:0] uio_oe,   // IO direction
    input  wire       ena,      // TT "design selected"
    input  wire       clk,      // global TT clock
    input  wire       rst_n     // global TT reset (active low)
);
```

**Pin mapping (logical):**

- **Main I/O:**

  | Signal   | Meaning                                       |
  |----------|-----------------------------------------------|
  | `ui_in`  | `[7:4] = A`, `[3:0] = B`                      |
  | `uo_out` | `A × B` (8-bit product from CPU)             |

- **SPI interface (to external RAM / RP2040):**

  | Signal      | TT pin       | Dir     | Description                       |
  |-------------|--------------|---------|-----------------------------------|
  | `spi_cs_n`  | `uio_out[0]` | output  | SPI Chip Select (active low)      |
  | `spi_mosi`  | `uio_out[1]` | output  | SPI MOSI                          |
  | `spi_miso`  | `uio_in[2]`  | input   | SPI MISO                          |
  | `spi_sck`   | `uio_out[3]` | output  | SPI clock (mode 0)                |
  | `valid`     | `uio_out[7]` | output  | One-cycle pulse when a micro-op executes |

- **Direction pins (`uio_oe`):**

  ```verilog
  assign uio_oe[0]   = 1'b1;    // CS   = output
  assign uio_oe[1]   = 1'b1;    // MOSI = output
  assign uio_oe[2]   = 1'b0;    // MISO = input
  assign uio_oe[3]   = 1'b1;    // SCK  = output
  assign uio_oe[7:4] = 4'b1000; // valid on [7], others input
  ```

### CPU wrapper: `spi_wrap`

`spi_wrap` is the brains that connect:

- the external **SPI RAM**,
- the **Program Counter (PC)**,
- and the **ExecutionUnit**.

Key responsibilities:

1. **Program Counter and state:**

   ```verilog
   reg [11:0] pc;          // PC (lower bits used as address)
   reg [3:0]  opcode1;
   reg [3:0]  opcode2;
   reg [3:0]  curr_opcode;
   reg        cpu_start;
   reg        cpu_valid;
   ```

2. **SPI instruction fetch:**

   - Each instruction byte from SPI holds **two 4-bit micro-operations**:
     - `opcode1 = spi_data[3:0]`
     - `opcode2 = spi_data[7:4]`
   - Address mapping is simple: `spi_addr = {4'h0, pc}`  
     (i.e. microcode at addresses 0x0000, 0x0001, …)

3. **SPI FSM:**

   States:

   - `S_RESET`
   - `S_FETCH_START`
   - `S_FETCH_WAIT_OPCODE`
   - `S_EXECUTE_1`
   - `S_EXECUTE_2`

   Flow:

   - `S_FETCH_START`: when `spi_busy == 0`, pulse `spi_start` to start a read.
   - `S_FETCH_WAIT_OPCODE`: wait for `spi_done == 1`, then latch `spi_data`.
   - `S_EXECUTE_1`: pulse `cpu_start`, set `curr_opcode = opcode1`.
   - `S_EXECUTE_2`: pulse `cpu_start`, set `curr_opcode = opcode2`, increment `pc`, and go back to `S_FETCH_START`.

4. **SPI engine: `spi_read_byte`**

   `spi_read_byte` performs a 23LC512-style READ (0x03) transaction:

   - Outputs `busy` while a transaction is in progress.
   - Sends `{8'h03, addr[15:0]}` MSB-first on MOSI.
   - Then clocks in 8 bits from MISO into `data_out`.
   - Outputs a one-cycle `done` pulse when the byte is ready.

   It drives the SPI pins exposed at the top level.

### ExecutionUnit datapath

`ExecutionUnit` implements a small micro-instruction set and the datapath. Inputs:

- `clk`, `reset`, `start`
- `opcode` (4 bits)
- `operand` (8 bits): in this design, from `in_port` (`ui_in`), so `[7:4]=A, [3:0]=B`.

Internally:

- **Registers** (`Registers.v`):
  - A (4-bit)
  - B (4-bit)
  - O (8-bit “output” register)
  - ACC (8-bit accumulator)
  - 8-bit shift register + flag (`SF`) used for LSH/RSH and “skip if zero” tests.

- **Instruction decoder** (`Control.v`): 4-bit opcode → one-hot control:

  ```text
  0:  LDA   (load A)
  1:  LDB   (load B)
  2:  LDO   (load O from ACC)
  3:  LDSA  (load shift reg from A)
  4:  LDSB  (load shift reg from B)
  5:  LSH   (shift left)
  6:  RSH   (shift right)
  7:  CLR   (clear)
  8:  SNZA  (skip-next-if-zero A/SF)
  9:  SNZS  (skip-next-if-zero shift flag)
  10: ADD
  11: SUB
  12: AND
  13: OR
  14: XOR
  15: INV
  ```

- **ALU** (`ALU.v`):

  - `ArithmeticLogicUnit` combines:
    - Add/Sub (8-bit)
    - AND/OR/XOR/INV (4-bit slice)
    - CLR (output 0)
  - Uses small combinational blocks (`combAdderSubtractor`, `combAND`, `combOR`, etc.).

- **Control muxes**:

  - `SR_MUX`: chooses A or B into the shift register.
  - `ADD_MUX`: merges ADD and SNZx control for branch-like behaviour.
  - `ALU_MUX`: selects first and second ALU operands (ACC, A, B, shiftOut, etc.) depending on SNZA/SNZS and flags.
  - `ENABLE_ACC_MUX`: decides when the ACC should capture ALU output.

- **ACC and cpuOut**:

  - ACC is updated when an ALU operation is active.
  - `cpuOut` (mapped to `uo_out`) follows the O register when `start` is asserted.

### Microcode: multiplication program

The demo microcode is a 4×4→8 multiplier built from the micro-ops above:

- A and B are loaded from `ui_in` into the datapath.
- The microprogram uses:
  - shift operations on one operand,
  - conditionals via SNZA/SNZS and the shift flag,
  - repeated ADD into ACC,
  - LDO to move ACC into O.

The **testbench** (`tb.v`) preloads the SPI RAM model’s `mem[]` with this microcode at addresses `0x00–0x0F` and fills the rest with `CLR,CLR` NOPs.

On real hardware, your RP2040 firmware would similarly load the SPI RAM contents.

---

## How to test

All tests live in the `test/` directory and use **cocotb + Icarus Verilog**.

### Requirements

- Python 3.11 (or compatible)
- `cocotb`
- `cocotb-test` / `cocotb-tools` (depending on your setup)
- Icarus Verilog (`iverilog`, `vvp`)

TinyTapeout’s GitHub template CI already installs these for you; locally you can do something like:

```sh
pip install cocotb cocotb-test
sudo apt install iverilog
```

### Running the full test suite

From the `test/` directory:

```sh
cd test
rm -f results.xml
make -B results.xml
```

This will:

- Run Icarus Verilog to compile:
  - all `src/*.v` modules,
  - the main testbench `tb.v`,
  - plus supporting models like `spi_ram_model.v`.
- Execute all defined cocotb tests in `test.py` (and any others configured).
- Produce:
  - `results.xml` – JUnit-style summary of test results.
  - `tb.fst` – GTKWave-viewable waveform.

You can inspect `tb.fst` with:

```sh
gtkwave tb.fst
```

### Top-level tests in `test/test.py`

The main system-level tests are:

1. **`test_multiplication_rom`**  
   - Randomly picks 10 pairs `(A,B) ∈ [0, 15]`.
   - For each pair:
     - Sets `dut.ui_in = (A << 4) | B`.
     - Waits 50,000 clock cycles (safe upper bound for one full microcode iteration).
     - Checks `dut.uo_out == A * B`.
   - Exercises: TT wrapper, SPI interface, microcode fetch, ExecutionUnit, ALU, shifter, registers.

2. **`test_multiplication_full_exhaustive`**  
   - Explicitly resets the DUT at the start.
   - Tests **all 256 combinations** of `A,B` in `[0..15]`.
   - Same pattern as the random test; each combination must match `A * B`.
   - Provides full coverage of the multiplier behaviour from the top level.

3. **`test_spi_activity`**  
   - After reset, watches `uio_out`:
     - Ensures CS (`uio_out[0]`) goes low at least once.
     - Ensures SCK (`uio_out[3]`) toggles while CS is low.
     - Ensures MOSI (`uio_out[1]`) changes while CS is low.
   - Confirms that the SPI bus is “alive” and looks like a real transaction.

4. **`test_midrun_reset`**  
   - Lets the CPU compute a product `(A1,B1)` and verifies the result.
   - Starts another multiply, then asserts reset **mid-run**.
   - After re-enabling, checks that a new multiply `(A3,B3)` still computes correctly.
   - Validates that synchronous reset cleanly reinitialises the CPU and SPI state machine.

5. **`test_uio_mapping`**  
   - Reads `dut.uio_oe`.
   - Asserts the expected direction mapping:
     - `[0] = 1` (CS output)
     - `[1] = 1` (MOSI output)
     - `[2] = 0` (MISO input)
     - `[3] = 1` (SCK output)
     - `[7:4] = 4'b1000`
   - Ensures we don’t accidentally drive MISO or misconfigure TT IOs.

### Unit-style tests

There are also more focused tests (depending on which ones you include):

- `test_alu.py` – calls the ALU with various inputs to verify ADD/SUB/AND/OR/XOR/INV/CLR.
- `test_instr_decoder.py` – checks that each 4-bit opcode maps to the correct one-hot control lines.
- `ProgramROMtest.v` + `tb_program_romtest.v` – Verilog-only sanity tests for the instruction ROM and control paths.

These are useful as references if you want to extend the ISA or microcode.

---

## External hardware

On silicon, the core expects to talk to an **external SPI memory** that behaves like a simple 23LC512-style RAM:

- Single command implemented: **READ (0x03)**.
- Address: 16 bits, MSB-first.
- Data: one byte (microcode containing two 4-bit instructions).

### Typical TinyTapeout board setup

Most TinyTapeout boards include an **RP2040** or similar microcontroller capable of:

- Speaking SPI to the user design.
- Providing a memory-mapped view of microcode.
- Providing a way to update the microcode over USB.

A typical wiring:

| TT pin        | Signal      | Connects to RP2040 |
|---------------|-------------|--------------------|
| `uio_out[0]`  | `spi_cs_n`  | SPI CS (chip select) |
| `uio_out[1]`  | `spi_mosi`  | SPI MOSI            |
| `uio_in[2]`   | `spi_miso`  | SPI MISO            |
| `uio_out[3]`  | `spi_sck`   | SPI SCK             |

On the RP2040 side, your firmware would:

1. Expose some RAM (or flash) region as the “program memory”.
2. Implement the **0x03 READ protocol**:
   - Listen for CS low.
   - Read byte 0: expect 0x03.
   - Read bytes 1–2: 16-bit address `addr`.
   - Output `mem[addr]` on subsequent SCK cycles.
3. Initialise `mem[0x0000..0x000F]` with the multiplier microcode (or your own program).

The Verilog testbench (`spi_ram_model.v`) provides an in-simulation reference implementation of this SPI RAM behaviour.

### Bringing up on real hardware

When you get your TinyTapeout ASIC back:

1. Flash your RP2040 firmware with the SPI RAM emulation and desired microcode.
2. Power the TT board and confirm SPI signals show activity on a scope / logic analyser.
3. Drive `ui_in` from the harness (e.g. USB command or physical switches, depending on the board).
4. Read `uo_out` as the 8-bit multiply result.

Because the core is microcoded, you can experiment with:

- Alternative microprograms (ALU demos, simple state machines).
- Simple “software-defined” behaviours using the same hardware datapath.

---

## Project structure

A typical repository layout:

```text
.
├── src/
│   ├── tt_um_spi_cpu.v        # TinyTapeout top-level wrapper
│   ├── spi_wrap.v             # PC + SPI fetch + core wrapper
│   ├── spi_read_byte.v        # Byte-wide SPI READ FSM
│   ├── cpu.v                  # ExecutionUnit instantiation
│   ├── ALU.v                  # ArithmeticLogicUnit + helpers
│   ├── Registers.v            # RegisterFile, ACC, shift register, DFFs
│   ├── Control.v              # InstructionDecoder, muxes, clkDiv
│   └── ...
└── test/
    ├── tb.v                   # TT-style top-level testbench, hooks SPI RAM model
    ├── spi_ram_model.v        # Behavioural SPI RAM (READ 0x03)
    ├── ProgramROMtest.v       # Example ROM-driven microcode test
    ├── tb_program_romtest.v   # TB for ProgramROMtest
    ├── tb_spi_read_byte.v     # TB for spi_read_byte
    ├── test.py                # Main cocotb system tests
    ├── test_alu.py            # ALU tests
    ├── test_instr_decoder.py  # Decoder tests
    └── Makefile               # Icarus + cocotb glue
```

---

## License

The hardware design files in this repository (HDL source, netlists, and any other
implementation-related files) are licensed under the **CERN Open Hardware Licence
Version 2 – Strongly Reciprocal (CERN-OHL-S-2.0)**.

You are free to use, study, modify, manufacture, and distribute this design,
provided that:

- You preserve this license notice and attribution to the original authors.
- If you modify the design and distribute your modified version, you must:
  - clearly document the changes, and
  - release your modifications under the same **CERN-OHL-S-2.0** license.

A copy of the full CERN-OHL-S-2.0 license text should be provided in the `LICENSE` file.

Unless otherwise stated, documentation, comments, and example testbenches in this
repository are also provided under **CERN-OHL-S-2.0**. If you reuse them, please
credit the original project and authors.

Copyright © 2026 <James Ashie Kotey, Bowen Shi and Mohammad Eissa / SHaRC Team>
