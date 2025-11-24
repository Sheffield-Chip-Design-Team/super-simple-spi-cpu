# # SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# # SPDX-License-Identifier: Apache-2.0



import random
import cocotb
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_multiplication_rom(dut):
    """
    System test for the SPI-based microcoded CPU.

    The microprogram in tb.v/spi_ram_model implements a 4×4 multiplier:
      - ui_in[7:4] = A
      - ui_in[3:0] = B
    After the CPU runs the microprogram, uo_out should equal A * B.
    """

    # tb.v:
    #   - generates the clock (always #10 clk = ~clk)
    #   - holds reset low for 50 ns, then releases it and sets ena=1
    #   - programs the SPI RAM with the multiplication microcode
    #
    # So here we just wait for that to complete.
    await Timer(5_000, unit="ns")  # 5 us for safety

    # Now exercise all 4×4 combinations
    for A in range(4):
        for B in range(4):
            # Present operands on ui_in: [A (high nibble), B (low nibble)]
            dut.ui_in.value = (A << 4) | B

            # Give the CPU time to: this is in tb.v
            #   - fetch micro-ops over SPI
            #   - run the microprogram
            #   - write result to out_port / uo_out
            #
            # 50_000 cycles at 50 MHz = 1ms plenty for this tiny core.
            for _ in range(50_000):
                await RisingEdge(dut.clk)

            val = dut.uo_out.value

            # Make sure the result is fully 0/1 (no X/Z)
            assert val.is_resolvable, (
                f"uo_out has X/Z for A={A}, B={B}: {val}"
            )

            got = int(val)
            expected = A * B

            assert got == expected, (
                f"For A={A}, B={B} expected {expected}, got {got}"
            )

            print (f"{A} x {B} = {got} (as expected) :D")
