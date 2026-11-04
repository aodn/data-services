"""Generate deployment bounds from per-map fits or reviewed fixed source-image layouts."""
import logging
import math
import re
import statistics
from urllib.parse import urljoin

from gliders_catalogue import MISSION, _CatalogueParser

LOG = logging.getLogger("gliders_yearmaps")
MAP_NAME = re.compile(r"(?P<year>\d{4})_(?P<platform>sl|sg)_(?P<variable>temp|tempa|psal|psala|flu2|doxy)_(?P<window>04d|12d|30d)(?P<nrt>_nrt)?\.html")
# Reviewed source layouts, not geographic coefficients. Each map is fitted separately.
PANELS = {("sl", 2025): (35, 12, 684, 551), ("sl", 2026): (35, 12, 684, 551),
          ("sg", 2018): (26, 0, 619, 435)}
# Fixed transformations for source GIF layouts reviewed offline against axis ticks,
# coastline landmarks and catalogue anchors: x = ax*longitude + bx, y = ay*latitude + by.
# Slocum reuses the reviewed 2025_sl_temp_04d fit; Seaglider is fitted on 2009-2018.
LAYOUTS = {
    "slocum": dict(panel=(35, 12, 684, 551), x=(12.94901443437376, -1363.4659043258107),
                   y=(-15.86078644507324, -162.82469540295943)),
    "seaglider": dict(panel=(26, 5, 619, 435), x=(9.86175697125394, -1009.6225388572977),
                      y=(-11.312929426565628, -108.6835430698172)),
}
VARIABLES = ("temp", "tempa", "psal", "psala", "flu2", "doxy")
# Every GIF below was checked to share its layout's panel, ticks, tick labels and artwork.
VERIFIED_IMAGES = {
    "%d_%s_%s%s.gif" % (year, platform, variable, suffix): layout
    for platform, suffix, years, layout in (("sl", "", range(2008, 2027), "slocum"),
                                            ("sl", "_nrt", (2025, 2026), "slocum"),
                                            ("sg", "", range(2009, 2019), "seaglider"))
    for year in years for variable in VARIABLES}
# Existing maximum held-out error; a fixed transformation makes every check held out.
MAX_ANCHOR_ERROR = 1.0
# Maximum median signed anchor offset per axis for a map with >= 2 anchors. Saved
# 2008-2026 maps reach 0.29 pixels; a shifted or regenerated layout is rejected whole.
MAX_LAYOUT_OFFSET = 0.5


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
    that mission. Mission labels (title or alt) and URL must agree. Panel
    position is geographic eligibility, checked per mission when generating. SL*/SG* text links are excluded. No GIF or calendar data is read.
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
        if len(parts) != 4 or any(not re.fullmatch(r"[+-]?[0-9]+", p) for p in parts):
            raise ValueError("Malformed mission rectangle: " + name)
        x1, y1, x2, y2 = rect = list(map(int, parts))
        if x1 >= x2 or y1 >= y2:
            raise ValueError("Reversed or empty mission rectangle: " + name)
        href = attrs.get("href", "")
        if not re.fullmatch(r"(?:\.\./|/gliders/)[A-Za-z0-9_-]+/latest\.html", href):
            raise ValueError("Unexpected mission link: " + name)
        path = urljoin("/gliders/yearmaps/" + filename, href)
        if not valid_mission_path(name, path, metadata):
            raise ValueError("Unexpected mission link: " + name)
        deployments[name] = dict(mission_name=name, pixel_rect=rect, bbox=None, url=path)
    return metadata, [deployments[name] for name in sorted(deployments)]


def source_image(html, filename):
    """Return the GIF the HTML image-map is drawn on, as named in its own HTML.

    Only the HTML is read. The image must be the single image using the single
    map and must be a same-directory GIF for this map's year, platform, variable
    and NRT state; otherwise the layout is unknown (None).
    """
    metadata = map_metadata(filename)
    parser = _CatalogueParser()
    parser.feed(html)
    parser.close()
    maps = [e for e in parser.elements if e.tag == "map"]
    images = [e for e in parser.elements if e.tag == "img" and e.attrs.get("usemap")]
    if len(maps) != 1 or len(images) != 1 or images[0].attrs["usemap"] != "#" + maps[0].attrs.get("name", ""):
        return None
    expected = "%d_%s_%s%s.gif" % (metadata["year"], metadata["platform"], metadata["variable"],
                                   "_nrt" if metadata["is_nrt"] else "")
    return expected if images[0].attrs.get("src", "").strip() == expected else None


def inside(rect, panel):
    x1, y1, x2, y2 = rect
    return panel[0] <= x1 < x2 <= panel[2] and panel[1] <= y1 < y2 <= panel[3]


