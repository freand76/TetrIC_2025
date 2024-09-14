# Copyright (c) Fredrik Andersson, 2024
# All rights reserved

import os
import pytest

from digsim.circuit import Circuit
from digsim.circuit.components import YosysComponent
from digsim.synth import Synthesis
from digsim.utils import YosysNetlist


class AluTester:
    def __init__(self, circuit, alu):
        self._circuit = circuit
        self._alu = alu
        self._alu.clk.value = 0
        self._alu.nreset.value = 0
        self._alu.A.value = 0
        self._alu.B.value = 0
        self._alu.ctrl.value = 0
        self.reset()
        self.clock()

    def reset(self):
        self._alu.nreset.value = 0
        self._circuit.run(ms=1)
        self._alu.nreset.value = 1
        self._circuit.run(ms=1)

    def clock(self):
        self._alu.clk.value = 1
        self._circuit.run(ms=1)
        self._alu.clk.value = 0
        self._circuit.run(ms=1)

    def ctrl(self, alu_control):
        self._alu.ctrl.value = alu_control
        self._circuit.run(ms=1)

    def run(self, A, B):
        self._alu.A.value = A
        self._alu.B.value = B
        self._circuit.run(ms=1)
        return self._alu.O.value


@pytest.fixture(scope="module")
def current_path():
    return f"{os.path.dirname(os.path.abspath(__file__))}"


@pytest.fixture(scope="module")
def alu_tester(current_path):
    circuit = Circuit()

    # Synth ALU
    alu = YosysComponent(circuit)
    alu_synthesis = Synthesis(
        [
            f"{current_path}/alu.v",
            f"{current_path}/rshifter.v",
            f"{current_path}/lshifter.v",
        ],
        "alu",
    )
    yosys_netlist = YosysNetlist()
    yosys_netlist.from_dict(alu_synthesis.synth_to_dict())
    alu.create_from_netlist(yosys_netlist)

    return AluTester(circuit, alu)


def test_zero(alu_tester):
    """Test ZERO operation"""
    alu_tester.ctrl(0)  # Set operation to ZERO
    assert 0 == alu_tester.run(0, 0)
    assert 0 == alu_tester.run(0xFFFFFFFF, 0xFFFFFFFF)
    assert 0 == alu_tester.run(0x12345678, 0xFFFF0000)
    assert 0 == alu_tester.run(0x0000FFFF, 0x12345678)


def test_jal(alu_tester):
    """Test ZERO operation"""
    alu_tester.ctrl(3)  # Set operation to JAL/JALR

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0xFFFFFFFF == alu_tester.run(0xFFFFFFFF, 0xFFFFFFFF)
    assert 0x12345678 == alu_tester.run(0x12345678, 0xFFFF0000)
    assert 0x0000FFFF == alu_tester.run(0x0000FFFF, 0x12345678)


def test_srav(alu_tester):
    """Test SRAV operation"""
    alu_tester.ctrl(7)  # Set operation to SRAV

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12345678 == alu_tester.run(0, 0x12345678)
    assert 0x01234567 == alu_tester.run(4, 0x12345678)
    assert 0x00001234 == alu_tester.run(16, 0x12345678)

    val = 0x80000000
    for idx in range(32):
        val = val | (0x80000000 >> idx)
        assert val == alu_tester.run(idx, 0x80000000)


def test_sll(alu_tester):
    """Test SLL operation"""
    alu_tester.ctrl(8)  # Set operation to SLL

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12345678 == alu_tester.run(0x12345678, 0 << 6)
    assert 0x23456780 == alu_tester.run(0x12345678, 4 << 6)
    assert 0x56780000 == alu_tester.run(0x12345678, 16 << 6)

    for idx in range(32):
        assert 0x00000001 << idx == alu_tester.run(0x00000001, idx << 6)


def test_srl(alu_tester):
    """Test SRL operation"""
    alu_tester.ctrl(10)  # Set operation to SRL

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12345678 == alu_tester.run(0x12345678, 0 << 6)
    assert 0x01234567 == alu_tester.run(0x12345678, 4 << 6)
    assert 0x00001234 == alu_tester.run(0x12345678, 16 << 6)

    for idx in range(32):
        assert 0x80000000 >> idx == alu_tester.run(0x80000000, idx << 6)


def test_sra(alu_tester):
    """Test SRA operation"""
    alu_tester.ctrl(11)  # Set operation to SRA

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12345678 == alu_tester.run(0x12345678, 0 << 6)
    assert 0x01234567 == alu_tester.run(0x12345678, 4 << 6)
    assert 0x00001234 == alu_tester.run(0x12345678, 16 << 6)

    val = 0x80000000
    for idx in range(32):
        val = val | (0x80000000 >> idx)
        assert val == alu_tester.run(0x80000000, idx << 6)


def test_sllv(alu_tester):
    """Test SLLV operation"""
    alu_tester.ctrl(12)  # Set operation to SLLV

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12345678 == alu_tester.run(0, 0x12345678)
    assert 0x23456780 == alu_tester.run(4, 0x12345678)
    assert 0x56780000 == alu_tester.run(16, 0x12345678)

    for idx in range(32):
        assert 0x00000001 << idx == alu_tester.run(idx, 0x00000001)


