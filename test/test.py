# # SPDX-FileCopyrightText: © 2024 Tiny Tapeout
# # SPDX-License-Identifier: Apache-2.0



import random
import cocotb
from cocotb.triggers import RisingEdge, Timer
async def wait_for_settle(dut, settle_time_ns=5_000):
    """
    Wait for tb.v to:
      - apply reset
      - preload SPI RAM
      - release reset and enable the design
    """
    await Timer(settle_time_ns, unit="ns")
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

    # Now exercise 10, random combinations
    for test in range(10):  # 0..99
       
        A = random.randint(0, 15)
        B = random.randint(0, 15)
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

        print (         f"{A} x {B} = {got}.")

@cocotb.test()
async def test_spi_activity(dut):
    """
    Check that the SPI interface is active and behaves like a real SPI bus
    from the top level.

    We verify:

      - CS (uio_out[0]) goes low at least once (a transaction starts)
      - SCK (uio_out[3]) toggles while CS is low
      - MOSI (uio_out[1]) changes at least once while CS is low

    This confirms the SPI FSM is driving a plausible transaction without
    relying on exact bit alignment or command encoding.
    """

    await wait_for_settle(dut)

    uio = dut.uio_out

    cs_low_seen = False
    sck_toggles_while_cs_low = 0
    mosi_changes_while_cs_low = 0

    last_sck = None
    last_mosi = None

    # Watch for some time
    for _ in range(50_000):
        await RisingEdge(dut.clk)

        val = uio.value
        if not val.is_resolvable:
            continue

        cs   = int(val[0])  # CS_n on bit 0
        mosi = int(val[1])  # MOSI on bit 1
        sck  = int(val[3])  # SCK  on bit 3

        if cs == 0:
            if not cs_low_seen:
                cs_low_seen = True
                last_sck = sck
                last_mosi = mosi
            else:
                # Count SCK toggles while CS is low
                if last_sck is not None and sck != last_sck:
                    sck_toggles_while_cs_low += 1

                # Count MOSI changes while CS is low
                if last_mosi is not None and mosi != last_mosi:
                    mosi_changes_while_cs_low += 1

                last_sck = sck
                last_mosi = mosi

    assert cs_low_seen, "SPI: CS_n (uio_out[0]) never went low; no transaction seen"
    assert sck_toggles_while_cs_low > 0, (
        "SPI: SCK (uio_out[3]) did not toggle while CS_n was low"
    )
    assert mosi_changes_while_cs_low > 0, (
        "SPI: MOSI (uio_out[1]) never changed while CS_n was low"
    )
    
# # @cocotb.test()
# # async def test_multiplication_full_exhaustive(dut):
#     """
#     Exhaustive 4-bit×4-bit multiplier test.

#     IMPORTANT: We explicitly reset the DUT here because previous tests
#     have already been running the CPU for a long time, and we want to
#     start this sweep from a clean PC/state.
#     """

#     # ---- Explicit reset to re-start microcode and PC ----
#     dut.rst_n.value = 0
#     dut.ena.value   = 0
#     dut.ui_in.value = 0

#     # Let a few clock cycles elapse with reset asserted
#     for _ in range(10):
#         await RisingEdge(dut.clk)

#     await wait_for_settle(dut)

#     # Release reset and enable the design again
#     dut.rst_n.value = 1
#     dut.ena.value   = 1

#     # Allow tb.v initialisation / microcode fetch to settle again

#     # ---- Exhaustive sweep ----
#     cycles_per_op = 50000  # should be plenty for one full microcode loop

#     for A in range(16):
#         for B in range(16):
            
#             # Present operands on ui_in: [A (high nibble), B (low nibble)]
#             dut.ui_in.value = (A << 4) | B

#             # Give the core time to:
#             #   - fetch micro-ops via SPI
#             #   - run the microprogram
#             #   - write result to out_port / uo_out
#             for _ in range(cycles_per_op):
#                 await RisingEdge(dut.clk)

#             val = dut.uo_out.value
#             assert val.is_resolvable, f"uo_out X/Z for A={A}, B={B}: {val}"

#             got = int(val)
#             expected = A * B

#             assert got == expected, (
#                 f"A={A}, B={B}: expected {expected}, got {got}"
#             )
#             print (         f"{A} x {B} = {got}.")

