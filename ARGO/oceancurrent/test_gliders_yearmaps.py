import copy
from pathlib import Path
import shutil
import json
import re
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

import gliders_yearmaps as generator
import publish_gliders_yearmaps as publisher

FIXTURES = Path(__file__).parent / 'fixtures' / 'gliders_yearmaps'
NAME = '2026_sl_temp_04d_nrt.html'


class ParsingTests(unittest.TestCase):
    def test_local_mission_links_and_invalid_urls(self):
        html = (FIXTURES / NAME).read_text()
        relative = '../Esperance20260526_nrt_4d/latest.html'
        root_relative = '/gliders/Esperance20260526_nrt_4d/latest.html'
        for href in (relative, root_relative):
            with self.subTest(href=href):
                _, deployments = generator.parse_yearmap(html.replace(relative, href), NAME)
                self.assertEqual(next(d['url'] for d in deployments
                                      if d['mission_name'] == 'Esperance20260526_nrt'), root_relative)
        for href in ('https://oceancurrent.aodn.org.au' + root_relative,
                     '//example.org' + root_relative, '../../gliders/Esperance20260526_nrt_4d/latest.html',
                     '../%2e%2e/Esperance20260526_nrt_4d/latest.html',
                     relative + '?redirect=1', relative + '#fragment', '../other_4d/latest.html'):
            with self.subTest(href=href), self.assertRaisesRegex(ValueError, 'Unexpected mission link'):
                generator.parse_yearmap(html.replace(relative, href), NAME)

    def test_saved_maps_separate_geography_calendar_and_labels(self):
        for name, count in [('2018_sg_temp_04d.html', 4), ('2025_sl_temp_04d.html', 27), (NAME, 12)]:
            with self.subTest(name=name):
                _, deployments = generator.parse_yearmap((FIXTURES / name).read_text(), name)
                self.assertEqual(len(deployments), count)
        _, deployments = generator.parse_yearmap((FIXTURES / NAME).read_text(), NAME)
        esperance = next(d for d in deployments if d['mission_name'] == 'Esperance20260526_nrt')
        self.assertEqual(esperance['pixel_rect'], [204, 368, 232, 393])
        self.assertEqual(esperance['url'], '/gliders/Esperance20260526_nrt_4d/latest.html')

    def test_malformed_incomplete_and_mismatched_html(self):
        html = (FIXTURES / NAME).read_text()
        for invalid in ['', html[:-30], html.replace('204  368  232  393', '204,368,232'),
                        html.replace('204  368  232  393', '232 368 204 393'),
                        html.replace('204  368  232  393', '1200 368 1232 393'),
                        html.replace('title="Esperance20260526_nrt"', 'title="Ceduna20260924_nrt"', 1),
                        html.replace('../Esperance20260526_nrt_4d/latest.html', 'https://other.example/mission'),
                        html.replace('<area shape="default"', '<area shape="unknown"'),
                        html.replace('<b>', '').replace('</b>', '')]:
            with self.subTest(invalid=invalid[:40]), self.assertRaises(ValueError):
                generator.parse_yearmap(invalid, NAME)

    def test_metadata_and_comma_separated_rectangles(self):
        html = (FIXTURES / NAME).read_text().replace('204  368  232  393', '204, 368,232,393')
        self.assertEqual(len(generator.parse_yearmap(html, NAME)[1]), 12)
        for name in ['2026_sl_temp_12d_nrt.html', '2018_sg_psal_30d.html']:
            self.assertEqual(generator.map_metadata(name)['id'], name[:-5])
        for name in ['2026_sl_temp.gif', '2026_sl_unknown_04d.html', '../' + NAME]:
            with self.assertRaises(ValueError):
                generator.map_metadata(name)

    def test_title_only_legacy_labels_and_ignored_non_geographic_areas(self):
        for name in ['2018_sg_temp_04d.html', NAME]:
            html = (FIXTURES / name).read_text()
            expected = generator.parse_yearmap(html, name)[1]
            title_only = re.sub(r' alt="[^"]*"', '', html)
            self.assertEqual(generator.parse_yearmap(title_only, name)[1], expected)
        # Neither non-geographic coordinates nor the displayed GIF participates in geometry.
        html = html.replace('997   455  1051   486', 'not geographic coordinates')
        html = html.replace('2026_sl_temp_nrt.gif', 'missing.gif')
        self.assertEqual(generator.parse_yearmap(html, NAME)[1], expected)


