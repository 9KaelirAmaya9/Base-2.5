"""Legacy entrypoint (thin trampoline)."""

from digital_ocean.scripts.python.orchestrate_teardown import *  # noqa: F401,F403
from digital_ocean.scripts.python.orchestrate_teardown import main as _main


if __name__ == "__main__":
    raise SystemExit(_main())
