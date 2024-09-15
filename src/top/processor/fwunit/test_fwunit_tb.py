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
        self._dut.r1_sel.value = 0
        self._dut.r2_sel.value = 0
        self._dut.mem_rd_sel.value = 0
        self._dut.wb_rd_sel.value = 0
        self._dut.mem_w_enable.value = 0
        self._dut.wb_w_enable.value = 0
        self._circuit.run(ms=1)

    def r1_sel(self, value):
        self._dut.r1_sel.value = value
        self._circuit.run(ms=1)

    def r2_sel(self, value):
        self._dut.r2_sel.value = value
        self._circuit.run(ms=1)

    def mem_rd_sel(self, value):
        self._dut.mem_rd_sel.value = value
        self._circuit.run(ms=1)

    def wb_rd_sel(self, value):
        self._dut.wb_rd_sel.value = value
        self._circuit.run(ms=1)

    def mem_w_enable(self, value):
        self._dut.mem_w_enable.value = value
        self._circuit.run(ms=1)

    def wb_w_enable(self, value):
        self._dut.wb_w_enable.value = value
        self._circuit.run(ms=1)

    def sel1(self):
        return self._dut.sel1.value

    def sel2(self):
        return self._dut.sel2.value


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
            f"{current_path}/fwunit.v",
        ],
        "fwunit",
    )
    yosys_netlist = YosysNetlist()
    yosys_netlist.from_dict(dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)

    circuit.init()
    yield DutTester(circuit, dut)


def test_no_forward(dut_tester):
    """Test no forward"""
    dut_tester.mem_w_enable(0)
    dut_tester.wb_w_enable(0)

    dut_tester.r1_sel(4)
    dut_tester.r2_sel(5)
    dut_tester.mem_rd_sel(4)

    assert 0 == dut_tester.sel1()
    assert 0 == dut_tester.sel2()


def test_forward_r1_mem(dut_tester):
    """Test forward r1 mem"""

    dut_tester.mem_w_enable(1)
    dut_tester.wb_w_enable(0)

    dut_tester.r1_sel(4)
    dut_tester.r2_sel(5)
    dut_tester.mem_rd_sel(4)

    assert 2 == dut_tester.sel1()
    assert 0 == dut_tester.sel2()

    dut_tester.wb_w_enable(1)
    assert 2 == dut_tester.sel1()
    assert 0 == dut_tester.sel2()


def test_forward_r2_mem(dut_tester):
    """Test forward r2 mem"""

    dut_tester.mem_w_enable(1)
    dut_tester.wb_w_enable(0)

    dut_tester.r1_sel(4)
    dut_tester.r2_sel(5)
    dut_tester.mem_rd_sel(5)

    assert 0 == dut_tester.sel1()
    assert 2 == dut_tester.sel2()

    dut_tester.wb_w_enable(1)
    assert 0 == dut_tester.sel1()
    assert 2 == dut_tester.sel2()


def test_forward_r1_wb(dut_tester):
    """Test forward r1 wb"""

    dut_tester.mem_w_enable(0)
    dut_tester.wb_w_enable(1)

    dut_tester.r1_sel(4)
    dut_tester.r2_sel(5)
    dut_tester.mem_rd_sel(4)

    assert 1 == dut_tester.sel1()
    assert 0 == dut_tester.sel2()


def test_forward_r2_wb(dut_tester):
    """Test forward r2 wb"""

    dut_tester.mem_w_enable(0)
    dut_tester.wb_w_enable(1)

    dut_tester.r1_sel(4)
    dut_tester.r2_sel(5)
    dut_tester.mem_rd_sel(5)

    assert 0 == dut_tester.sel1()
    assert 1 == dut_tester.sel2()
