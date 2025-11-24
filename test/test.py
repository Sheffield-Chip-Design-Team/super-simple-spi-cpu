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

# import cocotb
# from cocotb.triggers import RisingEdge, Timer


# @cocotb.test()
# async def test_project(dut):
#     """
#     Run the SPI-based tiny CPU for a bit and check that it outputs 3 on uo_out.

#     Program loaded in tb.v:

#         0: LDI 1
#         1: ADDI 1
#         2: ADDI 1   -> A = 3
#         3: OUT      -> uo_out = 3

#     No jump instruction is used.
#     """

#     # IMPORTANT:
#     # - tb.v generates the clock (always #10 clk = ~clk)
#     # - tb.v drives rst_n, ena, ui_in, uio_in and preloads RAM
#     # So we DO NOT drive those from Python, to avoid Xes from multiple drivers.

#     # Wait for tb.v to:
#     #   - run its initial block (50 ns reset, program load, then ena=1,rst_n=1)
#     #   - give the CPU some time to fetch/execute instructions
#     await Timer(500, unit="ns")

#     expected = 3
#     got = None

#     # Run up to N clock cycles, watching for uo_out == 3
#     for _ in range(2000):
#         await RisingEdge(dut.clk)

#         val = dut.uo_out.value

#         # Skip cycles where uo_out still has X/Z bits
#         if not val.is_resolvable:
#             continue

#         got = int(val)
#         if got == expected:
#             break

#     assert got == expected, f"Expected {expected}, got {got if got is not None else 'unresolved'}"
##############James
# import cocotb
# from cocotb.triggers import RisingEdge, Timer
# from cocotb.clock import Clock


# @cocotb.test()
# async def test_project(dut):
#     """
#     Run the SPI-based tiny CPU for a bit and check that it outputs 3 on uo_out.
#     """
#     dut.rst_n.value = 1

#     # generate clk
#     clk = Clock(dut.clk, 1, "ns")
#     cocotb.start_soon(clk.start(True)) 

#     await RisingEdge(dut.clk)
#     dut.rst_n.value = 0
#     await RisingEdge(dut.clk)
#     dut.rst_n.value = 1

#     dut.ui_in.value = 0

#     # Let the Verilog tb initial block assert reset, preload RAM, etc.
#     # Wait for reset to be released (~50 ns in tb.v) plus some margin.

#     for A in range (4):
#         for B in range (4):
#             dut.ui_in.value = (A << 4) | B
    
#             for i in range (10_000):
#                 await RisingEdge(dut.clk)

#             assert dut.uo_out.value == A * B, f"Expected {A * B} , got {dut.uo_out.value}"
#################James
import cocotb
from cocotb.triggers import RisingEdge, Timer


@cocotb.test()
async def test_project(dut):
    """
    System test for the SPI-based microcoded CPU.

    The microprogram in tb.v/spi_ram_model implements a 4×4 multiplier:
      - ui_in[7:4] = A
      - ui_in[3:0] = B
    After the CPU runs the microprogram, uo_out should equal A * B.
    """

    # tb.v:
    #   - generates the clock
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

            # Give the CPU time to:
            #   - fetch micro-ops over SPI
            #   - run the microprogram
            #   - write result to out_port / uo_out
            #
            # 10_000 cycles at 50 MHz = 200 us; plenty for this tiny core.
            for _ in range(10_000):
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

