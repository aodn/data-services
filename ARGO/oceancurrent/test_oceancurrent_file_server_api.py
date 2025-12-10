import os
import json
import tempfile
import shutil
import unittest
import unittest.mock
from unittest.mock import patch, MagicMock, mock_open

from oceancurrent_file_server_api import main


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
            self.verify_json("oceanColour-chlA", "STATE_daily/CHL", "CHL")
            self.verify_json("oceanColour-chlA-region", "", "oceanColour-chlA")
            self.verify_json("adjustedSeaLevelAnomaly-sst", "", "adjustedSeaLevelAnomaly-sst")
            self.verify_json("adjustedSeaLevelAnomaly-sst-year", "", "adjustedSeaLevelAnomaly-sst-year")
            self.verify_json("currentMetersCalendar-49", "timeseries", "currentMetersCalendar-49")
            self.verify_json("currentMetersRegion-49", "timeseries", "currentMetersRegion-49")
            self.verify_json("currentMetersPlot-49", "timeseries", "currentMetersPlot-49")
            self.verify_json("tidalCurrents-spd", "tides", "tidalCurrents-spd")
            self.verify_json("tidalCurrents-sl", "tides", "tidalCurrents-sl")
            self.verify_json("EACMooringArray", "EAC_array_figures", "EACMooringArray")
            # Verify no JSON file required if no gif files listed
            not_existed_path = os.path.join(self.file_test_dir, "timeseries", "currentMetersCalendar-48.json")
            self.assertFalse(os.path.exists(not_existed_path))


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
