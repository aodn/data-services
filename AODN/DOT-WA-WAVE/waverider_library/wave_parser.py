import logging
import os
import re

import numpy as np
import pandas as pd
from netCDF4 import Dataset, date2num

from generate_netcdf_att import generate_netcdf_att

logger = logging.getLogger(__name__)

def wave_data_parser(filepath):
    """
    parser of wave data file
    :param filepath: txt file path of AWAC wave data
    :return: pandas dataframe of data, pandas dataframe of data metadata
    """
    # parse wave file
    df = pd.read_excel(filepath)
    for row in range(df.shape[0]):
        for col in range(df.shape[1]):
            if df.iat[row, col] == 'Hs' or df.iat[row, col] == 'Hs(m)':
                row_start = row + 1
                break

    df = df.loc[row_start:]

    new_columns_names = ['datetime',
                         'Total_Hs', 'Total_Tp', 'Total_T1',
                         'Swell_Hs', 'Swell_Tp', 'Swell_T1', 'Swell_Dir',
                         'Sea_Hs', 'Sea_Tp', 'Sea_T1', 'Sea_Dir']
    df.columns = new_columns_names
    #df['datetime'] = pd.to_datetime(df['datetime'].map(lambda x: x), format='%d/%m/%Y %H:%M')
    df['datetime'] = pd.to_datetime(df['datetime'], format='%d/%b/%Y %H:%M', utc=True)  #need to include timezone

    df = df.set_index('datetime')

    return df


def gen_nc_wave_deployment(data_file_path, output_path):
    data = wave_data_parser(data_file_path)
    return

