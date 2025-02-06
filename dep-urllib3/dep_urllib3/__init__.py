# SPDX-FileCopyrightText: 2025-present Anil Kulkarni <akulkarni@anaconda.com>
#
# SPDX-License-Identifier: MIT

from .__about__ import __version__

def hello() -> None:
    print(f"dep-urllib3: {__version__}")

def hello_v1() -> None:
    parts = __version__.split('.')
    if parts[0] > '1':
        raise NotImplementedError(f"hello_v1 is not implemented for dep-urllib3=={__version__}")
    hello()

def hello_v2() -> None:
    parts = __version__.split('.')
    if parts[0] < '1':
        raise NotImplementedError(f"hello_v2 is not implemented for dep-urllib3=={__version__}")
    hello()
    
    