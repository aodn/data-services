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

    def test_file_structure_explorer(self):
        with patch('oceancurrent_file_server_api.OCEAN_CURRENT_FILE_ROOT_PATH', new=self.file_test_dir):
            main()

            # Verify the generated json files for a watched product
            product = "DR_SST_daily"
            subproduct = "SST"

            self.assertTrue(os.path.exists(os.path.join(self.file_test_dir, product, subproduct, f'{subproduct}.json')))

            # Verify the content of a generated json file
            generated_json_path = os.path.join(self.file_test_dir, product, subproduct, f"{subproduct}.json")
            with open(generated_json_path, 'r') as f:
                    generated_json = json.load(f)

            # replace seperator for windows
            for product in generated_json:
                product['path'] = product['path'].replace(os.sep, '/')
                for file in product['files']:
                    file['path'] = file['path'].replace(os.sep, '/')

            expected_json = [
                {
                    "path": "/DR_SST_daily/SST/AlbEsp",
                    "product": "sixDaySst",
                    "subProduct": "sst",
                    "region": "AlbEsp",
                    "files": [
                            {
                                "name": "20190801.gif",
                                "path": "/DR_SST_daily/SST/AlbEsp/20190801.gif"
                            }
                ]},
                {
                    "path": "/DR_SST_daily/SST/Indo",
                    "product": "sixDaySst",
                    "subProduct": "sst",
                    "region": "Indo",
                    "files": [
                            {
                                "name": "20210213.gif",
                                "path": "/DR_SST_daily/SST/Indo/20210213.gif"
                            }
                ]},
                {
                    "path": "/DR_SST_daily/SST/TimorP",
                    "product": "sixDaySst",
                    "subProduct": "sst",
                    "region": "TimorP",
                    "files": [
                            {
                                "name": "20201219.gif",
                                "path": "/DR_SST_daily/SST/TimorP/20201219.gif"
                            }
                ]},
            ]
            
            self.assertEqual(generated_json, expected_json, f"The generated SST.json content in DR_SST_daily is correct")

if __name__ == '__main__':
    unittest.main()