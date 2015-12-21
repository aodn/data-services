#!/usr/bin/python

import numpy as np
import os
import copy
from string import Template

HTTP_BASE = "http://imos-data.aodn.org.au" # TODO

# WERA constants
WERA_STATION_RADIALS_PER_HOUR = 6
# Need at least half the radials for every station
WERA_MIN_RADIALS_PER_STATION = WERA_STATION_RADIALS_PER_HOUR / 2

# For CODAR files, search variables seasonde_LLUV_S1CN to seasonde_LLUV_S6CN
# to populate the NOBS (number of obsevations)
CODAR_NOBS_VARIABLES = [ "seasonde_LLUV_S%dCN" % (i+1) for i in range(0, 6) ]

STATION_FREQUENCY_MINUTES = 5

NETCDF_COMPRESSION_LEVEL = 6
DELIMITER = "_"
DATE_TIME_FORMAT = "%Y%m%dT%H%M%SZ"
FACILITY_PREFIX = "IMOS_ACORN"
RADIAL_BASE = "radial"
RADIAL_QC_BASE = "radial_quality_controlled"
VECTOR_BASE = "vector"
ACORN_BASE = os.path.join("IMOS", "ACORN")

site_type_descriptions = {
    'WERA': {
        'stationInstrument': "WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH",
        'siteAbstract': "${warningQc}The ACORN facility is producing NetCDF files with radials data for each station every ten minutes. Radials represent the surface sea water state component along the radial direction from the receiver antenna and are calculated from the shift of an area under the bragg peaks in a Beam Power Spectrum. The radial values have been calculated using software provided by the manufacturer of the instrument.${radialQc} eMII is using a Matlab program to read all the netcdf files with radial data for two different stations and produce a one hour averaged product with U and V components of the current. Only radial data with a signal to noise ratio >= 8dB and quality control flags 1 or 2 are considered valid in the averaging process. In addition, at least 3 valid measurements (this number of observations is recorded in the NOBS1 and NOBS2 variables) for each radar station at each grid point are necessary to obtain an hourly averaged value. The final product is produced on a regular geographic grid. More information on the data processing is available through the IMOS MEST http://imosmest.aodn.org.au/geonetwork/srv/en/main.home ."
    },
    'CODAR': {
        'stationInstrument': "CODAR Ocean Sensors/SeaSonde"
    }
}

