"""Legacy entrypoint (thin trampoline)."""

from digital_ocean.scripts.python import exec as _impl

Client = _impl.Client
exec_on_droplet = _impl.exec_on_droplet
exec_on_app_service = _impl.exec_on_app_service


def __getattr__(name):
    return getattr(_impl, name)


def _sync_impl():
    _impl.Client = Client
    _impl.exec_on_droplet = exec_on_droplet
    _impl.exec_on_app_service = exec_on_app_service


def main():
    _sync_impl()
    return _impl.main()


if __name__ == "__main__":
    raise SystemExit(main())
