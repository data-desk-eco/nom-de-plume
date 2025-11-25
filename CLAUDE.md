# Data Desk Research Notebooks

Data Desk publishes investigative research as interactive notebooks using Observable Notebook Kit 2.0. Notebooks are standalone HTML pages with embedded JavaScript that compile to static sites.

## File Structure

```
repo/
├── docs/
│   ├── index.html           # Notebook source (EDIT THIS)
│   ├── assets/              # Images
│   └── .observable/dist/    # Built output (gitignored)
├── data/                    # DuckDB, CSV, JSON files
├── template.html            # HTML wrapper (auto-updates from .github repo)
├── Makefile
└── CLAUDE.md                # This file (auto-updates)
```

**Commit:** `docs/index.html`, `data/*`, `docs/assets/*`, `Makefile`
**Don't commit:** `docs/.observable/dist/`, `node_modules/`, `template.html`, `CLAUDE.md`

## Observable Notebook Basics

Notebooks use `<notebook>` element, not Jupyter format. Reactive execution: cells auto-run when dependencies change.

### Cell Types

```html
<!doctype html>
<notebook theme="midnight">
  <title>Research Title</title>

  <!-- Markdown -->
  <script id="header" type="text/markdown">
    # Heading
  </script>

  <!-- JavaScript -->
  <script id="analysis" type="module">
    const data = await FileAttachment("../data/flows.csv").csv({typed: true});
    display(Inputs.table(data));
  </script>

  <!-- SQL (queries DuckDB) -->
  <script id="flows" output="flows" type="application/sql" database="../data/data.duckdb" hidden>
    SELECT * FROM flows ORDER BY date DESC
  </script>

  <!-- Raw HTML -->
  <script id="chart" type="text/html">
    <div id="map" style="height: 500px;"></div>
  </script>
</notebook>
```

