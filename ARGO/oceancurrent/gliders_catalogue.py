"""Generate mission metadata from the legacy OceanCurrent Gliders catalogue."""
import argparse
from datetime import date
from html.parser import HTMLParser
import json
import math
import os
from pathlib import Path
import re
import tempfile
from urllib.parse import quote, unquote, urljoin, urlparse

SOURCE_URL = "https://oceancurrent.aodn.org.au/gliders/index.html"
VIEWS = {"bydate": "deployment_date", "bymission": "mission_name",
         "bydist": "distance_alongshore_to_darwin", "byebs": "event_based_sampling"}
HEADERS = ["N", "dates", "lat", "lon", "days", "km", "T-S", "details",
           "anim", "glider", "proc", "mission name"]
MISSION = re.compile(r"[A-Za-z][A-Za-z0-9_-]*\d{8}[A-Za-z]?(?:_[12])?(?:_nrt)?$")
MONTHS = "Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec".split()


class _Element:
    """The small portion of an HTML tree needed for catalogue extraction."""

    def __init__(self, tag, attrs=()):
        self.tag = tag
        self.attrs = dict(attrs)
        self.children = []

    def elements(self, tag, direct=False):
        for child in self.children:
            if isinstance(child, _Element):
                if child.tag == tag:
                    yield child
                if not direct:
                    yield from child.elements(tag)

    def strings(self):
        for child in self.children:
            if isinstance(child, str):
                yield child
            elif child.tag not in {"script", "style", "template"}:
                yield from child.strings()


class _CatalogueParser(HTMLParser):
    """Keep document order and nesting, without applying browser HTML repairs.

    Table selection uses the first table after each view anchor. A tree keeps
    direct row cells distinct from nested markup and preserves text boundaries.
    """

    _VOID_TAGS = frozenset("area base br col embed hr img input link meta param source track wbr".split())

    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.elements = []
        self._stack = [_Element("")]

    def handle_starttag(self, tag, attrs):
        element = _Element(tag, attrs)
        self._stack[-1].children.append(element)
        self.elements.append(element)
        if tag not in self._VOID_TAGS:
            self._stack.append(element)

    def handle_endtag(self, tag):
        # Ignore unmatched closing tags; close any unclosed children as well.
        for index in range(len(self._stack) - 1, 0, -1):
            if self._stack[index].tag == tag:
                del self._stack[index:]
                break

    def handle_startendtag(self, tag, attrs):
        self.handle_starttag(tag, attrs)
        if tag not in self._VOID_TAGS:
            self.handle_endtag(tag)

    def handle_data(self, data):
        self._stack[-1].children.append(data)

    def table_after(self, anchor_id):
        after_anchor = False
        for element in self.elements:
            if after_anchor and element.tag == "table":
                return element
            if element.tag == "a" and element.attrs.get("id") == anchor_id:
                after_anchor = True
        return None


def _text(cell):
    return " ".join(text.strip() for text in cell.strings() if text.strip())


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
    for anchor in cell.elements("a"):
        if anchor.attrs.get("href") is None:
            continue
        href = anchor.attrs["href"].strip()
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
    parser = _CatalogueParser()
    parser.feed(html)
    parser.close()
    records, orders = {}, {}
    tables = set()
    for anchor_id, view in VIEWS.items():
        table = parser.table_after(anchor_id)
        if table is None or id(table) in tables:
            raise ValueError("Missing catalogue table: " + anchor_id)
        tables.add(id(table))
        rows = list(table.elements("tr"))
        if not rows or [_text(c) for c in rows[0].elements("th")] != HEADERS:
            raise ValueError("Unexpected catalogue columns: " + anchor_id)
        units = "".join(rows[1].strings()) if len(rows) > 1 else ""
        if "°S" not in units or "°E" not in units:
            raise ValueError("Unexpected coordinate units: " + anchor_id)
        order = []
        for row in rows[1:]:
            cells = list(row.elements("td", direct=True))
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
    for record in records.values():
        record["visualisations"]["latest_images"] = dict.fromkeys(("4d", "12d", "30d"))
    return {"schema_version": 1, "source_url": source_url,
            "missions": [records[key] for key in sorted(records)], "orders": orders}


