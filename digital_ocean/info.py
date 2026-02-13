"""Legacy entrypoint (thin trampoline)."""

from digital_ocean.scripts.python import info as _impl

Client = _impl.Client

get_client = _impl.get_client
list_namespaces = _impl.list_namespaces
list_domains = _impl.list_domains
list_resource_metadata = _impl.list_resource_metadata
validate_env = _impl.validate_env


def __getattr__(name):
    return getattr(_impl, name)


def _sync_impl():
    _impl.Client = Client


def main():
    _sync_impl()
    return _impl.main()


if __name__ == "__main__":
    raise SystemExit(main())
