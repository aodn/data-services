import os
import unittest
from unittest.mock import Mock, patch

from ardc_nrt.lib.omc.api import omcApi
from pandas import Timestamp

from requests import Session


TEST_ROOT = os.path.dirname(__file__)


class TestOmcApi(unittest.TestCase):
    def setUp(self):
        os.environ["ARDC_OMC_SECRET_FILE_PATH"] = os.path.join(TEST_ROOT, "secrets_omc.json")

        self.api_access = {
            'access_token': 'show my your token',
            'session': 'this is a session object'
        }

        self.sources_info = {'count': 6, 'more_items': False, 'total_items': 6, 'sources':
            [{'id': 'b7b3ded0-6758-4006-904f-db45f8cc012e', 'revision': 1, 'name': 'B10', 'long_name': 'Beacon 10', 'description': '', 'coordinates': [115.653724, -33.315911], 'providers': [{'name': 'Beacon 10 Tide', 'type': 'tide_observed', 'resource': 'dds:AU/WA/Bunbury/Tides/Measured/BTA_AWAC Tide QC', 'properties': {}}, {'name': 'Beacon 10 AWAC', 'type': 'wave_observed', 'resource': 'dds:AU/WA/Bunbury/Waves/Measured/Beacon10_AWAC_1p5D_DUKC', 'properties': {}}, {'name': 'Beacon 10 Wind', 'type': 'wind_observed', 'resource': 'dds:AU/WA/Bunbury/Meteo/Wind/Measured/BN 10 Wind', 'properties': {}}], 'default_providers': {'tide_observed': 'Beacon 10 Tide', 'wave_observed': 'Beacon 10 AWAC', 'wind_observed': 'Beacon 10 Wind'}, 'meta': {}, 'is_superseded': False, 'is_deleted': False, 'created_time_utc': '2021-11-18T07:12:36.345066Z'},
             {'id': '79cfe155-748c-4daa-a152-13bf7c0290d2', 'revision': 0, 'name': 'B15', 'long_name': 'Beacon 15', 'description': '', 'coordinates': [118.508138889, -20.1736388889], 'providers': [{'name': 'primary', 'type': 'wave_observed', 'resource': 'dds:AU/WA/PortHedland/Waves/Measured/B15 WRB OMC 1D', 'properties': {}}], 'default_providers': {'wave_observed': 'primary'}, 'meta': {}, 'is_superseded': False, 'is_deleted': False, 'created_time_utc': '2021-11-18T02:21:31.873079Z'},
             {'id': '9d129524-9f82-426f-ad87-112f377497b5', 'revision': 0, 'name': 'B16', 'long_name': 'Beacon 16', 'description': '', 'coordinates': [118.510444444, -20.1721944444], 'providers': [{'name': 'primary', 'type': 'wave_observed', 'resource': 'dds:AU/WA/PortHedland/Waves/Measured/B16 AWAC_Filtered_1D', 'properties': {}}, {'name': 'primary', 'type': 'meteo_observed', 'resource': 'dds:AU/WA/PortHedland/Meteo/Meteorological/Measured/B16', 'properties': {}}, {'name': 'primary', 'type': 'wind_observed', 'resource': 'dds:AU/WA/PortHedland/Meteo/Wind/Measured/B16', 'properties': {}}], 'default_providers': {'wave_observed': 'primary', 'wind_observed': 'primary', 'meteo_observed': 'primary'}, 'meta': {}, 'is_superseded': False, 'is_deleted': False, 'created_time_utc': '2021-11-18T02:21:28.048669Z'},
             {'id': '55e5864e-9a29-4fd8-838e-beeb1ef611b7', 'revision': 3, 'name': 'B3', 'long_name': 'Beacon 3', 'description': '', 'coordinates': [115.649459, -33.293944], 'providers': [{'name': 'Beacon 3 Tide', 'type': 'tide_observed', 'resource': 'dds:AU/WA/Bunbury/Tides/Measured/BB3 AWAC Tide QC', 'properties': {}}, {'name': 'Beacon 3 AWAC', 'type': 'wave_observed', 'resource': 'dds:AU/WA/Bunbury/Waves/Measured/Beacon3_AWAC_1p5D_DUKC', 'properties': {}}], 'default_providers': {'tide_observed': 'Beacon 3 Tide', 'wave_observed': 'Beacon 3 AWAC'}, 'meta': {}, 'is_superseded': False, 'is_deleted': False, 'created_time_utc': '2021-11-18T07:11:49.41806Z'},
             {'id': '1f0c2644-7c1e-41b0-8d94-850bf0a85695', 'revision': 3, 'name': 'Beacon 2', 'long_name': 'Beacon 2', 'description': 'Beacon 2 Wave', 'coordinates': [-9.387, 38.624], 'providers': [{'name': 'Beacon 2 Wave', 'type': 'wave_observed', 'resource': 'dds:PT/Lisbon/Waves/Measured/TAS07642/MeanDir_1p5d', 'properties': {'schema': 'Measured15DWave'}}, {'name': 'Beacon 2 Wave forecast', 'type': 'wave_forecast', 'resource': 'dds:PT/Lisbon/Waves/Forecasts/Failover_Wave', 'properties': {'schema': 'ForecastSpatial15DWaveArraySchema'}}], 'default_providers': {}, 'meta': {}, 'is_superseded': False, 'is_deleted': False, 'created_time_utc': '2022-01-25T14:37:43.690484Z'},
             {'id': '8c5cdc02-e239-4419-90b8-afa504389f9d', 'revision': 0, 'name': 'GP', 'long_name': 'Gannet Passage', 'description': '', 'coordinates': [141.876895, -10.591385], 'providers': [{'name': 'Gannet Passage Wave', 'type': 'wave_observed', 'resource': 'dds:AU/QLD/TorresStrait/Waves/Measured/Waverider 2 DUKC', 'properties': {'schema': 'Measured15DWave'}}], 'default_providers': {'wave_observed': 'Gannet Passage Wave'}, 'meta': {}, 'is_superseded': False, 'is_deleted': False, 'created_time_utc': '2022-01-12T00:18:00.936159Z'}], 'latest': None}

        self.source_id = '79cfe155-748c-4daa-a152-13bf7c0290d2'

        self.source_id_latest_data = [{'attributes': {'institution': 'OMC International',
                                                      'extracted_date': '2022-03-16T07:39:57.5047195Z',
                                                      'source_id': 'b7b3ded0-6758-4006-904f-db45f8cc012e',
                                                      'source_name': 'B10',
                                                      'source_long_name': 'Beacon 10',
                                                      'provider_name': 'Beacon 10 AWAC',
                                                      'provider_type': 'wave_observed',
                                                      'coordinates': [115.653724, -33.315911]},
                                       'dimensions': {'time': 1},
                                       'variables': {'time': {'attributes': {'standard_name': 'time', 'long_name': 'Time of the observation', 'units': 'ISO8601 timestamp', 'data_min': '2022-03-16T07:18:00Z', 'data_max': '2022-03-16T07:18:00Z'},
                                                              'shape': ['time'],
                                                              'data': ['2022-03-16T07:18:00Z']}, 'hs': {'attributes': {'standard_name': 'wave_observed_significant_height_all', 'long_name': 'Observed wave significant height for all frequencies', 'units': 'm', 'coordinates': 'time', 'data_min': 0.070431, 'data_max': 0.070431}, 'shape': ['time'], 'data': [0.070431]}, 'tp': {'attributes': {'standard_name': 'wave_observed_peak_period_all', 'long_name': 'Observed wave peak period for all frequencies', 'units': 's', 'coordinates': 'time', 'data_min': 22.222222, 'data_max': 22.222222}, 'shape': ['time'], 'data': [22.222222]}, 'tm': {'attributes': {'standard_name': 'wave_observed_mean_period_all', 'long_name': 'Observed wave mean period for all frequencies', 'units': 's', 'coordinates': 'time', 'data_min': 9.008704, 'data_max': 9.008704}, 'shape': ['time'], 'data': [9.008704]}, 'mean_direction': {'attributes': {'standard_name': 'wave_observed_mean_direction_all', 'long_name': 'Observed wave mean direction for all frequencies', 'units': 'degrees', 'coordinates': 'time', 'data_min': 50.128314, 'data_max': 50.128314}, 'shape': ['time'], 'data': [50.128314]}, 'peak_direction': {'attributes': {'standard_name': 'wave_observed_peak_direction_all', 'long_name': 'Observed wave peak direction for all frequencies', 'units': 'degrees', 'coordinates': 'time', 'data_min': 226.440063, 'data_max': 226.440063}, 'shape': ['time'], 'data': [226.440063]}, 'hs_sea': {'attributes': {'standard_name': 'wave_observed_significant_height_sea', 'long_name': 'Observed wave significant height for sea frequencies', 'units': 'm', 'coordinates': 'time', 'comment': 'f<1/7', 'data_min': 0.036129, 'data_max': 0.036129}, 'shape': ['time'], 'data': [0.036129]}, 'tp_sea': {'attributes': {'standard_name': 'wave_observed_peak_period_sea', 'long_name': 'Observed wave peak period for sea frequencies', 'units': 's', 'coordinates': 'time', 'comment': 'f<1/7', 'data_min': 5.714286, 'data_max': 5.714286}, 'shape': ['time'], 'data': [5.714286]}, 'tm_sea': {'attributes': {'standard_name': 'wave_observed_mean_period_sea', 'long_name': 'Observed wave mean period for sea frequencies', 'units': 's', 'coordinates': 'time', 'comment': 'f<1/7', 'data_min': 5.921359, 'data_max': 5.921359}, 'shape': ['time'], 'data': [5.921359]}, 'mean_sea_direction': {'attributes': {'standard_name': 'wave_observed_mean_direction_sea', 'long_name': 'Observed wave mean direction for sea frequencies', 'units': 'degrees', 'coordinates': 'time', 'comment': 'f<1/7', 'data_min': 6.981742, 'data_max': 6.981742}, 'shape': ['time'], 'data': [6.981742]}, 'peak_sea_direction': {'attributes': {'standard_name': 'wave_observed_peak_direction_sea', 'long_name': 'Observed wave peak direction for sea frequencies', 'units': 'degrees', 'coordinates': 'time', 'comment': 'f<1/7', 'data_min': 26.000043, 'data_max': 26.000043}, 'shape': ['time'], 'data': [26.000043]}, 'hs_swell': {'attributes': {'standard_name': 'wave_observed_significant_height_swell', 'long_name': 'Observed wave significant height for swell frequencies', 'units': 'm', 'coordinates': 'time', 'comment': 'f>=1/7', 'data_min': 0.060459, 'data_max': 0.060459}, 'shape': ['time'], 'data': [0.060459]}, 'tp_swell': {'attributes': {'standard_name': 'wave_observed_peak_period_swell', 'long_name': 'Observed wave peak period for swell frequencies', 'units': 's', 'coordinates': 'time', 'comment': 'f>=1/7', 'data_min': 22.222222, 'data_max': 22.222222}, 'shape': ['time'], 'data': [22.222222]}, 'tm_swell': {'attributes': {'standard_name': 'wave_observed_mean_period_swell', 'long_name': 'Observed wave mean period for swell frequencies', 'units': 's', 'coordinates': 'time', 'comment': 'f>=1/7', 'data_min': 11.069702, 'data_max': 11.069702}, 'shape': ['time'], 'data': [11.069702]}, 'mean_swell_direction': {'attributes': {'standard_name': 'wave_observed_mean_direction_swell', 'long_name': 'Observed wave mean direction for swell frequencies', 'units': 'degrees', 'coordinates': 'time', 'comment': 'f>=1/7', 'data_min': 84.841693, 'data_max': 84.841693}, 'shape': ['time'], 'data': [84.841693]}, 'peak_swell_direction': {'attributes': {'standard_name': 'wave_observed_peak_direction_swell', 'long_name': 'Observed wave peak direction for swell frequencies', 'units': 'degrees', 'coordinates': 'time', 'comment': 'f>=1/7', 'data_min': 226.440063, 'data_max': 226.440063}, 'shape': ['time'], 'data': [226.440063]}}}]

    # https://stackoverflow.com/questions/17273393/mocking-session-in-requests-library
    @patch.object(Session, 'post')
    def test_get_access_token(self, mock_api_access):
        mock_api_access.return_value = Mock(ok=True, status_code=200, json=lambda: self.api_access)

        response = omcApi().get_access_token()

        self.assertEqual(self.api_access['access_token'], response['access_token'])

    @patch.object(Session, 'get')
    @patch.object(Session, 'post')
    def test_omc_get_sources_info(self, mock_api_access, mock_get_sources_info):
        mock_api_access.return_value = Mock(ok=True, status_code=200, json=lambda: self.api_access)
        mock_get_sources_info.return_value = Mock(ok=True, status_code=200, json=lambda: self.sources_info)

        # Call the service, which will send a request to the server.
        response = omcApi().get_sources_info()

        self.assertEqual(Timestamp("2021-11-18 07:12:36.345066+00:00"), response['created_time_utc'][0])

    @patch.object(Session, 'get')
    @patch.object(Session, 'post')
    def test_omc_get_source_info(self, mock_api_access, mock_get_sources_info):
        mock_api_access.return_value = Mock(ok=True, status_code=200, json=lambda: self.api_access)
        mock_get_sources_info.return_value = Mock(ok=True, status_code=200, json=lambda: self.sources_info)

        # Call the service, which will send a request to the server.
        response = omcApi(self.source_id).get_source_info()

        self.assertEqual(Timestamp("2021-11-18 02:21:31.873079+00:00"), response['created_time_utc'][0])

    @patch.object(Session, 'get')
    @patch.object(Session, 'post')
    def test_omc_get_source_id_wave_latest_date(self, mock_api_access, mock_get_source_id_wave_latest_date):
        mock_api_access.return_value = Mock(ok=True, status_code=200, json=lambda: self.api_access)
        mock_get_source_id_wave_latest_date.return_value = Mock(ok=True, status_code=200, json=lambda: self.source_id_latest_data)

        # Call the service, which will send a request to the server.
        response = omcApi(self.source_id).get_source_id_wave_latest_date()

        self.assertEqual(Timestamp("2022-03-16 07:18:00+00:00"), response)