def _snapshot(path):
    """Reject replacement, symlink retargeting and in-place changes during a read."""
    def signature():
        stat = path.stat()
        return (path.resolve(), stat.st_dev, stat.st_ino, stat.st_size,
                stat.st_mtime_ns, stat.st_ctime_ns)
    before = signature()
    content = path.read_bytes()
    if signature() != before:
        raise ValueError("Resource changed while reading")
    return content, before


def _latest_image(folder, page_url):
    # A symlink to a dated HTML frame is allowed only inside this window.
    if folder.resolve().name != folder.name:
        return None
    page = folder / "latest.html"
    if page.resolve().parent != folder.resolve():
        return None
    html, signature = _snapshot(page)
    if signature[0].parent != folder.resolve():
        return None
    parser = _CatalogueParser()
    parser.feed(html.decode("utf-8"))
    parser.close()
    images = {}
    for element in parser.elements:
        if element.tag != "img" or not element.attrs.get("src"):
            continue
        url = urlparse(urljoin(page_url, element.attrs["src"]))
        parent = urlparse(page_url)
        prefix = parent.path.rsplit("/", 1)[0] + "/"
        if (url.netloc != parent.netloc or url.query or url.fragment
                or not url.path.startswith(prefix)):
            continue
        relative = unquote(url.path[len(prefix):])
        image = folder / relative
        if ("/" in relative or not relative.lower().endswith(".gif")
                or image.resolve().parent != folder.resolve()):
            continue
        content, image_signature = _snapshot(image)
        if image_signature[0].parent != folder.resolve():
            return None
        if (len(content) >= 14 and content[:6] in (b"GIF87a", b"GIF89a")
                and content.endswith(b";")):
            images[url.path] = (image, image_signature)
    if len(images) != 1 or _snapshot(page)[1] != signature:
        return None
    url, (image, image_signature) = next(iter(images.items()))
    return url if _snapshot(image)[1] == image_signature else None


def resolve_latest_images(catalogue, input_path):
    """Use only displayed GIFs in linked mission-window folders, never filename order.

    The local directory mirrors source_url's gliders directory. Missing, ambiguous
    or changing resources are optional. Paths are website-root-relative; browsers
    prepend /resource. Symlinks and relative image references stay within a window.
    """
    source = urlparse(catalogue["source_url"])
    base = Path(input_path).parent
    prefix = source.path.rsplit("/", 1)[0] + "/"
    for record in catalogue["missions"]:
        visuals = record["visualisations"]
        for window in ("4d", "12d", "30d"):
            candidates = set()
            folders = {record["mission_name"] + "_" + window}
            if record["is_nrt"]:
                folders.add(record["mission_id"] + "_" + window + "_nrt")
            for link in visuals["details"] + visuals["animations"]:
                url = urlparse(link["url"])
                parts = unquote(url.path[len(prefix):]).split("/")
                if (url.netloc != source.netloc or not url.path.startswith(prefix)
                        or len(parts) != 2 or parts[0] not in folders):
                    continue
                try:
                    image = _latest_image(base / parts[0], urljoin(link["url"], "latest.html"))
                    if image:
                        candidates.add(image)
                except (OSError, ValueError, UnicodeError):
                    pass
            visuals["latest_images"][window] = next(iter(candidates)) if len(candidates) == 1 else None
    return catalogue


def generate_catalogue(input_path, output_path, source_url=SOURCE_URL):
    """Parse fully before atomically replacing output; failures leave it untouched."""
    input_path, output_path = Path(input_path), Path(output_path)
    if input_path.resolve() == output_path.resolve():
        raise ValueError("Input and output paths must differ")
    catalogue = parse_catalogue(input_path.read_text(encoding="utf-8"), source_url)
    resolve_latest_images(catalogue, input_path)
    write_catalogue(catalogue, output_path)
    return catalogue


def write_catalogue(catalogue, output_path):
    """Atomically publish an already parsed and validated catalogue."""
    output_path = Path(output_path)
    payload = json.dumps(catalogue, indent=2, ensure_ascii=False, allow_nan=False) + "\n"
    if output_path.exists() and json.loads(output_path.read_text(encoding="utf-8")) == catalogue:
        return catalogue
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