**Key points:**
- Each `<script>` has unique `id`
- Cells are `type="module"` by default (ES6 syntax)
- Use `display()` to render output (don't rely on return values)
- Variables defined in one cell available to all others

## Loading Data

### FileAttachment API

Paths relative to notebook (`docs/index.html`):
- Data files in root `data/` → use `../data/`
- Assets in `docs/assets/` → use `assets/`
- Always `await` FileAttachment calls

```javascript
// CSV with type inference
const flows = await FileAttachment("../data/flows.csv").csv({typed: true});

// JSON
const projects = await FileAttachment("../data/projects.json").json();

// Parquet
const tracks = await FileAttachment("../data/tracks.parquet").parquet();

// Images
const img = await FileAttachment("assets/photo.jpg").url();
```

### DuckDB / SQL Cells

SQL cells query DuckDB at build time, results embedded in HTML.

```html
<script id="query" output="flows" type="application/sql" database="../data/data.duckdb" hidden>
  SELECT * FROM flows WHERE year >= 2020
</script>
```

**Attributes:**
- `type="application/sql"` - marks as SQL query
- `database="../data/data.duckdb"` - path to database (relative to notebook)
- `output="flows"` - variable name for results
- `hidden` - don't display output (optional)

Results available as JS variable:
```javascript
display(html`<p>Found ${flows.length} flows</p>`);
```

### DuckDB Client (for complex queries)

```javascript
const db = DuckDBClient.of();
const summary = await db.query(`
  SELECT year, count(*) as n, sum(volume_kt) as total
  FROM flows GROUP BY year ORDER BY year
`);
display(Inputs.table(summary));
```

## Visualization

### Observable Plot

```javascript
display(Plot.plot({
  title: "Annual volumes by destination",
  x: {label: "Year"},
  y: {label: "Volume (Mt)", grid: true},
  color: {legend: true},
  marks: [
    Plot.barY(data, {x: "year", y: "volume", fill: "region", tip: true}),
    Plot.ruleY([0])
  ]
}));
```

**Common marks:** `Plot.line()`, `Plot.barY()`, `Plot.areaY()`, `Plot.dot()`
**Built-in:** automatic scales, tooltips with `tip: true`, responsive layout

### Interactive Inputs

```javascript
// Toggle
const show_all = view(Inputs.toggle({label: "Show all columns"}));

// Search
const searched = view(Inputs.search(data));

// Table
display(Inputs.table(searched, {
  rows: 25,
  columns: show_all ? undefined : ["name", "date", "value"]
}));

// Slider, select, etc.
const threshold = view(Inputs.range([0, 100], {step: 1, value: 50}));
const country = view(Inputs.select(["UK", "Norway", "Sweden"]));
```

`view()` makes input reactive - other cells auto-update when value changes.

### External Libraries

Load via dynamic imports or CDN:

```html
<!-- CSS -->
<script type="text/html">
  <link href="https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.css" rel="stylesheet" />
</script>

<!-- JS library -->
<script type="module">
  const script = document.createElement('script');
  script.src = 'https://api.mapbox.com/mapbox-gl-js/v2.15.0/mapbox-gl.js';
  script.onload = () => initMap();
  document.head.appendChild(script);
</script>
```

## Build & Deploy

### Makefile Targets

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

### Build Process

Compiles `docs/index.html` into standalone page:
1. Parse `<notebook>` element
2. Compile JS cells to modules
3. Bundle dependencies
4. Apply `template.html`
5. Output to `docs/.observable/dist/`

**Important:** SQL cells query at build time. Database needed for build, not deployment (results embedded in HTML).

### GitHub Actions Deployment

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
2. Download shared `template.html` and `CLAUDE.md`
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

## Common Patterns

### Data Aggregation

```javascript
// Group by and sum
const annual = d3.rollup(flows, v => d3.sum(v, d => d.volume), d => d.year);

// Map to array
const data = Array.from(annual, ([year, volume]) => ({year, volume}))
  .sort((a, b) => a.year - b.year);
```

### Formatting

```javascript
const formatDate = d3.utcFormat("%B %Y");
const formatNumber = d3.format(",.1f");
const formatCurrency = d3.format("$,.0f");
```

### Inline Calculations in Markdown

```javascript
// Calculate stats
const total = d3.sum(flows, d => d.volume);
const maxYear = d3.max(flows, d => d.year);
```

Reference in markdown:
```html
<script type="text/markdown">
  Analysis found ${total.toFixed(1)} Mt across ${flows.length} voyages,
  peaking in ${maxYear}.
</script>
```

### Geospatial (DuckDB Spatial)

```sql
<script type="application/sql" database="../data/flows.duckdb" output="ports">
  SELECT port_name, ST_AsGeoJSON(geometry) as geojson, count(*) as visits
  FROM port_visits GROUP BY port_name, geometry
</script>
```

Use in Mapbox/Leaflet:
```javascript
ports.forEach(p => {
  const coords = JSON.parse(p.geojson).coordinates;
  new mapboxgl.Marker().setLngLat(coords).addTo(map);
});
```

## Critical Gotchas

1. **Data paths:** Use `../data/` from notebook, not `data/`
2. **SQL database path:** `database="../data/data.duckdb"` in SQL cells
3. **Display everything:** Use `display()` explicitly, don't rely on return values
4. **Cell IDs:** Must be unique across notebook
5. **Await FileAttachment:** All FileAttachment calls return promises
6. **Edit source:** Edit `docs/index.html`, not `docs/.observable/dist/`
7. **Auto-updating files:** `template.html` and `CLAUDE.md` download from `.github` repo on deploy
8. **Case-sensitive paths:** GitHub Pages is case-sensitive
9. **SQL cells at build time:** Database must exist when running `make build`

## Creating New Notebook

1. Use `data-desk-eco.github.io` as GitHub template
2. Enable Pages (Settings → Pages → Source: GitHub Actions)
3. Clone: `git clone [url] && cd [repo] && yarn`
4. Preview: `make preview`
5. Edit `docs/index.html`
6. Push - deploys to `https://research.datadesk.eco/[repo-name]/`

## Resources

- Observable Notebook Kit: https://observablehq.com/notebook-kit/
- Observable Plot: https://observablehq.com/plot/
- Observable Inputs: https://observablehq.com/notebook-kit/inputs
- DuckDB SQL: https://duckdb.org/docs/sql/introduction
- All Data Desk notebooks: https://research.datadesk.eco/
