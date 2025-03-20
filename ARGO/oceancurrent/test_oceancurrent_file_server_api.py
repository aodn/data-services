import os
import json
import tempfile
import shutil
import unittest
from unittest.mock import patch

from oceancurrent_file_server_api import main, OCEAN_CURRENT_FILE_ROOT_PATH

class TestFileServerAPI(unittest.TestCase):

    def setUp(self):
        """Sets up a temporary test directory and copies test files."""
        self.test_dir = tempfile.mkdtemp()
        self.file_test_dir = os.path.join(self.test_dir, 'mnt/oceancurrent/website')

        # Copy test files to temp dir
        existing_test_files_path = os.path.join(os.path.dirname(__file__), 'tests')
        shutil.copytree(existing_test_files_path, self.test_dir, dirs_exist_ok=True)

    def prepare_test_cases(self):
        """Returns expected JSON contents for different test cases."""
        return {
            "ANMN_P49": [
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
                },
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
                },
                {
                    "path": "/timeseries/ANMN_P49/mapst",
                    "productId": "currentMetersRegion-49",
                    "region": "mapst",
                    "depth": None,
                    "files": [
                        {
                            "name": "01_Aust_K1_1.gif"
                        }
                    ]
                }
            ],
            "SST": [
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
            "CHL_AGE": [
                {
                    "path": "/STATE_daily/CHL_AGE/Au",
                    "productId": "oceanColour-chlAAge",
                    "region": "Au",
                    "depth": None,
                    "files": [
                        {
                            "name": "20190427.gif"
                        }
                    ]
                }
            ],
            "Rowley_chl": [
                {
                    "path": "/Rowley_chl",
                    "productId": "oceanColour-chlA",
                    "region": None,
                    "depth": None,
                    "files": [
                        {
                            "name": "2025031805.gif"
                        }
                    ]
                }
            ]
        }

    def load_and_normalize_json(self, file_path):
        """Loads JSON and normalizes paths for cross-platform compatibility."""
        with open(file_path, 'r') as f:
            data = json.load(f)
        for product in data:
            product['path'] = product['path'].replace(os.sep, '/')
        return data
    

    def verify_json(self, product_key, relative_path):
        """Verifies that the generated JSON matches the expected content."""
        expected_json = self.prepare_test_cases()[product_key]
        generated_json_path = os.path.join(self.file_test_dir, *relative_path.split('/'), f"{relative_path.split('/')[-1]}.json")

        self.assertEqual(self.load_and_normalize_json(generated_json_path), expected_json, 
                         f"The generated {relative_path}.json content is incorrect")

    def test_file_structure_explorer(self):
        """Tests file structure exploration and JSON generation."""
        with patch('oceancurrent_file_server_api.OCEAN_CURRENT_FILE_ROOT_PATH', new=self.file_test_dir):
            main()

            # Verify JSON files for all test cases
            self.verify_json("ANMN_P49", "timeseries/ANMN_P49")
            self.verify_json("SST", "DR_SST_daily/SST")
            self.verify_json("CHL_AGE", "STATE_daily/CHL_AGE")
            self.verify_json("Rowley_chl", "Rowley_chl")

if __name__ == '__main__':
    unittest.main()