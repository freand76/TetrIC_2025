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
        self._dut.address.value = 0
        self._dut.read.value = 0
        self._dut.spi_miso.value = 0
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

    def set_address(self, address):
        self._dut.address.value = address
        self._circuit.run(ms=1)

    def set_read(self, read):
        self._dut.read.value = read
        self._circuit.run(ms=1)

    def set_miso(self, miso):
        self._dut.spi_miso.value = miso

    def spics(self):
        return self._dut.spi_cs.value

    def sclk(self):
        return self._dut.spi_clk.value

    def mosi(self):
        return self._dut.spi_mosi.value

    def state(self):
        return self._dut.state.value

    def data_out(self):
        return self._dut.data_out.value


@pytest.fixture(scope="module")
def current_path():
    return f"{os.path.dirname(os.path.abspath(__file__))}"


@pytest.fixture(scope="module")
def dut_tester(current_path):
    circuit = Circuit(vcd="tb.vcd")
    # Synth DUT
    dut = YosysComponent(circuit)
    dut_synthesis = Synthesis(
        [
            f"{current_path}/flash_reader.v",
        ],
        "flash_reader",
    )
    yosys_netlist = YosysNetlist()
    yosys_netlist.from_dict(dut_synthesis.synth_to_dict())
    dut.create_from_netlist(yosys_netlist)
    circuit.init()

    yield DutTester(circuit, dut)


def test_start(dut_tester):
    """Test reset operation"""
    dut_tester.reset()

    print("HELLO")

    dut_tester.set_address(0x55330F)
    dut_tester.set_read(1)
    dut_tester.set_miso(1)

    for idx in range(100):
        dut_tester.set_miso(idx % 4 < 2)

        dut_tester.clock()
        print(
            f"STATE: {dut_tester.state()} {dut_tester.spics()}:{dut_tester.sclk()}:{dut_tester.mosi()}"
        )
        dut_tester.set_read(0)

    print(f"DATA {dut_tester.data_out()}")
