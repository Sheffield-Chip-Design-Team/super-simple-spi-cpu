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


import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_project(dut):
    """Check that tt_um_example reads 0xA5 from external SPI RAM at addr 0x12."""

    # Start clock (20 ns period = 50 MHz)
    cocotb.start_soon(Clock(dut.clk, 20, units="ns").start())

    # Default values
    dut.ena.value = 0
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0

    # Let things settle
    await Timer(50, units="ns")

    # Release reset and enable design
    dut.rst_n.value = 1
    dut.ena.value = 1

    # Tell the design which address to read: 0x12
    dut.ui_in.value = 0x12

    # Wait until the SPI read finishes.
    # Inside tb.v, the top instance is called "user_project", and inside that
    # your spi_read_byte instance is "spi_if", so we can watch its .done signal.
    # (This path must match your Verilog!)
    while int(dut.user_project.spi_if.done.value) == 0:
        await RisingEdge(dut.clk)

    # One more cycle to let uo_out stabilize
    await RisingEdge(dut.clk)

    got = int(dut.uo_out.value)
    exp = 0xA5

    assert got == exp, f"Expected 0x{exp:02X}, got 0x{got:02X}"
