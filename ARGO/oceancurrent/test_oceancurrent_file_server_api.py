import os
import json
import tempfile
import shutil
import unittest
from unittest.mock import patch

from oceancurrent_file_server_api import main, OCEAN_CURRENT_FILE_ROOT_PATH

class TestFileServerAPI(unittest.TestCase):

    def setUp(self) -> None:
        # Create a temporary directory
        self.test_dir = tempfile.mkdtemp()
        # mock the website root path
        self.file_test_dir = os.path.join(self.test_dir, 'mnt/oceancurrent/website')

        # Path to the existing test files
        self.existing_test_files_path = os.path.join(os.path.dirname(__file__), 'tests')
        
        # Copy all test files to the temporary directory
        for item in os.listdir(self.existing_test_files_path):
            s = os.path.join(self.existing_test_files_path, item)
            d = os.path.join(self.test_dir, item)
            if os.path.isdir(s):
                shutil.copytree(s, d, False, None)
            else:
                shutil.copy2(s, d)

    def prepare_test_cases(self):
        # Expected json content for current meter product
        expected_json_ANMN_P49 = [
                {
                    "path": "/timeseries/ANMN_P49/NWSBRW/xyz",
                    "productId": "currentMetersPlot-49",
                    "region": "NWSBRW",
                    "depth": "xyz",
                    "files": [
                        {
                            "name": "NWSBRW-1907-Long-Ranger-Workhorse-ADCP-159p4_xyz.gif",
                            "path": "/timeseries/ANMN_P49/NWSBRW/xyz/NWSBRW-1907-Long-Ranger-Workhorse-ADCP-159p4_xyz.gif"
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
                            "name": "NWSBRW-2405-Signature500-160_zt.gif",
                            "path": "/timeseries/ANMN_P49/NWSBRW/zt/NWSBRW-2405-Signature500-160_zt.gif"
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
                            "name": "SW+S_2007-10.gif",
                            "path": "/timeseries/ANMN_P49/SW+S_2007-10.gif"
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
                            "name": "01_Aust_K1_1.gif",
                            "path": "/timeseries/ANMN_P49/mapst/01_Aust_K1_1.gif"
                        }
                    ]
                }
            ]
        
        # Expected json content for SST product
        expected_json_SST = [
                {
                    "path": "/DR_SST_daily/SST/AlbEsp",
                    "productId": "sixDaySst-sst",
                    "region": "AlbEsp",
                    "depth": None,
                    "files": [
                        {
                            "name": "20190801.gif",
                            "path": "/DR_SST_daily/SST/AlbEsp/20190801.gif"
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
                            "name": "20210213.gif",
                            "path": "/DR_SST_daily/SST/Indo/20210213.gif"
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
                            "name": "20201219.gif",
                            "path": "/DR_SST_daily/SST/TimorP/20201219.gif"
                        }
                    ]
                }
            ]
        
        return expected_json_ANMN_P49, expected_json_SST


    def test_file_structure_explorer(self):
        with patch('oceancurrent_file_server_api.OCEAN_CURRENT_FILE_ROOT_PATH', new=self.file_test_dir):
            main()

            # Verify the generated json files for current meter product
            self.assertTrue(os.path.exists(os.path.join(self.file_test_dir, "timeseries", "ANMN_P49", "ANMN_P49.json")))

            # Verify the content of a generated json file
            generated_json_path = os.path.join(self.file_test_dir, "timeseries", "ANMN_P49", "ANMN_P49.json")
            with open(generated_json_path, 'r') as f:
                    generated_json = json.load(f)
            # replace seperator for windows
            for product in generated_json:
                product['path'] = product['path'].replace(os.sep, '/')
                for file in product['files']:
                    file['path'] = file['path'].replace(os.sep, '/')
            # expected json content
            expected_json_ANMN_P49, expected_json_SST = self.prepare_test_cases()
            
            self.assertEqual(generated_json, expected_json_ANMN_P49, f"The generated ANMN_P49.json content in timeseries/ANMN_P49 is correct")

            # Verify the generated json files for SST product
            self.assertTrue(os.path.exists(os.path.join(self.file_test_dir, "DR_SST_daily", "SST", "SST.json")))
            # verify the content of a generated json file for sst product
            generated_json_path = os.path.join(self.file_test_dir, "DR_SST_daily", "SST", "SST.json")
            with open(generated_json_path, 'r') as f:
                    generated_json = json.load(f)
            # replace seperator for windows
            for product in generated_json:
                product['path'] = product['path'].replace(os.sep, '/')
                for file in product['files']:
                    file['path'] = file['path'].replace(os.sep, '/')
            self.assertEqual(generated_json, expected_json_SST, f"The generated SST.json content in DR_SST_daily/SST is correct")



if __name__ == '__main__':
    unittest.main()