class GeographyTests(unittest.TestCase):
    def test_matches_original_typescript_calibration_and_inverse_bounds(self):
        catalogue = json.loads((FIXTURES / 'catalogue.json').read_text())
        reference = json.loads((FIXTURES / 'frontend-reference.json').read_text())
        for record in reference['maps']:
            with self.subTest(map=record['id']):
                filename = record['id'] + '.html'
                _, deployments = generator.parse_yearmap((FIXTURES / filename).read_text(), filename)
                if 'unsupported' in record:
                    with self.assertRaisesRegex(ValueError, 'six missions'):
                        generator.calibrate(deployments, catalogue)
                    continue
                calibration = generator.calibrate(deployments, catalogue)
                for key in ('x', 'y'):
                    for actual, expected in zip(calibration[key], record[key]):
                        self.assertAlmostEqual(actual, expected, places=9)
                for key in ('max_error', 'rms_error', 'held_out_error'):
                    self.assertAlmostEqual(calibration[key], record[key], places=9)
                for deployment, expected in zip(deployments, record['deployments']):
                    self.assertEqual(deployment['mission_name'], expected['mission_name'])
                    for actual, value in zip(generator.geographic_bbox(deployment['pixel_rect'], calibration), expected['bbox']):
                        self.assertAlmostEqual(actual, value, places=5)
                # Independently measured axis ticks from both saved source maps.
                # The reference points were not used to fit catalogue/rectangle centres.
                for lon, px in [(110, 60), (120, 190), (130, 320), (140, 449), (155, 644)]:
                    self.assertLessEqual(abs(calibration['x'][0] * lon + calibration['x'][1] - px), 1)
                for lat, py in [(-15, 75), (-25, 233), (-35, 392), (-45, 551)]:
                    self.assertLessEqual(abs(calibration['y'][0] * lat + calibration['y'][1] - py), 1)

    def test_rejects_outliers_ambiguous_positions_and_unknown_layouts(self):
        catalogue = json.loads((FIXTURES / 'catalogue.json').read_text())
        _, deployments = generator.parse_yearmap((FIXTURES / NAME).read_text(), NAME)
        for mission in catalogue['missions']:
            if mission['mission_name'] == 'Esperance20260526_nrt':
                mission['longitude'] += 2
        with self.assertRaisesRegex(ValueError, 'residuals'):
            generator.calibrate(deployments, catalogue)
        # Conflicting processing versions cannot be chosen arbitrarily as anchors.
        ambiguous = {'missions': [{'mission_name': d['mission_name'], 'longitude': 120, 'latitude': -30}
                                  for d in deployments]}
        ambiguous['missions'] += [dict(m, longitude=121) for m in ambiguous['missions']]
        with self.assertLogs(generator.LOG, level='WARNING'):
            with self.assertRaisesRegex(ValueError, 'six missions'):
                generator.calibrate(deployments, ambiguous)
        unknown = NAME.replace('2026', '2024')
        with self.assertLogs(generator.LOG, level='WARNING') as logs:
            result = generator.generate_yearmaps({unknown: (FIXTURES / NAME).read_bytes().replace(b'2026_sl', b'2024_sl')}, catalogue)
        self.assertIn('No reviewed geographic panel', '\n'.join(logs.output))
        self.assertTrue(all(d['bbox'] is None for d in result['maps'][0]['deployments']))

    def test_missing_catalogue_positions_are_logged(self):
        sources = {NAME: (FIXTURES / NAME).read_bytes()}
        with self.assertLogs(generator.LOG, level='WARNING') as logs:
            result = generator.generate_yearmaps(sources, {'missions': []})
        self.assertIn('Missing or ambiguous catalogue position', '\n'.join(logs.output))
        self.assertEqual(len(result['maps'][0]['deployments']), 12)
        self.assertTrue(all(d['bbox'] is None for d in result['maps'][0]['deployments']))


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'yearmaps'
        shutil.copytree(FIXTURES, self.source)
        self.catalogue = self.root / 'catalogue.json'
        (self.source / 'catalogue.json').rename(self.catalogue)
        self.output = self.root / 'output.json'

    def publish(self, **kwargs):
        return publisher.publish_yearmaps(self.source, self.catalogue, self.output,
                                         **dict({'source_complete': True}, **kwargs))

    def test_deterministic_unchanged_and_reference_json(self):
        (self.source / 'index.html').write_text('<html>Directory listing</html>')
        self.publish()
        expected = (FIXTURES / 'expected.json').read_bytes()
        # The reference covers map/deployment order, links, geographic bounds and null fallbacks.
        self.assertEqual(self.output.read_bytes(), expected)
        previous = self.output.stat()
        self.publish()
        self.assertEqual(self.output.read_bytes(), expected)
        self.assertEqual(self.output.stat().st_mtime_ns, previous.st_mtime_ns)

    def test_only_html_and_catalogue_are_read(self):
        for image in self.source.glob('*.gif'):
            image.unlink()
        with patch.object(publisher, '_snapshot', wraps=publisher._snapshot) as snapshot:
            result = self.publish()
        self.assertTrue(all(call.args[0].suffix in ('.html', '.json') for call in snapshot.call_args_list))
        self.assertEqual(sum(d['bbox'] is not None for m in result['maps'] for d in m['deployments']), 39)
        self.assertTrue(all('image' not in m and 'calibration_status' not in m for m in result['maps']))

    def test_missing_malformed_and_incomplete_sources_preserve_previous(self):
        self.publish()
        original = self.output.read_bytes()
        for name in [NAME]:
            source = self.source / name
            data = source.read_bytes()
            invalids = [None, b'', data[:len(data)//2]]
            if name == NAME:
                invalids.append(data.replace(b'204  368  232  393', b'204 368 232 900'))
            for invalid in invalids:
                with self.subTest(source=name, content=invalid[:40] if invalid else invalid):
                    if invalid is None:
                        source.unlink()
                    else:
                        source.write_bytes(invalid)
                    with self.assertRaises((OSError, ValueError)):
                        self.publish()
                    self.assertEqual(self.output.read_bytes(), original)
            source.write_bytes(data)

    def test_empty_sources_and_unknown_combinations_fail(self):
        for p in self.source.glob('*.html'):
            p.unlink()
        with self.assertRaisesRegex(ValueError, 'No year-map'):
            self.publish()
        (self.source / '2026_sl_unknown_04d.html').write_text('unsupported')
        with self.assertRaisesRegex(ValueError, 'Unsupported'):
            self.publish()
        self.assertFalse(self.output.exists())

    def test_invalid_baseline_and_catalogue_preserved(self):
        for invalid in [b'null', b'{}', b'{bad']:
            self.output.write_bytes(invalid)
            with self.assertRaises(ValueError):
                self.publish()
            self.assertEqual(self.output.read_bytes(), invalid)
        self.output.unlink()
        self.catalogue.write_text('{}')
        with self.assertRaises(ValueError):
            self.publish()
        self.assertFalse(self.output.exists())

    def test_changed_output_and_write_failure_preserves_previous(self):
        self.publish()
        original = self.output.read_bytes()
        p = self.source / NAME
        p.write_text(p.read_text().replace('204  368  232  393', '205 368 232 393'))
        self.publish()
        self.assertNotEqual(self.output.read_bytes(), original)
        original = self.output.read_bytes()
        p.write_text(p.read_text().replace('205 368 232 393', '206 368 232 393'))
        with patch('gliders_catalogue.os.replace', side_effect=OSError('disk failure')):
            with self.assertRaises(OSError):
                self.publish()
        self.assertEqual(self.output.read_bytes(), original)
        self.assertEqual({p.name for p in self.root.iterdir()}, {'yearmaps', 'catalogue.json', 'output.json'})

    def test_stability_observation_and_final_snapshot(self):
        self.publish()
        original = self.output.read_bytes()
        with patch.object(publisher.time, 'sleep') as sleep:
            self.publish(source_complete=False, stability_seconds=2)
        sleep.assert_called_once_with(2)
        def mutate(seconds):
            p = self.source / NAME
            p.write_bytes(p.read_bytes() + b'\n')
        with patch.object(publisher.time, 'sleep', side_effect=mutate):
            with self.assertRaisesRegex(ValueError, 'stability observation'):
                self.publish(source_complete=False)
        real_generate = publisher.generate_yearmaps
        def generate(*args):
            result = real_generate(*args)
            mutate(0)
            return result
        with patch.object(publisher, 'generate_yearmaps', side_effect=generate):
            with self.assertRaisesRegex(ValueError, 'during generation'):
                self.publish()
        self.assertEqual(self.output.read_bytes(), original)

    def test_changes_during_read_and_directory_changes(self):
        read = Path.read_bytes
        def changed(path):
            result = read(path)
            if path.name == NAME:
                path.write_bytes(result + b'\n')
            return result
        with patch.object(Path, 'read_bytes', changed):
            with self.assertRaisesRegex(ValueError, 'changed while reading'):
                self.publish()
        def remove(seconds):
            (self.source / NAME).unlink()
        with patch.object(publisher.time, 'sleep', side_effect=remove):
            with self.assertRaisesRegex(ValueError, 'stability observation'):
                self.publish(source_complete=False)

    def test_configuration_and_schema_validation(self):
        valid = self.publish()
        for seconds in [0, -1, float('inf'), float('nan')]:
            with self.assertRaises(ValueError):
                self.publish(stability_seconds=seconds)
        changes = [lambda d: d.update(schema_version=True), lambda d: d.update(maps=[]),
                   lambda d: d['maps'].append(d['maps'][0]),
                   lambda d: d['maps'][0]['deployments'][0].update(pixel_rect=[1, 2, 0, 3]),
                   lambda d: d['maps'][0]['deployments'][0].update(url='https://other/'),
                   lambda d: d['maps'][0]['deployments'][0].update(bbox=[-200, -40, 120, -30])]
        for change in changes:
            candidate = copy.deepcopy(valid)
            change(candidate)
            with self.assertRaises(ValueError):
                publisher.validate_yearmaps(candidate)

    def test_cli_independent_execution_status_and_logging(self):
        args = ['--input', str(self.source),
                '--catalogue', str(self.catalogue), '--output', str(self.output), '--source-complete']
        for script in (publisher.__file__, generator.__file__):
            with self.subTest(script=script):
                success = subprocess.run([sys.executable, '-S', script] + args, capture_output=True, text=True)
                self.assertEqual(success.returncode, 0, success.stderr)
                for expected in ['maps=3', 'deployments=43', 'missing_bounds=4', 'status=0']:
                    self.assertIn(expected, success.stderr)
        original = self.output.read_bytes()
        (self.source / NAME).unlink()
        failure = subprocess.run([sys.executable, '-S', publisher.__file__] + args, capture_output=True, text=True)
        self.assertEqual(failure.returncode, 1)
        self.assertIn('previous output preserved', failure.stderr)
        self.assertIn('status=1', failure.stderr)
        self.assertEqual(self.output.read_bytes(), original)


if __name__ == '__main__':
    unittest.main()
