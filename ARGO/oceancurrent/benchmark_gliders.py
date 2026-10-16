"""Opt-in local benchmark; creates synthetic assets only in a temporary directory.

Run: TMPDIR=/var/tmp python3 ARGO/oceancurrent/benchmark_gliders.py
Allow space for approximately 2.4 million directory entries in the stress fixture.
Fixture creation/cleanup are excluded from worker timing and peak RSS.
"""

import json
import logging
import os
from pathlib import Path
import resource
import shutil
import subprocess
import sys
import tempfile
import time


def build_fixture(root, scenario):
    source = Path(__file__).parent / "tests/mnt/oceancurrent/website"
    shutil.copytree(source, root, dirs_exist_ok=True)
    if scenario == "baseline":
        return
    # Deterministic, illustrative distributions, not a production census.
    distribution = ([24] * 65 + [100] * 25 + [352] * 8 + [913] * 2
                    if scenario == "representative"
                    else [100] * 25 + [352] * 50 + [913] * 25)
    for prefix, count in (("", 2133), ("nav", 603)):
        for index in range(count):
            period = (4, 12, 30)[index % 3]
            # Includes suffixes, alternate NRT placement, missing periods/videos.
            mission = f"{prefix}Mission{index}20260922"
            ending = (f"A_nrt_{period}d", f"_1_{period}d",
                      f"_{period}d_nrt", f"_{period}d")[index % 4]
            directory = root / "gliders" / (mission + ending)
            directory.mkdir(parents=True)
            seed = directory / "2026000000.gif"
            seed.touch()
            for frame in range(distribution[index % 100]):
                # Hard links avoid millions of inodes; every name is a real file.
                if frame:
                    os.link(seed, directory / f"{2026000000 + frame}.gif")
                os.link(seed, directory / f"{2026000000 + frame}.html")
            if index % 5:
                os.link(seed, directory / f"{directory.name}.mp4")
            for name in ("index.php", "data.json"):
                os.link(seed, directory / name)
    for folder, count in (("missionTS", 760), ("yearmaps", 210)):
        directory = root / "gliders" / folder
        directory.mkdir()
        for index in range(count):
            (directory / f"figure{index}.gif").touch()


def measure(root):
    import oceancurrent_file_server_api as scanner

    logging.disable(logging.CRITICAL)
    scanner.OCEAN_CURRENT_FILE_ROOT_PATH = str(root)
    scanner.OC_API_ENDPOINT = None  # No metadata or monitoring requests.
    metrics = {"gliders_scan_seconds": 0, "gliders_json_seconds": 0,
               "matched_files": {}, "json_bytes": {}}
    scan, save = scanner.scan_files_from_config, scanner.save_result_as_json

    def timed_scan(parent_directory, config):
        started = time.perf_counter()
        files = scan(parent_directory, config)
        if config["productId"].startswith("gliders-"):
            metrics["gliders_scan_seconds"] += time.perf_counter() - started
            metrics["matched_files"][config["productId"]] = len(files)
        return files

    def timed_save(files, config, parent_directory):
        started = time.perf_counter()
        save(files, config, parent_directory)
        if config["productId"].startswith("gliders-"):
            metrics["gliders_json_seconds"] += time.perf_counter() - started
            output = parent_directory / "gliders" / f'{config["productId"]}.json'
            metrics["json_bytes"][config["productId"]] = output.stat().st_size

    scanner.scan_files_from_config = timed_scan
    scanner.save_result_as_json = timed_save
    started, cpu_started = time.perf_counter(), time.process_time()
    scanner.main()  # All 48 configurations, including existing development fixtures.
    metrics["total_seconds"] = time.perf_counter() - started
    metrics["cpu_seconds"] = time.process_time() - cpu_started
    rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    metrics["peak_rss_mib"] = rss / (1024 ** 2 if sys.platform == "darwin" else 1024)
    print(json.dumps(metrics))


if __name__ == "__main__":
    if len(sys.argv) == 3 and sys.argv[1] == "--worker":
        measure(Path(sys.argv[2]))
    else:
        for scenario in ("baseline", "representative", "higher-load"):
            print(f"Preparing {scenario} temporary fixture...", flush=True)
            with tempfile.TemporaryDirectory(prefix="gliders-benchmark-") as temporary:
                root = Path(temporary) / "website"
                build_fixture(root, scenario)
                result = subprocess.run(
                    [sys.executable, str(Path(__file__).resolve()), "--worker", str(root)],
                    check=True, capture_output=True, text=True,
                )
                # The scanner can print a logging fallback warning before JSON.
                metrics = json.loads(result.stdout.splitlines()[-1])
                print(json.dumps({"scenario": scenario, **metrics}), flush=True)
