# Copyright (c) Fredrik Andersson, 2024
# All rights reserved

import pytest
from digsim.circuit import Circuit
from digsim.circuit.components import YosysComponent
from digsim.synth import Synthesis
from digsim.utils import YosysNetlist


class DutTester:
    def __init__(self, circuit, dut):
        self._circuit = circuit
        self._dut = dut
        self._dut.A.value = 0
        self._dut.B.value = 0
        self._dut.ctrl.value = 0

    def ctrl(self, alu_control):
        self._dut.ctrl.value = alu_control
        self._circuit.run(ms=1)

    def run(self, A, B):
        self._dut.A.value = A
        self._dut.B.value = B
        self._circuit.run(ms=1)
        return self._dut.O.value

    def n_zero(self):
        return self._dut.n_zero.value

    def overflow(self):
        return self._dut.overflow.value


@pytest.fixture(scope="module")
def dut_tester(rtl_path):
    circuit = Circuit()

    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{rtl_path}/alu.v",
            f"{rtl_path}/rshifter.v",
            f"{rtl_path}/lshifter.v",
        ],
        "alu",
    )
    yosys_netlist = YosysNetlist(**dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_zero(dut_tester):
    """Test ZERO operation"""
    dut_tester.ctrl(0)  # Set operation to ZERO
    assert 0 == dut_tester.run(0, 0)
    assert 0 == dut_tester.run(0xFFFFFFFF, 0xFFFFFFFF)
    assert 0 == dut_tester.run(0x12345678, 0xFFFF0000)
    assert 0 == dut_tester.run(0x0000FFFF, 0x12345678)


def test_jal(dut_tester):
    """Test ZERO operation"""
    dut_tester.ctrl(3)  # Set operation to JAL/JALR

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0xFFFFFFFF == dut_tester.run(0xFFFFFFFF, 0xFFFFFFFF)
    assert 0x12345678 == dut_tester.run(0x12345678, 0xFFFF0000)
    assert 0x0000FFFF == dut_tester.run(0x0000FFFF, 0x12345678)


def test_srav(dut_tester):
    """Test SRAV operation"""
    dut_tester.ctrl(7)  # Set operation to SRAV

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12345678 == dut_tester.run(0, 0x12345678)
    assert 0x01234567 == dut_tester.run(4, 0x12345678)
    assert 0x00001234 == dut_tester.run(16, 0x12345678)

    val = 0x80000000
    for idx in range(32):
        val = val | (0x80000000 >> idx)
        assert val == dut_tester.run(idx, 0x80000000)


def test_sll(dut_tester):
    """Test SLL operation"""
    dut_tester.ctrl(8)  # Set operation to SLL

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12345678 == dut_tester.run(0x12345678, 0 << 6)
    assert 0x23456780 == dut_tester.run(0x12345678, 4 << 6)
    assert 0x56780000 == dut_tester.run(0x12345678, 16 << 6)

    for idx in range(32):
        assert 0x00000001 << idx == dut_tester.run(0x00000001, idx << 6)


def test_srl(dut_tester):
    """Test SRL operation"""
    dut_tester.ctrl(10)  # Set operation to SRL

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12345678 == dut_tester.run(0x12345678, 0 << 6)
    assert 0x01234567 == dut_tester.run(0x12345678, 4 << 6)
    assert 0x00001234 == dut_tester.run(0x12345678, 16 << 6)

    for idx in range(32):
        assert 0x80000000 >> idx == dut_tester.run(0x80000000, idx << 6)


def test_sra(dut_tester):
    """Test SRA operation"""
    dut_tester.ctrl(11)  # Set operation to SRA

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12345678 == dut_tester.run(0x12345678, 0 << 6)
    assert 0x01234567 == dut_tester.run(0x12345678, 4 << 6)
    assert 0x00001234 == dut_tester.run(0x12345678, 16 << 6)

    val = 0x80000000
    for idx in range(32):
        val = val | (0x80000000 >> idx)
        assert val == dut_tester.run(0x80000000, idx << 6)


def test_sllv(dut_tester):
    """Test SLLV operation"""
    dut_tester.ctrl(12)  # Set operation to SLLV

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12345678 == dut_tester.run(0, 0x12345678)
    assert 0x23456780 == dut_tester.run(4, 0x12345678)
    assert 0x56780000 == dut_tester.run(16, 0x12345678)

    for idx in range(32):
        assert 0x00000001 << idx == dut_tester.run(idx, 0x00000001)


def test_srlv(dut_tester):
    """Test SRLV operation"""
    dut_tester.ctrl(14)  # Set operation to SRLV

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12345678 == dut_tester.run(0, 0x12345678)
    assert 0x01234567 == dut_tester.run(4, 0x12345678)
    assert 0x00001234 == dut_tester.run(16, 0x12345678)

    for idx in range(32):
        assert 0x80000000 >> idx == dut_tester.run(idx, 0x80000000)


def test_lui(dut_tester):
    """Test LUI operation"""
    dut_tester.ctrl(15)  # Set operation to LUI

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x12340000 == dut_tester.run(0, 0x1234)
    assert 0x12340000 == dut_tester.run(0xFEFEFEFE, 0x1234)
    assert 0xFFFF0000 == dut_tester.run(0, 0xFFFF)


def test_add(dut_tester):
    """Test ADD operation"""
    dut_tester.ctrl(16)  # Set operation to ADD / ADDI / LW / SW

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x00000300 == dut_tester.run(0x100, 0x200)
    assert 0x30000000 == dut_tester.run(0x10000000, 0x20000000)

    # TODO Should give overflow
    assert 0x80000001 == dut_tester.run(0x7FFFFFFF, 2)

    # TODO Should NOT give overflow
    assert 0x7FFFFFF2 == dut_tester.run(0x7FFFFFF0, 2)


def test_addu(dut_tester):
    """Test ADDU operation"""
    dut_tester.ctrl(17)  # Set operation to ADDU / ADDUI

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x00000300 == dut_tester.run(0x100, 0x200)
    assert 0x30000000 == dut_tester.run(0x10000000, 0x20000000)

    # TODO Should give overflow
    assert 0x00000001 == dut_tester.run(0xFFFFFFFF, 2)

    # TODO Should NOT give overflow
    assert 0xFFFFFFF2 == dut_tester.run(0xFFFFFFF0, 2)


def test_sub(dut_tester):
    """Test SUB operation"""
    dut_tester.ctrl(18)  # Set operation to SUB, BEQ, BNE, BGE, BGT

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x00000200 == dut_tester.run(0x300, 0x100)
    assert 0x20000000 == dut_tester.run(0x30000000, 0x10000000)

    # TODO Should give overflow (from largest neg to larges pos)
    assert 0x7FFFFFFF == dut_tester.run(0x80000000, 1)

    # TODO Should NOT give overflow (going from 0 to -1)
    assert 0xFFFFFFFF == dut_tester.run(0, 1)


def test_subu(dut_tester):
    """Test SUBU operation"""
    dut_tester.ctrl(19)  # Set operation to SUBU

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x00000200 == dut_tester.run(0x300, 0x100)
    assert 0x20000000 == dut_tester.run(0x30000000, 0x10000000)

    # TODO Should give overflow
    assert 0xFFFFFFFF == dut_tester.run(0, 1)

    # TODO Should NOT give overflow
    assert 0xFFFFFFFE == dut_tester.run(0xFFFFFFFF, 1)
    assert 0x00000000 == dut_tester.run(0xFFFFFFFF, 0xFFFFFFFF)


def test_and(dut_tester):
    """Test AND operation"""
    dut_tester.ctrl(20)  # Set operation to AND

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0x00000000 == dut_tester.run(0xFFFFFFFF, 0)
    assert 0x00000000 == dut_tester.run(0, 0xFFFFFFFF)
    assert 0xFFFFFFFF == dut_tester.run(0xFFFFFFFF, 0xFFFFFFFF)
    assert 0x12340000 == dut_tester.run(0x12345678, 0xFFFF0000)
    assert 0x00005678 == dut_tester.run(0x0000FFFF, 0x12345678)


def test_or(dut_tester):
    """Test OR operation"""
    dut_tester.ctrl(21)  # Set operation to OR

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0xFFFFFFFF == dut_tester.run(0xFFFF0000, 0x0000FFFF)
    assert 0x11111111 == dut_tester.run(0x11111111, 0)
    assert 0x22222222 == dut_tester.run(0, 0x22222222)
    assert 0x3333333F == dut_tester.run(0x33333333, 0xF)


def test_xor(dut_tester):
    """Test XOR operation"""
    dut_tester.ctrl(22)  # Set operation to XOR

    assert 0x00000000 == dut_tester.run(0, 0)
    assert 0xFFFFFFFF == dut_tester.run(0, 0xFFFFFFFF)
    assert 0xFFFFFFFF == dut_tester.run(0xFFFFFFFF, 0)
    assert 0x33333333 == dut_tester.run(0xCCCCCCCC, 0xFFFFFFFF)
    assert 0xCCCC3333 == dut_tester.run(0xFFFF0000, 0x33333333)


def test_nor(dut_tester):
    """Test NOR operation"""
    dut_tester.ctrl(23)  # Set operation to NOR

    assert 0xFFFFFFFF == dut_tester.run(0, 0)
    assert 0x00000000 == dut_tester.run(0, 0xFFFFFFFF)
    assert 0xEEEEEEEE == dut_tester.run(0x00001111, 0x11110000)


def test_n_zero_flag(dut_tester):
    """Test the n_zero flag"""
    dut_tester.ctrl(22)  # Set operation to XOR

    assert 0x00000000 == dut_tester.run(0, 0)
    assert dut_tester.n_zero() == 0

    assert 0x11111111 == dut_tester.run(0, 0x11111111)
    assert dut_tester.n_zero() == 1


def test_overflow_flag(dut_tester):
    """Test the n_zero flag"""
    dut_tester.ctrl(18)  # Set operation to SUB, BEQ, BNE, BGE, BGT

    assert 0x00000000 == dut_tester.run(0, 0)
    # Overflow is 0 because 0 is not greater than 0
    assert dut_tester.overflow() == 0

    assert 20 == dut_tester.run(30, 10)
    # Overflow is 0 because 10 is not greater than 30
    assert dut_tester.overflow() == 0

    assert 0xFFFFFFFF == dut_tester.run(0, 1)
    # Overflow is 1 because 1 is not greater than 0
    assert dut_tester.overflow() == 1

    # Overflow BUG: BGE / BGT only handles positive numbers
    # Overflow is 0 even if 6 is greater than -10
    assert 0xFFFFFFF0 == dut_tester.run(-10 & 0xFFFFFFFF, 6)  # ports take unsigned values
    assert dut_tester.overflow() == 0
