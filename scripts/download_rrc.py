#!/usr/bin/env python3
"""Download Texas RRC EBCDIC data files from MFT server using Playwright."""

import sys
from pathlib import Path
from playwright.sync_api import sync_playwright

# MFT link IDs for each dataset (from RRC downloads page)
DATASETS = {
    'p4f606.ebc.gz': '19f9b9c7-2b82-4d7c-8dbd-77145a86d3de',   # P-4 Certificate of Authorization
    'orf850.ebc.gz': '04652169-eed6-4396-9019-2e270e790f6c',   # P-5 Organization
    'dbf900.ebc.gz': 'b070ce28-5c58-4fe2-9eb7-8b70befb7af9',   # Full Wellbore
}


def download_file(page, filename: str, link_id: str, output_dir: Path) -> Path:
    """Download a single file from MFT."""
    url = f'https://mft.rrc.texas.gov/link/{link_id}'
    output_path = output_dir / filename

    page.goto(url)
    page.wait_for_load_state('networkidle')

    # Select file row, then click Download
    page.locator(f'a:has-text("{filename}")').locator('xpath=ancestor::tr').click(force=True)
    page.wait_for_timeout(500)

    with page.expect_download(timeout=300000) as download_info:
        page.locator('button:has-text("Download")').click(force=True)

    download = download_info.value
    download.save_as(output_path)

    size_mb = output_path.stat().st_size / 1024 / 1024
    print(f"  {filename}: {size_mb:.1f} MB")

    return output_path


def main():
    output_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('data')
    files_to_download = sys.argv[2:] if len(sys.argv) > 2 else list(DATASETS.keys())

    output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Downloading {len(files_to_download)} file(s) from Texas RRC MFT...")

    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        context = browser.new_context(accept_downloads=True, viewport={'width': 1920, 'height': 1080})
        page = context.new_page()

        for filename in files_to_download:
            if filename not in DATASETS:
                print(f"  Unknown file: {filename}", file=sys.stderr)
                continue
            download_file(page, filename, DATASETS[filename], output_dir)

        browser.close()

    print("Done")


if __name__ == '__main__':
    main()
