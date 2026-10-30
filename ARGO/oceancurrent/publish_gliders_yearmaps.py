"""Validate stable local year-maps and atomically publish their geographic index."""
import argparse
import json
import logging
import math
from pathlib import Path
import re
import sys
import time

from gliders_catalogue import MISSION, _snapshot, write_catalogue
from gliders_yearmaps import generate_yearmaps, map_metadata, valid_mission_path
from publish_gliders_catalogue import validate_catalogue

LOG = logging.getLogger("gliders_yearmaps_publication")


def validate_yearmaps(document):
    """Validate both candidates and existing baselines before any replacement."""
    def require(condition, message):
        if not condition:
            raise ValueError(message)

    require(isinstance(document, dict) and type(document.get("schema_version")) is int
            and document["schema_version"] == 1, "Expected schema_version == 1")
    maps = document.get("maps")
    require(isinstance(maps, list) and bool(maps), "Missing or empty maps")
    ids = []
    for entry in maps:
        require(isinstance(entry, dict) and isinstance(entry.get("id"), str), "Invalid map")
        metadata = map_metadata(entry["id"] + ".html")
        require(all(type(entry.get(k)) is type(v) and entry[k] == v for k, v in metadata.items()), "Invalid map identity")
        ids.append(entry["id"])
        deployments = entry.get("deployments")
        require(isinstance(deployments, list), "Invalid deployments")
        names = []
        for deployment in deployments:
            require(isinstance(deployment, dict), "Invalid deployment")
            name = deployment.get("mission_name")
            require(isinstance(name, str) and MISSION.fullmatch(name), "Invalid mission name")
            names.append(name)
            rect = deployment.get("pixel_rect")
            require(isinstance(rect, list) and len(rect) == 4 and all(type(v) is int for v in rect), "Invalid pixel_rect")
            require(0 <= rect[0] < rect[2] and 0 <= rect[1] < rect[3], "Invalid rectangle extent")
            require(valid_mission_path(name, deployment.get("url"), metadata), "Invalid deployment URL")
            require("bbox" in deployment, "Missing bbox")
            bbox = deployment["bbox"]
            if bbox is not None:
                require(isinstance(bbox, list) and len(bbox) == 4 and all(type(v) in (int, float)
                        and math.isfinite(v) for v in bbox), "Invalid bbox")
                require(-180 <= bbox[0] < bbox[2] <= 180 and -90 <= bbox[1] < bbox[3] <= 90, "Invalid WGS84 extent")
        require(len(names) == len(set(names)), "Duplicate mission rectangles")
    require(len(ids) == len(set(ids)), "Duplicate map ids")
    return len(maps)


def _sources(directory, catalogue):
    """Only immediate year-map HTML and the catalogue; no GIF or mission scans."""
    names = sorted(path.name for path in directory.glob("*.html") if re.match(r"\d{4}_", path.name))
    if not names:
        raise ValueError("No year-map HTML discovered")
    resources = {catalogue}
    for name in names:
        # Unknown combinations are visible failures, never guessed or fabricated.
        map_metadata(name)
        resources.add(directory / name)
    return {path: _snapshot(path) for path in sorted(resources)}


def publish_yearmaps(directory, catalogue, destination, *, source_complete=False, stability_seconds=30):
    directory, catalogue, destination = Path(directory), Path(catalogue), Path(destination)
    if not math.isfinite(stability_seconds) or stability_seconds <= 0:
        raise ValueError("stability-seconds must be finite and positive")
    sources = _sources(directory, catalogue)
    if destination.resolve() in {path.resolve() for path in sources} or destination.parent.resolve() == directory.resolve():
        raise ValueError("Output must be outside the year-map sources and differ from all inputs")
    if not source_complete:
        LOG.info("Observing year-map source stability for %s seconds (not proof of upstream completion)", stability_seconds)
        time.sleep(stability_seconds)
        if _sources(directory, catalogue) != sources:
            raise ValueError("Sources changed during stability observation")
    missions = json.loads(sources[catalogue][0])
    validate_catalogue(missions)
    snapshots = {path.name: value[0] for path, value in sources.items()
                 if path.parent == directory and path.suffix == ".html"}
    document = generate_yearmaps(snapshots, missions)
    count = validate_yearmaps(document)
    exists = destination.exists()
    previous = json.loads(destination.read_bytes()) if exists else None
    if exists:
        validate_yearmaps(previous)
        missing = {m["id"] for m in previous["maps"]} - {m["id"] for m in document["maps"]}
        if missing:
            raise ValueError("Previously published maps disappeared; review upstream completeness: " + ", ".join(sorted(missing)))
    # Re-enumerate as well as re-read, detecting additions, deletions and updates.
    if _sources(directory, catalogue) != sources:
        raise ValueError("Sources changed during generation; publication aborted")
    changed = previous != document
    if changed:
        write_catalogue(document, destination)
    LOG.info("Year-map publication changed=%s maps=%d deployments=%d missing_bounds=%d destination=%s", changed, count,
             sum(len(m["deployments"]) for m in document["maps"]),
             sum(d["bbox"] is None for m in document["maps"] for d in m["deployments"]), destination)
    return document


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=Path("/mnt/oceancurrent/website/gliders/yearmaps"))
    parser.add_argument("--catalogue", type=Path, default=Path("/mnt/oceancurrent/website/api/gliders-catalogue.json"))
    parser.add_argument("--output", type=Path, default=Path("/mnt/oceancurrent/website/api/gliders-yearmaps.json"))
    parser.add_argument("--source-complete", action="store_true", help="Manual confirmation; skip stability wait")
    parser.add_argument("--stability-seconds", type=float, default=30)
    args = parser.parse_args(argv)
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s %(message)s")
    started = time.monotonic()
    LOG.info("Publication started source=%s destination=%s", args.input, args.output)
    status = 1
    try:
        publish_yearmaps(args.input, args.catalogue, args.output,
                         source_complete=args.source_complete, stability_seconds=args.stability_seconds)
        status = 0
    except (OSError, ValueError, ImportError) as error:
        LOG.error("Year-map validation/publication failed; previous output preserved: %s", error)
    finally:
        LOG.info("Publication completed status=%d duration_seconds=%.3f", status, time.monotonic() - started)
    return status


if __name__ == "__main__":
    sys.exit(main())
