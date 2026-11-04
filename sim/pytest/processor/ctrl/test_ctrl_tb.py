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
        self._dut.instr.value = 0
        self._circuit.run(ms=1)

    def instr(self, instr):
        self._dut.instr.value = instr
        self._circuit.run(ms=1)

    def ife_ctrl(self):
        return self._dut.ife_ctrl.value

    def id_ctrl(self):
        return self._dut.id_ctrl.value

    def ex_ctrl(self):
        return self._dut.ex_ctrl.value

    def mem_ctrl(self):
        return self._dut.mem_ctrl.value

    def wb_ctrl(self):
        return self._dut.wb_ctrl.value


@pytest.fixture(scope="module")
def dut_tester(rtl_path):
    circuit = Circuit()

    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{rtl_path}/ctrl.v",
        ],
        "ctrl",
    )
    yosys_netlist = YosysNetlist(**dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_nop(dut_tester):
    """Test NOP instruction"""

    dut_tester.instr(0x00000000)

    assert 0 == dut_tester.ife_ctrl()
    assert 0 == dut_tester.id_ctrl()
    assert 0x68 == dut_tester.ex_ctrl()
    assert 0 == dut_tester.mem_ctrl()
    assert 0x1 == dut_tester.wb_ctrl()


def test_j(dut_tester):
    """Test J instruction"""
    dut_tester.instr(0x08000000)

    assert 1 == dut_tester.ife_ctrl()


def test_jal(dut_tester):
    """Test JAL instruction"""
    dut_tester.instr(0x0C000000)

    assert 1 == dut_tester.ife_ctrl()


def test_mfc3(dut_tester):
    """Test MFC3 instruction"""

    dut_tester.instr(0x4C000000)

    assert 0 == dut_tester.ife_ctrl()
    assert 0 == dut_tester.id_ctrl()
    assert 0x5F == dut_tester.ex_ctrl()
    assert 0 == dut_tester.mem_ctrl()
    assert 0x1 == dut_tester.wb_ctrl()


def test_addu(dut_tester):
    """Test ADDU instruction"""

    dut_tester.instr(0x00000021)

    assert 0 == dut_tester.ife_ctrl()
    assert 0 == dut_tester.id_ctrl()
    assert 0x51 == dut_tester.ex_ctrl()
    assert 0 == dut_tester.mem_ctrl()
    assert 0x1 == dut_tester.wb_ctrl()


def test_lw(dut_tester):
    """Test LW instruction"""

    dut_tester.instr(0x8C000000)

    assert 0 == dut_tester.ife_ctrl()
    assert 1 == dut_tester.id_ctrl()
    assert 0x30 == dut_tester.ex_ctrl()
    assert 0x2 == dut_tester.mem_ctrl()
    assert 0x3 == dut_tester.wb_ctrl()