def test_srlv(alu_tester):
    """Test SRLV operation"""
    alu_tester.ctrl(14)  # Set operation to SRLV

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12345678 == alu_tester.run(0, 0x12345678)
    assert 0x01234567 == alu_tester.run(4, 0x12345678)
    assert 0x00001234 == alu_tester.run(16, 0x12345678)

    for idx in range(32):
        assert 0x80000000 >> idx == alu_tester.run(idx, 0x80000000)


def test_lui(alu_tester):
    """Test LUI operation"""
    alu_tester.ctrl(15)  # Set operation to LUI

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x12340000 == alu_tester.run(0, 0x1234)
    assert 0x12340000 == alu_tester.run(0xFEFEFEFE, 0x1234)
    assert 0xFFFF0000 == alu_tester.run(0, 0xFFFF)


def test_add(alu_tester):
    """Test ADD operation"""
    alu_tester.ctrl(16)  # Set operation to ADD / ADDI / LW / SW

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x00000300 == alu_tester.run(0x100, 0x200)
    assert 0x30000000 == alu_tester.run(0x10000000, 0x20000000)

    # TODO Should give overflow
    assert 0x80000001 == alu_tester.run(0x7FFFFFFF, 2)

    # TODO Should NOT give overflow
    assert 0x7FFFFFF2 == alu_tester.run(0x7FFFFFF0, 2)


def test_addu(alu_tester):
    """Test ADDU operation"""
    alu_tester.ctrl(17)  # Set operation to ADDU / ADDUI

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x00000300 == alu_tester.run(0x100, 0x200)
    assert 0x30000000 == alu_tester.run(0x10000000, 0x20000000)

    # TODO Should give overflow
    assert 0x00000001 == alu_tester.run(0xFFFFFFFF, 2)

    # TODO Should NOT give overflow
    assert 0xFFFFFFF2 == alu_tester.run(0xFFFFFFF0, 2)


def test_sub(alu_tester):
    """Test SUB operation"""
    alu_tester.ctrl(18)  # Set operation to SUB, BEQ, BNE, BGE, BGT

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x00000200 == alu_tester.run(0x300, 0x100)
    assert 0x20000000 == alu_tester.run(0x30000000, 0x10000000)

    # TODO Should give overflow (from largest neg to larges pos)
    assert 0x7FFFFFFF == alu_tester.run(0x80000000, 1)

    # TODO Should NOT give overflow (going from 0 to -1)
    assert 0xFFFFFFFF == alu_tester.run(0, 1)


def test_subu(alu_tester):
    """Test SUBU operation"""
    alu_tester.ctrl(19)  # Set operation to SUBU

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x00000200 == alu_tester.run(0x300, 0x100)
    assert 0x20000000 == alu_tester.run(0x30000000, 0x10000000)

    # TODO Should give overflow
    assert 0xFFFFFFFF == alu_tester.run(0, 1)

    # TODO Should NOT give overflow
    assert 0xFFFFFFFE == alu_tester.run(0xFFFFFFFF, 1)
    assert 0x00000000 == alu_tester.run(0xFFFFFFFF, 0xFFFFFFFF)


def test_and(alu_tester):
    """Test AND operation"""
    alu_tester.ctrl(20)  # Set operation to AND

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0x00000000 == alu_tester.run(0xFFFFFFFF, 0)
    assert 0x00000000 == alu_tester.run(0, 0xFFFFFFFF)
    assert 0xFFFFFFFF == alu_tester.run(0xFFFFFFFF, 0xFFFFFFFF)
    assert 0x12340000 == alu_tester.run(0x12345678, 0xFFFF0000)
    assert 0x00005678 == alu_tester.run(0x0000FFFF, 0x12345678)


def test_or(alu_tester):
    """Test OR operation"""
    alu_tester.ctrl(21)  # Set operation to OR

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0xFFFFFFFF == alu_tester.run(0xFFFF0000, 0x0000FFFF)
    assert 0x11111111 == alu_tester.run(0x11111111, 0)
    assert 0x22222222 == alu_tester.run(0, 0x22222222)
    assert 0x3333333F == alu_tester.run(0x33333333, 0xF)


def test_xor(alu_tester):
    """Test XOR operation"""
    alu_tester.ctrl(22)  # Set operation to XOR

    assert 0x00000000 == alu_tester.run(0, 0)
    assert 0xFFFFFFFF == alu_tester.run(0, 0xFFFFFFFF)
    assert 0xFFFFFFFF == alu_tester.run(0xFFFFFFFF, 0)
    assert 0x33333333 == alu_tester.run(0xCCCCCCCC, 0xFFFFFFFF)
    assert 0xCCCC3333 == alu_tester.run(0xFFFF0000, 0x33333333)


def test_nor(alu_tester):
    """Test NOR operation"""
    alu_tester.ctrl(23)  # Set operation to NOR

    assert 0xFFFFFFFF == alu_tester.run(0, 0)
    assert 0x00000000 == alu_tester.run(0, 0xFFFFFFFF)
    assert 0xEEEEEEEE == alu_tester.run(0x00001111, 0x11110000)
