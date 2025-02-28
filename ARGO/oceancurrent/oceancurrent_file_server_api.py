import pandas as pd
import json
import os
import logging
import re
from typing import List
from collections import defaultdict

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
        "subproduct": [
            {"name": "fourHourSst-sstFilled", "path": "SST_Filled"},
            {"name": "fourHourSst-sst", "path": "SST"},
            {"name": "fourHourSst-sstAge", "path": "SST_Age"},
            {"name": "fourHourSst-windSpeed", "path": "Wind"}
        ],
        "max_layer": 3
    },
    "sixDaySst": {
        "rootpath": ["DR_SST_daily", "STATE_daily"],
        "subproduct": [
            {"name": "sixDaySst-sst", "path": "SST"},
            {"name": "sixDaySst-sstAnomaly", "path": "SST_ANOM"},
            {"name": "sixDaySst-centile", "path": "pctiles"}
        ],
        "max_layer": 3
    },
    "currentMeters": {
        "rootpath": ["timeseries"],
        "subproduct": [
            {"name": "currentMeters-mooredInstrumentArray", "path": "ANMN_P49"},
            {"name": "currentMeters-shelf", "path": "ANMN_P49"},
            {"name": "currentMeters-deepADCP", "path": "ANMN_P48"},
            {"name": "currentMeters-deepADV", "path": "ANMN_P48"},
            {"name": "currentMeters-southernOcean", "path": "ANMN_P48"}
        ],
        "max_layer": 4
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
            path: string, the path of the product in the server.
            product: string, the product name.
            subProduct: string, the subproduct name.
            region: string, the region name.
            depth: string, the depth of the product. Only current meter products have depth attribute 'xyz' or 'zt'.
            files: List[Files], a list of Files objects.
        A product object can be converted to json format through the `to_json` method. 
        Attributes `region`, `files` and `path` can be set through the `set_region`, `set_files` and `set_path` methods.
    """
    def __init__(self, product: str, subProduct: str) -> None:
        self.path = None
        self.product = product
        self.subProduct = subProduct
        self.region = None
        self.depth = None
        self.files = []

    def set_region(self, region: str) -> None:
        self.region = region
    
    def set_files(self, files: List[Files]) -> None:
        self.files = files

    def set_path(self, path: str) -> None:
        self.path = path

    def set_depth(self, depth: str) -> None:
        self.depth = depth

    def to_json(self):
        return {
            "path": self.path,
            "product": self.product,
            "subProduct": self.subProduct,
            "region": self.region,
            "depth": self.depth, # only current meter products have depth attribute
            "files": [f.to_json() for f in self.files]
        }
    
    def __eq__(self, other):
        if not isinstance(other, Product):
            return NotImplemented
        
        return self.product == other.product and self.subProduct == other.subProduct and self.region == other.region and self.depth == other.depth
    
    def __hash__(self):
        return hash((self.path, self.product, self.subProduct, self.region, self.depth))

# Define service class to explore the file structure
class FileStructureExplorer:
    def __init__(self, root_path: str) -> None:
        self.root_path = root_path
        self.watched_products = []
        self.watched_subproducts = {}
        self.product_name_mapping = {}
        self.scanned_product = {}

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

    def scan_products(self):
        # list all the products in the base path
        watched_products = set(self.watched_products)
        listed_products = os.scandir(self.root_path)
        products_folder = [f.name for f in listed_products if f.is_dir() and f.name in watched_products]
        
        # catch empty folder case
        if len(products_folder) == 0:
            logger.error("No products found in the base path.")
            return
        else:
            logger.info("Found product folders: {}".format(products_folder))
            
            for product in products_folder:
                product_name = self.product_name_mapping.get(product)
                product_config = FILE_PATH_CONFIG[product_name]
                current_layer = 1
                self.list_product_files(product_name=product_name, current_layer=current_layer, product_config=product_config, path=[self.root_path, product])
        if self.scanned_product:
            for product, profiles in self.scanned_product.items():
                data = [p.to_json() for p in profiles]
                json_file = os.path.join(self.root_path, product[0], product[1], f"{product[1]}.json")
                with open(json_file, "w") as f:
                    json.dump(data, f, indent=4)
                logger.info("Scanned product {} and created JSON file for subproduct: {}".format(profiles[0].product, profiles[0].subProduct))
                    

    def list_product_files(self, product_name, current_layer, product_config, path):
        if current_layer < product_config["max_layer"]:
            with os.scandir(os.path.join(*path)) as folders:
                for f in folders:
                    # do filtering for subproducts to save computation time
                    product = path[-1]
                    if current_layer == 1 and len(self.watched_subproducts[product]) > 0:
                        watched_subproducts = {sub["path"] for sub in self.watched_subproducts.get(product, [])}
                        if f.name not in watched_subproducts:
                            continue

                    if f.is_dir():
                        new_path = path + [f.name]
                        self.list_product_files(product_name, current_layer + 1, product_config, path=new_path)

        elif current_layer == product_config["max_layer"]:
            product_name = self.product_name_mapping.get(path[1])
            subproduct_name = next((sub["name"] for sub in self.watched_subproducts[path[1]] if sub["path"] == path[2]), None)
            if subproduct_name is None:
                subproduct_name = path[2]
                
            # init product object
            region = None
            depth = None
            current_product_path = None
            profile = Product(product=product_name, subProduct=subproduct_name)

            path_elements = path[1:product_config["max_layer"] + 1]
            current_product_path = os.path.normpath(os.path.join(*path_elements))
            region = path[3] if product_config["max_layer"] >= 3 else None
            depth = path[4] if product_config["max_layer"] >= 4 else None

            if not current_product_path.startswith(os.sep):  
                current_product_path = os.sep + current_product_path

            profile.set_region(region)
            profile.set_path(current_product_path)
            profile.set_depth(depth)

            # scan the gif files
            gif_files = []
            # file path only need relative path, no need to include the root path
            with os.scandir(os.path.join(*path)) as files:
                for file in files:
                    if file.is_file() and file.name.endswith(".gif"):
                        file_path = os.path.join(*path[1:], file.name)
                        file_relative_path = os.path.normpath(file_path)
                        file_obj = Files(name=file.name, path=file_relative_path)
                        gif_files.append(file_obj)
            profile.set_files(gif_files)

            product_subproduct = (path[1], path[2])
            scanned_products = set(self.scanned_product.keys())
            if product_subproduct not in scanned_products:
                self.scanned_product[product_subproduct] = [profile]
            else:
                profiles = self.scanned_product.get(product_subproduct)
                profiles.append(profile)
                self.scanned_product[product_subproduct] = profiles
            
    
def main():
    file_structure_explorer = FileStructureExplorer(OCEAN_CURRENT_FILE_ROOT_PATH)
    file_structure_explorer.load_config()
    file_structure_explorer.scan_products()

if __name__ == "__main__":
    main()