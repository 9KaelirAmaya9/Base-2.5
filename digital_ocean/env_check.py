"""Legacy entrypoint (thin trampoline)."""

from digital_ocean.scripts.python.env_check import *  # noqa: F401,F403
from digital_ocean.scripts.python.env_check import main as _main


if __name__ == "__main__":
    raise SystemExit(_main())
