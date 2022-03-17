import os
import unittest
import pandas
from unittest.mock import Mock, patch

from ardc_nrt.lib.sofar.api import apiSofar
from pandas import Timestamp


TEST_ROOT = os.path.dirname(__file__)


class TestOmcApi(unittest.TestCase):
    def setUp(self):
        os.environ["ARDC_SOFAR_SECRET_FILE_PATH"] = os.path.join(TEST_ROOT, "secrets_sofar.json")

        self.get_devices_info = {'message': '19 devices', 'data':
            {'devices': [{'name': 'King George Sound (SPOT-0169)', 'spotterId': 'SPOT-0169'},
                         {'name': 'Drifting #1- Bremer Canyon (SPOT-0170)', 'spotterId': 'SPOT-0170'},
                         {'name': 'TwoRocksDrift01_(SPOT-0162)', 'spotterId': 'SPOT-0162'},
                         {'name': 'Sofar Drifter (SPOT-0172)', 'spotterId': 'SPOT-0172'},
                         {'name': 'Torbay East (SPOT-0171)', 'spotterId': 'SPOT-0171'},
                         {'name': 'TwoRocksDrift03_(SPOT-0168)', 'spotterId': 'SPOT-0168'},
                         {'name': 'Hillarys (SPOT-0093)', 'spotterId': 'SPOT-0093'},
                         {'name': 'Goodrich Bank OLD (SPOT-0551)', 'spotterId': 'SPOT-0551'},
                         {'name': 'Tantabiddi (SPOT-0558)', 'spotterId': 'SPOT-0558'},
                         {'name': 'Torbay East (SPOT-0559)', 'spotterId': 'SPOT-0559'},
                         {'name': 'Dampier (SPOT-0561)', 'spotterId': 'SPOT-0561'},
                         {'name': 'Torbay West (SPOT-0757)', 'spotterId': 'SPOT-0757'},
                         {'name': '', 'spotterId': 'SPOT-1040'},
                         {'name': 'TwoRocksDrift02_(SPOT-1266)', 'spotterId': 'SPOT-1266'},
                         {'name': 'Dampier (SPOT-1294)', 'spotterId': 'SPOT-1294'},
                         {'name': 'Goodrich Bank (SPOT-1292)', 'spotterId': 'SPOT-1292'},
                         {'name': '', 'spotterId': 'SPOT-1668'},
                         {'name': '', 'spotterId': 'SPOT-1667'},
                         {'name': '', 'spotterId': 'SPOT-1669'}]}}

        self.source_id_data = {'data':
                                   {'spotterId': 'SPOT-0169',
                                    'spotterName': 'King George Sound (SPOT-0169)', 'payloadType': 'full', 'batteryVoltage': 4.1, 'batteryPower': -0.03,
                                    'solarVoltage': 6.89, 'humidity': 47.2,
                                    'track': [{'latitude': -35.0795333, 'longitude': 117.97845, 'timestamp': '2022-03-17T04:07:18.000Z'},
                                              {'latitude': -35.0795333, 'longitude': 117.9784167, 'timestamp': '2022-03-17T04:37:18.000Z'}],
                                    'waves': [{'significantWaveHeight': 0.485, 'peakPeriod': 14.628, 'meanPeriod': 6.346, 'peakDirection': 77.837, 'peakDirectionalSpread': 40.759, 'meanDirection': 77.422, 'meanDirectionalSpread': 43.366, 'timestamp': '2022-03-17T04:37:18.000Z', 'latitude': -35.07953, 'longitude': 117.97842}],
                                    'frequencyData': [{'frequency': [0.0293, 0.03906, 0.04883, 0.05859, 0.06836, 0.07813, 0.08789, 0.09766, 0.10742, 0.11719, 0.12695, 0.13672, 0.14648, 0.15625, 0.16602, 0.17578, 0.18555, 0.19531, 0.20508, 0.21484, 0.22461, 0.23438, 0.24414, 0.25391, 0.26367, 0.27344, 0.2832, 0.29297, 0.30273, 0.3125, 0.32227, 0.33203, 0.35156, 0.38086, 0.41016, 0.43945, 0.46875, 0.49805, 0.6543], 'df': [0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.00977, 0.0293, 0.0293, 0.0293, 0.0293, 0.0293, 0.0293, 0.2832], 'varianceDensity': [0.002500608, 0.005251072, 0.014253056, 0.07576883200000001, 0.213302272, 0.20029849600000002, 0.102025216, 0.069266432, 0.152287232, 0.12052992, 0.042510336, 0.030507008, 0.02975744, 0.030507008, 0.027506688, 0.02175488, 0.018504704, 0.017004543999999996, 0.01575424, 0.014753792000000002, 0.017254400000000003, 0.020504576, 0.018254847999999997, 0.014253056, 0.012253183999999999, 0.013002752, 0.010753024, 0.008252416, 0.008752128000000001, 0.01100288, 0.010252288, 0.010502144, 0.008752128000000001, 0.005751808, 0.00475136, 0.0035010560000000002, 0.00300032, 0.00300032, 0.002000896], 'direction': [356.85477437770754, 45.48120920170459, 72.04506456473229, 80.45547592247306, 77.8371791683686, 74.88345504289776, 75.23255640620687, 81.64000083675501, 88.44173460788772, 85.505658732283, 83.29013818645109, 80.46274086913002, 76.99401294741381, 75.60191932781402, 72.67527571514813, 69.86597015068662, 68.69422946442523, 67.39247009437713, 62.844682606464914, 68.18255735042067, 69.77121362375078, 69.91880068718638, 66.285026173564, 64.6373624642041, 75.98557455283077, 63.96630608486004, 56.22186210668872, 60.202369209995254, 70.24252687207189, 71.18237822451522, 58.111471755351886, 51.54625191489362, 60.139137874551636, 63.03822611545627, 62.65899463379611, 69.57000527356377, 73.43383674079655, 65.99875943055207, 50.5053766984193], 'directionalSpread': [77.33494752816797, 77.62438055465753, 62.455766839336114, 46.40177866373237, 40.75881558566064, 38.034514964528476, 32.811811162485036, 33.70537780695472, 25.793241548007693, 25.85712302305827, 35.950061552995415, 41.51740813292723, 41.44387255538275, 40.44479199465037, 36.447088621039, 39.60673966786431, 41.75452436624076, 44.621310367877385, 45.91217172547079, 47.96026520208968, 44.29863309014964, 41.97276310333878, 43.4739619920075, 48.22207852310138, 49.8419948513161, 53.39844100403477, 55.59660130152176, 55.71681772837057, 56.78104130142201, 56.770323284300154, 59.705737854555565, 56.76125040862571, 58.4841270875303, 60.52897491762299, 63.42214362250478, 64.61723912663874, 66.70606079849551, 68.12223830392962, 76.21533899242522],
                                                       'timestamp': '2022-03-17T04:37:18.000Z', 'latitude': -35.07953, 'longitude': 117.97842}]}}

    def test_lookup_get_tokens(self):
        response = apiSofar().lookup_get_tokens()

        self.assertEqual("tell him he's dreaming", response['UWA'])

    # in the code, get is called. not requests.get , hence only patching ...api.get and not api.requests.get
    # see https://auth0.com/blog/mocking-api-calls-in-python/
    @patch('ardc_nrt.lib.sofar.api.get')
    def test_get_devices_info(self, mock_get_devices_info):
        mock_get_devices_info.return_value = Mock(ok=True, status_code=200, json=lambda: self.get_devices_info)
        response_token = apiSofar().lookup_get_tokens()['UWA']

        response = apiSofar().get_devices_info(response_token)

        self.assertEqual("King George Sound (SPOT-0169)", response['name'][0])
        self.assertEqual("SPOT-0169", response['spotterId'][0])

    # TODO: mock self.lookup_get_source_id_token as it relies on config data in module
    @patch('ardc_nrt.lib.sofar.api.get')
    def test_get_source_id_latest_data(self, mock_get_source_data):
        mock_get_source_data.return_value = Mock(ok=True, status_code=200, json=lambda: self.source_id_data)

        response = apiSofar().get_source_id_latest_data('SPOT-0169')

        self.assertEqual(Timestamp("2022-03-17T04:37:18+0000", tz='UTC'), response['timestamp'][0])


if __name__ == '__main__':
    unittest.main()
