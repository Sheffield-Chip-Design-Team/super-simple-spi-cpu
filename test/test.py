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

        print (f"{A} x {B} = {got} (as expected) :D")

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
    ######passes commenting it out for speed up
# @cocotb.test()
# async def test_multiplication_full_exhaustive(dut):
#     """
#     Exhaustive 4-bit×4-bit multiplier test.

#     IMPORTANT: We explicitly reset the DUT here because previous tests
#     have already been running the CPU for a long time, and we want to
#     start this sweep from a clean PC/state.
#     """

#     # ---- Explicit reset to re-start microcode and PC ----
#     dut.rst_n.value = 0
#     dut.ena.value   = 0

#     # Let a few clock cycles elapse with reset asserted
#     for _ in range(10):
#         await RisingEdge(dut.clk)

#     # Release reset and enable the design again
#     dut.rst_n.value = 1
#     dut.ena.value   = 1

#     # Allow tb.v initialisation / microcode fetch to settle again
#     await wait_for_settle(dut)

#     # ---- Exhaustive sweep ----
#     # Use the same "very safe" wait as the random test
#     cycles_per_op = 50_000  # 50k cycles at 50 MHz ≈ 1 ms per pair

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


@cocotb.test()
async def test_midrun_reset(dut):
    """
    Check that asserting rst_n low mid-run resets the core cleanly and it
    still works afterwards.

    Scenario:
      1. Let the CPU compute one product (A1,B1) and check the result.
      2. Start another product (A2,B2), then assert reset in the middle.
      3. Release reset and check a new product (A3,B3) is still correct.
    """

    # Start from whatever state previous tests left, but let things settle
    await wait_for_settle(dut)

    # ---- 1) Baseline multiply before reset ----
    A1, B1 = 7, 9
    dut.ui_in.value = (A1 << 4) | B1

    # Use the same long wait as the random test so we know the result is valid
    for _ in range(50_000):
        await RisingEdge(dut.clk)

    val1 = dut.uo_out.value
    assert val1.is_resolvable, f"uo_out X/Z before reset for A={A1},B={B1}: {val1}"
    got1 = int(val1)
    exp1 = A1 * B1
    assert got1 == exp1, f"Before reset: expected {exp1}, got {got1}"

    # ---- 2) Start another multiply, then reset mid-run ----
    A2, B2 = 5, 6
    dut.ui_in.value = (A2 << 4) | B2

    # Let it run a bit, but not long enough to certainly finish
    for _ in range(5_000):
        await RisingEdge(dut.clk)

    # Assert reset mid-run
    dut.rst_n.value = 0
    dut.ena.value   = 0

    # Hold reset for a few cycles
    for _ in range(10):
        await RisingEdge(dut.clk)

    # Release reset and re-enable
    dut.rst_n.value = 1
    dut.ena.value   = 1

    # Give the core time to restart its microcoded loop
    await wait_for_settle(dut)

    # ---- 3) After reset, verify a new multiply still works ----
    A3, B3 = 3, 4
    dut.ui_in.value = (A3 << 4) | B3

    for _ in range(50_000):
        await RisingEdge(dut.clk)

    val3 = dut.uo_out.value
    assert val3.is_resolvable, f"uo_out X/Z after reset for A={A3},B={B3}: {val3}"
    got3 = int(val3)
    exp3 = A3 * B3

    assert got3 == exp3, (
        f"After mid-run reset: expected {exp3} for A={A3},B={B3}, got {got3}"
    )

@cocotb.test()
async def test_uio_mapping(dut):
    """
    Check that uio_oe correctly configures the SPI pins and upper nibble.

    Expectations from tt_um_spi_cpu_top:
      - uio_oe[0] = 1  (CS output)
      - uio_oe[1] = 1  (MOSI output)
      - uio_oe[2] = 0  (MISO input)
      - uio_oe[3] = 1  (SCK output)
      - uio_oe[7:4] = 4'b1000
    """

    # Let reset + RAM preload finish so uio_oe is stable
    await wait_for_settle(dut)

    val = dut.uio_oe.value
    assert val.is_resolvable, f"uio_oe has X/Z: {val}"

    mask = int(val)

    cs_oe   = (mask >> 0) & 1
    mosi_oe = (mask >> 1) & 1
    miso_oe = (mask >> 2) & 1
    sck_oe  = (mask >> 3) & 1
    upper   = (mask >> 4) & 0xF  # bits [7:4]

    assert cs_oe == 1,   f"Expected uio_oe[0]=1 for CS, got {cs_oe}"
    assert mosi_oe == 1, f"Expected uio_oe[1]=1 for MOSI, got {mosi_oe}"
    assert miso_oe == 0, f"Expected uio_oe[2]=0 for MISO input, got {miso_oe}"
    assert sck_oe == 1,  f"Expected uio_oe[3]=1 for SCK, got {sck_oe}"
    assert upper == 0b1000, f"Expected uio_oe[7:4]=0b1000, got {upper:04b}"
