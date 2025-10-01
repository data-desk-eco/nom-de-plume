#!/usr/bin/env python3
"""Fetch methane emissions data from Carbon Mapper API for Texas 2025."""

import json
import urllib.request
from datetime import datetime, UTC

# Texas bounding box: [west, south, east, north]
TEXAS_BBOX = [-106.65, 25.84, -93.51, 36.50]

# API configuration
API_BASE_URL = "https://api.carbonmapper.org"

# Build query parameters for 2025 CH4 plumes in Texas
bbox_params = "&".join(f"bbox={v}" for v in TEXAS_BBOX)
other_params = "datetime=2025-01-01T00:00:00Z/..&plume_gas=CH4"
url = f"{API_BASE_URL}/api/v1/catalog/sources.geojson?{bbox_params}&{other_params}"

# Fetch data (no auth required for sources.geojson)
req = urllib.request.Request(url)
with urllib.request.urlopen(req) as response:
    data = json.loads(response.read())

# Save to file with timestamp
timestamp = datetime.now(UTC).strftime("%Y-%m-%dT%H_%M_%S.%fZ")[:-4] + "Z"
output_file = f"data/sources_{timestamp}.json"

with open(output_file, "w") as f:
    json.dump(data, f)

print(f"Fetched {len(data.get('features', []))} sources")
print(f"Saved to {output_file}")
