# Copyright (c) Fredrik Andersson, 2024
# All rights reserved

"""Shared fixtures of the module testbenches (digsim)."""

import pathlib

import pytest


PYTEST_DIR = pathlib.Path(__file__).resolve().parent
RTL_DIR = PYTEST_DIR.parents[1] / "rtl"


@pytest.fixture(scope="module")
def rtl_path(request):
    """The RTL folder of the tested module: sim/pytest/<path> -> rtl/<path>"""
    test_dir = pathlib.Path(request.path).resolve().parent
    return str(RTL_DIR / test_dir.relative_to(PYTEST_DIR))
