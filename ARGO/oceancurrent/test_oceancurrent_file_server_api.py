import os
import json
import tempfile
import shutil
import unittest
import unittest.mock
from unittest.mock import patch, MagicMock, mock_open

from pathlib import Path

from oceancurrent_file_server_api import (
    main, FILE_PATH_CONFIG, scan_files_from_config, save_result_as_json,
)


class TestFileServerAPI(unittest.TestCase):

    def setUp(self):
        """Sets up a temporary test directory and copies test files."""
        self.test_dir = tempfile.mkdtemp()
        self.file_test_dir = os.path.join(self.test_dir, "mnt/oceancurrent/website")

        # Copy test files to temp dir
        existing_test_files_path = os.path.join(os.path.dirname(__file__), "tests")
        shutil.copytree(existing_test_files_path, self.test_dir, dirs_exist_ok=True)

    def prepare_test_cases(self):
        """Returns expected JSON contents for different test cases."""
        return {
            "fourHourSst-sst": [
                {
                    "path": "/SST_4hr/SST/Adelaide",
                    "productId": "fourHourSst-sst",
                    "region": "Adelaide",
                    "depth": None,
                    "files": [
                        {
                            "name": "2024041918.gif"
                        }
                    ]
                },
                {
                    "path": "/SST_4hr/SST/SAgulfs",
                    "productId": "fourHourSst-sst",
                    "region": "SAgulfs",
                    "depth": None,
                    "files": [
                        {
                            "name": "2024051010.gif"
                        }
                    ]
                },
            ],
            "sixDaySst-sst": [
                {
                    "path": "/DR_SST_daily/SST/AlbEsp",
                    "productId": "sixDaySst-sst",
                    "region": "AlbEsp",
                    "depth": None,
                    "files": [
                        {
                            "name": "20190801.gif"
                        }
                    ]
                },
                {
                    "path": "/DR_SST_daily/SST/Indo",
                    "productId": "sixDaySst-sst",
                    "region": "Indo",
                    "depth": None,
                    "files": [
                        {
                            "name": "20210213.gif"
                        }
                    ]
                },
                {
                    "path": "/DR_SST_daily/SST/TimorP",
                    "productId": "sixDaySst-sst",
                    "region": "TimorP",
                    "depth": None,
                    "files": [
                        {
                            "name": "20201219.gif"
                        }
                    ]
                }
            ],
            "sealCtd-sealTracks": [
                {
                    "path": "/AATAMS/GAB/tracks",
                    "productId": "sealCtd-sealTracks",
                    "region": "GAB",
                    "depth": None,
                    "files": [
                        {
                            "name": "20240522.gif"
                        }
                    ]
                },
                {
                    "path": "/AATAMS/POLAR/tracks",
                    "productId": "sealCtd-sealTracks",
                    "region": "POLAR",
                    "depth": None,
                    "files": [
                        {
                            "name": "20240522.gif"
                        }
                    ]
                }
            ],
            "sealCtd-sealTracks-video": [
                {
                    "path": "/AATAMS/GAB/tracks",
                    "productId": "sealCtd-sealTracks-video",
                    "region": "GAB",
                    "depth": None,
                    "files": [
                        {
                            "name": "tracks_2017.mp4"
                        }
                    ]
                }
            ],
            "sealCtd-timeseriesTemperature": [
                {
                    "path": "/AATAMS/GAB/timeseries",
                    "productId": "sealCtd-timeseriesTemperature",
                    "region": "GAB",
                    "depth": None,
                    "files": [
                        {
                            "name": "T_2010_2011_p0.gif"
                        }
                    ]
                }
            ],
            "sealCtdTags-10days": [
                {
                    "path": "/AATAMS/SATTAGS/Q9900180/10days",
                    "productId": "sealCtdTags-10days",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "20090210.gif"
                        }
                    ]
                }
            ],
            "sealCtdTags-temperature": [
                {
                    "path": "/AATAMS/SATTAGS/Q9900180",
                    "productId": "sealCtdTags-temperature",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "T.gif"
                        }
                    ]
                }
            ],
            "adjustedSeaLevelAnomaly-sla": [
                {
                    "path": "/STATE_daily/SLA/NE",
                    "productId": "adjustedSeaLevelAnomaly-sla",
                    "region": "NE",
                    "depth": None,
                    "files": [
                        {
                            "name": "20151003.gif"
                        }
                    ]
                }
            ],
            "adjustedSeaLevelAnomaly-nonTidalSla": [
                {
                    "path": "/STATE_daily/NTSLA/Au",
                    "productId": "adjustedSeaLevelAnomaly-nonTidalSla",
                    "region": "Au",
                    "depth": None,
                    "files": [
                        {
                            "name": "2026011812.gif"
                        },
                        {
                            "name": "2026011818.gif"
                        }
                    ]
                }
            ],
            "oceanColour-chlA": [
                {
                    "path": "/STATE_daily/CHL/NZ",
                    "productId": "oceanColour-chlA",
                    "region": "NZ",
                    "depth": None,
                    "files": [
                        {
                            "name": "20190101.gif"
                        }
                    ]
                }
            ],
            "oceanColour-chlA-region": [
                {
                    "path": "/Rowley_chl",
                    "productId": "oceanColour-chlA",
                    "region": "Rowley",
                    "depth": None,
                    "files": [
                        {
                            "name": "2025031805.gif"
                        }
                    ]
                },
                {
                    "path": "/Tas_chl",
                    "productId": "oceanColour-chlA",
                    "region": "Tas",
                    "depth": None,
                    "files": [
                        {
                            "name": "2025031905.gif"
                        },
                        {
                            "name": "2025032204.gif"
                        }
                    ]
                }
            ],
            "oceanColour-chlA-year": [
                {
                    "path": "/Rowley_chl/2009",
                    "productId": "oceanColour-chlA",
                    "region": "Rowley",
                    "depth": None,
                    "files": [
                        {
                            "name": "2009032304.gif"
                        }
                    ]
                }
            ],
            "adjustedSeaLevelAnomaly-sst": [
                {
                    "path": "/Adelaide",
                    "productId": "adjustedSeaLevelAnomaly-sst",
                    "region": "Adelaide",
                    "depth": None,
                    "files": [
                        {
                            "name": "20250321.gif"
                        }
                    ]
                },
                {
                    "path": "/SO",
                    "productId": "adjustedSeaLevelAnomaly-sst",
                    "region": "SO",
                    "depth": None,
                    "files": [
                        {
                            "name": "20160120.gif"
                        }
                    ]
                }
            ],
            "adjustedSeaLevelAnomaly-sst-year": [
                {
                    "path": "/Adelaide/2009",
                    "productId": "adjustedSeaLevelAnomaly-sst-year",
                    "region": "Adelaide",
                    "depth": None,
                    "files": [
                        {
                            "name": "20090321.gif"
                        }
                    ]
                }
            ],
            "currentMetersCalendar-49": [
                {
                    "path": "/timeseries/ANMN_P49",
                    "productId": "currentMetersCalendar-49",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "SW+S_2007-10.gif"
                        }
                    ]
                }
            ],
            "currentMetersRegion-49": [
                {
                    "path": "/timeseries/ANMN_P49/mapst",
                    "productId": "currentMetersRegion-49",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "01_Aust_K1_1.gif"
                        }
                    ]
                }
            ],
            "currentMetersPlot-49": [
                {
                    "path": "/timeseries/ANMN_P49/NWSBRW/xyz",
                    "productId": "currentMetersPlot-49",
                    "region": "NWSBRW",
                    "depth": "xyz",
                    "files": [
                        {
                            "name": "NWSBRW-1907-Long-Ranger-Workhorse-ADCP-159p4_xyz.gif"
                        }
                    ]
                },
                {
                    "path": "/timeseries/ANMN_P49/NWSBRW/zt",
                    "productId": "currentMetersPlot-49",
                    "region": "NWSBRW",
                    "depth": "zt",
                    "files": [
                        {
                            "name": "NWSBRW-2405-Signature500-160_zt.gif"
                        }
                    ]
                }
            ],
            "tidalCurrents-spd": [
                {
                    "path": "/tides/Darwin_spd/2025",
                    "productId": "tidalCurrents-spd",
                    "region": "Darwin",
                    "depth": None,
                    "files": [
                        {"name": "202412310000.gif"},
                        {"name": "202601020030.gif"},
                    ],
                },
                {
                    "path": "/tides/SA_spd/2025",
                    "productId": "tidalCurrents-spd",
                    "region": "SA",
                    "depth": None,
                    "files": [
                        {"name": "202412310030.gif"},
                        {"name": "202512312330.gif"},
                        {"name": "202601010100.gif"},
                    ],
                },
            ],
            "tidalCurrents-sl": [
                {
                    "path": "/tides/SA_hv/2025",
                    "productId": "tidalCurrents-sl",
                    "region": "SA",
                    "depth": None,
                    "files": [
                        {"name": "202412310030.gif"},
                        {"name": "202601010100.gif"},
                    ],
                },
                {
                    "path": "/tides/Bass_hv/2025",
                    "productId": "tidalCurrents-sl",
                    "region": "Bass",
                    "depth": None,
                    "files": [
                        {"name": "202512312330.gif"},
                        {"name": "202601010100.gif"},
                    ],
                },
            ],
            "tidalCurrents-monthplots": [
                {
                    "path": "/tides/monthplots",
                    "productId": "tidalCurrents-monthplots",
                    "region": None,
                    "depth": None,
                    "files": [
                        {"name": "CSIRO_28064_198712.gif"},
                        {"name": "CSIRO_28072_202101.gif"},
                        {"name": "NTC_Y_island_202512.gif"},
                    ],
                },
            ],
            "EACMooringArray": [
                {
                    "path": "/EAC_array_figures/SST/Brisbane",
                    "productId": "EACMooringArray",
                    "region": "Brisbane",
                    "depth": None,
                    "files": [
                        {
                            "name": "20220724.gif"
                        },
                        {
                            "name": "20220725.gif"
                        }
                    ]
                }
            ],
            "swotGsla-ssh": [
                {
                    "path": "/DR_SWOT/SSH/Au",
                    "productId": "swotGsla-ssh",
                    "region": "Au",
                    "depth": None,
                    "files": [
                        {
                            "name": "20260426223317.gif"
                        }
                    ]
                },
                {
                    "path": "/DR_SWOT/SSH/Tas",
                    "productId": "swotGsla-ssh",
                    "region": "Tas",
                    "depth": None,
                    "files": [
                        {
                            "name": "20260424190628.gif"
                        }
                    ]
                }
            ],
            "fishSOOP-profiles": [
                {
                    "path": "/fishsoop/Au/2026",
                    "productId": "fishSOOP-profiles",
                    "region": "Au",
                    "depth": None,
                    "files": [
                        {
                            "name": "20260609.gif"
                        }
                    ]
                },
                {
                    "path": "/fishsoop/TasE/2026",
                    "productId": "fishSOOP-profiles",
                    "region": "TasE",
                    "depth": None,
                    "files": [
                        {
                            "name": "20260609.gif"
                        }
                    ]
                }
            ],
            "fishSOOP-quarterlyAnomalies": [
                {
                    "path": "/fishsoop/anom2",
                    "productId": "fishSOOP-quarterlyAnomalies",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "tanom_reg11_TasE_2025Q2_layer3.gif"
                        },
                        {
                            "name": "tanom_avg_p1.gif"
                        }
                    ]
                }
            ],
            "fishSOOP-depthAnomalies": [
                {
                    "path": "/fishsoop/anom",
                    "productId": "fishSOOP-depthAnomalies",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "tanom_reg18_Au_layer8.gif"
                        }
                    ]
                }
            ],
        }

    def load_and_normalize_json(self, file_path):
        """Loads JSON and normalizes paths for cross-platform compatibility."""
        with open(file_path, "r") as f:
            data = json.load(f)
        for product in data:
            product["path"] = product["path"].replace(os.sep, "/")
        return data

    def verify_json(self, product_key, relative_path, file_name):
        """Verifies that the generated JSON structure matches expected, ignoring order. relative_path is empty if the file stored at the root"""
        expected_json = self.prepare_test_cases()[product_key]

        if relative_path != "":
            generated_json_path = os.path.join(self.file_test_dir, *relative_path.split("/"), f"{file_name}.json")
        else:
            generated_json_path = os.path.join(self.file_test_dir, f"{file_name}.json")

        actual_json = self.load_and_normalize_json(generated_json_path)

        # Verify structure matches (same number of items)
        self.assertEqual(len(actual_json), len(expected_json),
                        f"Different number of items in {file_name}.json")

        # Create sets of (path, region) tuples for order-independent comparison
        actual_items = {(item.get("path", ""), item.get("region", "")) for item in actual_json}
        expected_items = {(item.get("path", ""), item.get("region", "")) for item in expected_json}

        self.assertEqual(actual_items, expected_items,
                        f"Different path/region combinations in {file_name}.json")

        # Verify each item has correct structure (ignoring file content and order)
        actual_map = {(item.get("path", ""), item.get("region", "")): item for item in actual_json}
        expected_map = {(item.get("path", ""), item.get("region", "")): item for item in expected_json}

        for key in expected_map:
            actual_item = actual_map[key]
            expected_item = expected_map[key]

            # Check required fields match
            for field in ["path", "productId", "region", "depth"]:
                self.assertEqual(actual_item.get(field), expected_item.get(field),
                               f"Field '{field}' mismatch for {key} in {file_name}.json")

            # Check files array has expected structure (same length, proper format)
            actual_files = actual_item.get("files", [])
            expected_files = expected_item.get("files", [])
            self.assertEqual(len(actual_files), len(expected_files),
                           f"Different number of files for {key} in {file_name}.json")

            # Verify all files have proper structure
            for file_item in actual_files:
                self.assertIsInstance(file_item, dict, f"File item not a dict in {file_name}.json")
                self.assertIn("name", file_item, f"File missing 'name' field in {file_name}.json")

    def test_file_structure_explorer(self):
        """Tests file structure exploration and JSON generation."""
        # Mock monitoring-related functions to avoid EC2 metadata service calls
        with patch(
            "oceancurrent_file_server_api.OCEAN_CURRENT_FILE_ROOT_PATH",
            new=self.file_test_dir,
        ), patch(
            "oceancurrent_file_server_api._load_api_endpoint",
            return_value=None  # Disable monitoring in tests
        ), patch(
            "oceancurrent_file_server_api.fetch_instance_identity",
            return_value=None  # No EC2 identity in tests
        ):
            main()

            # Verify JSON files for all test cases
            self.verify_json("fourHourSst-sst", "SST_4hr/SST", "SST")
            self.verify_json("sixDaySst-sst", "DR_SST_daily/SST", "SST")
            self.verify_json("sealCtd-sealTracks", "AATAMS/", "sealCtd-sealTracks")
            self.verify_json("sealCtd-sealTracks-video", "AATAMS/", "sealCtd-sealTracks-video")
            self.verify_json("sealCtd-timeseriesTemperature", "AATAMS/", "sealCtd-timeseriesTemperature")
            self.verify_json("sealCtdTags-10days", "AATAMS/", "sealCtdTags-10days")
            self.verify_json("sealCtdTags-temperature", "AATAMS/", "sealCtdTags-temperature")
            self.verify_json("adjustedSeaLevelAnomaly-sla", "STATE_daily/SLA", "SLA")
            self.verify_json("adjustedSeaLevelAnomaly-nonTidalSla", "STATE_daily/NTSLA", "NTSLA")
            self.verify_json("oceanColour-chlA", "STATE_daily/CHL", "CHL")
            self.verify_json("oceanColour-chlA-region", "", "oceanColour-chlA")
            self.verify_json("adjustedSeaLevelAnomaly-sst", "", "adjustedSeaLevelAnomaly-sst")
            self.verify_json("adjustedSeaLevelAnomaly-sst-year", "", "adjustedSeaLevelAnomaly-sst-year")
            self.verify_json("currentMetersCalendar-49", "timeseries", "currentMetersCalendar-49")
            self.verify_json("currentMetersRegion-49", "timeseries", "currentMetersRegion-49")
            self.verify_json("currentMetersPlot-49", "timeseries", "currentMetersPlot-49")
            self.verify_json("tidalCurrents-spd", "tides", "tidalCurrents-spd")
            self.verify_json("tidalCurrents-sl", "tides", "tidalCurrents-sl")
            self.verify_json("tidalCurrents-monthplots", "tides", "tidalCurrents-monthplots")
            self.verify_json("EACMooringArray", "EAC_array_figures", "EACMooringArray")
            self.verify_json("swotGsla-ssh", "DR_SWOT/SSH", "SSH")
            self.verify_json("fishSOOP-profiles", "fishsoop", "fishSOOP-profiles")
            self.verify_json("fishSOOP-quarterlyAnomalies", "fishsoop", "fishSOOP-quarterlyAnomalies")
            self.verify_json("fishSOOP-depthAnomalies", "fishsoop", "fishSOOP-depthAnomalies")
            # Verify the fishsoop finder maps folder is excluded by the region whitelist
            fishsoop_json_path = os.path.join(self.file_test_dir, "fishsoop", "fishSOOP-profiles.json")
            fishsoop_regions = {item["region"] for item in self.load_and_normalize_json(fishsoop_json_path)}
            self.assertNotIn("maps", fishsoop_regions, "Navigation folder 'maps' should not be indexed")
            # Verify unrelated directories under DR_SWOT/SSH are excluded by the region whitelist
            swot_json_path = os.path.join(self.file_test_dir, "DR_SWOT", "SSH", "SSH.json")
            swot_regions = {item["region"] for item in self.load_and_normalize_json(swot_json_path)}
            self.assertNotIn("archive", swot_regions, "Unrelated directory 'archive' should not be indexed")
            # Verify no JSON file required if no gif files listed
            not_existed_path = os.path.join(self.file_test_dir, "timeseries", "currentMetersCalendar-48.json")
            self.assertFalse(os.path.exists(not_existed_path))



