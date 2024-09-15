# Copyright (c) Fredrik Andersson, 2024
# All rights reserved

import os
import pytest

from digsim.circuit import Circuit
from digsim.circuit.components import YosysComponent


class DutTester:
    def __init__(self, circuit, dut):
        self._circuit = circuit
        self._dut = dut
        self._dut.clk.value = 0
        self._dut.n_reset.value = 0
        self._dut.data_in.value = 0
        self._dut.n_ext_stall.value = 0
        self._dut.imem_ack.value = 0
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

    def imem_ack(self, ack):
        self._dut.imem_ack.value = ack
        self._circuit.run(ms=1)

    def n_ext_stall(self, n_stall):
        self._dut.n_ext_stall.value = n_stall
        self._circuit.run(ms=1)

    def data_in(self, data):
        self._dut.data_in.value = data
        self._circuit.run(ms=1)

    def debug_pc(self):
        return self._dut.debug_pc.value

    def data_out(self):
        return self._dut.data_out.value

    def imem_addr_out(self):
        return self._dut.imem_addr_out.value


@pytest.fixture(scope="module")
def current_path():
    return f"{os.path.dirname(os.path.abspath(__file__))}"


@pytest.fixture(scope="module")
def dut_tester(current_path):
    circuit = Circuit()

    # Load DUT
    dut = YosysComponent(circuit, f"{current_path}/processor.json")
    circuit.init()
    yield DutTester(circuit, dut)


def test_zero(dut_tester):
    """Test ZERO operation"""
    dut_tester.reset()
    dut_tester.imem_ack(1)
    dut_tester.n_ext_stall(1)
    dut_tester.data_in(0xFEDEBEDA)

    for x in range(10):
        print(
            "PC",
            dut_tester.debug_pc(),
            dut_tester.imem_addr_out(),
            hex(dut_tester.data_out()),
        )
        dut_tester.clock()

    dut_tester.n_ext_stall(0)

    for x in range(10):
        print("PC", dut_tester.debug_pc(), dut_tester.imem_addr_out())
        dut_tester.clock()
