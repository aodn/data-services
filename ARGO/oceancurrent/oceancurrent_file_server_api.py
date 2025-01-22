import configparser
import pandas as pd
import json
import tempfile
import os
from typing import List
from pathlib import Path
import logging

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


"""
Please config product path with the following formatting rules:
    1. FILE_PATH_CONFIG is a global variable to store the root path of the selected products and subproducts.
       Please ensure it is in JSON format.
    2. Elements in FILE_PATH_CONFIG is formatted as key-value pairs:
        - key: string, the product name.
        - value: dict, the root paths (file forlder name) of the products and the subproducts.
    3. The rootpath is a list of strings, which are the corresponding file folder name of each product.
    4. The subproduct is a list of strings, which are the corresponding file folder name of each subproduct.

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

class FileStructureAnalyser:
    def __init__(self) -> None:
        self.temp_dir = tempfile.mkdtemp()

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

    def load_config(self):
        """
            Load the configurations from global variable FILE_PATH_CONFIG for selected products.
        """
        watchedProduct = []
        watchedSubProduct = []
        productMap = {}
        file_path_config = FILE_PATH_CONFIG
        for key, value in file_path_config.items():
            subproducts = value["subproduct"]
            rootpaths = value["rootpath"]
            for rootpath in rootpaths:
                watchedProduct.append(rootpath)
                productMap[rootpath] = key
            for subproduct in subproducts:
                watchedSubProduct.append(subproduct)
        return watchedProduct, watchedSubProduct, productMap
    
    def data_preprocess(self, file_structure, watchedProduct, watchedSubProduct):
        """
            Preprocess the data from the file structure file. The function will read the file structure file and filter the data based on the watched products and subproducts which is defined in the config file `config.ini`.
            Input:
                file_structure: pd.DataFrame, the file structure data.
                watchedProduct: List[str], the list of watched products.
                watchedSubProduct: List[str], the list of watched subproducts.
            Output:
                file_structure: pd.DataFrame, the filtered file structure data.
                productMap: dict, a dictionary to map the root path to the product name.
        """
        temp_file_structure = file_structure.copy()
        temp_file_structure["full_path"] = file_structure["default_path"].str[1:]
        temp_file_structure.drop(columns=["default_path"], inplace=True)
        temp_file_structure = temp_file_structure[temp_file_structure['full_path'].str.endswith('.gif')]
        temp_file_structure["paths"] = temp_file_structure["full_path"].str.split("/")
        temp_file_structure.loc[:, "paths"] = temp_file_structure["paths"].apply(lambda x: [item for item in x if item != ''])
        temp_file_structure.loc[:, "product"] = temp_file_structure["paths"].apply(lambda x: x[0])
        temp_file_structure.loc[:, "file_name"] = temp_file_structure["paths"].apply(lambda x: x[-1])
        temp_file_structure = temp_file_structure[temp_file_structure['product'].isin(watchedProduct)]
        temp_file_structure.loc[:, "subProduct"] = temp_file_structure["paths"].apply(lambda x: x[1])
        temp_file_structure = temp_file_structure[temp_file_structure['subProduct'].isin(watchedSubProduct)]
        return temp_file_structure
    
    def group_data_formatter(self, data):
        """
            Group the data by the region and format the data to the required format.
            Input:
                data: pd.DataFrame, the data to be formatted.
            Output:
                List[dict], the formatted data in the required, which is the list of files grouped by the region.
        """
        grouped = data.groupby("region")
        grouped_data = []
        for group_name, group_df in grouped:
            product = Product(product=group_df.iloc[0]["product"], 
                            subProduct=self.to_camel_case(group_df.iloc[0]["subProduct"]),
                            region=group_name)
            product.set_path(path="/" + group_df.iloc[0]["folder_path"] + "/" + group_df.iloc[0]["region"])
            product_files = []
            for row in group_df.itertuples(index=False):
                file_name = row.file_name
                file_path = row.full_path
                f = Files(name=file_name, path=file_path)
                product_files.append(f)
            product.set_files(product_files)
            grouped_data.append(product.to_json())
        return grouped_data
    
    def data_formatter(self, ds, productMap):
        """
            Format the data to the required format. The data will be grouped by the product and subproduct, then save the data to a json file, which is named by the subproduct under the product folder.
            Input:
                ds: pd.DataFrame, the data to be formatted.
                productMap: dict, a dictionary to map the root path to the product name.
        """
        formatted_data = ds.copy()
        formatted_data["region"] = ds["paths"].apply(lambda x: x[2])
        formatted_data["folder_path"] = ds.apply(lambda row: '/'.join([row['product'], row['subProduct']]), axis=1)
        
        grouped = formatted_data.groupby("folder_path")
        for group_name, group_df in grouped:
            group_df["product"] = group_df["product"].apply(lambda x: productMap.get(x))
            
            grouped = self.group_data_formatter(group_df)

            # get current folder path
            current_folder = self.base_path
            filePath = os.path.join(current_folder, f"{group_name}.json")            

            directory = os.path.dirname(filePath)
            if not os.path.exists(directory):
                os.makedirs(directory)

            with open(filePath, 'w') as json_file:
                json.dump(grouped, json_file, indent=2)

class FileStructureExplorer(FileStructureAnalyser):
    def __init__(self):
        # extend the FileStructureAnalyser class
        super().__init__()
        
        # define the base path and products (list of strings) for the explorer
        self.watchedProducts = self.get_watched_products()[0]
        self.watchedSubProducts = self.get_watched_products()[1]
        self.productMap = self.get_watched_products()[2]

        self.base_path = None

    def set_base_path(self, base_path: Path):
        """
            Set the base directory folder path for exploring the file structure.
            Input:
                base_path: Path, the base directory folder path.
        """
        self.base_path = base_path

    def get_watched_products(self) -> List[str]:
        """
            This method reads the configuration file and returns the list of watched products.
        """
        return self.load_config()
    

    def list_products(self) -> pd.DataFrame:
        """
            This method go through the base path and list the files in the products, with a walk through the subproducts.
            Output:
                pd.DataFrame, the file structure data which has the same structure from https://oceancurrent.aodn.org.au/OC_files.txt, 
                which has two columns: file_size and default_path.
        """
        products = []
        # find watched products in current directory
        for product in os.listdir(self.base_path):
            product_path = Path(os.path.join(self.base_path, product))
            if product in self.watchedProducts and product_path.is_dir():
                # list sub products in the watched product folder
                for sub_product in os.listdir(product_path):
                    sub_product_path = Path(os.path.join(product_path, sub_product))
                    if sub_product in self.watchedSubProducts and sub_product_path.is_dir():
                        # list files in the sub product folder
                        for root, _, files in os.walk(sub_product_path):
                            for file in files:
                                # keep only files with '.gif' extension
                                if file.endswith(".gif"):
                                    file_size = os.path.getsize(os.path.join(root, file))
                                    # reformat the file path to be relative to the base path
                                    file_path = os.path.join(root, file).replace(self.base_path, ".")
                                    file_path = file_path.replace("\\", "/")
                                    products.append({"file_size": file_size, "default_path": file_path})
        # convert the list to dataframe
        productDF = pd.DataFrame(products)
        return productDF
    
    def pipeline(self, base_path: str):
        """
            The pipeline to explore the file structure and save the data to the required format.
            Input:
                base_path: str, the base directory folder path.
        """
        self.set_base_path(base_path)
        list_products = self.list_products()
        # analyse file structure to JSON response
        raw_data = self.data_preprocess(list_products, self.watchedProducts, self.watchedSubProducts)
        self.data_formatter(raw_data, self.productMap)

if __name__ == '__main__':
    file_structure = FileStructureExplorer()
    file_structure.pipeline(os.path.join(os.path.dirname(__file__), 'tests'))
    logger.info("File structure exploration completed.")
