#!/usr/bin/env python3
"""Legacy entrypoint (thin trampoline)."""

from __future__ import annotations

import runpy
from pathlib import Path


def main() -> None:
    target = Path(__file__).resolve().parent / "python" / "slo_smoke.py"
    runpy.run_path(str(target), run_name="__main__")


if __name__ == "__main__":
    main()
