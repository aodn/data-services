import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from gliders_catalogue_test_utils import edit_cells, edit_rows, has_mission

from gliders_catalogue import generate_catalogue, parse_catalogue


FIXTURE = Path(__file__).parent / "fixtures" / "gliders_catalogue.html"


class TestGlidersCatalogue(unittest.TestCase):
    def setUp(self):
        self.html = FIXTURE.read_text()
        self.catalogue = parse_catalogue(self.html)
        self.records = {r["mission_name"]: r for r in self.catalogue["missions"]}

    def test_matches_previous_implementation(self):
        # Captured from the BeautifulSoup implementation using the same fixture.
        expected = FIXTURE.with_suffix(".json").read_bytes()
        self.assertEqual(self.catalogue, json.loads(expected))
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "catalogue.json"
            generate_catalogue(FIXTURE, output)
            self.assertEqual(output.read_bytes(), expected)

    def test_unique_missions_and_versions(self):
        self.assertEqual(len(self.records), 8)
        normal = self.records["Brisbane20180306A"]
        nrt = self.records["Brisbane20180306A_nrt"]
        self.assertEqual(normal["mission_id"], nrt["mission_id"])
        self.assertNotEqual(normal["id"], nrt["id"])
        self.assertFalse(normal["is_nrt"])
        self.assertTrue(nrt["is_nrt"])
        self.assertEqual(nrt["processing_version"], "3.0.")
        self.assertEqual(normal["processing_version"], "5.00")
        self.assertEqual(self.records["TasEastCoast20241031"]["catalogue_numbers"], ["394", "395"])
        self.assertIn("JervisBay20180503a", self.records)
        self.assertNotEqual(self.records["Perth20110626_1"]["mission_id"],
                            self.records["Perth20110626_2"]["mission_id"])

    def test_metadata_and_links(self):
        mission = self.records["Brisbane20180306A"]
        self.assertEqual(mission["start_date"], "2018-03-06")
        self.assertEqual(mission["end_date"], "2018-03-10")
        self.assertLess(mission["latitude"], 0)
        self.assertGreater(mission["longitude"], 0)
        self.assertEqual(mission["glider_id"], "SG540")
        self.assertTrue(mission["scientific_data_url"].endswith("Brisbane20180306A/catalog.html"))
        self.assertTrue(mission["temperature_salinity_url"].endswith("missionTS/sg_Brisbane20180306A.html"))
        for kind, ending in [("details", "/latest.html"), ("animations", ".mp4")]:
            links = mission["visualisations"][kind]
            self.assertEqual([link["label"] for link in links], ["4", "12", "30"])
            self.assertTrue(all(link["url"].endswith(ending) for link in links))
        # km is travelled distance, never the catalogue's alongshore sort metric.
        self.assertEqual(mission["distance_travelled_km"], 403)
        self.assertNotIn("distance_to_darwin", mission)

    def test_orders_and_event_membership(self):
        orders = self.catalogue["orders"]
        ids = {name: record["id"] for name, record in self.records.items()}
        self.assertEqual(orders["event_based_sampling"], [ids["TwoRocks20260327"], ids["TasEastCoast20241031"]])
        self.assertEqual(orders["deployment_date"][0], ids["TwoRocks20260327"])
        self.assertEqual(orders["mission_name"][0], ids["JervisBay20180503a"])
        self.assertNotEqual(orders["distance_alongshore_to_darwin"], orders["deployment_date"])
        # The mission-name view in the real catalogue omits this historical NRT row.
        self.assertNotIn(ids["Brisbane20180306A_nrt"], orders["mission_name"])
        for order in orders.values():
            self.assertEqual(len(order), len(set(order)))
            self.assertTrue(set(order).issubset(ids.values()))

    def test_missing_optional_metadata(self):
        mission = self.records["Perth20110626_2"]
        self.assertEqual(mission["dates_raw"], "Jun - Aug 2011")
        for field in ["start_date", "end_date", "latitude", "longitude", "duration_days",
                      "distance_travelled_km", "glider_id", "temperature_salinity_url", "scientific_data_url"]:
            self.assertIsNone(mission[field], field)
        self.assertEqual(mission["visualisations"], {"details": [], "animations": [], "latest_images": dict.fromkeys(("4d", "12d", "30d"))})

    def test_same_name_different_processing_versions(self):
        def add_version(row):
            if has_mission(row, "Brisbane20180306A"):
                return row + edit_cells(row, {10: "6.00"})
            return row

        result = parse_catalogue(edit_rows(self.html, add_version, view="bydate"))
        versions = [r for r in result["missions"] if r["mission_name"] == "Brisbane20180306A"]
        self.assertEqual(len(versions), 2)
        self.assertEqual(len({r["id"] for r in versions}), 2)

    def test_dates(self):
        html = self.html.replace("06 Mar - 10 Mar 2018", "20 Dec - 10 Jan 2018")
        record = next(r for r in parse_catalogue(html)["missions"] if r["mission_name"] == "Brisbane20180306A")
        self.assertEqual(record["start_date"], "2017-12-20")
        self.assertEqual(record["end_date"], "2018-01-10")
        html = self.html.replace("06 Mar - 10 Mar 2018", "31 Feb - 10 Mar 2018")
        record = next(r for r in parse_catalogue(html)["missions"] if r["mission_name"] == "Brisbane20180306A")
        self.assertIsNone(record["start_date"])

    def test_conflicting_metadata_rejected(self):
        # Change just one occurrence, leaving other catalogue views intact.
        html = self.html.replace("06 Mar - 10 Mar 2018", "07 Mar - 10 Mar 2018", 1)
        with self.assertRaisesRegex(ValueError, "Conflicting metadata"):
            parse_catalogue(html)

    def test_empty_event_view_and_partial_visualisations(self):
        html = edit_rows(self.html, lambda row: "" if "<td>" in row else row, view="byebs")
        html = edit_rows(html, lambda row: edit_cells(row, {7: "", 8: ""})
                         if has_mission(row, "Brisbane20180306A") else row, view="bydate")
        result = parse_catalogue(html)
        self.assertEqual(result["orders"]["event_based_sampling"], [])
        record = next(r for r in result["missions"] if r["mission_name"] == "Brisbane20180306A")
        self.assertEqual(len(record["visualisations"]["details"]), 3)

    def test_invalid_optional_numbers(self):
        html = edit_rows(self.html, lambda row: edit_cells(row, {2: "NaN", 3: "999", 4: "-2", 5: "inf"})
                         if has_mission(row, "Brisbane20180306A") else row)
        record = next(r for r in parse_catalogue(html)["missions"]
                      if r["mission_name"] == "Brisbane20180306A")
        for field in ["latitude", "longitude", "duration_days", "distance_travelled_km"]:
            self.assertIsNone(record[field])

    def test_empty_and_incomplete_catalogue_rejected(self):
        html = edit_rows(self.html, lambda row: "" if "<td>" in row else row)
        with self.assertRaisesRegex(ValueError, "Empty catalogue view"):
            parse_catalogue(html)

    def test_nested_markup_entities_and_link_filtering(self):
        link = '<a href="../details.html?a=1&amp;b=2"><b>4</b>&nbsp;day</a>'
        details = (link + link + '<a>no href</a><a href="">empty</a>'
                   '<a href="javascript:alert(1)">script</a><a href="mailto:a@b">mail</a>')
        html = edit_rows(self.html, lambda row: edit_cells(row, {
            7: details, 9: '<b>SG</b><br>540<!-- ignored --><img src="unused">'
                            '<script>ignored</script><style>ignored</style>'})
                         if has_mission(row, "Brisbane20180306A") else row)
        result = parse_catalogue(html, "https://example.org/gliders/index.html")
        mission = next(r for r in result["missions"] if r["mission_name"] == "Brisbane20180306A")
        self.assertEqual(mission["glider_id"], "SG 540")
        self.assertEqual(mission["visualisations"]["details"], [
            {"label": "4 day", "url": "https://example.org/details.html?a=1&b=2"}])

    def test_view_anchors_and_table_wrappers(self):
        html = self.html.replace('<a id=', '<A ID=').replace('</a><table>', '</A><div><table>')
        html = html.replace('</table>', '</table></div>')
        html = html.replace('<table>', '<TABLE><tbody>').replace('</table>', '</tbody></TABLE>')
        self.assertEqual(parse_catalogue(html), self.catalogue)

    def test_two_views_cannot_share_a_table(self):
        html = self.html.replace('<a id=bydate>', '<a id=bymission></a><a id=bydate>', 1)
        with self.assertRaisesRegex(ValueError, "Missing catalogue table: bymission"):
            parse_catalogue(html)

    def test_columns_and_units_are_validated(self):
        for html, message in [
                (self.html.replace('<th>N</th>', '<th>changed</th>', 1), "Unexpected catalogue columns"),
                (self.html.replace('°S', '°N', 1), "Unexpected coordinate units"),
                (self.html.replace('°E', '°W', 1), "Unexpected coordinate units")]:
            with self.subTest(message=message), self.assertRaisesRegex(ValueError, message):
                parse_catalogue(html)

    def test_invalid_source_preserves_output(self):
        with tempfile.TemporaryDirectory() as folder:
            source, output = Path(folder) / "index.html", Path(folder) / "catalogue.json"
            source.write_text(self.html)
            generate_catalogue(source, output)
            original = output.read_bytes()
            for invalid in ["", "<html>Maintenance</html>",
                            self.html.replace('id="bydist"', 'id="missing"').replace('id=bydist', 'id=missing'),
                            self.html.replace("°S", "°N"),
                            self.html.replace("Brisbane20180306A", "invalid").replace("<table>", "<table><tr><th>changed</th></tr>")]:
                source.write_text(invalid)
                with self.assertRaises(ValueError):
                    generate_catalogue(source, output)
                self.assertEqual(output.read_bytes(), original)

    def test_atomic_failure_and_determinism(self):
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "catalogue.json"
            generate_catalogue(FIXTURE, output)
            original = output.read_bytes()
            self.assertEqual(json.loads(original), self.catalogue)
            generate_catalogue(FIXTURE, output)
            self.assertEqual(output.read_bytes(), original)
            with patch("gliders_catalogue.os.replace", side_effect=OSError("write failed")):
                with self.assertRaises(OSError):
                    generate_catalogue(FIXTURE, output, "https://example.org/gliders/index.html")
            self.assertEqual(output.read_bytes(), original)
            self.assertEqual(list(Path(folder).iterdir()), [output])


if __name__ == "__main__":
    unittest.main()