class TestGlidersConfiguration(unittest.TestCase):
    """Build representative assets only inside a temporary website root."""

    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.configs = [c for c in FILE_PATH_CONFIG
                        if c["productId"].startswith("gliders-")]
        self.expected = {c["productId"]: [] for c in self.configs}
        for navigation in (False, True):
            category = "navigation" if navigation else "mission"
            for mission, periods in (("TasEastCoast20260922_nrt", (4, 12, 30)),
                                     ("TasEastCoast20260811", (4,))):
                for period in periods:
                    directory = ("nav" if navigation else "") + f"{mission}_{period}d"
                    for extension, suffix in (("gif", ""), ("mp4", "-video")):
                        # Older missions deliberately have no animation.
                        if extension == "mp4" and "nrt" not in mission:
                            continue
                        name = "2026101500.gif" if extension == "gif" else f"{directory}.mp4"
                        self.add_asset(directory, name)
                        self.expected[f"gliders-{category}{suffix}"].append({
                            "path": f"/gliders/{directory}",
                            "productId": f"gliders-{category}{suffix}",
                            "region": directory, "depth": None,
                            "files": [{"name": name}],
                        })
                    for name in ("index.html", "data.json", "index.php", "fake.gif.html"):
                        self.add_asset(directory, name)
        for category, directory, name in (
                ("ts", "missionTS", "sl_TasEastCoast20260922_nrt.gif"),
                ("yearmaps", "yearmaps", "2026_sl_temp_nrt.gif")):
            self.add_asset(directory, name)
            self.add_asset(directory, "index.php")
            self.add_asset(directory, "ignored.mp4")
            self.expected[f"gliders-{category}"].append({
                "path": f"/gliders/{directory}", "productId": f"gliders-{category}",
                "region": None, "depth": None, "files": [{"name": name}],
            })
        for directory in ("TasEastCoast20260922_nrt_4d_backup",
                          "TasEastCoast20260922_nrt_40d", "unrelated",
                          "prefixnavTasEastCoast20260922_nrt_4d_extra"):
            self.add_asset(directory, "2026101500.gif")
        self.add_asset("TasEastCoast20260922_nrt_4d/nested", "ignored.gif")
        sibling = self.root / "gliders_backup" / "TasEastCoast20260922_nrt_4d"
        sibling.mkdir(parents=True)
        (sibling / "ignored.gif").touch()

    def add_asset(self, directory, name):
        target = self.root / "gliders" / directory / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.touch()

    def test_exact_indexes_and_repeat_scan(self):
        self.assertEqual(len(self.configs), 6)
        sentinel = self.root / "gliders" / "unrelated.json"
        sentinel.write_text("preserve me")
        for _ in range(2):  # Generated indexes must not feed back into the next scan.
            for config in self.configs:
                with self.subTest(product=config["productId"]):
                    files = scan_files_from_config(self.root, config)
                    save_result_as_json(files, config, self.root)
                    output = self.root / "gliders" / f'{config["productId"]}.json'
                    actual = json.loads(output.read_text())
                    self.assertEqual(sorted(actual, key=lambda r: r["path"]),
                                     sorted(self.expected[config["productId"]],
                                            key=lambda r: r["path"]))
        self.assertEqual(sentinel.read_text(), "preserve me")
        self.assertEqual(set(self.root.rglob("*.json")),
                         {self.root / "gliders" / f'{c["productId"]}.json'
                          for c in self.configs}
                         | {sentinel}
                         | set(self.root.glob("gliders/*/data.json")))

    def test_historical_missions(self):
        # All 42 directories linked by the legacy catalogue and missed originally.
        catalogue = Path(__file__).parent / "fixtures/gliders_historical_missions.txt"
        names = catalogue.read_text().splitlines()
        self.assertEqual(len(names), 42)
        # Other confirmed production names: NRT after the period, and suffix + NRT.
        names += ["Cooktown20160217_4d_nrt", "Cooktown20160217_12d_nrt",
                  "Portland20160128_4d_nrt", "JervisBay20180503a_nrt_12d"]
        for navigation in (False, True):
            category = "navigation" if navigation else "mission"
            for name in names:
                directory = ("nav" if navigation else "") + name
                self.add_asset(directory, "2026101500.gif")
                self.add_asset(directory, f"{directory}.mp4")
            for suffix, extension in (("", ".gif"), ("-video", ".mp4")):
                product = f"gliders-{category}{suffix}"
                config = next(c for c in self.configs if c["productId"] == product)
                save_result_as_json(scan_files_from_config(self.root, config),
                                    config, self.root)
                actual = json.loads((self.root / "gliders" / f"{product}.json").read_text())
                expected = self.expected[product] + [{
                    "path": f"/gliders/{('nav' if navigation else '') + name}",
                    "productId": product,
                    "region": ("nav" if navigation else "") + name,
                    "depth": None,
                    "files": [{"name": "2026101500.gif" if extension == ".gif"
                               else f"{('nav' if navigation else '') + name}.mp4"}],
                } for name in names]
                self.assertEqual(sorted(actual, key=lambda r: r["path"]),
                                 sorted(expected, key=lambda r: r["path"]))

    def test_exclude_unconfirmed_variants(self):
        names = ["Brisbane20180306AB_4d", "Perth20110626_3_4d",
                 "Cooktown20160217_nrt_4d_nrt", "Cooktown20160217_4d_NRT",
                 "Mission20260922_4d_backup", "Mission20260922_4d_tsfoa",
                 "Mission20260922_12d_vtsfc", "Mission20260922_nrt_4d_vtTsS",
                 "Mission20260922_nrt_4d_vtsTS", "Mission20260922_10d",
                 "missionTS_sl_dev1", "yearmaps_junk"]
        for prefix in ("", "nav"):
            for name in names:
                for extension in ("gif", "mp4"):
                    self.add_asset(prefix + name, "unrelated." + extension)
        for config in self.configs:
            files = scan_files_from_config(self.root, config)
            self.assertFalse(any(f.stem == "unrelated" for f in files))

    def test_optional_products_absent(self):
        for asset in (self.root / "gliders").rglob("*.mp4"):
            asset.unlink()
        shutil.rmtree(self.root / "gliders/missionTS")
        shutil.rmtree(self.root / "gliders/yearmaps")
        for config in self.configs:
            files = scan_files_from_config(self.root, config)
            if config["productId"] in ("gliders-mission", "gliders-navigation"):
                self.assertEqual(len(files), 4)  # Three NRT periods + one older period.
            else:
                self.assertEqual(files, [])

    def test_absent_gliders(self):
        with tempfile.TemporaryDirectory() as empty:
            for config in self.configs:
                self.assertEqual(scan_files_from_config(Path(empty), config), [])


