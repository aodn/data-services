import pandas as pd
import json
import os
import logging
import re
from typing import List
from pathlib import Path

# Define the absolute path of the file directory root path
OCEAN_CURRENT_FILE_ROOT_PATH = "/mnt/oceancurrent/website/"

logging.basicConfig(level=logging.INFO, format="%(levelname)s - %(message)s")
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Define the selected products and their corresponding subproducts to watch
"""
Please config product path with the following formatting rules:
    1. FILE_PATH_CONFIG is a global variable to store the root path of the selected products and subproducts.
       Please ensure it is in JSON format.
    2. Elements in FILE_PATH_CONFIG is formatted as key-value pairs:
        - key: string, the product name.
        - value: dict, the root paths (file forlder name) of the products and the subproducts.
    3. The rootpath is a list of strings, which are the corresponding path (file folder name) of each product.
    4. The subproduct is a list of strings, which are the corresponding path (file folder name) of each subproduct.

"""
FILE_PATH_CONFIG = {
    "fourHourSst": {
        "rootpath": ["SST_4hr"],
        "subproduct": ["SST_Filled", "SST", "SST_Age", "Wind"]
    },
    "sixDaySst": {
        "rootpath": ["DR_SST_daily", "STATE_daily"],
        "subproduct": ["SST", "SST_ANOM", "pctiles"]
    }
}

class Files:
    """
        Files class to store the file information. A file has two attributes: name and path. Both in string format.
        A file object can be converted to json format through the `to_json` method.
    """
    def __init__(self, name: str, path:str) -> None:
        self.name = name
        self.path = path

    def to_json(self):
        return {
            "name": self.name,
            "path": self.path
        }
    
class Product:
    """
        A Product class to store the product information. A product has four attributes: product, subProduct, region, path and files.
        Attributes:
            product: string, the product name.
            subProduct: string, the subproduct name.
            region: string, the region name.
            files: List[Files], a list of Files objects.
            path: string, the path of the product in the server.
        A product object can be converted to json format through the `to_json` method. 
        Attributes `region`, `files` and `path` can be set through the `set_region`, `set_files` and `set_path` methods.
    """
    def __init__(self, product: str, subProduct: str, region: str) -> None:
        self.product = product
        self.subProduct = subProduct
        self.region = region
        self.path = None
        self.files = []

    def set_region(self, region: str) -> None:
        self.region = region
    
    def set_files(self, files: List[Files]) -> None:
        self.files = files

    def set_path(self, path: str) -> None:
        self.path = path

    def to_json(self):
        return {
            "path": self.path,
            "product": self.product,
            "subProduct": self.subProduct,
            "region": self.region,
            "files": [f.to_json() for f in self.files]
        }
    
    def __eq__(self, other):
        if not isinstance(other, Product):
            return NotImplemented
        
        return self.product == other.product and self.subProduct == other.subProduct and self.region == other.region

# Define service class to explore the file structure
class FileStructureExplorer:
    def __init__(self, root_path: str) -> None:
        self.root_path = root_path
        self.watched_products = []
        self.watched_subproducts = {}
        self.product_name_mapping = {}

    def load_config(self):
        # go through the FILE_PATH_CONFIG and look for the selected products and subproducts
        watched_products = []
        watched_subproducts = {}
        product_name_mapping = {}

        for product_name, products in FILE_PATH_CONFIG.items():
            for product in products["rootpath"]:
                watched_products.append(product)
                product_name_mapping[product] = product_name
                subproducts = []
                for subproduct in products["subproduct"]:
                    subproducts.append(subproduct)
                watched_subproducts[product] = subproducts
        self.watched_products = watched_products
        self.watched_subproducts = watched_subproducts
        self.product_name_mapping = product_name_mapping

    def to_camel_case(self, text):
        """
            Convert a string to camel case format.
            Input:
                text: string, the input text.
            Output:
                string, the camel case format of the input text.
        """
        words = text.replace("_", " ").split()
        return words[0].lower() + ''.join(word.capitalize() for word in words[1:])

    def list_products(self):
        # list all the products in the base path
        products_folder = [f for f in os.listdir(self.root_path) if os.path.isdir(os.path.join(self.root_path, f)) and f in self.watched_products]
        
        # catch empty folder case
        if len(products_folder) == 0:
            logger.error("No products found in the base path.")
            return
        else:
            logger.info("Found products: {}".format(products_folder))
            # list all the subproducts in the products
            for product in products_folder:
                subproducts = Path(os.path.join(self.root_path, product)).iterdir()
                for subproduct in subproducts:
                    current_products = []
                    if subproduct.is_dir() and subproduct.name in self.watched_subproducts[product]:
                        logger.info("Found subproducts: {}".format(subproduct))
                        
                        # list all the region folders in the subproduct folder
                        all_regions = [folder for folder in os.listdir(subproduct) if os.path.isdir(os.path.join(subproduct, folder))]
                        logger.info("Found regions: {}".format(all_regions))

                        # list all the gif files in the region folders
                        for region in all_regions:
                            gif_files = []
                            all_files = os.listdir(os.path.join(subproduct, region))
                            filenames = [f for f in all_files if os.path.isfile(os.path.join(os.path.join(subproduct, region), f)) and f.endswith(".gif")]
                            
                            for file in filenames:
                                file_path = os.path.join(product, subproduct.name, region, file)
                                # catch the difference between windows and linux file path
                                file_path = os.path.normpath(file_path)

                                # add separator if not exist
                                if not file_path.startswith(os.sep):  
                                    file_path = os.sep + file_path

                                file = Files(name=file, path=file_path)
                                gif_files.append(file)
                            # catch empty file case
                            if len(gif_files) == 0:
                                logger.error("No gif files found in the folder {}".format(region))

                            current_product_path = os.path.normpath(os.path.join(product, subproduct.name, region))

                            if not current_product_path.startswith(os.sep):  
                                current_product_path = os.sep + current_product_path
                                
                            current_product = Product(product=self.product_name_mapping.get(product), subProduct=self.to_camel_case(subproduct.name), region=region)
                            current_product.set_files(gif_files)
                            current_product.set_path(current_product_path)
                            current_products.append(current_product)

                    # save to json file
                    data = [p.to_json() for p in current_products]
                    with open(os.path.join(subproduct, f"{subproduct.name}.json"), "w") as f:
                        json.dump(data, f, indent=4)
                        logger.info("JSON file generated: {}".format(os.path.join(subproduct, f"{subproduct.name}.json")))
            
    
def main():
    file_structure_explorer = FileStructureExplorer(OCEAN_CURRENT_FILE_ROOT_PATH)
    file_structure_explorer.load_config()
    file_structure_explorer.list_products()

if __name__ == "__main__":
    main()