site_descriptions = {
    'GBR': {
        'type': "WERA",
        'name': "Capricorn Bunker Group",
        'timezone': 10.0,
        'max_speed': 2.0,
        'stations': {
            'TAN': {
                'name': "Tannum Sands"
            },
            'LEI': {
                'name': "Lady Elliott"
            }
        },
        'stations_order': [] # TODO Site deactivated?
    },
    'CBG': {
        'type': "WERA",
        'name': "Capricorn Bunker Group",
        'timezone': 10.0,
        'max_speed': 3.0,
        'stations': {
            'TAN': {
                'name': "Tannum Sands"
            },
            'LEI': {
                'name': "Lady Elliott"
            }
        },
        'stations_order': [ 'TAN', 'LEI' ],
        'overrides': [
            {
                'time_start': '19700101T000000',
                'time_end': '20110301T040459',
                'attributes': {
                    'file_suffix': '-before_20110301T040500'
                }
            }
        ]
    },
    'SAG': {
        'type': "WERA",
        'name': "South Australia Gulf",
        'timezone': 9.5,
        'max_speed': 3.0,
        'stations': {
            'CWI': {
                'name': "Cape Wiles"
            },
            'CSP': {
                'name': "Cape Spencer"
            }
        },
        'stations_order': [ 'CWI', 'CSP' ]
    },
    'PCY': {
        'type': "WERA",
        'name': "Rottnest Shelf",
        'timezone': 8.0,
        'max_speed': 3.0,
        'stations': {
            'GUI': {
                'name': "Guilderton"
            },
            'FRE': {
                'name': "Fremantle"
            }
        },
        'stations_order': [] # TODO Site deactivated?
    },
    'ROT': {
        'type': "WERA",
        'name': "Rottnest Shelf",
        'timezone': 8.0,
        'max_speed': 3.0,
        'stations': {
            'GUI': {
                'name': "Guilderton"
            },
            'FRE': {
                'name': "Fremantle"
            }
        },
        'stations_order': [ 'GUI', 'FRE' ]
    },
    'COF': {
        'type': "WERA",
        'name': "Coffs Harbour",
        'timezone': 10.0,
        'max_speed': 3.0,
        'stations': {
            'RRK': {
                'name': "Red Rock"
            },
            'NNB': {
                'name': "North Nambucca"
            }
        },
        'stations_order': [ 'RRK', 'NNB' ]
    },
    'BONC': {
        'type': "CODAR",
        'name': "Bonney Coast",
        'stations': [ 'BONC' ],
        'timezone': 9.5,
        'dimensions': {
            "lat": 69,
            "lon": 69
        },
        'stations': {
            'BFCV': {
                'name': "Cape Douglas"
            },
            'NOCR': {
                'name': "Nora Creina"
            }
        },
        'stations_order': [ 'BFCV', 'NOCR' ]
    },
    'TURQ': {
        'type': "CODAR",
        'name': "Turqoise Coast",
        'stations': [ 'TURQ' ],
        'timezone': 8.0,
        'dimensions': {
            "lat": 60,
            "lon": 59
        },
        'stations': {
            'SBRD': {
                'name': "SeaBird"
            },
            'CRVT': {
                'name': "Cervantes"
            },
            'GHED': {
                'name': "Green Head"
            },
            'LANC': {
                'name': "Lancelin"
            }
        },
        'stations_order': [ 'LANC', 'GHED' ],
        'overrides': [
            {
                'time_start': '19700101T000000',
                'time_end': '20121214T235959',
                'attributes': {
                    'dimensions': {
                        "lat": 55,
                        "lon": 57
                    },
                    'stations_order': [ 'SBRD', 'CRVT' ],
                    'file_suffix': '-before_20121215T000000'
                }
            },
            {
                'time_start': '20121215T000000',
                'time_end': '20130318T235959',
                'attributes': {
                    'stations_order': [ 'SBRD', 'GHED' ]
                }
            }
        ]
    }
}

# Perform calculations with np.float64 for better precision. Variables will be
# stored as float4 (32 bit) in the NetCDF file though
var_mapping_wera = {
    "ssr_Surface_Radial_Sea_Water_Speed": np.float64,
    "ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity": np.float64,
    "ssr_Surface_Radial_Sea_Water_Speed_Standard_Error": np.float64,
    "ssr_Surface_Radial_Sea_Water_Speed_quality_control": np.float32,
    "ssr_Bragg_Signal_To_Noise": np.float64
}

var_mapping_codar = {
    "ssr_Surface_Eastward_Sea_Water_Velocity": np.float64,
    "ssr_Surface_Eastward_Sea_Water_Velocity_Standard_Error": np.float64,
    "ssr_Surface_Northward_Sea_Water_Velocity": np.float64,
    "ssr_Surface_Northward_Sea_Water_Velocity_Standard_Error": np.float64,
    "seasonde_LLUV_S1CN": np.float32, # Use floats, so we can use nans
    "seasonde_LLUV_S2CN": np.float32,
    "seasonde_LLUV_S3CN": np.float32,
    "seasonde_LLUV_S4CN": np.float32,
    "seasonde_LLUV_S5CN": np.float32,
    "seasonde_LLUV_S6CN": np.float32
}

qc_flag_values = np.arange(10, dtype=np.int8)
qc_flag_meaning = [
    "no_qc_performed ",
    "good_data ",
    "probably_good_data ",
    "bad_data_that_are_potentially_correctable ",
    "bad_data ",
    "value_changed ",
    "not_used ",
    "not_used ",
    "interpolated_values ",
    "missing_values"
]

FLOAT_FILL_VALUE = np.float(999999.0)
BYTE_FILL_VALUE = np.byte(-99)

