"""Generate deployment bounds using the former frontend's per-map linear fit."""
import logging
import math
import re
from urllib.parse import unquote, urljoin, urlparse

from gliders_catalogue import MISSION, _CatalogueParser

LOG = logging.getLogger("gliders_yearmaps")
MAP_NAME = re.compile(r"(?P<year>\d{4})_(?P<platform>sl|sg)_(?P<variable>temp|tempa|psal|psala|flu2|doxy)_(?P<window>04d|12d|30d)(?P<nrt>_nrt)?\.html")
BASE = "https://oceancurrent.aodn.org.au/gliders/yearmaps/"
# Reviewed source layouts, not geographic coefficients. Each map is fitted separately.
PANELS = {("sl", 2025): (35, 12, 684, 551), ("sl", 2026): (35, 12, 684, 551),
          ("sg", 2018): (26, 0, 619, 435)}


def map_metadata(filename):
    match = MAP_NAME.fullmatch(filename)
    if not match:
        raise ValueError("Unsupported year-map filename: " + filename)
    values = match.groupdict()
    return dict(id=filename[:-5], year=int(values["year"]), platform=values["platform"],
                variable=values["variable"], window=values["window"], is_nrt=bool(values["nrt"]))


def valid_mission_path(name, path, metadata):
    window = str(int(metadata["window"][:-1])) + "d"
    folders = {name + "_" + window}
    if name.endswith("_nrt"):
        folders.add(name[:-4] + "_" + window + "_nrt")
    return (isinstance(path, str) and name.endswith("_nrt") == metadata["is_nrt"] and
            path in {"/gliders/" + folder + "/latest.html" for folder in folders})


def parse_yearmap(html, filename):
    """Read the first mission-labelled rectangle; later links are not geometry.

    In the saved CSIRO sources the geographic rectangle precedes other links for
    that mission. Mission labels (title or alt), URL and the reviewed panel must
    agree. SL*/SG* text links are excluded. No GIF or calendar data is read.
    """
    metadata = map_metadata(filename)
    if not re.search(r"</html\s*>\s*$", html, re.I):
        raise ValueError("Incomplete year-map HTML: " + filename)
    parser = _CatalogueParser()
    parser.feed(html)
    parser.close()
    active = {e.attrs.get("href", "").strip() for e in parser.elements
              if e.tag == "a" and any(e.elements("b"))}
    if filename not in active:
        raise ValueError("Year-map identity not confirmed by active navigation: " + filename)
    maps = [e for e in parser.elements if e.tag == "map"]
    if len(maps) != 1 or not any(e.attrs.get("shape") == "default" and e.attrs.get("href") == "#"
                                 for e in maps[0].elements("area")):
        raise ValueError("Missing complete HTML image-map")
    deployments = {}
    panel = PANELS.get((metadata["platform"], metadata["year"]))
    for area in maps[0].elements("area"):
        attrs = area.attrs
        labels = {attrs[key] for key in ("title", "alt") if MISSION.fullmatch(attrs.get(key, ""))}
        if not labels:
            continue
        if len(labels) != 1:
            raise ValueError("Conflicting mission labels")
        name = labels.pop()
        if name in deployments:
            continue
        if attrs.get("shape", "").lower() != "rect":
            raise ValueError("Unsupported mission area shape: " + name)
        parts = re.split(r"[\s,]+", attrs.get("coords", "").strip())
        if len(parts) != 4 or any(not p.isdigit() for p in parts):
            raise ValueError("Malformed mission rectangle: " + name)
        x1, y1, x2, y2 = rect = list(map(int, parts))
        if x1 >= x2 or y1 >= y2:
            raise ValueError("Reversed or empty mission rectangle: " + name)
        if panel and not (panel[0] <= x1 < x2 <= panel[2] and panel[1] <= y1 < y2 <= panel[3]):
            raise ValueError("First mission rectangle outside reviewed geographic panel: " + name)
        url = urlparse(urljoin(BASE + filename, attrs.get("href", "")))
        path = unquote(url.path)
        if (url.scheme != "https" or url.netloc != urlparse(BASE).netloc or url.query or url.fragment
                or not valid_mission_path(name, path, metadata)):
            raise ValueError("Unexpected mission link: " + name)
        deployments[name] = dict(mission_name=name, pixel_rect=rect, bbox=None, url=path)
    return metadata, [deployments[name] for name in sorted(deployments)]


def fit_axis(samples, geographic, pixel):
    mean_geo = sum(s[geographic] for s in samples) / len(samples)
    mean_pixel = sum(s[pixel] for s in samples) / len(samples)
    variance = sum((s[geographic] - mean_geo) ** 2 for s in samples)
    if variance < 1e-8:
        raise ValueError("Degenerate calibration coordinates")
    scale = sum((s[geographic] - mean_geo) * (s[pixel] - mean_pixel) for s in samples) / variance
    return scale, mean_pixel - scale * mean_geo


