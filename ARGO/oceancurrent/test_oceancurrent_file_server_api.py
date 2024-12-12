import os
import json
import tempfile
import shutil
import unittest

from oceancurrent_file_server_api import FileStructureExplorer

class TestFileServerAPI(unittest.TestCase):

    def setUp(self) -> None:
        # Create a temporary directory
        self.test_dir = tempfile.mkdtemp()

        # Path to the existing test files
        self.existing_test_files_path = os.path.join(os.path.dirname(__file__), 'tests')
        
        # # Copy all test files to the temporary directory
        # for item in os.listdir(self.existing_test_files_path):
        #     s = os.path.join(self.existing_test_files_path, item)
        #     d = os.path.join(self.test_dir, item)
        #     if os.path.isdir(s):
        #         shutil.copytree(s, d, False, None)
        #     else:
        #         shutil.copy2(s, d)
    
    def tearDown(self):
        # Remove the temporary directory and all its contents
        shutil.rmtree(self.test_dir)

    def test_file_structure_explorer(self):
        file_structure = FileStructureExplorer()

        # generate json files through the pipeline method
        file_structure.pipeline(self.existing_test_files_path)

        # Verify the generated folders as watched products
        self.assertEqual(file_structure.watchedProducts, ['SST_4hr', 'DR_SST_daily', 'STATE_daily'])

        # Verify the generated json files for a watched product
        self.assertTrue(os.path.exists(os.path.join(self.existing_test_files_path, 'SST_4hr', 'SST.json')))

        # Verify the content of a generated json file
        generated_json_path = os.path.join(self.existing_test_files_path, "DR_SST_daily", "SST.json")
        with open(generated_json_path, 'r') as f:
                generated_json = json.load(f)
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
        
        self.assertEqual(generated_json, expected_json, f"The generated SST.json content in DR_SST_daily is incorrect")

if __name__ == '__main__':
    unittest.main()
        
        