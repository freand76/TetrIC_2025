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
        self._dut.clk.value = 0
        self._dut.n_reset.value = 0
        self._dut.r1_sel.value = 0
        self._dut.r2_sel.value = 0
        self._dut.rd_sel.value = 0
        self._dut.w_enable.value = 0
        self._dut.w_data.value = 0
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

    def read_registerA(self, r1_sel):
        self._dut.r1_sel.value = r1_sel
        self._circuit.run(ms=1)
        return self._dut.r1_data.value

    def read_registerB(self, r2_sel):
        self._dut.r2_sel.value = r2_sel
        self._circuit.run(ms=1)
        return self._dut.r2_data.value

    def write_register(self, rd_sel, w_data):
        self._dut.rd_sel.value = rd_sel
        self._dut.w_data.value = w_data
        self._dut.w_enable.value = 1  # Set write enable
        self._circuit.run(ms=1)  # Let signals ripple to the DFF
        self.clock()  # Clock in the new value
        self._dut.w_enable.value = 0  # Clear write enable
        self._circuit.run(ms=1)


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
            f"{current_path}/regbank.v",
        ],
        "regbank",
    )
    yosys_netlist = YosysNetlist(**dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)
    circuit.init()

    yield DutTester(circuit, dut)


def test_reset_zero(dut_tester):
    """Test reset operation"""
    dut_tester.reset()

    for idx in range(32):
        assert 0 == dut_tester.read_registerA(idx)
        assert 0 == dut_tester.read_registerB(idx)

    for idx in range(32):
        dut_tester.write_register(idx, 0x12345678)

    for idx in range(1, 32):
        assert 0x12345678 == dut_tester.read_registerA(idx)
        assert 0x12345678 == dut_tester.read_registerB(idx)

    dut_tester.reset()

    for idx in range(32):
        assert 0 == dut_tester.read_registerA(idx)
        assert 0 == dut_tester.read_registerB(idx)


def test_write_single_register(dut_tester):
    """Test write single register"""
    dut_tester.reset()

    dut_tester.write_register(7, 0x12345678)

    for idx in range(0, 32):
        if idx == 7:
            assert 0x12345678 == dut_tester.read_registerA(idx)
            assert 0x12345678 == dut_tester.read_registerB(idx)
        else:
            assert 0 == dut_tester.read_registerA(idx)
            assert 0 == dut_tester.read_registerB(idx)


def test_write_register_zero(dut_tester):
    """Test write register zero"""
    dut_tester.reset()

    assert 0 == dut_tester.read_registerA(0)
    assert 0 == dut_tester.read_registerB(0)

    dut_tester.write_register(0, 0x12345678)

    assert 0 == dut_tester.read_registerA(0)
    assert 0 == dut_tester.read_registerB(0)
