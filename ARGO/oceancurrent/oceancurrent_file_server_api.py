import pandas as pd
import json
import os
import logging
import re
from typing import List, Dict
from collections import deque

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
        - key: string, the product name as defined in https://github.com/aodn/ocean-current-frontend/blob/main/src/constants/product.ts.
        - value: dict, the root paths (file forlder name) of the products and the subproducts.
    3. The rootpath is a list of strings, which are the corresponding path (file folder name) of each product.
    4. The subproduct is a list of strings, which are the corresponding path (file folder name) of each subproduct.
    5. The max_layer is an integer, which is the maximum depth of the file structure to search for the gif files.
    6. The excluded is a list of dits, which are the folder names to exclude in the search and the no. of layer in which the fodler is located. If the value is None, no folder will be excluded.
    7. The included is a list of dicts, which are the folder names to include in the search and the no. of layer in which the folder is located. If the value is None, all folders will be included.

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
        "max_layer": 3,
        "include": None,
        "exclude": None
    },
    "sixDaySst": {
        "rootpath": ["DR_SST_daily", "STATE_daily"],
        "subproduct": [
            {"name": "sixDaySst-sst", "path": "SST"},
            {"name": "sixDaySst-sstAnomaly", "path": "SST_ANOM"},
            {"name": "sixDaySst-centile", "path": "pctiles"}
        ],
        "max_layer": 3,
        "include": None,
        "exclude": None
    },
    "currentMetersPlot":{
        "rootpath": ["timeseries"],
        "subproduct": [
            # the subproduct name is the product name and the version number with a hypen between them
            {"name": "currentMetersPlot-49", "path": "ANMN_P49"},
            {"name": "currentMetersPlot-48", "path": "ANMN_P48"}
        ],
        "max_layer": 4,
        "include": None,
        "exclude": [
            {"name": "mapst", "layer": 3} # exclude the mapst folder at the 3rd layer - the rest of the folders at the 3rd layer will be included
        ]
     },
    "currentMetersCalendar": {
        "rootpath": ["timeseries"],
        "subproduct": [
            # the subproduct name is the product name and the version number with a hypen between them
            {"name": "currentMetersCalendar-49", "path": "ANMN_P49"},
            {"name": "currentMetersCalendar-48", "path": "ANMN_P48"}
        ],
        "max_layer": 2,
        "include": None,
        "exclude": None
    },
    "currentMetersRegion": {
        "rootpath": ["timeseries"],
        "subproduct": [
            # the subproduct name is the product name and the version number with a hypen between them
            {"name": "currentMetersRegion-49", "path": "ANMN_P49"},
            {"name": "currentMetersRegion-48", "path": "ANMN_P48"}
        ],
        "max_layer": 3,
        "include": [
            {"name": "mapst", "layer": 3}
        ], # only scan the mapst folder at the 3rd layer - the rest of the folders at the 3rd layer will be excluded
        "exclude": None
    },
    "oceanColour": {
        "rootpath": ["STATE_daily"],
        "subproduct": [
            {"name": "oceanColour-chlA", "path": "CHL"},
            {"name": "oceanColour-chlAAge", "path": "CHL_AGE"}
        ],
        "max_layer": 3,
        "include": None,
        "exclude": None
    },
    # (Ocean Colour) Snapshot Chlorophyll-a in which case the product is separated by region, located at the root path
    "oceanColour": {
        # The rootpath is an empty list because the product is located at the root website path. TODO: add corresponding logic
        "rootpath": [],
        # TODO: use "*.*_chl$" as the subproduct path
        "subproduct": [
            {
                "name": "oceanColour-chlA", "path": ".*_chl$"
            }
        ],
        "max_layer": 1,
        "include": None,
        "exclude": None
    },
    # Subproducts SLA and Centiles of product (Ocean Colour) Snapshot Chlorophyll-a
    "adjustedSeaLevelAnomaly": {
        "rootpath": ["STATE_daily"],
        "subproduct": [
            {"name": "adjustedSeaLevelAnomaly-sla", "path": "SLA"},
            {"name": "adjustedSeaLevelAnomaly-centiles", "path": "SLA_pctiles"}
        ],
        "max_layer": 3,
        "include": None,
        "exclude": None
    },
    # Adjusted Sea Level Anom. SLA + SST
    "adjustedSeaLevelAnomaly": {
        # The rootpath is an empty list because the product is located at the root website path. TODO: add corresponding logic
        "rootpath": [],
        "subproduct": [
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "GAB"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "ht"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "NE"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "NW"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "SE"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "SO"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "SW"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Adelaide"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "AlbEsp"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Bris-Syd"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Brisbane"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Brisbane2"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Broome"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "CGBR"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "CLeeu"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Coffs"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "DonPer"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "EGAB"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Kimberley"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "LordHoweS"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "NGBR"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "NWS"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Ningaloo"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Perth"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "RechEyre"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Rottnest"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "SAgulfs"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "SGBR"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "SNSW"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Syd-Hob"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "Tas"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "TasE"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "TimorP"},
            {"name": "adjustedSeaLevelAnomaly-sst", "path": "XmasI"}
        ],
        "max_layer": 1,
        "include": None,
        "exclude": None
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
            "name": self.name
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
        if len(FILE_PATH_CONFIG.get(self.product).get("subproduct")) == 0:
            productId = f"{self.product}-{self.subProduct}" if self.subProduct else self.product
        else:
            productId = self.subProduct
        return {
            "path": self.path,
            "productId": productId, # productId is the subproduct name, otherwise it is the product name and the folder name with a hyphen between them
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
        self.config = FILE_PATH_CONFIG
        self.root_path = root_path
        self.scanned_product = {}

        # convert the products to be watched to a stack
        self.watched_products = deque()
        for product_name, products in FILE_PATH_CONFIG.items():
            for product in products["rootpath"]:
                if not "*" in product:
                    # format the watched products as "product_name:product_path" because there might be multiple root paths for a product
                    self.watched_products.append(product_name + ":" + product)
                else:
                    matched_folders = self.fuzzy_match(product, self.root_path)
                    for folder in matched_folders:
                        self.watched_products.append(product_name + ":" + folder)
        

    def load_product_config(self, product_name: str) -> Dict:
        return self.config.get(product_name)
    

    def fuzzy_match(self, pattern, current_path) -> List[str]:
        # if there is "*" in the path, it should be a fuzzy match so that folders follow this pattern should be included
        with os.scandir(current_path) as folders:
            return [f.name for f in folders if re.match(pattern, f.name) and f.is_dir()]
    

    def scan_products(self):
        # list all the products in the base path
        watched_products_path = set([p.split(":")[1] for p in self.watched_products])
        listed_products = os.scandir(self.root_path)
        products_folder = [f.name for f in listed_products if f.is_dir() and f.name in watched_products_path]
        
        # catch empty folder case
        if len(products_folder) == 0:
            logger.error("No products found in the base path: {}".format(self.root_path))
            return
        else:
            logger.info("Found product folders: {}".format(products_folder))

        # scan gif files for each product
        while self.watched_products:
            # get the current product config to scan from the product folder
            current_scan_product = self.watched_products.popleft()
            
            product_name, product_path = current_scan_product.split(":")
            product_config = FILE_PATH_CONFIG[product_name]

            # if the subproduct is emrty, scanning start from the product folder
            if len(product_config["subproduct"]) == 0:
                self.list_product_files(product_name=product_name, current_layer=1, product_config=product_config, path=[self.root_path, product_path])
            else:
                for subproduct in product_config["subproduct"]:
                    # evaluate the subproduct path
                    subproduct_path = os.path.join(self.root_path, product_path, subproduct["path"])
                    if not os.path.exists(subproduct_path):
                        logger.error("Subproduct path: {} does not exist.".format(subproduct_path))
                        continue
                    else:
                        logger.info("Scanning product: {} in folder: {}".format(product_name, subproduct["path"]))
                        self.list_product_files(product_name=product_name, current_layer=2, product_config=product_config, path=[self.root_path, product_path, subproduct["path"]])
        if self.scanned_product:
            for product, profiles in self.scanned_product.items():
                data = [p.to_json() for p in profiles]
                if product[1]:
                    json_file = os.path.join(self.root_path, product[0], product[1], f"{product[1]}.json")
                    logger.info("JSON file {} created for product: {}".format(f"{product[1]}.json", profiles[0].subProduct))
                else:
                    json_file = os.path.join(self.root_path, product[0], f"{product[0]}.json")
                    logger.info("JSON file {} created for product: {}".format(f"{product[0]}.json", profiles[0].product))
                with open(json_file, "w") as f:
                    json.dump(data, f, indent=4)


    def list_product_files(self, product_name, current_layer, product_config, path):
            subproducts = product_config["subproduct"]
            if current_layer < product_config["max_layer"]:
                try:
                    with os.scandir(os.path.join(*path)) as folders:
                        # check if the folder is excluded
                        if product_config["exclude"]:
                            for exclude in product_config["exclude"]:
                                if exclude["layer"] == current_layer:
                                    folders = [f for f in folders if f.name != exclude["name"]]
                        # check if the folder is included
                        if product_config["include"]:
                            for include in product_config["include"]:
                                if include["layer"] == current_layer:
                                    folders = [f for f in folders if f.name == include["name"]]

                        for f in folders:
                            # do filtering for subproducts to save computation time
                            product = path[-1]
                            if current_layer == 1 and len(subproducts) > 0:
                                watched_subproducts = {sub["path"] for sub in self.watched_subproducts.get(product, [])}
                                if f.name not in watched_subproducts:
                                    continue

                            if f.is_dir():
                                new_path = path + [f.name]
                                self.list_product_files(product_name, current_layer + 1, product_config, path=new_path)
                except FileNotFoundError as e:
                    logger.error("Error scanning folder: {}".format(e))

            elif current_layer == product_config["max_layer"]:
                if product_config["exclude"]:
                    for exclude in product_config["exclude"]:
                        if exclude["name"] == path[-1]:
                            return
                if product_config["include"]:
                    for include in product_config["include"]:
                        if include["name"] != path[-1]:
                            return
                subproduct_name = next((sub["name"] for sub in subproducts if sub["path"] == path[2]), None)
                if subproduct_name is None and product_config["max_layer"] >=2 :
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
                try:
                    with os.scandir(os.path.join(*path)) as files:
                        for file in files:
                            if file.is_file() and file.name.endswith(".gif"):
                                file_path = os.path.join(*path[1:], file.name)
                                file_relative_path = os.path.join(os.sep, os.path.normpath(file_path))
                                file_obj = Files(name=file.name, path=file_relative_path)
                                gif_files.append(file_obj)
                    profile.set_files(gif_files)

                    if product_config["max_layer"] == 1:
                        # scanned at the product level and there is no subproduct
                        product_subproduct = (path[1], None)
                    else:
                        product_subproduct = (path[1], path[2])
                    scanned_products = set(self.scanned_product.keys())
                    if product_subproduct not in scanned_products:
                        self.scanned_product[product_subproduct] = [profile]
                    else:
                        profiles = self.scanned_product.get(product_subproduct)
                        profiles.append(profile)
                        self.scanned_product[product_subproduct] = profiles
                except FileNotFoundError as e:
                    logger.error("Error scanning folder: {}".format(e))
    
def main():
    file_structure_explorer = FileStructureExplorer(OCEAN_CURRENT_FILE_ROOT_PATH)
    file_structure_explorer.scan_products()

if __name__ == "__main__":
    main()