current_variables = {
    "TIME": {
        "dtype": "f8",
        "dimensions": [ "TIME" ],
        "attributes": [
            [ "standard_name", "time" ],
            [ "long_name",     "time" ],
            [ "units",         "days since 1950-01-01 00:00:00 UTC" ],
            [ "axis",          "T" ],
            [ "valid_min",     0.0 ],
            [ "valid_max",     999999.0 ],
            [ "calendar",      "gregorian" ],
            [ "comment",       "Given time lays at the middle of the averaging time period." ]
        ]
    },
    "LATITUDE": {
        "dtype": "f8",
        "dimensions": [ "LATITUDE" ],
        "attributes": [
            [ "standard_name",   "latitude" ],
            [ "long_name",       "latitude" ],
            [ "units",           "degrees_north" ],
            [ "axis",            "Y" ],
            [ "valid_min",       -90.0 ],
            [ "valid_max",       90.0 ],
            [ "reference_datum", "geographical coordinates, WGS84 datum" ]
        ]
    },
    "LONGITUDE": {
        "dtype": "f8",
        "dimensions": [ "LONGITUDE" ],
        "attributes": [
            [ "standard_name",   "longitude" ],
            [ "long_name",       "longitude" ],
            [ "units",           "degrees_east" ],
            [ "axis",            "X" ],
            [ "valid_min",       -180.0 ],
            [ "valid_max",       180.0 ],
            [ "reference_datum", "geographical coordinates, WGS84 datum" ]
        ]
    },
    "GDOP": {
        "dtype": "f4",
        "dimensions": [ "LATITUDE", "LONGITUDE" ],
        "fill_value": FLOAT_FILL_VALUE,
        "attributes": [
            [ "long_name",   "radar beam intersection angle" ],
            [ "units",       "Degrees" ],
            [ "valid_min",   np.float32(0.0) ],
            [ "valid_max",   np.float32(180.0) ],
            [ "coordinates", "LATITUDE LONGITUDE" ],
            [ "comment",     "This angle is used to assess the impact of Geometric Dilution of Precision. If angle between [150; 160[ or ]20; 30], QC flag will not be lower than 3. If angle >= 160 or <= 20, then QC flag will not be lower than 4." ]
        ]
    },
    "UCUR": {
        "dtype": "f4",
        "fill_value": FLOAT_FILL_VALUE,
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "standard_name",       "eastward_sea_water_velocity" ],
            [ "long_name",           "Mean of sea water velocity U component values in 1 hour${longNameComment}" ],
            [ "units",               "m s-1" ],
            [ "valid_min",           np.float32(-10) ],
            [ "valid_max",           np.float32(10.0) ],
            [ "cell_methods",        "TIME: mean" ],
            [ "ancillary_variables", "NOBS1, NOBS2, UCUR_quality_control" ],
            [ "coordinates",         "TIME LATITUDE LONGITUDE" ]
        ]
    },
    "VCUR": {
        "dtype": "f4",
        "fill_value": FLOAT_FILL_VALUE,
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "standard_name",       "northward_sea_water_velocity" ],
            [ "long_name",           "Mean of sea water velocity V component values in 1 hour${longNameComment}" ],
            [ "units",               "m s-1" ],
            [ "valid_min",           np.float32(-10) ],
            [ "valid_max",           np.float32(10.0) ],
            [ "cell_methods",        "TIME: mean" ],
            [ "ancillary_variables", "NOBS1, NOBS2, VCUR_quality_control" ],
            [ "coordinates",         "TIME LATITUDE LONGITUDE" ]
        ]
    },
    "UCUR_sd": {
        "dtype": "f4",
        "fill_value": np.float32(FLOAT_FILL_VALUE),
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "long_name",           "Standard deviation of sea water velocity U component values in 1 hour${longNameComment}" ],
            [ "units",               "m s-1" ],
            [ "valid_min",           np.float32(-10) ],
            [ "valid_max",           np.float32(10.0) ],
            [ "cell_methods",        "TIME: standard_deviation" ],
            [ "ancillary_variables", "NOBS1, NOBS2, UCUR_quality_control" ],
            [ "coordinates",         "TIME LATITUDE LONGITUDE" ]
        ]
    },
    "VCUR_sd": {
        "dtype": "f4",
        "fill_value": np.float32(FLOAT_FILL_VALUE),
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "long_name",           "Standard deviation of sea water velocity V component values in 1 hour${longNameComment}" ],
            [ "units",               "m s-1" ],
            [ "valid_min",           np.float32(-10) ],
            [ "valid_max",           np.float32(10.0) ],
            [ "cell_methods",        "TIME: standard_deviation" ],
            [ "ancillary_variables", "NOBS1, NOBS2, VCUR_quality_control" ],
            [ "coordinates",         "TIME LATITUDE LONGITUDE" ]
        ]
    },
    "NOBS1": {
        "dtype": "b",
        "fill_value": BYTE_FILL_VALUE,
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "long_name",   "Number of observations of sea water velocity in 1 hour from station 1${longNameComment}" ],
            [ "coordinates", "TIME LATITUDE LONGITUDE" ]
        ]
    },
    "NOBS2": {
        "dtype": "b",
        "fill_value": BYTE_FILL_VALUE,
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "long_name",   "Number of observations of sea water velocity in 1 hour from station 2${longNameComment}" ],
            [ "coordinates", "TIME LATITUDE LONGITUDE" ]
        ]
    },
    "UCUR_quality_control": {
        "dtype": "b",
        "fill_value": BYTE_FILL_VALUE,
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "standard_name",               "eastward_sea_water_velocity status_flag" ],
            [ "long_name",                   "quality flag for eastward_sea_water_velocity" ],
            [ "coordinates",                 "TIME LATITUDE LONGITUDE" ],
            [ "quality_control_conventions", "IMOS standard set using IODE flags" ],
            [ "quality_control_set",         1. ],
            [ "valid_min",                   min(qc_flag_values) ],
            [ "valid_max",                   max(qc_flag_values) ],
            [ "flag_values",                 qc_flag_values ],
            [ "flag_meanings",               qc_flag_meaning ]
        ]
    },
    "VCUR_quality_control": {
        "dtype": "b",
        "fill_value": BYTE_FILL_VALUE,
        "dimensions": [ "TIME", "LATITUDE", "LONGITUDE" ],
        "attributes": [
            [ "standard_name",               "northward_sea_water_velocity status_flag" ],
            [ "long_name",                   "quality flag for northward_sea_water_velocity" ],
            [ "coordinates",                 "TIME LATITUDE LONGITUDE" ],
            [ "quality_control_conventions", "IMOS standard set using IODE flags" ],
            [ "quality_control_set",         1. ],
            [ "valid_min",                   min(qc_flag_values) ],
            [ "valid_max",                   max(qc_flag_values) ],
            [ "flag_values",                 qc_flag_values ],
            [ "flag_meanings",               qc_flag_meaning ]
        ]
    }
}

