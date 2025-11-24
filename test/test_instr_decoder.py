import cocotb
from cocotb.triggers import Timer


# Helper to read all control outputs into a dict for easier assertions
def get_ctrl(dut):
    return {
        "LDA":  int(dut.LDA.value),
        "LDB":  int(dut.LDB.value),
        "LDO":  int(dut.LDO.value),
        "LDSA": int(dut.LDSA.value),
        "LDSB": int(dut.LDSB.value),
        "LSH":  int(dut.LSH.value),
        "RSH":  int(dut.RSH.value),
        "CLR":  int(dut.CLR.value),
        "SNZA": int(dut.SNZA.value),
        "SNZS": int(dut.SNZS.value),
        "ADD":  int(dut.ADD.value),
        "SUB":  int(dut.SUB.value),
        "AND":  int(dut.AND.value),
        "OR":   int(dut.OR.value),
        "XOR":  int(dut.XOR.value),
        "INV":  int(dut.INV.value),
    }


@cocotb.test()
async def test_decoder_one_hot_all_opcodes(dut):
    """
    For instructionIn 0..15, exactly one control signal should be 1,
    matching the mapping in InstructionDecoder.
    """
    expected_names = {
        0:  "LDA",
        1:  "LDB",
        2:  "LDO",
        3:  "LDSA",
        4:  "LDSB",
        5:  "LSH",
        6:  "RSH",
        7:  "CLR",
        8:  "SNZA",
        9:  "SNZS",
        10: "ADD",
        11: "SUB",
        12: "AND",
        13: "OR",
        14: "XOR",
        15: "INV",
    }

    for opcode in range(16):
        dut.instructionIn.value = opcode
        await Timer(1, units="ns")

        ctrl = get_ctrl(dut)
        ones = [name for name, val in ctrl.items() if val == 1]

        assert len(ones) == 1, (
            f"Opcode {opcode}: expected exactly 1 control high, got {len(ones)}: {ones}"
        )

        expected = expected_names[opcode]
        assert ones[0] == expected, (
            f"Opcode {opcode}: expected {expected}=1, got {ones[0]}=1"
        )


@cocotb.test()
async def test_decoder_default_nop(dut):
    """
    For any opcode outside 0..15 (if width were larger), the decoder should produce NOP (all zeros).
    With 4-bit input we can't drive >15, but we can still check that
    no 'stray' states appear when changing inputs.
    """
    # Just toggle a few values and ensure outputs don't go X
    for opcode in [0, 5, 10, 15]:
        dut.instructionIn.value = opcode
        await Timer(1, units="ns")
        ctrl = get_ctrl(dut)
        # All values must be 0 or 1, but never X/Z
        for name, val in ctrl.items():
            assert val in (0, 1), f"{name} had invalid value {val}"
