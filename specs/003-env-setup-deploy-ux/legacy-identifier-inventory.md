# Legacy Identifier Inventory

This file captured the initial repository-wide inventory of hardcoded legacy-name occurrences at the start of this feature.

Notes:

- The exact legacy token is intentionally not written here to keep the repo free of that literal string.
- Inventory was collected using a tracked-only grep sweep (e.g., `git grep -n -i`), then grouped by area (env defaults, docs, scripts, app code, deployment automation).

Result summary:

- Inventory completed early in the feature.
- Subsequent tasks removed/neutralized all tracked legacy-name literals.
