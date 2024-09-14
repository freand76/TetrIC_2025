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
        self._dut.n_stall.value = 0
        self._dut.imem_ack.value = 0
        self._dut.instr_in.value = 0

    def instr_in(self, instr):
        self._dut.instr_in.value = instr
        self._circuit.run(ms=1)

    def ctrl(self, n_stall, imem_ack):
        self._dut.n_stall.value = n_stall
        self._dut.imem_ack.value = imem_ack
        self._circuit.run(ms=1)

    def out(self):
        return self._dut.instr_out.value


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
            f"{current_path}/instr_or_nop.v",
        ],
        "instr_or_nop",
    )
    yosys_netlist = YosysNetlist()
    yosys_netlist.from_dict(dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_zero_or_nop(dut_tester):
    """Test zero_or_nop"""
    dut_tester.instr_in(0xFEDEBEDA)

    dut_tester.ctrl(0, 0)
    assert 0 == dut_tester.out()

    dut_tester.ctrl(1, 0)
    assert 0 == dut_tester.out()

    dut_tester.ctrl(0, 1)
    assert 0 == dut_tester.out()

    dut_tester.ctrl(1, 1)
    assert 0xFEDEBEDA == dut_tester.out()

    dut_tester.instr_in(0x12345678)
    assert 0x12345678 == dut_tester.out()
