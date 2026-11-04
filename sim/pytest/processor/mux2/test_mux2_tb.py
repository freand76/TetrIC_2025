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
        self._dut.sel.value = 0

    def setA(self, A):
        self._dut.A.value = A
        self._circuit.run(ms=1)

    def setB(self, B):
        self._dut.B.value = B
        self._circuit.run(ms=1)

    def sel(self, sel):
        self._dut.sel.value = sel
        self._circuit.run(ms=1)

    def out(self):
        return self._dut.O.value


@pytest.fixture(scope="module")
def dut_tester(rtl_path):
    circuit = Circuit()

    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{rtl_path}/mux2.v",
        ],
        "mux2",
    )
    yosys_netlist = YosysNetlist(**dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_mux(dut_tester):
    """Test MUX"""
    dut_tester.sel(0)
    dut_tester.setA(0x12345678)
    dut_tester.setB(0xDEADBEEF)

    assert dut_tester.out() == 0x12345678
    dut_tester.setA(0x11112222)
    assert dut_tester.out() == 0x11112222

    dut_tester.sel(1)
    assert dut_tester.out() == 0xDEADBEEF
    dut_tester.setA(0xFFFFFFFF)
    assert dut_tester.out() == 0xDEADBEEF
    dut_tester.setB(0x10101010)
    assert dut_tester.out() == 0x10101010

    dut_tester.sel(0)
    assert dut_tester.out() == 0xFFFFFFFF
    dut_tester.setB(0x99887766)
    assert dut_tester.out() == 0xFFFFFFFF

    dut_tester.sel(1)
    assert dut_tester.out() == 0x99887766
