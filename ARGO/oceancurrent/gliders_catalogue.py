"""Generate mission metadata from the legacy OceanCurrent Gliders catalogue."""
import argparse
from datetime import date
import json
import math
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import quote, urljoin, urlparse

from bs4 import BeautifulSoup

SOURCE_URL = "https://oceancurrent.aodn.org.au/gliders/index.html"
VIEWS = {"bydate": "deployment_date", "bymission": "mission_name",
         "bydist": "distance_alongshore_to_darwin", "byebs": "event_based_sampling"}
HEADERS = ["N", "dates", "lat", "lon", "days", "km", "T-S", "details",
           "anim", "glider", "proc", "mission name"]
MISSION = re.compile(r"[A-Za-z][A-Za-z0-9_-]*\d{8}[A-Za-z]?(?:_[12])?(?:_nrt)?$")
MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()


def _text(cell):
    return cell.get_text(" ", strip=True)


def _number(text, minimum, maximum=None):
    try:
        value = float(text)
    except ValueError:
        return None
    if not math.isfinite(value) or value < minimum or (maximum is not None and value > maximum):
        return None
    return value


def _dates(raw):
    """The catalogue gives the end year; a wrapped month belongs to the prior year."""
    match = re.fullmatch(r"(\d{2}) ([A-Z][a-z]{2}) - (\d{2}) ([A-Z][a-z]{2}) (\d{4})", raw)
    if not match:
        return None, None
    day1, month1, day2, month2, year = match.groups()
    try:
        m1, m2 = MONTHS.index(month1) + 1, MONTHS.index(month2) + 1
        end = date(int(year), m2, int(day2))
        start = date(int(year) - (m1 > m2), m1, int(day1))
        if start > end:
            return None, None
        return start.isoformat(), end.isoformat()
    except ValueError:
        return None, None


def _links(cell, source_url):
    links = []
    for anchor in cell.find_all("a", href=True):
        href = anchor["href"].strip()
        url = urljoin(source_url, href)
        if href and urlparse(url).scheme in ("http", "https"):
            link = {"label": _text(anchor), "url": url}
            if link not in links:
                links.append(link)
    return links


def _record(cells, source_url):
    values = [_text(cell) for cell in cells]
    name = values[11]
    if not values[0].isdigit() or not MISSION.fullmatch(name):
        return None
    processing = values[10] or None
    start, end = _dates(values[1])
    # The header explicitly specifies degrees south and degrees east.
    latitude = _number(values[2], -90, 90)
    scientific = _links(cells[11], source_url)
    ts = _links(cells[6], source_url)
    return {
        "id": quote(name, safe="") + "@" + quote(processing or "unknown", safe=""),
        "mission_id": re.sub(r"_nrt$", "", name),
        "mission_name": name,
        "catalogue_numbers": [values[0]],
        "processing_version": processing,
        "is_nrt": name.endswith("_nrt"),
        "dates_raw": values[1] or None,
        "start_date": start, "end_date": end,
        "latitude": -abs(latitude) if latitude is not None else None,
        "longitude": _number(values[3], -180, 180),
        "duration_days": _number(values[4], 0),
        "distance_travelled_km": _number(values[5], 0),
        "glider_id": values[9] or None,
        "visualisations": {"details": _links(cells[7], source_url),
                           "animations": _links(cells[8], source_url)},
        "temperature_salinity_url": ts[0]["url"] if ts else None,
        "scientific_data_url": scientific[0]["url"] if scientific else None,
    }


def parse_catalogue(html, source_url=SOURCE_URL):
    """Return a deterministic catalogue, rejecting missing views and conflicting rows.

    Optional values are null, unavailable visualisations are empty lists. Year and
    summary rows have no mission identifier and are ignored, as are incomplete rows.
    """
    soup = BeautifulSoup(html, "html.parser")
    records, orders = {}, {}
    tables = set()
    for anchor_id, view in VIEWS.items():
        anchor = soup.find("a", id=anchor_id)
        table = anchor.find_next("table") if anchor else None
        if table is None or id(table) in tables:
            raise ValueError("Missing catalogue table: " + anchor_id)
        tables.add(id(table))
        rows = table.find_all("tr")
        if not rows or [_text(c) for c in rows[0].find_all("th")] != HEADERS:
            raise ValueError("Unexpected catalogue columns: " + anchor_id)
        units = rows[1].get_text() if len(rows) > 1 else ""
        if "°S" not in units or "°E" not in units:
            raise ValueError("Unexpected coordinate units: " + anchor_id)
        order = []
        for row in rows[1:]:
            cells = row.find_all("td", recursive=False)
            if len(cells) != len(HEADERS):
                continue
            record = _record(cells, source_url)
            if record is None:
                continue
            key = record["id"]
            if key in records:
                previous = records[key]
                for field, value in record.items():
                    if field == "catalogue_numbers":
                        previous[field] = sorted(set(previous[field] + value), key=int)
                    elif field == "visualisations":
                        for kind, links in value.items():
                            for link in links:
                                if link not in previous[field][kind]:
                                    previous[field][kind].append(link)
                    elif previous[field] is None:
                        previous[field] = value
                    elif value is not None and previous[field] != value:
                        raise ValueError("Conflicting metadata for {}: {}".format(key, field))
            else:
                records[key] = record
            if key not in order:
                order.append(key)
        if not order and view != "event_based_sampling":
            raise ValueError("Empty catalogue view: " + anchor_id)
        orders[view] = order
    if not records:
        raise ValueError("Empty catalogue")
    return {"schema_version": 1, "source_url": source_url,
            "missions": [records[key] for key in sorted(records)], "orders": orders}


def generate_catalogue(input_path, output_path, source_url=SOURCE_URL):
    """Parse fully before atomically replacing output; failures leave it untouched."""
    input_path, output_path = Path(input_path), Path(output_path)
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must differ")
    catalogue = parse_catalogue(input_path.read_text(encoding="utf-8"), source_url)
    payload = json.dumps(catalogue, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
    temporary = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=output_path.parent,
                                         prefix="." + output_path.name, delete=False) as stream:
            temporary = stream.name
            stream.write(payload)
            stream.flush()
            os.fsync(stream.fileno())
        # NamedTemporaryFile is private by default; the published catalogue is public.
        os.chmod(temporary, 0o644)
        os.replace(temporary, output_path)
    finally:
        if temporary and os.path.exists(temporary):
            os.unlink(temporary)
    return catalogue


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True, help="Local legacy index.html")
    parser.add_argument("--output", type=Path, required=True, help="Destination JSON (parent must exist)")
    parser.add_argument("--source-url", default=SOURCE_URL, help="Base URL for resolving catalogue links")
    args = parser.parse_args()
    try:
        catalogue = generate_catalogue(args.input, args.output, args.source_url)
    except (OSError, ValueError) as error:
        parser.exit(1, "Catalogue generation failed: {}\n".format(error))
    print("Wrote {} mission versions to {}".format(len(catalogue["missions"]), args.output))


if __name__ == "__main__":
    main()