class TestMonitoringFunctions(unittest.TestCase):
    """Tests for EC2 monitoring and fatal log notification functions."""

    @patch('oceancurrent_file_server_api.requests.put')
    def test_get_imds_token_success(self, mock_put):
        """Test successful IMDSv2 token retrieval."""
        from oceancurrent_file_server_api import get_imds_token

        mock_response = MagicMock()
        mock_response.text = "test-token-123"
        mock_response.raise_for_status = MagicMock()
        mock_put.return_value = mock_response

        token = get_imds_token()

        self.assertEqual(token, "test-token-123")
        mock_put.assert_called_once()

    @patch('oceancurrent_file_server_api.requests.put')
    def test_get_imds_token_failure(self, mock_put):
        """Test IMDSv2 token retrieval failure."""
        from oceancurrent_file_server_api import get_imds_token
        import requests

        # Use proper requests exception type
        mock_put.side_effect = requests.exceptions.RequestException("Connection failed")

        token = get_imds_token()

        self.assertIsNone(token)

    @patch('oceancurrent_file_server_api.requests.get')
    @patch('oceancurrent_file_server_api.get_imds_token')
    def test_fetch_instance_identity_success(self, mock_get_token, mock_get):
        """Test successful EC2 instance identity fetch."""
        from oceancurrent_file_server_api import fetch_instance_identity

        mock_get_token.return_value = "test-token"
        mock_response = MagicMock()
        mock_response.text = "test-pkcs7-signature"
        mock_response.raise_for_status = MagicMock()
        mock_get.return_value = mock_response

        pkcs7 = fetch_instance_identity()

        self.assertEqual(pkcs7, "test-pkcs7-signature")
        mock_get.assert_called_once()

    @patch('oceancurrent_file_server_api.requests.get')
    @patch('oceancurrent_file_server_api.get_imds_token')
    def test_fetch_instance_identity_failure(self, mock_get_token, mock_get):
        """Test EC2 instance identity fetch failure."""
        from oceancurrent_file_server_api import fetch_instance_identity
        import requests

        mock_get_token.return_value = None
        # Use proper requests exception type
        mock_get.side_effect = requests.exceptions.RequestException("Connection failed")

        pkcs7 = fetch_instance_identity()

        self.assertIsNone(pkcs7)

    @patch('oceancurrent_file_server_api.requests.post')
    @patch('oceancurrent_file_server_api._cached_pkcs7', 'test-pkcs7')
    @patch('oceancurrent_file_server_api.OC_API_ENDPOINT', 'https://test.example.com/api')
    def test_send_fatal_log_success(self, mock_post):
        """Test successful fatal log notification."""
        from oceancurrent_file_server_api import send_fatal_log

        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_post.return_value = mock_response

        result = send_fatal_log("Test error message", source_type="test", additional_context="unit_test=true")

        self.assertTrue(result)
        mock_post.assert_called_once()

        # Verify payload structure
        call_args = mock_post.call_args
        payload = call_args[1]['json']
        self.assertIn('pkcs7', payload)
        self.assertIn('timestamp', payload)
        self.assertIn('errorMessage', payload)
        self.assertIn('source', payload)
        self.assertIn('context', payload)
        self.assertEqual(payload['errorMessage'], "Test error message")
        self.assertIn('test', payload['source'])

    @patch('oceancurrent_file_server_api._cached_pkcs7', None)
    @patch('oceancurrent_file_server_api.OC_API_ENDPOINT', 'https://test.example.com/api')
    def test_send_fatal_log_no_pkcs7(self):
        """Test fatal log notification when PKCS7 signature is not available."""
        from oceancurrent_file_server_api import send_fatal_log

        result = send_fatal_log("Test error message")

        self.assertFalse(result)

    @patch('oceancurrent_file_server_api._cached_pkcs7', 'test-pkcs7')
    @patch('oceancurrent_file_server_api.OC_API_ENDPOINT', None)
    def test_send_fatal_log_no_endpoint(self):
        """Test fatal log notification when API endpoint is not configured."""
        from oceancurrent_file_server_api import send_fatal_log

        result = send_fatal_log("Test error message")

        self.assertFalse(result)

    def test_load_api_endpoint_from_env(self):
        """Test loading API endpoint from environment variable."""
        from oceancurrent_file_server_api import _load_api_endpoint

        # Mock both path checks and environment variable (use correct env var name)
        with patch.dict(os.environ, {'OC_API_ENDPOINT': 'https://env.example.com/api'}, clear=False):
            with patch('oceancurrent_file_server_api.os.path.exists', return_value=False):
                endpoint = _load_api_endpoint()

        self.assertEqual(endpoint, 'https://env.example.com/api')

    def test_load_api_endpoint_from_file(self):
        """Test loading API endpoint from config file."""
        from oceancurrent_file_server_api import _load_api_endpoint

        with tempfile.NamedTemporaryFile(mode='w', delete=False, suffix='.conf') as f:
            f.write('https://file.example.com/api')
            config_file = f.name

        try:
            # Mock the config file location to point to our temp file
            with patch.dict(os.environ, {'OC_API_ENDPOINT': ''}, clear=False):
                with patch('oceancurrent_file_server_api.os.path.exists') as mock_exists:
                    with patch('builtins.open', mock_open(read_data='https://file.example.com/api')):
                        def exists_side_effect(path):
                            return path == '/etc/imos/oc_api_endpoint.conf'
                        mock_exists.side_effect = exists_side_effect

                        endpoint = _load_api_endpoint()

            self.assertEqual(endpoint, 'https://file.example.com/api')
        finally:
            os.unlink(config_file)


if __name__ == '__main__':
    unittest.main()
