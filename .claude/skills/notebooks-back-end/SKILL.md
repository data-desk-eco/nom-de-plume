---
name: notebooks-back-end
description: Use when building, deploying, or setting up notebooks. Covers Makefile targets (make build, make data, make etl), GitHub Actions workflows, CI/CD, and creating new notebook repositories.
---

# Notebook build and deployment

## Makefile targets

Every notebook should define two data targets:

| Target | Purpose | Where |
|--------|---------|-------|
| `make etl` | Expensive computation (large downloads, model training, heavy processing) | Local only |
| `make data` | Lightweight refresh (fetch artifacts, run analysis, export for notebook) | GitHub Actions |

**Simple notebook (no heavy step):**
```makefile
.PHONY: build preview etl data clean

build:
	yarn build

preview:
	yarn preview

etl: data  # no heavy step, just alias

data:
	python scripts/fetch_and_process.py

clean:
	rm -rf docs/.observable/dist
```

**Complex notebook (with heavy ETL):**
```makefile
.PHONY: build preview etl data clean

build:
	yarn build

preview:
	yarn preview

# Expensive local computation - run manually, upload artifacts to GitHub Releases
etl: data/infrastructure.duckdb
	@echo "Done. Upload to GitHub Releases:"
	@echo "  gzip -k data/infrastructure.duckdb"
	@echo "  gh release create v1 data/infrastructure.duckdb.gz"

data/infrastructure.duckdb: data/source.gpkg scripts/build_infra.py
	python scripts/build_infra.py

# CI-friendly refresh - downloads artifacts, runs lightweight analysis
data:
	@if [ ! -f data/infrastructure.duckdb ]; then \
		echo "Downloading from GitHub Releases..."; \
		gh release download latest -p infrastructure.duckdb.gz -D data && \
		gunzip data/infrastructure.duckdb.gz; \
	fi
	python scripts/analyze.py
	duckdb data/data.duckdb < queries/export.sql

clean:
	rm -rf docs/.observable/dist data/data.duckdb
```

**Usage:**
- `make preview` - local dev server with hot reload (http://localhost:3000)
- `make build` - compile to `docs/.observable/dist/`
- `make etl` - run expensive local computation (manual, infrequent)
- `make data` - lightweight data refresh (runs in GitHub Actions)
- `make clean` - remove build artifacts

## Build process

Compiles `docs/index.html` into standalone page:
1. Parse `<notebook>` element
2. Compile JS cells to modules
3. Bundle dependencies
4. Apply `template.html`
5. Output to `docs/.observable/dist/`

**Important:** SQL cells query at build time. Database needed for build, not deployment (results embedded in HTML).

## GitHub Actions deployment

Each notebook repo has a minimal `deploy.yml` that calls a shared reusable workflow:

```yaml
name: Deploy notebook

on:
  schedule:
    - cron: '0 6 1 * *'  # Monthly - adjust per repo
  workflow_dispatch:
  push:
    branches: [main]

jobs:
  deploy:
    uses: data-desk-eco/.github/.github/workflows/notebook-deploy.yml@main
    permissions:
      contents: write
      pages: write
      id-token: write
    secrets: inherit
```

The reusable workflow handles:
1. Checkout and setup (Node, Yarn, DuckDB)
2. Download shared `template.html` and `.claude/` (includes skills and shared CLAUDE.md)
3. Run `make data`
4. Commit any changes
5. Run `make build`
6. Deploy to GitHub Pages

**Pages setup:** Settings → Pages → Source: GitHub Actions

**Skip data step:** For notebooks without a data target:
```yaml
jobs:
  deploy:
    uses: data-desk-eco/.github/.github/workflows/notebook-deploy.yml@main
    with:
      skip_data: true
    # ...
```

## Creating a new notebook

1. Use `data-desk-eco.github.io` as GitHub template
2. Enable Pages (Settings → Pages → Source: GitHub Actions)
3. Clone: `git clone [url] && cd [repo] && yarn`
4. Preview: `make preview`
5. Edit `docs/index.html`
6. Push - deploys to `https://research.datadesk.eco/[repo-name]/`

## Auto-updating files

These files download from the `.github` repo on each deploy:
- `template.html` - HTML wrapper
- `.claude/` - Claude Code skills and shared instructions (`.claude/CLAUDE.md`)

Don't edit these locally - changes will be overwritten.

**Project-specific instructions:** Create a root `CLAUDE.md` in your notebook repo for project-specific context. This file won't be overwritten and should be committed.
