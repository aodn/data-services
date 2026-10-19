import copy
import fcntl
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from bs4 import BeautifulSoup

import publish_gliders_catalogue as publisher
from gliders_catalogue import parse_catalogue

FIXTURE = Path(__file__).parent / "fixtures" / "gliders_catalogue.html"
SCRIPT = Path(__file__).with_name("publish_gliders_catalogue.py")


class TestPublication(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.source = Path(self.folder.name) / "index.html"
        self.destination = Path(self.folder.name) / "gliders-catalogue.json"
        self.html = FIXTURE.read_text(encoding="utf-8")
        self.source.write_text(self.html, encoding="utf-8")
        self.count = len(parse_catalogue(self.html)["missions"])

    def publish(self, **kwargs):
        options = dict(source_complete=True, initial_mission_count=self.count)
        options.update(kwargs)
        return publisher.publish_catalogue(self.source, self.destination, **options)

    def remove_mission(self, name, only_view=None):
        soup = BeautifulSoup(self.html, "html.parser")
        container = soup.find("a", id=only_view).find_next("table") if only_view else soup
        for row in container.find_all("tr"):
            cells = row.find_all("td", recursive=False)
            if len(cells) == 12 and cells[-1].get_text(strip=True) == name:
                row.decompose()
        self.source.write_text(str(soup), encoding="utf-8")

    def test_initial_publication_and_unchanged_output(self):
        with self.assertLogs(publisher.LOG, level="INFO") as logs:
            result = self.publish()
        self.assertEqual(json.loads(self.destination.read_text()), parse_catalogue(self.html))
        self.assertEqual(len(result["missions"]), self.count)
        self.assertEqual(self.destination.stat().st_mode & 0o777, 0o644)
        self.assertIn("previous=None new=8", "\n".join(logs.output))
        original = self.destination.stat()
        self.source.write_text(self.html + "\n", encoding="utf-8")
        with patch.object(publisher, "LOG") as log, patch("gliders_catalogue.write_catalogue") as write:
            self.publish()
        write.assert_not_called()
        self.assertEqual(self.destination.stat().st_mtime_ns, original.st_mtime_ns)
        self.assertIn("False", str(log.info.call_args_list))

    def test_updated_mission_information(self):
        self.publish()
        self.source.write_text(self.html.replace("SG540", "SG541"), encoding="utf-8")
        result = self.publish()
        self.assertEqual(json.loads(self.destination.read_text()), result)
        self.assertTrue(any(r["glider_id"] == "SG541" for r in result["missions"]))

    def test_invalid_or_incomplete_source_preserves_output(self):
        self.publish()
        original = self.destination.read_bytes()
        for invalid in ("", "<html>Maintenance</html>", self.html[:self.html.index("<a id=bymission>")]):
            with self.subTest(invalid=invalid[:30]):
                self.source.write_text(invalid)
                with self.assertRaises(ValueError):
                    self.publish()
                self.assertEqual(self.destination.read_bytes(), original)

    def test_reduction_and_explicit_threshold(self):
        self.publish()
        original = self.destination.read_bytes()
        self.remove_mission("Brisbane20180306A_nrt")
        for threshold in (0, 10):
            with self.assertRaisesRegex(ValueError, "Reduction requires manual review"):
                self.publish(max_reduction_percent=threshold)
            self.assertEqual(self.destination.read_bytes(), original)
        result = self.publish(max_reduction_percent=12.5)
        self.assertEqual(len(result["missions"]), self.count - 1)

    def test_partial_view_reduction_even_when_total_unchanged(self):
        self.publish()
        original = self.destination.read_bytes()
        self.remove_mission("TwoRocks20260327", only_view="byebs")
        with self.assertRaisesRegex(ValueError, "event_based_sampling"):
            self.publish()
        self.assertEqual(self.destination.read_bytes(), original)

    def test_missing_unreadable_and_changing_source(self):
        self.publish()
        original = self.destination.read_bytes()
        self.source.unlink()
        with self.assertRaises(FileNotFoundError):
            self.publish()
        self.source.write_text(self.html)
        with patch.object(Path, "read_bytes", side_effect=PermissionError("unreadable")):
            with self.assertRaises(PermissionError):
                self.publish()
        read_source = publisher._read_source
        calls = []

        def changed_source(path):
            if calls:
                path.write_text(self.html + "<!-- new publication -->")
            calls.append(True)
            return read_source(path)

        with patch.object(publisher, "_read_source", side_effect=changed_source):
            with self.assertRaisesRegex(ValueError, "Source changed"):
                self.publish()
        self.assertEqual(self.destination.read_bytes(), original)

    def test_changes_during_snapshot_read_rejected(self):
        real_read = Path.read_bytes

        def changing_read(path):
            result = real_read(path)
            path.write_bytes(result + b" ")
            return result

        with patch.object(Path, "read_bytes", changing_read):
            with self.assertRaisesRegex(ValueError, "Source changed while reading"):
                self.publish()
        self.assertFalse(self.destination.exists())

    def test_configuration_and_first_publication_review_required(self):
        for options in (dict(initial_mission_count=None),
                        dict(initial_mission_count=1), dict(initial_mission_count=0),
                        dict(stability_seconds=0), dict(stability_seconds=-1),
                        dict(stability_seconds=float("nan")), dict(stability_seconds=float("inf")),
                        dict(max_reduction_percent=-1), dict(max_reduction_percent=100),
                        dict(max_reduction_percent=float("nan")), dict(max_reduction_percent=float("inf"))):
            with self.subTest(options=options), self.assertRaises(ValueError):
                self.publish(**options)
            self.assertFalse(self.destination.exists())
        with self.assertRaisesRegex(ValueError, "Source must differ"):
            publisher.publish_catalogue(self.source, self.source, source_complete=True)

    def test_invalid_baseline_requires_recovery_preserves_bytes(self):
        for value in (None, {}, {"schema_version": 2}, "invalid JSON"):
            self.destination.write_text(json.dumps(value))
            original = self.destination.read_bytes()
            with self.assertRaises(ValueError):
                self.publish()
            self.assertEqual(self.destination.read_bytes(), original)
        self.destination.write_text("{broken JSON")
        with self.assertRaises(ValueError):
            self.publish()
        self.assertEqual(self.destination.read_text(), "{broken JSON")

    def test_schema_records_and_orders_validation(self):
        valid = parse_catalogue(self.html)
        changes = [lambda c: c.update(schema_version=True),
                   lambda c: c.update(missions=[]),
                   lambda c: c["missions"][0].update(mission_name="invalid"),
                   lambda c: c["missions"][0].update(latitude=999),
                   lambda c: c["missions"].append(c["missions"][0]),
                   lambda c: c["orders"].pop("mission_name"),
                   lambda c: c["orders"].update(deployment_date=["unknown"]),
                   lambda c: c["orders"].update(event_based_sampling=[[], []])]
        for change in changes:
            candidate = copy.deepcopy(valid)
            change(candidate)
            with self.assertRaises(ValueError):
                publisher.validate_catalogue(candidate)

    def test_concurrent_publication_fails(self):
        self.publish()
        original = self.destination.read_bytes()
        lock_path = Path(str(self.destination) + ".lock")
        with lock_path.open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = subprocess.run([sys.executable, str(SCRIPT), "--input", str(self.source),
                                     "--output", str(self.destination), "--source-complete"],
                                    capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("holds the output lock", result.stderr)
        self.assertEqual(self.destination.read_bytes(), original)
        self.assertTrue(lock_path.exists())

    def test_periodic_check_waits_and_publishes_only_stable_source(self):
        with patch.object(publisher.time, "sleep") as sleep:
            result = self.publish(source_complete=False, stability_seconds=15)
        sleep.assert_called_once_with(15)
        self.assertEqual(json.loads(self.destination.read_text()), result)
        original = self.destination.stat().st_mtime_ns
        with patch.object(publisher.time, "sleep"), patch("gliders_catalogue.write_catalogue") as write:
            self.publish(source_complete=False)
        write.assert_not_called()
        self.assertEqual(self.destination.stat().st_mtime_ns, original)

    def test_periodic_source_change_aborts_before_generation(self):
        self.publish()
        original = self.destination.read_bytes()

        def update_source(seconds):
            self.source.write_text(self.html.replace("SG540", "SG541"))

        with patch.object(publisher.time, "sleep", side_effect=update_source):
            with patch("gliders_catalogue.parse_catalogue") as parse:
                with self.assertRaisesRegex(ValueError, "stability observation"):
                    self.publish(source_complete=False)
            parse.assert_not_called()
        self.assertEqual(self.destination.read_bytes(), original)

    def test_content_update_with_preserved_mtime_is_published(self):
        self.publish()
        stat = self.source.stat()
        self.source.write_text(self.html.replace("SG540", "SG541"))
        os.utime(self.source, ns=(stat.st_atime_ns, stat.st_mtime_ns))
        with patch.object(publisher.time, "sleep"):
            result = self.publish(source_complete=False)
        self.assertTrue(any(r["glider_id"] == "SG541" for r in result["missions"]))
        self.assertEqual(json.loads(self.destination.read_text()), result)

    def test_observation_compares_content_even_if_stat_signature_matches(self):
        self.publish()
        original = self.destination.read_bytes()
        html, signature = publisher._read_source(self.source)
        with patch.object(publisher.time, "sleep"), patch.object(
                publisher, "_read_source", side_effect=[(html, signature), (html + b" ", signature)]):
            with self.assertRaisesRegex(ValueError, "stability observation"):
                self.publish(source_complete=False)
        self.assertEqual(self.destination.read_bytes(), original)

    def test_external_lock_and_manual_confirmation(self):
        lock_path = Path(self.folder.name) / "outside-transfer.lock"
        with patch.object(publisher.time, "sleep") as sleep:
            self.publish(lock_file=lock_path)
        sleep.assert_not_called()
        self.assertTrue(lock_path.exists())
        self.assertFalse(Path(str(self.destination) + ".lock").exists())
        with lock_path.open("a") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            with self.assertRaisesRegex(ValueError, "holds the output lock"):
                self.publish(lock_file=lock_path)
        with self.assertRaisesRegex(ValueError, "destination must differ"):
            self.publish(lock_file=self.destination)

    def test_periodic_cli_failure_exit_and_logging(self):
        self.publish()
        original = self.destination.read_bytes()
        lock_path = Path(self.folder.name) / "outside-transfer.lock"

        def update_source(seconds):
            self.source.write_text(self.html.replace("SG540", "SG541"))

        with patch.object(publisher.time, "sleep", side_effect=update_source) as sleep:
            with self.assertLogs(publisher.LOG, level="INFO") as logs:
                status = publisher.main(["--input", str(self.source), "--output", str(self.destination),
                                         "--stability-seconds", "5", "--lock-file", str(lock_path)])
        self.assertEqual(status, 1)
        sleep.assert_called_once_with(5)
        self.assertTrue(lock_path.exists())
        self.assertEqual(self.destination.read_bytes(), original)
        messages = "\n".join(logs.output)
        for expected in ("Observing HTML stability", "stability observation", "status=1", "duration_seconds="):
            self.assertIn(expected, messages)

    def test_publication_failure_preserves_previous_and_cleans_temp(self):
        self.publish()
        original = self.destination.read_bytes()
        self.source.write_text(self.html.replace("SG540", "SG541"))
        with patch("gliders_catalogue.os.replace", side_effect=OSError("disk failure")):
            with self.assertRaisesRegex(OSError, "disk failure"):
                self.publish()
        self.assertEqual(self.destination.read_bytes(), original)
        self.assertEqual({p.name for p in Path(self.folder.name).iterdir()},
                         {self.source.name, self.destination.name, self.destination.name + ".lock"})

    def test_cli_exit_codes_and_logging(self):
        args = ["--input", str(self.source), "--output", str(self.destination),
                "--source-complete", "--initial-mission-count", str(self.count)]
        with self.assertLogs(publisher.LOG, level="INFO") as logs:
            self.assertEqual(publisher.main(args), 0)
        messages = "\n".join(logs.output)
        for expected in ("Publication started", str(self.source), str(self.destination),
                         "previous=None new=8", "changed=True", "status=0", "duration_seconds="):
            self.assertIn(expected, messages)
        with patch.dict(sys.modules, {"gliders_catalogue": None}):
            with self.assertLogs(publisher.LOG, level="INFO") as logs:
                self.assertEqual(publisher.main(args), 1)
        self.assertIn("Validation/publication failed", "\n".join(logs.output))
        self.assertIn("status=1", "\n".join(logs.output))
        result = subprocess.run([sys.executable, str(SCRIPT), "--input", str(self.source),
                                 "--output", str(self.destination), "--max-reduction-percent", "invalid"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid float value", result.stderr)

    def test_cli_missing_beautifulsoup_and_source_log_failures(self):
        self.publish()
        original = self.destination.read_bytes()
        args = [str(SCRIPT), "--input", str(self.source),
                "--output", str(self.destination), "--source-complete"]
        # -S removes site-packages, simulating the production dependency being absent.
        result = subprocess.run([sys.executable, "-S"] + args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("No module named 'bs4'", result.stderr)
        self.assertIn("Validation/publication failed", result.stderr)
        self.assertIn("status=1", result.stderr)
        self.source.unlink()
        result = subprocess.run([sys.executable] + args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("No such file", result.stderr)
        self.assertIn("duration_seconds=", result.stderr)
        self.assertEqual(self.destination.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
