"""Legacy entrypoint (thin trampoline)."""

from digital_ocean.scripts.python import edit as _impl

Client = _impl.Client


def __getattr__(name):
    return getattr(_impl, name)


def _sync_impl():
    _impl.Client = Client


def main():
    _sync_impl()
    return _impl.main()


if __name__ == "__main__":
    raise SystemExit(main())
