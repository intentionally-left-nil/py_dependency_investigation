# SPDX-FileCopyrightText: 2025-present Anil Kulkarni <akulkarni@anaconda.com>
#
# SPDX-License-Identifier: MIT

from .__about__ import __version__
from dep_urllib3 import hello_v1

def hello() -> None:
    hello_v1()
    print(f"dep-plain: {__version__}")
