#!/usr/bin/env python3
"""Fetch methane plume data from Carbon Mapper API for Texas and Louisiana."""

import csv
import sys
import urllib.request
from datetime import datetime, timedelta, timezone
from io import StringIO

API_BASE = "https://api.carbonmapper.org/api/v1/catalog/plume-csv"

# Bounding boxes: [west, south, east, north]
REGIONS = {
    "texas": [-106.65, 25.84, -93.51, 36.50],
    "louisiana": [-94.04, 28.93, -88.75, 33.02],
}

# Date filter - rolling 12-month window
_start = (datetime.now(timezone.utc) - timedelta(days=365)).strftime("%Y-%m-%dT00:00:00Z")
DATETIME_FILTER = f"{_start}/.."


def fetch_plumes(bbox: list[float], gas: str | None = None) -> list[dict]:
    """Fetch plumes from Carbon Mapper API."""
    params = [f"bbox={v}" for v in bbox]
    params.append(f"datetime={DATETIME_FILTER}")
    if gas:
        params.append(f"plume_gas={gas}")

    url = f"{API_BASE}?{'&'.join(params)}"

    req = urllib.request.Request(url)
    req.add_header("User-Agent", "nom-de-plume/1.0")

    with urllib.request.urlopen(req, timeout=60) as response:
        content = response.read().decode("utf-8")

    reader = csv.DictReader(StringIO(content))
    return list(reader)


def main():
    all_plumes = []
    seen_ids = set()

    for region, bbox in REGIONS.items():
        # Fetch CH4 plumes (primary focus)
        plumes = fetch_plumes(bbox, gas="CH4")
        for p in plumes:
            if p["plume_id"] not in seen_ids:
                seen_ids.add(p["plume_id"])
                all_plumes.append(p)
        print(f"  {region}: {len(plumes)} CH4 plumes", file=sys.stderr)

    print(f"Total: {len(all_plumes)} unique plumes", file=sys.stderr)

    if not all_plumes:
        print("ERROR: No plumes fetched", file=sys.stderr)
        sys.exit(1)

    # Write CSV to stdout (Makefile redirects to file)
    fieldnames = list(all_plumes[0].keys())
    writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames)
    writer.writeheader()
    writer.writerows(all_plumes)


if __name__ == "__main__":
    main()
