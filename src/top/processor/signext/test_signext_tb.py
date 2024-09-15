# Copyright (c) Fredrik Andersson, 2024
# All rights reserved

import os
import pytest

from digsim.circuit import Circuit
from digsim.circuit.components import YosysComponent
from digsim.synth import Synthesis
from digsim.utils import YosysNetlist


class DutTester:
    def __init__(self, circuit, dut):
        self._circuit = circuit
        self._dut = dut
        self._dut.ctrl.value = 0
        self._dut.A.value = 0
        self._circuit.run(ms=1)

    def A(self, A):
        self._dut.A.value = A
        self._circuit.run(ms=1)

    def ctrl(self, ctrl):
        self._dut.ctrl.value = ctrl
        self._circuit.run(ms=1)

    def out(self):
        return self._dut.O.value


@pytest.fixture(scope="module")
def current_path():
    return f"{os.path.dirname(os.path.abspath(__file__))}"


@pytest.fixture(scope="module")
def dut_tester(current_path):
    circuit = Circuit()

    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{current_path}/signext.v",
        ],
        "signext",
    )
    yosys_netlist = YosysNetlist()
    yosys_netlist.from_dict(dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_signext(dut_tester):
    """Test sign_ext"""
    dut_tester.ctrl(0)

    dut_tester.A(0x0000FFFF)
    assert 0xFFFFFFFF == dut_tester.out()

    dut_tester.A(0x00007FFF)
    assert 0x7FFF == dut_tester.out()


def test_zero_ext(dut_tester):
    """Test zero_ext"""
    dut_tester.ctrl(1)

    dut_tester.A(0x0000FFFF)
    assert 0x0000FFFF == dut_tester.out()

    dut_tester.A(0x00007FFF)
    assert 0x00007FFF == dut_tester.out()

    dut_tester.ctrl(3)

    dut_tester.A(0x0000FFFF)
    assert 0x0000FFFF == dut_tester.out()

    dut_tester.A(0x00007FFF)
    assert 0x00007FFF == dut_tester.out()


def test_one_ext(dut_tester):
    """Test one ext"""
    dut_tester.ctrl(2)

    dut_tester.A(0x0000FFFF)
    assert 0xFFFFFFFF == dut_tester.out()

    dut_tester.A(0x00007FFF)
    assert 0xFFFF7FFF == dut_tester.out()
