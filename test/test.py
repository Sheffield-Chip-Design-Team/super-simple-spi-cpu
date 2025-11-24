# # SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# # SPDX-License-Identifier: Apache-2.0

# import cocotb
# from cocotb.clock import Clock
# from cocotb.triggers import ClockCycles


# @cocotb.test()
# async def test_project(dut):
#     dut._log.info("Start")

#     # Set the clock period to 10 us (100 KHz)
#     clock = Clock(dut.clk, 10, unit="us")
#     cocotb.start_soon(clock.start())

#     # Reset
#     dut._log.info("Reset")
#     dut.ena.value = 1
#     dut.ui_in.value = 0
#     dut.uio_in.value = 0
#     dut.rst_n.value = 0
#     await ClockCycles(dut.clk, 10)
#     dut.rst_n.value = 1

#     dut._log.info("Test project behavior")

#     # Set the input values you want to test
#     dut.ui_in.value = 20
#     dut.uio_in.value = 30

#     # Wait for one clock cycle to see the output values
#     await ClockCycles(dut.clk, 1)

#     # The following assersion is just an example of how to check the output values.
#     # Change it to match the actual expected output of your module:
#     assert dut.uo_out.value == 50

#     # Keep testing the module by changing the input values, waiting for
#     # one or more clock cycles, and asserting the expected output values.


# import cocotb
# from cocotb.clock import Clock
# from cocotb.triggers import RisingEdge, Timer


# @cocotb.test()
# async def test_project(dut):
#     """
#     Run the tiny CPU for a bit and check that it outputs 3 on uo_out.

#     Program in tb.v:

#         0: LDI 1
#         1: ADDI 1
#         2: ADDI 1   -> A = 3
#         3: OUT      -> uo_out = 3
#         4: JMP 3    -> loop

#     So after a while, uo_out should be 3 (0x03).
#     """

#     # Start clock
#     cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

#     # At time 0 the Verilog tb initial block will assert reset and preload RAM.
#     # Let things settle a bit.
#     await Timer(100, units="ns")

#     # Ensure reset is released and design enabled (tb.v already does this, but be explicit)
#     dut.rst_n.value = 1
#     dut.ena.value = 1

#     # Run for some cycles, watching for uo_out == 3
#     expected = 3
#     got = int(dut.uo_out.value)

#     for _ in range(2000):
#         await RisingEdge(dut.clk)
#         got = int(dut.uo_out.value)
#         if got == expected:
#             break

#     assert got == expected, f"Expected {expected}, got {got}"

import cocotb
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_project(dut):
    """
    Run the SPI-based tiny CPU for a bit and check that it outputs 3 on uo_out.

    Program loaded in tb.v:

        0: LDI 1
        1: ADDI 1
        2: ADDI 1   -> A = 3
        3: OUT      -> uo_out = 3

    No jump instruction is used.
    """

    # Let the Verilog tb initial block assert reset, preload RAM, etc.
    # Wait for reset to be released (~50 ns in tb.v) plus some margin.
    await Timer(200, units="ns")

    expected = 3
    got = int(dut.uo_out.value)

    # Run up to 2000 clock cycles, watching for uo_out == 3
    for _ in range(2000):
        await RisingEdge(dut.clk)
        got = int(dut.uo_out.value)
        if got == expected:
            break

    assert got == expected, f"Expected {expected}, got {got}"
