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

      - CS  = uio_out[0]
      - MOSI = uio_out[1]
      - SCK  = uio_out[3]

    We expect the first SPI transaction after reset to be:
      - Command 0x03 (READ)
      - Address 0x0000 (first byte in external SPI RAM)

    This tests:
      - spi_read_byte's shift logic
      - MOSI bit ordering and SCK timing
      - correct use of command 0x03 and address 0x0000
    """

    await wait_for_settle(dut)

    cs   = dut.uio_out[0]
    mosi = dut.uio_out[1]
    sck  = dut.uio_out[3]

    # Wait (up to some cycles) for CS to go low (start of first SPI transaction)
    for _ in range(10_000):
        await RisingEdge(dut.clk)
        if cs.value.is_resolvable and int(cs.value) == 0:
            break
    else:
        assert False, "spi_cs_n never went low (no SPI transaction observed)"

    # Now CS is low: capture MOSI bits on SCK rising edges
    bits = []

    # We expect: 8 bits command + 16 bits address + 8 bits data = 32 bits.
    # We only *need* the first 24 bits (command+address) for this test.
    max_bits = 32
    for _ in range(max_bits):
        # Wait for a rising edge on SCK
        await RisingEdge(sck)

        # If CS has gone high again, the transaction is over
        if cs.value.is_resolvable and int(cs.value) == 1:
            break

        # Sample MOSI bit (Mode 0: data is valid around rising edge)
        if not mosi.value.is_resolvable:
            # treat X/Z as 0 for this purpose
            bits.append(0)
        else:
            bits.append(int(mosi.value))

    # We expect at least command + address = 8 + 16 = 24 bits
    assert len(bits) >= 24, (
        f"Expected at least 24 bits in first SPI transaction, got {len(bits)}"
    )

    # Decode big-endian bits into integers
    def bits_to_int(b):
        return int("".join(str(x) for x in b), 2)

    cmd_bits  = bits[0:8]
    addr_bits = bits[8:24]

    cmd  = bits_to_int(cmd_bits)
    addr = bits_to_int(addr_bits)

    assert cmd == 0x03, f"SPI: expected READ command 0x03, got 0x{cmd:02X}"
    assert addr == 0x0000, f"SPI: expected first address 0x0000, got 0x{addr:04X}"
