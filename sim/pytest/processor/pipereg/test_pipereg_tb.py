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
        self._dut.n_reset.value = 0
        self._dut.clk.value = 0
        self._dut.enable.value = 0
        self._dut.D.value = 0
        self.reset()
        self.clock()

    def reset(self):
        self._dut.n_reset.value = 0
        self._circuit.run(ms=1)
        self._dut.n_reset.value = 1
        self._circuit.run(ms=1)

    def clock(self):
        self._dut.clk.value = 1
        self._circuit.run(ms=1)
        self._dut.clk.value = 0
        self._circuit.run(ms=1)

    def setD(self, D):
        self._dut.D.value = D
        self._circuit.run(ms=1)

    def enable(self, en):
        if en:
            self._dut.enable.value = 1
        else:
            self._dut.enable.value = 0
        self._circuit.run(ms=1)

    def out(self):
        return self._dut.Q.value


@pytest.fixture(scope="module")
def dut_tester(rtl_path):
    circuit = Circuit()

    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{rtl_path}/pipereg.v",
            f"{rtl_path}/pipereg_inst8.v",
        ],
        "pipereg_inst8",
    )
    yosys_netlist = YosysNetlist(**dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_reset(dut_tester):
    """Test reset"""
    dut_tester.reset()

    dut_tester.setD(0x12)
    dut_tester.enable(True)
    dut_tester.clock()
    dut_tester.enable(False)
    dut_tester.setD(0x34)
    dut_tester.clock()

    assert dut_tester.out() == 0x12

    dut_tester.reset()

    assert dut_tester.out() == 0


def test_changing_value(dut_tester):
    """Test reset"""
    dut_tester.reset()

    dut_tester.setD(0x12)
    dut_tester.enable(True)
    dut_tester.clock()

    assert dut_tester.out() == 0x12

    dut_tester.setD(0x34)
    dut_tester.clock()

    assert dut_tester.out() == 0x34

    dut_tester.setD(0x01)
    assert dut_tester.out() == 0x34
    dut_tester.setD(0x02)
    assert dut_tester.out() == 0x34
    dut_tester.setD(0x03)
    assert dut_tester.out() == 0x34
    dut_tester.setD(0x04)
    assert dut_tester.out() == 0x34
    dut_tester.clock()
    assert dut_tester.out() == 0x04