global_attributes = [
    [ "project",                      "Integrated Marine Observing System (IMOS)" ],
    [ "Conventions",                  "CF-1.5,IMOS-1.2" ],
    [ "institution",                  "Australian Coastal Ocean Radar Network (ACORN)" ],
    [ "title",                        "IMOS ACORN $siteLongName ($site), one hour averaged current $titleQc data, $timeCoverageStart" ],
    [ "instrument",                   "$stationInstrument" ],
    [ "site_code",                    "$site, $siteLongName" ],
    [ "ssr_Stations",                 "$stations" ],
    [ "id",                           "$id" ],
    [ "date_created",                 "$dateCreated" ],
    [ "abstract",                     "$siteAbstract" ],
    [ "history",                      "${prevHistory} ${dateCreated} Modification of the NetCDF format by eMII to visualise the data using ncWMS." ],
    [ "source",                       "Terrestrial HF radar" ],
    [ "keywords",                     "Oceans" ],
    [ "netcdf_version",               "4.1.1" ],
    [ "naming_authority",             "IMOS" ],
    [ "quality_control_set",          "1" ],
    [ "file_version",                 "$fileVersion" ],
    [ "file_version_quality_control", "$fileVersionDescriptionQC" ],
    [ "geospatial_lat_min",           0. ],
    [ "geospatial_lat_max",           0. ],
    [ "geospatial_lat_units",         "degrees_north" ],
    [ "geospatial_lon_min",           0. ],
    [ "geospatial_lon_max",           0. ],
    [ "geospatial_lon_units",         "degrees_east" ],
    [ "geospatial_vertical_min",      0. ],
    [ "geospatial_vertical_max",      0. ],
    [ "geospatial_vertical_units",    "m" ],
    [ "time_coverage_start",          "$timeCoverageStart" ],
    [ "time_coverage_end",            "$timeCoverageEnd" ],
    [ "time_coverage_duration",       "$timeCoverageDuration" ],
    [ "local_time_zone",              0. ],
    [ "data_centre_email",            "info@emii.org.au" ],
    [ "data_centre",                  "eMarine Information Infrastructure (eMII)" ],
    [ "author",                       "Galibert, Guillaume" ],
    [ "author_email",                 "guillaume.galibert@utas.edu.au" ],
    [ "institution_references",       "http://www.imos.org.au/acorn.html" ],
    [ "principal_investigator",       "Wyatt, Lucy" ],
    [ "citation",                     " The citation in a list of references is: IMOS, [year-of-data-download], [Title], [data-access-URL], accessed [date-of-access]" ],
    [ "acknowledgment",               "Data was sourced from the Integrated Marine Observing System (IMOS) - IMOS is supported by the Australian Government through the National Collaborative Research Infrastructure Strategy (NCRIS) and the Super Science Initiative (SSI)." ],
    [ "distribution_statement",       "Data, products and services from IMOS are provided \"as is\" without any warranty as to fitness for a particular purpose" ],
    [ "comment",                      "${extraComment}This NetCDF file has been created using the IMOS NetCDF User Manual v1.2. A copy of the document is available at http://imos.org.au/facility_manuals.html ." ]
]

