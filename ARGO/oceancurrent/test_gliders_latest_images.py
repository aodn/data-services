"""Discovery uses captured legacy HTML, not timestamp guesses or navigation links."""
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

from gliders_catalogue import parse_catalogue, resolve_latest_images
from publish_gliders_catalogue import publish_catalogue, validate_catalogue

FIXTURES = Path(__file__).parent / 'fixtures'


class TestLatestImages(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'index.html'
        shutil.copy(FIXTURES / 'gliders_catalogue.html', self.source)
        self.window = self.root / 'TwoRocks20260327_4d'
        self.window.mkdir()
        for name in ('2026041300.html', '2026041300.gif'):
            shutil.copy(FIXTURES / 'gliders_latest' / name, self.window / name)
        (self.window / 'latest.html').symlink_to('2026041300.html')
        self.output = self.root / 'catalogue.json'

    def resolve(self):
        catalogue = resolve_latest_images(parse_catalogue(self.source.read_text()), self.source)
        validate_catalogue(catalogue)
        return next(m for m in catalogue['missions'] if m['mission_name'] == 'TwoRocks20260327')['visualisations']['latest_images']

    def publish(self):
        return publish_catalogue(self.source, self.output, source_complete=True)

    def test_real_legacy_page_and_symlink(self):
        self.assertEqual(self.resolve(), {'4d': '/gliders/TwoRocks20260327_4d/2026041300.gif', '12d': None, '30d': None})
        # Explicit frame reference wins over a newer-looking file.
        shutil.copy(self.window / '2026041300.gif', self.window / '2099010100.gif')
        self.assertTrue(self.resolve()['4d'].endswith('2026041300.gif'))

    def test_real_nrt_page_and_only_linked_windows(self):
        self.source.write_text(self.source.read_text().replace('Brisbane20180306A_nrt', 'TasEastCoast20260922_nrt'))
        folder = self.root / 'TasEastCoast20260922_nrt_4d'
        folder.mkdir()
        shutil.copy(FIXTURES / 'gliders_latest' / 'nrt.html', folder / 'latest.html')
        shutil.copy(self.window / '2026041300.gif', folder / '2026101500.gif')
        catalogue = resolve_latest_images(parse_catalogue(self.source.read_text()), self.source)
        mission = next(m for m in catalogue['missions'] if m['mission_name'] == 'TasEastCoast20260922_nrt')
        self.assertEqual(mission['visualisations']['latest_images'], {
            '4d': '/gliders/TasEastCoast20260922_nrt_4d/2026101500.gif', '12d': None, '30d': None})

    def test_symlinked_gif_inside_window(self):
        (self.window / 'alias.gif').symlink_to('2026041300.gif')
        (self.window / '2026041300.html').write_text('<IMG src=alias.gif>')
        self.assertTrue(self.resolve()['4d'].endswith('/alias.gif'))

    def test_animation_links_can_identify_windows_but_unlinked_windows_are_ignored(self):
        catalogue = parse_catalogue(self.source.read_text())
        mission = next(m for m in catalogue['missions'] if m['mission_name'] == 'TwoRocks20260327')
        mission['visualisations']['details'] = []
        resolve_latest_images(catalogue, self.source)
        self.assertIsNotNone(mission['visualisations']['latest_images']['4d'])
        mission['visualisations']['animations'] = []
        resolve_latest_images(catalogue, self.source)
        self.assertIsNone(mission['visualisations']['latest_images']['4d'])

    def test_changed_optional_reference_during_generation_is_null(self):
        original = resolve_latest_images
        calls = []
        def changing(catalogue, source):
            result = original(catalogue, source)
            calls.append(True)
            if len(calls) == 1:
                (self.window / '2026041300.html').write_text('<IMG src=missing.gif>')
            return result
        with patch('gliders_catalogue.resolve_latest_images', side_effect=changing):
            result = self.publish()
        mission = next(m for m in result['missions'] if m['mission_name'] == 'TwoRocks20260327')
        self.assertIsNone(mission['visualisations']['latest_images']['4d'])

    def test_relative_and_root_relative_references(self):
        page = self.window / '2026041300.html'
        for src in ('./2026041300.gif', '/gliders/TwoRocks20260327_4d/2026041300.gif'):
            page.write_text('<IMG src=' + src + '>')
            self.assertIsNotNone(self.resolve()['4d'])

    def test_missing_malformed_and_cross_mission_references(self):
        page = self.window / '2026041300.html'
        for html in ('', '<a href=2026041300.gif>NEXT</a>', '<IMG src=missing.gif>',
                     '<IMG src=../Other20260327_4d/2026041300.gif>',
                     '<IMG src=https://example.org/2026041300.gif>', '<IMG src="2026041300.gif',
                     '<IMG src=2026041300.gif><IMG src=second.gif>'):
            with self.subTest(html=html):
                shutil.copy(self.window / '2026041300.gif', self.window / 'second.gif')
                page.write_text(html)
                self.assertIsNone(self.resolve()['4d'])
        page.write_text('<IMG src=2026041300.gif>')
        (self.window / '2026041300.gif').write_bytes(b'GIF89a incomplete')
        self.assertIsNone(self.resolve()['4d'])

    def test_cross_mission_symlinks_rejected(self):
        other = self.root / 'Other20260327_4d'
        other.mkdir()
        shutil.copy(self.window / '2026041300.gif', other / 'frame.gif')
        (self.window / '2026041300.gif').unlink()
        (self.window / '2026041300.gif').symlink_to(other / 'frame.gif')
        self.assertIsNone(self.resolve()['4d'])

    def test_only_frame_changes_trigger_publication_and_no_rewrite(self):
        self.publish()
        original = self.output.read_bytes()
        shutil.copy(self.window / '2026041300.gif', self.window / 'new.gif')
        (self.window / '2026041300.html').write_text('<IMG src=new.gif>')
        self.publish()
        self.assertNotEqual(self.output.read_bytes(), original)
        stat = self.output.stat()
        self.publish()
        self.assertEqual(self.output.stat().st_mtime_ns, stat.st_mtime_ns)
        self.assertEqual(self.output.stat().st_ino, stat.st_ino)

    def test_optional_missing_or_changing_images_publish_metadata(self):
        with patch('gliders_catalogue._snapshot', side_effect=ValueError('changing')):
            result = self.publish()
        self.assertEqual(len(result['missions']), 8)
        self.assertTrue(all(m['visualisations']['latest_images']['4d'] is None for m in result['missions']))
        (self.window / 'latest.html').unlink()
        self.publish()

    def test_invalid_metadata_preserves_previous_valid_catalogue(self):
        self.publish()
        previous = self.output.read_bytes()
        self.source.write_text('<html>incomplete')
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(previous, self.output.read_bytes())

    def test_old_catalogue_validation_and_invalid_latest(self):
        catalogue = parse_catalogue(self.source.read_text())
        for mission in catalogue['missions']:
            mission['visualisations'].pop('latest_images')
        validate_catalogue(catalogue)
        catalogue['missions'][0]['visualisations']['latest_images'] = {'4d': 'bad'}
        with self.assertRaises(ValueError):
            validate_catalogue(catalogue)


class TestTemperatureSalinityImage(unittest.TestCase):
    """The published T-S link is a missionTS HTML page; publish only the GIF it displays."""

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'index.html'
        shutil.copy(FIXTURES / 'gliders_catalogue.html', self.source)
        self.folder = self.root / 'missionTS'
        self.folder.mkdir()
        self.page = self.folder / 'sl_TwoRocks20260327.html'
        shutil.copy(FIXTURES / 'gliders_ts' / self.page.name, self.page)
        shutil.copy(FIXTURES / 'gliders_latest' / '2026041300.gif', self.folder / 'sl_TwoRocks20260327.gif')

    def resolve(self, name='TwoRocks20260327'):
        catalogue = resolve_latest_images(parse_catalogue(self.source.read_text()), self.source)
        validate_catalogue(catalogue)
        return next(m for m in catalogue['missions'] if m['mission_name'] == name)

    def test_real_legacy_page_resolves_displayed_gif(self):
        mission = self.resolve()
        self.assertTrue(mission['temperature_salinity_url'].endswith('/gliders/missionTS/sl_TwoRocks20260327.html'))
        self.assertEqual(mission['visualisations']['temperature_salinity_image'],
                         '/gliders/missionTS/sl_TwoRocks20260327.gif')

    def test_nrt_page(self):
        name = 'sg_Brisbane20180306A_nrt'
        (self.folder / (name + '.html')).write_text('<img src="' + name + '.gif">')
        shutil.copy(self.folder / 'sl_TwoRocks20260327.gif', self.folder / (name + '.gif'))
        self.assertEqual(self.resolve('Brisbane20180306A_nrt')['visualisations']['temperature_salinity_image'],
                         '/gliders/missionTS/' + name + '.gif')

    def test_missing_or_unverifiable_diagrams_are_null(self):
        # Missing page; mission without a T-S link; other missions in the fixture.
        self.assertIsNone(self.resolve('Brisbane20180306A')['visualisations']['temperature_salinity_image'])
        self.assertIsNone(self.resolve('Perth20110626_2')['visualisations']['temperature_salinity_image'])
        for html in ('', '<img src=missing.gif>', '<img src=../TwoRocks20260327_4d/2026041300.gif>',
                     '<img src=https://example.org/sl_TwoRocks20260327.gif>',
                     '<img src=sl_TwoRocks20260327.gif><img src=other.gif>'):
            with self.subTest(html=html):
                shutil.copy(self.folder / 'sl_TwoRocks20260327.gif', self.folder / 'other.gif')
                self.page.write_text(html)
                self.assertIsNone(self.resolve()['visualisations']['temperature_salinity_image'])
        self.page.write_text('<img src=sl_TwoRocks20260327.gif>')
        (self.folder / 'sl_TwoRocks20260327.gif').write_bytes(b'GIF89a incomplete')
        self.assertIsNone(self.resolve()['visualisations']['temperature_salinity_image'])

    def test_only_missionts_pages_on_the_source_host_are_read(self):
        catalogue = parse_catalogue(self.source.read_text())
        mission = next(m for m in catalogue['missions'] if m['mission_name'] == 'TwoRocks20260327')
        for url in ('https://example.org/gliders/missionTS/sl_TwoRocks20260327.html',
                    'https://oceancurrent.aodn.org.au/gliders/TwoRocks20260327_4d/latest.html',
                    'https://oceancurrent.aodn.org.au/gliders/missionTS/sl_TwoRocks20260327.gif',
                    'https://oceancurrent.aodn.org.au/gliders/missionTS/sl_TwoRocks20260327.html?x=1'):
            with self.subTest(url=url):
                mission['temperature_salinity_url'] = url
                resolve_latest_images(catalogue, self.source)
                self.assertIsNone(mission['visualisations']['temperature_salinity_image'])

    def test_changing_diagram_during_publication_is_null(self):
        original = resolve_latest_images
        calls = []
        def changing(catalogue, source):
            result = original(catalogue, source)
            calls.append(True)
            if len(calls) == 1:
                self.page.write_text('<img src=missing.gif>')
            return result
        with patch('gliders_catalogue.resolve_latest_images', side_effect=changing):
            result = publish_catalogue(self.source, self.root / 'catalogue.json', source_complete=True)
        mission = next(m for m in result['missions'] if m['mission_name'] == 'TwoRocks20260327')
        self.assertIsNone(mission['visualisations']['temperature_salinity_image'])

    def test_old_catalogue_without_field_and_invalid_values(self):
        catalogue = parse_catalogue(self.source.read_text())
        for mission in catalogue['missions']:
            mission['visualisations'].pop('temperature_salinity_image')
        validate_catalogue(catalogue)
        for value in ('/gliders/missionTS/sl_TwoRocks20260327.html', 'missionTS/x.gif',
                      'https://oceancurrent.aodn.org.au/gliders/missionTS/x.gif', 1):
            with self.subTest(value=value):
                catalogue['missions'][0]['visualisations']['temperature_salinity_image'] = value
                with self.assertRaises(ValueError):
                    validate_catalogue(catalogue)
