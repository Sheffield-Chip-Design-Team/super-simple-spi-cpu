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
async def test_spi_protocol_first_transaction(dut):
    """
    Check the SPI protocol for the first instruction fetch.

    From the top level we can see:

      - CS   = uio_out[0]
      - MOSI = uio_out[1]
      - SCK  = uio_out[3]

    We expect the first SPI transaction after reset to contain:
      - Command 0x03 (READ)
      - Address 0x0000 (first byte in external SPI RAM)

    Because we are sampling at clk-rate rather than perfect SCK phase,
    we allow for a few-bit alignment error and slide a window over the
    captured MOSI bits to find the cmd+address frame.
    """

    # Let reset + RAM preload finish
    await wait_for_settle(dut)

    uio = dut.uio_out

    # --- Wait for CS to go low (start of first SPI transaction) ---

    cs_low_seen = False
    for _ in range(10_000):
        await RisingEdge(dut.clk)

        val = uio.value
        if not val.is_resolvable:
            continue

        cs = int(val[0])  # bit 0 = CS
        if cs == 0:
            cs_low_seen = True
            break

    assert cs_low_seen, "spi_cs_n never went low (no SPI transaction observed)"

    # --- Capture MOSI bits on SCK rising edges while CS is low ---

    bits = []
    max_bits = 48  # a bit more than cmd(8)+addr(16)+data(8)

    last_sck = 0

    for _ in range(50_000):  # plenty of cycles to see one transaction
        await RisingEdge(dut.clk)

        val = uio.value
        if not val.is_resolvable:
            continue

        cs   = int(val[0])  # CS
        mosi = int(val[1])  # MOSI
        sck  = int(val[3])  # SCK

        # If CS goes high, the transaction is over
        if cs == 1:
            # stop if we already saw some bits
            if len(bits) > 0:
                break
            else:
                # no bits yet, keep looking (maybe glitch)
                continue

        # Detect SCK rising edge (0 -> 1)
        if last_sck == 0 and sck == 1:
            bits.append(mosi)
            if len(bits) >= max_bits:
                break

        last_sck = sck

    # We expect at least command + address = 8 + 16 = 24 bits
    assert len(bits) >= 24, (
        f"Expected at least 24 bits in first SPI transaction, got {len(bits)}"
    )

    # Helper to decode big-endian bit slices into integers
    def bits_to_int(b):
        return int("".join(str(x) for x in b), 2)

    # --- Slide a window across bits to find cmd=0x03 and addr=0x0000 ---

    found = False
    best_cmd = None
    best_addr = None

    for start in range(0, len(bits) - 24 + 1):
        cmd_bits  = bits[start : start + 8]
        addr_bits = bits[start + 8 : start + 24]

        cmd  = bits_to_int(cmd_bits)
        addr = bits_to_int(addr_bits)

        # Remember one example for debug messages
        if best_cmd is None:
            best_cmd = cmd
            best_addr = addr

        if cmd == 0x03 and addr == 0x0000:
            found = True
            break

    assert found, (
        f"SPI: did not find cmd=0x03, addr=0x0000 in captured MOSI stream; "
        f"example window saw cmd=0x{best_cmd:02X}, addr=0x{best_addr:04X}"
    )