attribute_templating_wera = {
    "stationInstrument": site_type_descriptions['WERA']['stationInstrument'],
    "longNameComment": ", after rejection of obvious bad data (see abstract).",
    "warningQc": "These data have not been quality controlled. ",
    "radialQc": " Each current value has a quality control flag based on Geometric Dilution of Precision (GDOP) information only.",
    "fileVersionDescriptionQC": "Data in this file has not been fully quality controlled. Provided flags are only based on Geometric Dilution of Precision (GDOP) information (radials crossing angles at each grid point).",
    "fileVersion": "Level 0 - Raw data",
    "titleQc": "non QC",
    "extraComment": "",
    # Those attributes we do not want
    "id": None,
    "history": None,
    "time_coverage_duration": None
}
attribute_templating_wera['siteAbstract'] = Template(site_type_descriptions['WERA']['siteAbstract']).substitute(attribute_templating_wera)

attribute_templating_wera_qc = {
    "stationInstrument": site_type_descriptions['WERA']['stationInstrument'],
    "longNameComment": ", after rejection of obvious bad data (see abstract).",
    "warningQc": "",
    "radialQc": " Each current value has a corresponding quality control flag.",
    "fileVersionDescriptionQC": "Data in this file has been through the IMOS quality control procedure (Reference Table C). Every data point in this file has an associated quality flag.",
    "fileVersion": "Level 1 - Quality Controlled data",
    "titleQc": "QC",
    "extraComment": "",
    # Those attributes we do not want
    "id": None,
    "history": None,
    "time_coverage_duration": None
}
attribute_templating_wera_qc['siteAbstract'] = Template(site_type_descriptions['WERA']['siteAbstract']).substitute(attribute_templating_wera_qc)

attribute_templating_codar = {
    "stationInstrument": site_type_descriptions['CODAR']['stationInstrument'],
    "longNameComment": ".",
    "warningQc": "",
    "radialQc": " Each current value has a corresponding quality control flag.",
    "fileVersionDescriptionQC": "Data in this file has not been fully quality controlled. Provided flags are only based on Geometric Dilution of Precision (GDOP) information (radials crossing angles at each grid point).",
    "fileVersion": "Level 0 - Raw data",
    "titleQc": "non QC",
    "extraComment": "These data have not been quality controlled. They represent values calculated using software provided by CODAR Ocean Sensors. The file has been modified by eMII in order to visualise the data using ncWMS software. ",
    # Those attributes we do not want
    "time_coverage_end": None
}

variable_order = [
    "TIME", "LATITUDE", "LONGITUDE",
    "GDOP", "UCUR", "VCUR", "UCUR_sd", "VCUR_sd",
    "NOBS1", "NOBS2", "UCUR_quality_control", "VCUR_quality_control"
]
