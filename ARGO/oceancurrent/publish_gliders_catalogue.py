"""Check stable Gliders HTML and atomically publish validated mission metadata."""
import argparse
import json
import logging
import math
from pathlib import Path
import sys
import time
from urllib.parse import quote, urlparse

LOG = logging.getLogger("gliders_catalogue_publication")


def validate_catalogue(catalogue):
    """Validate generated JSON and any previously published catalogue."""
    from gliders_catalogue import MISSION, VIEWS

    def require(condition, message):
        if not condition:
            raise ValueError(message)

    def public_url(value):
        return isinstance(value, str) and urlparse(value).scheme in ("http", "https") and bool(urlparse(value).netloc)

    require(isinstance(catalogue, dict) and type(catalogue.get("schema_version")) is int
            and catalogue["schema_version"] == 1, "Expected schema_version == 1")
    require(public_url(catalogue.get("source_url")), "Invalid source_url")
    missions = catalogue.get("missions")
    require(isinstance(missions, list) and bool(missions), "Missing or empty missions")
    ids = []
    for record in missions:
        require(isinstance(record, dict), "Invalid mission record")
        name, version = record.get("mission_name"), record.get("processing_version")
        require(isinstance(name, str) and MISSION.fullmatch(name), "Invalid mission_name")
        require(version is None or isinstance(version, str) and bool(version.strip()), "Invalid processing_version")
        require(record.get("id") == quote(name, safe="") + "@" + quote(version or "unknown", safe=""), "Invalid mission id")
        require(record.get("mission_id") == (name[:-4] if name.endswith("_nrt") else name), "Invalid mission_id")
        require(type(record.get("is_nrt")) is bool and record["is_nrt"] == name.endswith("_nrt"), "Invalid is_nrt")
        numbers = record.get("catalogue_numbers")
        require(isinstance(numbers, list) and bool(numbers)
                and all(isinstance(n, str) and n.isdigit() for n in numbers), "Invalid catalogue_numbers")
        for field in ("dates_raw", "start_date", "end_date", "glider_id", "processing_version"):
            require(field in record and (record[field] is None or isinstance(record[field], str)), "Invalid " + field)
        for field, low, high in (("latitude", -90, 90), ("longitude", -180, 180),
                                 ("duration_days", 0, math.inf), ("distance_travelled_km", 0, math.inf)):
            value = record.get(field)
            require(field in record and (value is None or type(value) in (int, float)
                    and math.isfinite(value) and low <= value <= high), "Invalid " + field)
        for field in ("temperature_salinity_url", "scientific_data_url"):
            require(field in record and (record[field] is None or public_url(record[field])), "Invalid " + field)
        visuals = record.get("visualisations")
        require(isinstance(visuals, dict), "Invalid visualisations")
        for kind in ("details", "animations"):
            links = visuals.get(kind)
            require(isinstance(links, list) and all(isinstance(link, dict)
                    and isinstance(link.get("label"), str) and public_url(link.get("url"))
                    for link in links), "Invalid visualisations: " + kind)
        ids.append(record["id"])
    require(len(ids) == len(set(ids)), "Duplicate mission ids")
    orders = catalogue.get("orders")
    require(isinstance(orders, dict), "Missing orders")
    for view in VIEWS.values():
        order = orders.get(view)
        require(isinstance(order, list) and all(isinstance(item, str) for item in order), "Missing or invalid order: " + view)
        require(len(order) == len(set(order)) and set(order).issubset(ids), "Invalid order references: " + view)
        require(bool(order) or view == "event_based_sampling", "Empty order: " + view)
    return len(missions)


def _read_source(path):
    """Read one snapshot, rejecting replacement or in-place changes during the read."""
    before = path.stat()
    content = path.read_bytes()
    after = path.stat()
    signature = lambda stat: (stat.st_dev, stat.st_ino, stat.st_size, stat.st_mtime_ns, stat.st_ctime_ns)
    if signature(before) != signature(after):
        raise ValueError("Source changed while reading; wait for upstream publication to complete")
    return content, signature(after)


def publish_catalogue(source, destination, *, source_complete=False, stability_seconds=30):
    """Validate a stable source and publish changed content, including the first run.

    Quiet snapshots cannot prove upstream completion. Executions may overlap;
    atomic replacement prevents partial JSON reads but does not serialize updates.
    """
    from gliders_catalogue import parse_catalogue, write_catalogue

    source, destination = Path(source), Path(destination)
    if not math.isfinite(stability_seconds) or stability_seconds <= 0:
        raise ValueError("stability-seconds must be finite and positive")
    if source.resolve() == destination.resolve():
        raise ValueError("Source must differ from destination")
    html, signature = _read_source(source)
    if not source_complete:
        LOG.info("Observing HTML stability for %s seconds (not an upstream completion signal)", stability_seconds)
        time.sleep(stability_seconds)
        observed_html, observed_signature = _read_source(source)
        if observed_html != html or observed_signature != signature:
            raise ValueError("Source changed during stability observation; retry on the next check")
    catalogue = parse_catalogue(html.decode("utf-8"))
    new_count = validate_catalogue(catalogue)
    previous_bytes = destination.read_bytes() if destination.exists() else None
    previous = json.loads(previous_bytes) if previous_bytes is not None else None
    previous_count = validate_catalogue(previous) if previous_bytes is not None else None
    LOG.info("Mission counts previous=%s new=%d", previous_count, new_count)
    for view, order in catalogue["orders"].items():
        old = previous["orders"][view] if previous is not None else None
        LOG.info("Catalogue order %s previous=%s new=%d changed=%s", view,
                 len(old) if old is not None else None, len(order), old != order)
    current_html, current_signature = _read_source(source)
    if current_html != html or current_signature != signature:
        raise ValueError("Source changed during generation; publication aborted")
    # Semantic equality avoids rewriting even a differently formatted valid baseline.
    changed = previous != catalogue
    if changed:
        write_catalogue(catalogue, destination)
    LOG.info("Catalogue publication changed=%s missions=%d destination=%s", changed, new_count, destination)
    return catalogue


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--source-complete", action="store_true",
                        help="Manual confirmation of upstream completion; skips the stability wait")
    parser.add_argument("--stability-seconds", type=float, default=30,
                        help="Quiet observation window for periodic checks; default 30, not proof of completion")
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    started = time.monotonic()
    LOG.info("Publication started source=%s destination=%s", args.input, args.output)
    status = 1
    try:
        publish_catalogue(args.input, args.output, source_complete=args.source_complete,
                          stability_seconds=args.stability_seconds)
        status = 0
    except (OSError, ValueError, ImportError) as error:
        LOG.error("Validation/publication failed; previous catalogue preserved: %s", error)
    finally:
        LOG.info("Publication completed status=%d duration_seconds=%.3f", status, time.monotonic() - started)
    return status


if __name__ == "__main__":
    sys.exit(main())
