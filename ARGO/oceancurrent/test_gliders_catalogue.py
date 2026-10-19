import copy
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from bs4 import BeautifulSoup

from gliders_catalogue import generate_catalogue, parse_catalogue


FIXTURE = Path(__file__).parent / "fixtures" / "gliders_catalogue.html"


class TestGlidersCatalogue(unittest.TestCase):
    def setUp(self):
        self.html = FIXTURE.read_text()
        self.catalogue = parse_catalogue(self.html)
        self.records = {r["mission_name"]: r for r in self.catalogue["missions"]}

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
        self.assertEqual(mission["visualisations"], {"details": [], "animations": []})

    def test_same_name_different_processing_versions(self):
        soup = BeautifulSoup(self.html, "html.parser")
        row = next(r for r in soup.find_all("tr")
                   if any(a.get_text() == "Brisbane20180306A" for a in r.find_all("a")))
        extra = copy.deepcopy(row)
        extra.find_all("td")[10].string = "6.00"
        row.insert_after(extra)
        result = parse_catalogue(str(soup))
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
        soup = BeautifulSoup(self.html, "html.parser")
        event_table = soup.find("a", id="byebs").find_next("table")
        for row in event_table.find_all("tr")[2:]:
            row.decompose()
        date_table = soup.find("a", id="bydate").find_next("table")
        for row in date_table.find_all("tr"):
            cells = row.find_all("td", recursive=False)
            if len(cells) == 12 and cells[-1].get_text() == "Brisbane20180306A":
                cells[7].clear()
                cells[8].clear()
        result = parse_catalogue(str(soup))
        self.assertEqual(result["orders"]["event_based_sampling"], [])
        record = next(r for r in result["missions"] if r["mission_name"] == "Brisbane20180306A")
        self.assertEqual(len(record["visualisations"]["details"]), 3)

    def test_invalid_optional_numbers(self):
        soup = BeautifulSoup(self.html, "html.parser")
        for row in soup.find_all("tr"):
            cells = row.find_all("td", recursive=False)
            if len(cells) == 12 and cells[-1].get_text() == "Brisbane20180306A":
                for index, value in [(2, "NaN"), (3, "999"), (4, "-2"), (5, "inf")]:
                    cells[index].string = value
        record = next(r for r in parse_catalogue(str(soup))["missions"]
                      if r["mission_name"] == "Brisbane20180306A")
        for field in ["latitude", "longitude", "duration_days", "distance_travelled_km"]:
            self.assertIsNone(record[field])

    def test_empty_and_incomplete_catalogue_rejected(self):
        soup = BeautifulSoup(self.html, "html.parser")
        for row in soup.find_all("tr"):
            if row.find_all("td", recursive=False):
                row.decompose()
        with self.assertRaisesRegex(ValueError, "Empty catalogue view"):
            parse_catalogue(str(soup))

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
                    generate_catalogue(FIXTURE, output)
            self.assertEqual(output.read_bytes(), original)
            self.assertEqual(list(Path(folder).iterdir()), [output])


if __name__ == "__main__":
    unittest.main()
