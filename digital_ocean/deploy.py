"""Legacy entrypoint (thin trampoline)."""

from digital_ocean.scripts.python import deploy as _impl

Client = _impl.Client
post_creation_hook = _impl.post_creation_hook


def __getattr__(name):
    return getattr(_impl, name)


def _sync_impl():
    _impl.Client = Client
    _impl.post_creation_hook = post_creation_hook


def main():
    _sync_impl()
    return _impl.main()


if __name__ == "__main__":
    raise SystemExit(main())
