import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from gliders_catalogue_test_utils import edit_rows, has_mission

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
        options = dict(source_complete=True)
        options.update(kwargs)
        return publisher.publish_catalogue(self.source, self.destination, **options)

    def remove_mission(self, name, only_view=None):
        html = edit_rows(self.html, lambda row: "" if has_mission(row, name) else row,
                         view=only_view)
        self.source.write_text(html, encoding="utf-8")

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

    def test_mission_increase_and_decrease_are_published(self):
        self.publish()
        self.remove_mission("Brisbane20180306A_nrt")
        with self.assertLogs(publisher.LOG, level="INFO") as logs:
            result = self.publish()
        self.assertEqual(len(result["missions"]), self.count - 1)
        self.assertEqual(json.loads(self.destination.read_text()), result)
        self.assertIn("previous=8 new=7", "\n".join(logs.output))
        self.source.write_text(self.html, encoding="utf-8")
        with self.assertLogs(publisher.LOG, level="INFO") as logs:
            result = self.publish()
        self.assertEqual(len(result["missions"]), self.count)
        self.assertEqual(json.loads(self.destination.read_text()), result)
        self.assertIn("previous=7 new=8", "\n".join(logs.output))

    def test_individual_order_reductions_are_published(self):
        from gliders_catalogue import VIEWS

        for anchor, view in VIEWS.items():
            with self.subTest(view=view):
                self.source.write_text(self.html, encoding="utf-8")
                previous = self.publish()
                self.remove_mission("TwoRocks20260327", only_view=anchor)
                with self.assertLogs(publisher.LOG, level="INFO") as logs:
                    result = self.publish()
                self.assertEqual(len(result["missions"]), self.count)
                self.assertEqual(len(result["orders"][view]), len(previous["orders"][view]) - 1)
                self.assertEqual(json.loads(self.destination.read_text()), result)
                expected = "Catalogue order %s previous=%d new=%d changed=True" % (
                    view, len(previous["orders"][view]), len(result["orders"][view]))
                self.assertIn(expected, "\n".join(logs.output))

    def test_order_changes_logged_even_when_counts_unchanged(self):
        previous = self.publish()
        reordered = copy.deepcopy(previous)
        for order in reordered["orders"].values():
            order.reverse()
        with patch("gliders_catalogue.parse_catalogue", return_value=reordered):
            with self.assertLogs(publisher.LOG, level="INFO") as logs:
                result = self.publish()
        self.assertEqual(json.loads(self.destination.read_text()), result)
        for view, order in previous["orders"].items():
            self.assertIn("Catalogue order %s previous=%d new=%d changed=True" % (
                view, len(order), len(order)), "\n".join(logs.output))

    def test_invalid_initial_html_does_not_publish(self):
        for invalid in ("", "<html>Maintenance</html>", self.html[:self.html.index("<a id=bymission>")]):
            with self.subTest(invalid=invalid[:30]):
                self.source.write_text(invalid)
                with self.assertRaises(ValueError):
                    self.publish()
                self.assertFalse(self.destination.exists())

    def test_invalid_generated_catalogue_rejected_before_any_write(self):
        valid = parse_catalogue(self.html)
        changes = [lambda c: c.update(schema_version=2),
                   lambda c: c["missions"][0].update(mission_name="invalid"),
                   lambda c: c["missions"][0].pop("latitude"),
                   lambda c: c["missions"][0].update(longitude=999),
                   lambda c: c["orders"].pop("mission_name"),
                   lambda c: c["orders"].update(deployment_date=["unknown"])]
        for existing in (False, True):
            if existing:
                self.publish()
            original = self.destination.read_bytes() if existing else None
            for change in changes:
                with self.subTest(existing=existing, change=change):
                    candidate = copy.deepcopy(valid)
                    change(candidate)
                    with patch("gliders_catalogue.parse_catalogue", return_value=candidate):
                        with patch("gliders_catalogue.write_catalogue") as write:
                            with self.assertRaises(ValueError):
                                self.publish()
                        write.assert_not_called()
                    if existing:
                        self.assertEqual(self.destination.read_bytes(), original)
                    else:
                        self.assertFalse(self.destination.exists())

    def test_atomic_publication_and_reference_output(self):
        from gliders_catalogue import os as writer_os

        self.publish()
        original = self.destination.read_bytes()
        self.assertEqual(original, FIXTURE.with_suffix(".json").read_bytes())
        self.source.write_text(self.html.replace("SG540", "SG541"))
        replace = writer_os.replace
        snapshots = []

        def inspect_replace(temporary, destination):
            temporary = Path(temporary)
            self.assertEqual(temporary.parent, destination.parent)
            self.assertEqual(destination.read_bytes(), original)
            snapshots.append(json.loads(temporary.read_text()))
            replace(temporary, destination)

        with patch("gliders_catalogue.os.replace", side_effect=inspect_replace) as replaced:
            result = self.publish()
        replaced.assert_called_once()
        self.assertEqual(snapshots, [result])
        self.assertEqual(json.loads(self.destination.read_text()), result)
        self.assertEqual(set(Path(self.folder.name).iterdir()), {self.source, self.destination})

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

    def test_invalid_configuration(self):
        for seconds in (0, -1, float("nan"), float("inf")):
            with self.subTest(seconds=seconds), self.assertRaises(ValueError):
                self.publish(stability_seconds=seconds)
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

    def test_no_lock_created_and_manual_confirmation_skips_wait(self):
        with patch.object(publisher.time, "sleep") as sleep:
            self.publish()
        sleep.assert_not_called()
        self.assertEqual(set(Path(self.folder.name).iterdir()), {self.source, self.destination})

    def test_periodic_check_waits_and_publishes_only_stable_source(self):
        with patch.object(publisher.time, "sleep") as sleep:
            result = self.publish(source_complete=False, stability_seconds=15)
        sleep.assert_called_once_with(15)
        self.assertEqual(json.loads(self.destination.read_text()), result)
        original = self.destination.stat().st_mtime_ns
        with patch.object(publisher.time, "sleep") as sleep, patch("gliders_catalogue.write_catalogue") as write:
            self.publish(source_complete=False)
        sleep.assert_called_once_with(30)
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

    def test_periodic_cli_failure_exit_and_logging(self):
        self.publish()
        original = self.destination.read_bytes()

        def update_source(seconds):
            self.source.write_text(self.html.replace("SG540", "SG541"))

        with patch.object(publisher.time, "sleep", side_effect=update_source) as sleep:
            with self.assertLogs(publisher.LOG, level="INFO") as logs:
                status = publisher.main(["--input", str(self.source), "--output", str(self.destination),
                                         "--stability-seconds", "5"])
        self.assertEqual(status, 1)
        sleep.assert_called_once_with(5)
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
                         {self.source.name, self.destination.name})

    def test_cli_exit_codes_and_logging(self):
        args = ["--input", str(self.source), "--output", str(self.destination),
                "--source-complete"]
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
                                 "--output", str(self.destination), "--stability-seconds", "invalid"],
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("invalid float value", result.stderr)

    def test_cli_without_site_packages_and_source_log_failures(self):
        args = [str(SCRIPT), "--input", str(self.source),
                "--output", str(self.destination), "--source-complete"]
        # -S excludes site-packages, including BeautifulSoup, for a first publication.
        result = subprocess.run([sys.executable, "-S"] + args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("status=0", result.stderr)
        self.assertEqual(json.loads(self.destination.read_text()), parse_catalogue(self.html))
        original = self.destination.read_bytes()
        self.source.unlink()
        result = subprocess.run([sys.executable] + args, capture_output=True, text=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("No such file", result.stderr)
        self.assertIn("duration_seconds=", result.stderr)
        self.assertEqual(self.destination.read_bytes(), original)


if __name__ == "__main__":
    unittest.main()
