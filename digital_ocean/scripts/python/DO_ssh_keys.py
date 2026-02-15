"""Manage DigitalOcean SSH keys.

Usage examples:
    python -m digital_ocean.scripts.python.DO_ssh_keys --list
    python -m digital_ocean.scripts.python.DO_ssh_keys --add --name project1 --public-key-path ~/.ssh/project1.pub
    python -m digital_ocean.scripts.python.DO_ssh_keys --delete --id 123456 --yes
    python -m digital_ocean.scripts.python.DO_ssh_keys --delete --fingerprint "aa:bb:cc:..." --yes
    python -m digital_ocean.scripts.python.DO_ssh_keys --find --name project1
"""

import argparse
import json
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from pydo import Client

from digital_ocean.scripts.python.do_logging import logger


def load_env():
    load_dotenv(dotenv_path=Path.cwd() / ".env", override=False)


def require_token():
    token = os.getenv("DO_API_TOKEN")
    if not token:
        print("ERROR: DO_API_TOKEN is required in .env", file=sys.stderr)
        sys.exit(1)
    return token


def read_public_key(path_str):
    path = Path(path_str).expanduser()
    if not path.exists():
        raise FileNotFoundError(f"Public key not found: {path}")
    return path.read_text(encoding="utf-8").strip()


def list_keys(client):
    resp = client.ssh_keys.list()
    keys = (resp or {}).get("ssh_keys", [])
    return keys


def find_by_name(keys, name):
    matches = [k for k in keys if k.get("name") == name]
    return matches


def add_key(client, name, public_key, dry_run=False):
    if dry_run:
        logger.info(f"[DRY RUN] Would create SSH key: name={name}")
        return {"dry_run": True}
    try:
        existing = list_keys(client)
        for key in existing:
            if key.get("public_key") == public_key or key.get("name") == name:
                logger.info("SSH key already exists; using existing key.")
                return {"ssh_key": key, "existing": True}
    except Exception:
        # If listing fails, still attempt create below.
        pass
    resp = client.ssh_keys.create({"name": name, "public_key": public_key})
    return resp


def delete_key(client, key_id=None, fingerprint=None, dry_run=False):
    if dry_run:
        logger.info(f"[DRY RUN] Would delete SSH key: id={key_id} fingerprint={fingerprint}")
        return {"dry_run": True}
    if key_id is not None:
        return client.ssh_keys.delete(key_id)
    return client.ssh_keys.delete(fingerprint)


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Manage DigitalOcean SSH keys using DO_API_TOKEN from .env"
    )
    parser.add_argument("--list", action="store_true", help="List SSH keys")
    parser.add_argument("--find", action="store_true", help="Find SSH keys by name")
    parser.add_argument("--add", action="store_true", help="Add an SSH key")
    parser.add_argument("--delete", action="store_true", help="Delete an SSH key")
    parser.add_argument("--name", help="SSH key name (for --add or --find)")
    parser.add_argument("--public-key", help="Public key content (for --add)")
    parser.add_argument("--public-key-path", help="Path to public key file (for --add)")
    parser.add_argument("--id", help="SSH key ID (for --delete)")
    parser.add_argument("--fingerprint", help="SSH key fingerprint (for --delete)")
    parser.add_argument("--json", action="store_true", help="Output JSON")
    parser.add_argument("--dry-run", action="store_true", help="Show actions without changes")
    parser.add_argument("--yes", action="store_true", help="Skip confirmation for delete")

    args = parser.parse_args(argv)

    load_env()
    token = require_token()
    client = Client(token=token)

    if args.list:
        keys = list_keys(client)
        if args.json:
            print(json.dumps(keys, indent=2))
        else:
            for k in keys:
                print(f"{k.get('id')}\t{k.get('name')}\t{k.get('fingerprint')}")
        return 0

    if args.find:
        if not args.name:
            print("ERROR: --name is required for --find", file=sys.stderr)
            return 2
        keys = list_keys(client)
        matches = find_by_name(keys, args.name)
        if args.json:
            print(json.dumps(matches, indent=2))
        else:
            for k in matches:
                print(f"{k.get('id')}\t{k.get('name')}\t{k.get('fingerprint')}")
        return 0

    if args.add:
        if not args.name:
            print("ERROR: --name is required for --add", file=sys.stderr)
            return 2
        public_key = args.public_key
        if not public_key and args.public_key_path:
            try:
                public_key = read_public_key(args.public_key_path)
            except Exception as e:
                print(f"ERROR: {e}", file=sys.stderr)
                return 2
        if not public_key:
            print("ERROR: --public-key or --public-key-path is required for --add", file=sys.stderr)
            return 2
        resp = add_key(client, args.name, public_key, dry_run=args.dry_run)
        if args.json:
            print(json.dumps(resp, indent=2))
        else:
            logger.info("SSH key created.")
        return 0

    if args.delete:
        if not args.id and not args.fingerprint:
            print("ERROR: --id or --fingerprint is required for --delete", file=sys.stderr)
            return 2
        if not args.yes:
            confirm = input("Delete SSH key? Type 'yes' to continue: ").strip().lower()
            if confirm != "yes":
                print("Aborted.")
                return 0
        resp = delete_key(
            client, key_id=args.id, fingerprint=args.fingerprint, dry_run=args.dry_run
        )
        if args.json:
            print(json.dumps(resp, indent=2))
        else:
            logger.info("SSH key deleted.")
        return 0

    parser.print_help()
    return 0


if __name__ == "__main__":
    sys.exit(main())
