# SPDX-FileCopyrightText: 2025-present Anil Kulkarni <akulkarni@anaconda.com>
#
# SPDX-License-Identifier: MIT

from .__about__ import __version__

def hello() -> None:
    print(f"dep-a: {__version__}")