def calibrate(deployments, catalogue):
    """Port of calibrateGliderMap: fit centres, then validate EVERY matched mission.

    Centre agreement is checked, not assumed exact. Integer rectangle edges and
    catalogue coordinates rounded to 0.01 degrees explain subpixel residuals.
    """
    positions = {}
    for m in catalogue["missions"]:
        positions.setdefault(m["mission_name"], set()).add((m["longitude"], m["latitude"]))
    samples = []
    for d in deployments:
        matches = positions.get(d["mission_name"], set())
        if len(matches) != 1 or any(v is None or not math.isfinite(v) for v in next(iter(matches), ())):
            LOG.warning("Missing or ambiguous catalogue position mission=%s", d["mission_name"])
            continue
        lon, lat = next(iter(matches))
        x1, y1, x2, y2 = d["pixel_rect"]
        samples.append((lon, lat, (x1 + x2) / 2, (y1 + y2) / 2))
    if len(samples) < 6 or any(max(s[i] for s in samples) - min(s[i] for s in samples) < 10 for i in (0, 1)):
        raise ValueError("At least six missions spanning 10 degrees in both axes are required")
    x, y = fit_axis(samples, 0, 2), fit_axis(samples, 1, 3)
    if x[0] <= 0 or y[0] >= 0:
        raise ValueError("Unexpected map axis orientation")

    def residual(sample, x, y):
        lon, lat, px, py = sample
        return math.hypot(px - (x[0] * lon + x[1]), py - (y[0] * lat + y[1]))

    errors = [residual(s, x, y) for s in samples]
    held_out = []
    for i, sample in enumerate(samples):
        others = samples[:i] + samples[i + 1:]
        held_out.append(residual(sample, fit_axis(others, 0, 2), fit_axis(others, 1, 3)))
    maximum, rms, held = max(errors), math.sqrt(sum(e * e for e in errors) / len(errors)), max(held_out)
    if maximum > 0.75 or rms > 0.5 or held > 1:
        raise ValueError("Calibration residuals exceed limits: max=%.3f rms=%.3f held_out=%.3f pixels" % (maximum, rms, held))
    return dict(x=x, y=y, max_error=maximum, rms_error=rms, held_out_error=held, samples=len(samples))


def pixel_to_geographic(x, y, calibration):
    lon = (x - calibration["x"][1]) / calibration["x"][0]
    lat = (y - calibration["y"][1]) / calibration["y"][0]
    if not math.isfinite(lon) or not math.isfinite(lat) or not -180 <= lon <= 180 or not -90 <= lat <= 90:
        raise ValueError("Invalid inverse geographic coordinates")
    return lon, lat


def geographic_bbox(rect, calibration):
    x1, y1, x2, y2 = rect
    corners = [pixel_to_geographic(x, y, calibration) for x, y in ((x1, y1), (x2, y1), (x2, y2), (x1, y2))]
    return [round(v, 6) for v in (min(p[0] for p in corners), min(p[1] for p in corners),
                                max(p[0] for p in corners), max(p[1] for p in corners))]


def generate_yearmaps(sources, catalogue):
    maps = []
    for filename in sorted(sources):
        metadata, deployments = parse_yearmap(sources[filename].decode("utf-8"), filename)
        try:
            if (metadata["platform"], metadata["year"]) not in PANELS:
                raise ValueError("No reviewed geographic panel for this year/platform")
            calibration = calibrate(deployments, catalogue)
            # Calculate the whole map before assigning; an invalid inverse leaves all bounds null.
            bounds = [geographic_bbox(d["pixel_rect"], calibration) for d in deployments]
            for d, bbox in zip(deployments, bounds):
                d["bbox"] = bbox
            LOG.info("Calibration map=%s samples=%d max=%.3f rms=%.3f held_out=%.3f pixels", metadata["id"],
                     calibration["samples"], calibration["max_error"], calibration["rms_error"], calibration["held_out_error"])
        except ValueError as error:
            LOG.warning("Unverified geography map=%s: %s", metadata["id"], error)
        metadata["deployments"] = deployments
        LOG.info("Map discovered id=%s deployments=%d missing_bounds=%d", metadata["id"], len(deployments),
                 sum(d["bbox"] is None for d in deployments))
        maps.append(metadata)
    return dict(schema_version=1, maps=maps)


if __name__ == "__main__":
    import sys
    from publish_gliders_yearmaps import main
    sys.exit(main())
