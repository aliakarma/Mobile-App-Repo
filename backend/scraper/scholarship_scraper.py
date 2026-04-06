from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable

import requests
from bs4 import BeautifulSoup, Tag


@dataclass
class OpportunityRecord:
    title: str
    deadline: str
    eligibility: str
    link: str


class ScraperError(Exception):
    """Raised when scraping fails unexpectedly."""


def fetch_html(url: str, timeout: int = 15) -> str:
    """Fetch HTML from a URL with basic network error handling."""
    try:
        response = requests.get(url, timeout=timeout)
        response.raise_for_status()
        return response.text
    except requests.RequestException as exc:
        raise ScraperError(f"Failed to fetch URL: {url}. Error: {exc}") from exc


def _safe_text(root: Tag, selector: str, default: str = "N/A") -> str:
    element = root.select_one(selector)
    if element is None:
        return default
    text = element.get_text(strip=True)
    return text if text else default


def _safe_link(root: Tag, selector: str, default: str = "") -> str:
    element = root.select_one(selector)
    if element is None:
        return default
    href = element.get("href")
    if not isinstance(href, str):
        return default
    return href.strip()


def parse_opportunities(html: str) -> list[OpportunityRecord]:
    """
    Parse opportunities from a sample page structure like:

    <div class="scholarship-card">
      <h2 class="title">Scholarship Name</h2>
      <p class="deadline">Deadline: 2026-08-01</p>
      <p class="eligibility">Eligibility: Undergraduate students</p>
      <a class="apply-link" href="https://example.org/apply">Apply</a>
    </div>
    """
    soup = BeautifulSoup(html, "html.parser")
    cards = soup.select(".scholarship-card")

    opportunities: list[OpportunityRecord] = []
    for card in cards:
        title = _safe_text(card, ".title")
        deadline = _safe_text(card, ".deadline")
        eligibility = _safe_text(card, ".eligibility")
        link = _safe_link(card, "a.apply-link")

        opportunities.append(
            OpportunityRecord(
                title=title,
                deadline=deadline,
                eligibility=eligibility,
                link=link,
            )
        )

    return opportunities


def serialize_records(records: Iterable[OpportunityRecord]) -> list[dict[str, str]]:
    return [asdict(record) for record in records]


def save_to_json(records: Iterable[OpportunityRecord], output_path: Path) -> None:
    data = serialize_records(records)
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(json.dumps(data, indent=2), encoding="utf-8")
    except OSError as exc:
        raise ScraperError(f"Failed to write JSON file: {output_path}. Error: {exc}") from exc


def scrape_scholarships(url: str, output_path: Path) -> list[OpportunityRecord]:
    html = fetch_html(url)
    records = parse_opportunities(html)
    save_to_json(records, output_path)
    return records


def scrape_from_html(html: str, output_path: Path) -> list[OpportunityRecord]:
    records = parse_opportunities(html)
    save_to_json(records, output_path)
    return records


SAMPLE_HTML = """
<html>
  <body>
    <div class="scholarship-card">
      <h2 class="title">Merit Scholarship 2026</h2>
      <p class="deadline">2026-08-30</p>
      <p class="eligibility">GPA 3.5+ and full-time enrollment</p>
      <a class="apply-link" href="https://example.org/merit-2026">Apply now</a>
    </div>
    <div class="scholarship-card">
      <h2 class="title">STEM Impact Grant</h2>
      <p class="deadline">2026-09-15</p>
      <p class="eligibility">STEM students with project portfolio</p>
      <a class="apply-link" href="https://example.org/stem-impact">Apply now</a>
    </div>
    <div class="scholarship-card">
      <h2 class="title">Community Leadership Fund</h2>
      <p class="eligibility">Applicants with volunteer leadership experience</p>
      <a class="apply-link" href="https://example.org/community-fund">Apply now</a>
    </div>
  </body>
</html>
"""


if __name__ == "__main__":
    output_file = Path(__file__).resolve().parents[1] / "opportunities.json"

    try:
        extracted = scrape_from_html(SAMPLE_HTML, output_file)
        print(f"Saved {len(extracted)} opportunities to {output_file}")
    except ScraperError as exc:
        print(f"Scraper failed: {exc}")
