"""Isolated behavioral tests; never query live Everything or private documents."""
import contextlib
import hashlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from unittest.mock import patch
from urllib.parse import parse_qs, urlsplit

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "skills/find/scripts/content-index.py"
spec = importlib.util.spec_from_file_location("content_index", SCRIPT)
index = importlib.util.module_from_spec(spec)
spec.loader.exec_module(index)


class FinderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.db = self.folder / "test.db"
        self.doc = self.folder / "한글 sample.txt"
        self.doc.write_text("드론 안전수칙\nflight safety lesson", encoding="utf-8")
        self.entries = [self.doc]
        self.incomplete = False

    def update(self, *options):
        args = index.build_parser().parse_args(["update", "--db", str(self.db), "--extensions", "txt", *options])
        def results(*unused):
            for item in self.entries:
                yield item, len(self.entries)
            if self.incomplete:
                raise RuntimeError("incomplete result set")
        with patch.object(index, "everything_results", results), patch.object(index.Path, "is_dir", return_value=True), contextlib.redirect_stdout(io.StringIO()) as out, contextlib.redirect_stderr(io.StringIO()):
            index.cmd_update(args)
        return json.loads(out.getvalue())

    def search(self, query="드론", *options):
        args = index.build_parser().parse_args(["search", query, "--db", str(self.db), *options])
        with contextlib.redirect_stdout(io.StringIO()) as out:
            index.cmd_search(args)
        return json.loads(out.getvalue())

    def test_incremental_search_counts_and_read_only(self):
        other = self.folder / "other.txt"
        other.write_text("드론 연습", encoding="utf-8")
        self.entries.append(other)
        source_before = self.doc.read_bytes()
        self.assertEqual(self.update()["indexed"], 2)
        self.assertEqual(self.update()["unchanged"], 2)
        before = hashlib.sha256(self.db.read_bytes()).hexdigest()
        data = self.search("드론", "--limit", "1")
        self.assertEqual((data["total_results"], data["count"]), (2, 1))
        self.assertEqual(hashlib.sha256(self.db.read_bytes()).hexdigest(), before)
        self.assertEqual(self.doc.read_bytes(), source_before)
        self.assertEqual(self.search('"flight safety"')["count"], 1)
        self.assertEqual(self.search("드론", "--extensions", "pdf")["count"], 0)
        self.doc.write_text("updated unique marker", encoding="utf-8")
        self.assertEqual(self.update()["indexed"], 1)
        self.assertEqual(self.search("unique")["count"], 1)

    def test_missing_index_is_not_created(self):
        with self.assertRaises(FileNotFoundError):
            self.search()
        self.assertFalse(self.db.exists())

    def test_prune_only_matching_scope(self):
        self.update()
        self.entries = []
        self.assertEqual(self.update("--prune")["removed"], 1)

    def test_custom_and_changed_scope_prune_rejected(self):
        self.update()
        with self.assertRaises(ValueError):
            self.update("--query", "file: sample", "--prune")
        with self.assertRaises(ValueError):
            self.update("--drives", "Z", "--prune")
        self.assertEqual(self.search()["count"], 1)
        self.update("--drives", "Z")
        with self.assertRaises(ValueError):
            self.update("--prune")

    def test_incomplete_update_preserves_old_rows(self):
        self.update()
        self.entries = []
        self.incomplete = True
        with self.assertRaises(RuntimeError):
            self.update("--prune")
        self.assertEqual(self.search()["count"], 1)

    def test_failed_extraction_is_retried(self):
        with patch.object(index, "extract_content", side_effect=RuntimeError("dependency unavailable")):
            self.assertEqual(self.update()["errors"], 1)
        self.assertEqual(self.update()["indexed"], 1)
        self.assertEqual(self.search()["count"], 1)

    def test_drive_configuration(self):
        self.assertEqual(index.resolve_drives("F,D,F"), ["D", "F"])
        with self.assertRaises(ValueError):
            index.resolve_drives("C,invalid")

    def test_optional_tika_missing(self):
        with patch.object(index, "resolve_tika", return_value=None):
            with self.assertRaisesRegex(RuntimeError, "not configured"):
                index.extract_hwp(self.doc, 1)

    def test_path_filter_treats_wildcards_literally(self):
        special = self.folder / "rate_100%.txt"
        special.write_text("드론", encoding="utf-8")
        self.entries.append(special)
        self.update()
        data = self.search("드론", "--path", "rate_100%")
        self.assertEqual(data["count"], 1)
        self.assertEqual(data["results"][0]["name"], special.name)

    def test_http_incomplete_pagination_rejected(self):
        with patch.object(index, "open_everything_url", return_value=io.BytesIO(b'{"totalResults": 2, "results": []}')):
            with self.assertRaisesRegex(RuntimeError, "incomplete"):
                list(index.everything_results("http://127.0.0.1/", "file:", 10))

    def test_http_and_powershell_wrappers(self):
        shell = shutil.which("pwsh") or shutil.which("powershell")
        if not shell:
            self.skipTest("PowerShell is unavailable")
        requests = []
        doc = self.doc
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                query = parse_qs(urlsplit(self.path).query)
                requests.append(query)
                if "simulate_failure" in query.get("search", [""])[0]:
                    self.send_error(503, "Simulated Everything failure")
                    return
                offset = int(query.get("offset", ["0"])[0])
                payload = {"totalResults": 1, "results": [] if offset else [{
                    "name": doc.name, "path": str(doc.parent), "size": doc.stat().st_size,
                    "date_modified": "133000000000000000", "type": "file"
                }]}
                self.send_response(200)
                self.send_header("Content-Type", "application/json; charset=utf-8")
                self.end_headers()
                self.wfile.write(json.dumps(payload).encode())
            def log_message(self, *args):
                pass
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        def stop():
            server.shutdown()
            server.server_close()
            thread.join()
        self.addCleanup(stop)
        endpoint = f"http://127.0.0.1:{server.server_port}/"
        def run(name, *args):
            env = dict(os.environ, PYTHONIOENCODING="utf-8")
            result = subprocess.run([shell, "-NoProfile", "-File", str(ROOT / "skills/find/scripts" / name), *args],
                                    capture_output=True, encoding="utf-8-sig", env=env, timeout=30)
            self.assertEqual(result.returncode, 0, result.stderr)
            return json.loads(result.stdout)
        metadata = run("find-files.ps1", "-Query", "sample", "-Drives", "F", "-Endpoint", endpoint)
        self.assertEqual(metadata["Results"][0]["FullPath"], str(doc))
        self.assertEqual(metadata["ReturnedResults"], 1)
        self.assertIn("f:", requests[-1]["search"][0])
        default_metadata = run("find-files.ps1", "-Query", "sample", "-Endpoint", endpoint)
        default_drive = os.environ.get("SystemDrive", "C:").lower()
        self.assertIn(default_drive, default_metadata["Query"])
        updated = run("update-content-index.ps1", "-Extensions", "txt", "-Drives", "F", "-Endpoint", endpoint,
                      "-Database", str(self.db), "-PythonPath", sys.executable)
        self.assertEqual(updated["indexed"], 1)
        searched = run("search-content.ps1", "-Query", "드론", "-Database", str(self.db), "-PythonPath", sys.executable)
        self.assertEqual(searched["total_results"], 1)
        failed = subprocess.run([shell, "-NoProfile", "-File", str(ROOT / "skills/find/scripts/find-files.ps1"),
                                 "-Query", "simulate_failure", "-Endpoint", endpoint],
                                capture_output=True, timeout=30)
        self.assertNotEqual(failed.returncode, 0)
        self.assertIn(b"Everything HTTP search failed", failed.stderr)
        missing = subprocess.run([shell, "-NoProfile", "-File", str(ROOT / "skills/find/scripts/search-content.ps1"),
                                  "-Query", "sample", "-PythonPath", str(self.folder / "missing-python.exe")],
                                 capture_output=True, timeout=30)
        self.assertNotEqual(missing.returncode, 0)


if __name__ == "__main__":
    unittest.main()
