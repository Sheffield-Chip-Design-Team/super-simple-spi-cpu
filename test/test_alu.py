import cocotb
from cocotb.triggers import Timer


def clear_ctrl(dut):
    """Helper: clear all ALU control signals."""
    dut.ADD.value = 0
    dut.SUB.value = 0
    dut.AND.value = 0
    dut.OR.value  = 0
    dut.XOR.value = 0
    dut.INV.value = 0
    dut.CLR.value = 0


@cocotb.test()
async def test_alu_add_basic(dut):
    """Check simple ADD without overflow."""
    clear_ctrl(dut)

    dut.in1.value = 5
    dut.in2.value = 7
    dut.ADD.value = 1

    await Timer(1, units="ns")

    assert int(dut.out.value) == 12, f"ADD: expected 12, got {int(dut.out.value)}"
    assert int(dut.overflow.value) == 0, "ADD: unexpected overflow"


@cocotb.test()
async def test_alu_add_overflow(dut):
    """Check ADD sets overflow on carry out."""
    clear_ctrl(dut)

    dut.in1.value = 0xFF
    dut.in2.value = 0x01
    dut.ADD.value = 1

    await Timer(1, units="ns")

    out = int(dut.out.value)
    ov  = int(dut.overflow.value)

    assert out == 0x00, f"ADD overflow: expected 0x00, got 0x{out:02X}"
    assert ov == 1, "ADD overflow: expected overflow=1"


@cocotb.test()
async def test_alu_sub_basic(dut):
    """Check simple SUB."""
    clear_ctrl(dut)

    dut.in1.value = 10
    dut.in2.value = 3
    dut.SUB.value = 1

    await Timer(1, units="ns")

    assert int(dut.out.value) == 7, f"SUB: expected 7, got {int(dut.out.value)}"
    # 10 - 3 should not overflow for unsigned
    assert int(dut.overflow.value) == 0, "SUB: unexpected overflow"


@cocotb.test()
async def test_alu_and_or_xor_inv(dut):
    """Check AND / OR / XOR / INV on low 4 bits."""
    clear_ctrl(dut)

    # Use values that exercise bits 0..3
    dut.in1.value = 0b0000_1010  # low nibble = 1010
    dut.in2.value = 0b0000_0110  # low nibble = 0110

    # AND
    dut.AND.value = 1
    await Timer(1, units="ns")
    and_out = int(dut.out.value) & 0x0F
    assert and_out == 0b0010, f"AND: expected 0010, got {and_out:04b}"
    assert int(dut.overflow.value) == 0
    dut.AND.value = 0

    # OR
    dut.OR.value = 1
    await Timer(1, units="ns")
    or_out = int(dut.out.value) & 0x0F
    assert or_out == 0b1110, f"OR: expected 1110, got {or_out:04b}"
    assert int(dut.overflow.value) == 0
    dut.OR.value = 0

    # XOR
    dut.XOR.value = 1
    await Timer(1, units="ns")
    xor_out = int(dut.out.value) & 0x0F
    assert xor_out == 0b1100, f"XOR: expected 1100, got {xor_out:04b}"
    assert int(dut.overflow.value) == 0
    dut.XOR.value = 0

    # INV (on in1)
    dut.INV.value = 1
    await Timer(1, units="ns")
    inv_out = int(dut.out.value) & 0x0F
    # in1 low nibble = 1010 → invert = 0101
    assert inv_out == 0b0101, f"INV: expected 0101, got {inv_out:04b}"
    assert int(dut.overflow.value) == 0
    dut.INV.value = 0


@cocotb.test()
async def test_alu_clr_and_nop(dut):
    """Check CLR and NOP (no control signals)."""
    clear_ctrl(dut)

    # NOP: no control → out should be 0 (per your default assignment)
    dut.in1.value = 0xAA
    dut.in2.value = 0x55

    await Timer(1, units="ns")
    assert int(dut.out.value) == 0, f"NOP: expected 0, got {int(dut.out.value)}"
    assert int(dut.overflow.value) == 0

    # CLR: explicitly force outputs to 0
    dut.CLR.value = 1
    await Timer(1, units="ns")
    assert int(dut.out.value) == 0, f"CLR: expected 0, got {int(dut.out.value)}"
    assert int(dut.overflow.value) == 0
