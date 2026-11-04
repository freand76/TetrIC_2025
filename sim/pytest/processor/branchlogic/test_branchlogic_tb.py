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
        self._dut.n_zero.value = 0
        self._dut.overflow.value = 0
        self._dut.ctrl.value = 0
        self._circuit.run(ms=1)

    def n_zero(self, n_zero):
        self._dut.n_zero.value = n_zero
        self._circuit.run(ms=1)

    def overflow(self, overflow):
        self._dut.overflow.value = overflow
        self._circuit.run(ms=1)

    def ctrl(self, ctrl):
        self._dut.ctrl.value = ctrl
        self._circuit.run(ms=1)

    def pcmux1_ctrl(self):
        return self._dut.pcmux1_ctrl.value

    def pcmux3_ctrl(self):
        return self._dut.pcmux3_ctrl.value


@pytest.fixture(scope="module")
def dut_tester(rtl_path):
    circuit = Circuit()

    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{rtl_path}/branchlogic.v",
        ],
        "branchlogic",
    )
    yosys_netlist = YosysNetlist(**dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_jump_register(dut_tester):
    """Test jump register JR/JALR"""

    dut_tester.ctrl(3)

    dut_tester.n_zero(0)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 1 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(0)
    dut_tester.overflow(1)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 1 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 1 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(1)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 1 == dut_tester.pcmux3_ctrl()


def test_beq(dut_tester):
    """Test BEQ"""
    dut_tester.ctrl(1)

    dut_tester.n_zero(0)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(0)
    dut_tester.overflow(1)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(0)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(1)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()


def test_bne(dut_tester):
    """Test BNE"""
    dut_tester.ctrl(2)

    dut_tester.n_zero(0)
    dut_tester.overflow(0)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(0)
    dut_tester.overflow(1)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(1)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()


def test_bge(dut_tester):
    """Test BGE"""
    dut_tester.ctrl(5)

    dut_tester.n_zero(0)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(0)
    dut_tester.overflow(1)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(1)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()


def test_bgt(dut_tester):
    """Test BGT"""
    dut_tester.ctrl(6)

    dut_tester.n_zero(0)
    dut_tester.overflow(0)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(0)
    dut_tester.overflow(1)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(0)
    assert 1 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()

    dut_tester.n_zero(1)
    dut_tester.overflow(1)
    assert 0 == dut_tester.pcmux1_ctrl()
    assert 0 == dut_tester.pcmux3_ctrl()