def layout_bounds(deployments, catalogue, layout):
    """Apply a reviewed fixed layout mission by mission; return (bbox, null reason, error).

    A rectangle gets bounds only when it lies inside the layout panel and its
    centre agrees with the mission's single catalogue position within the
    existing one-pixel held-out limit. Other missions in the map are unaffected.
    The map's median offset must also show the layout still fits (ValueError).
    """
    positions = {}
    for m in catalogue["missions"]:
        positions.setdefault(m["mission_name"], set()).add((m["longitude"], m["latitude"]))
    panel, results, offsets = layout["panel"], [], []
    for d in deployments:
        x1, y1, x2, y2 = d["pixel_rect"]
        matches = positions.get(d["mission_name"], set())
        if not inside(d["pixel_rect"], panel):
            results.append((None, "outside verified panel", None))
        elif len(matches) != 1 or any(v is None or not math.isfinite(v) for v in next(iter(matches))):
            results.append((None, "missing or ambiguous catalogue position", None))
        else:
            lon, lat = next(iter(matches))
            offsets.append(((x1 + x2) / 2 - (layout["x"][0] * lon + layout["x"][1]),
                            (y1 + y2) / 2 - (layout["y"][0] * lat + layout["y"][1])))
            error = math.hypot(*offsets[-1])
            if error > MAX_ANCHOR_ERROR:
                results.append((None, "catalogue position disagrees by %.2f pixels" % error, None))
            else:
                results.append((geographic_bbox(d["pixel_rect"], layout), None, error))
    if len(offsets) >= 2:
        median = [statistics.median(o[axis] for o in offsets) for axis in (0, 1)]
        if max(map(abs, median)) > MAX_LAYOUT_OFFSET:
            raise ValueError("Median anchor offset x=%.2f y=%.2f pixels; layout no longer fits" % tuple(median))
    return results


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
        html = sources[filename].decode("utf-8")
        metadata, deployments = parse_yearmap(html, filename)
        try:
            panel = PANELS.get((metadata["platform"], metadata["year"]))
            if panel is None:
                raise ValueError("No reviewed geographic panel for this year/platform")
            # Only in-panel rectangles are anchors or get bounds; every one must still pass.
            eligible = [d for d in deployments if inside(d["pixel_rect"], panel)]
            calibration = calibrate(eligible, catalogue)
            # Calculate the whole map before assigning; an invalid inverse leaves all bounds null.
            bounds = [geographic_bbox(d["pixel_rect"], calibration) for d in eligible]
            for d, bbox in zip(eligible, bounds):
                d["bbox"] = bbox
            for d in deployments:
                if d not in eligible:
                    LOG.warning("Null bbox map=%s mission=%s: outside reviewed panel", metadata["id"], d["mission_name"])
            LOG.info("Calibration map=%s samples=%d max=%.3f rms=%.3f held_out=%.3f pixels", metadata["id"],
                     calibration["samples"], calibration["max_error"], calibration["rms_error"], calibration["held_out_error"])
        except ValueError as error:
            # Maps the per-map fit cannot verify may reuse their source image's reviewed layout.
            layout = VERIFIED_IMAGES.get(source_image(html, filename))
            try:
                if layout is None:
                    raise ValueError("source image layout not verified")
                results = layout_bounds(deployments, catalogue, LAYOUTS[layout])
            except ValueError as rejection:
                LOG.warning("Unverified geography map=%s: %s; %s", metadata["id"], error, rejection)
            else:
                for d, (bbox, reason, _) in zip(deployments, results):
                    d["bbox"] = bbox
                    if reason:
                        LOG.warning("Null bbox map=%s mission=%s: %s", metadata["id"], d["mission_name"], reason)
                accepted = [e for _, _, e in results if e is not None]
                # A per-map fit was expected for reviewed panels, so its fallback is a warning.
                LOG.log(logging.WARNING if (metadata["platform"], metadata["year"]) in PANELS else logging.INFO,
                        "Reviewed layout map=%s layout=%s accepted=%d max_anchor_error=%.3f pixels (per-map fit: %s)",
                        metadata["id"], layout, len(accepted), max(accepted, default=0), error)
        metadata["deployments"] = deployments
        LOG.info("Map discovered id=%s deployments=%d missing_bounds=%d", metadata["id"], len(deployments),
                 sum(d["bbox"] is None for d in deployments))
        maps.append(metadata)
    return dict(schema_version=1, maps=maps)


if __name__ == "__main__":
    import sys
    from publish_gliders_yearmaps import main
    sys.exit(main())
