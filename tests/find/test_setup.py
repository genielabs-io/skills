"""Environment checks against temporary files and a loopback mock, with no downloads."""
import contextlib
import importlib.util
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

ROOT = Path(__file__).resolve().parents[2]
SHELL = shutil.which("pwsh") or shutil.which("powershell")
spec = importlib.util.spec_from_file_location("check_python", ROOT / "skills/find/scripts/check-python.py")
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)


def ps_literal(value):
    return "'" + str(value).replace("'", "''") + "'"


class ProbeTests(unittest.TestCase):
    def test_package_missing_and_wrong_version(self):
        requirements = ROOT / "skills/find/requirements.txt"
        with patch.object(probe.importlib.metadata, "version", side_effect=probe.importlib.metadata.PackageNotFoundError("missing")):
            self.assertTrue(all(not item["ready"] for item in probe.check_packages(requirements)))
        with patch.object(probe.importlib.metadata, "version", return_value="999.0.0"):
            self.assertTrue(all(not item["ready"] for item in probe.check_packages(requirements)))


@unittest.skipUnless(SHELL and os.name == "nt", "Windows PowerShell is needed")
class SetupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.skill = self.folder / "find"
        shutil.copytree(ROOT / "skills/find", self.skill, ignore=shutil.ignore_patterns(".venv", "__pycache__"))

    def run_setup(self, *args, expected=0):
        result = subprocess.run([SHELL, "-NoProfile", "-File", str(self.skill / "scripts/setup.ps1"), "-Json", *args],
                                capture_output=True, encoding="utf-8-sig", timeout=30)
        self.assertEqual(result.returncode, expected, result.stderr)
        return json.loads(result.stdout)

    def run_functions(self, code, expected=0):
        prefix = ". " + ps_literal(self.skill / "scripts/common.ps1") + "\n"
        prefix += ". " + ps_literal(self.skill / "scripts/setup-support.ps1") + "\n"
        result = subprocess.run([SHELL, "-NoProfile", "-Command", "$ErrorActionPreference='Stop'\n" + prefix + code],
                                capture_output=True, encoding="utf-8-sig", timeout=30)
        self.assertEqual(result.returncode, expected, result.stderr)
        return result

    @contextlib.contextmanager
    def http_server(self, valid=True):
        requests = []
        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                requests.append(self.path)
                self.send_response(200)
                self.send_header("Content-Type", "application/json")
                self.end_headers()
                self.wfile.write(b'{"totalResults": 0, "results": []}' if valid else b'{"other_service": true}')
            def log_message(self, *args):
                pass
        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            yield f"http://127.0.0.1:{server.server_port}/", requests
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_metadata_does_not_need_python(self):
        with self.http_server() as (endpoint, requests):
            data = self.run_setup("-Scope", "Metadata", "-Endpoint", endpoint, "-PythonPath", str(self.folder / "missing.exe"))
        self.assertTrue(data["Ready"])
        self.assertIsNone(data["ContentRuntimeReady"])
        self.assertEqual(len(requests), 1)
        self.assertIn("find-environment-probe", requests[0])
        self.assertFalse((self.skill / ".venv").exists())

    def test_wrong_http_service_is_not_ready(self):
        with self.http_server(valid=False) as (endpoint, unused):
            data = self.run_setup("-Scope", "Metadata", "-Endpoint", endpoint, "-Strict", expected=1)
        self.assertFalse(data["MetadataReady"])
        self.assertTrue(any(c["Name"] == "Everything HTTP" and c["Status"] == "action_required" for c in data["Checks"]))

    def test_content_checks_are_offline_and_read_only(self):
        before = {p.relative_to(self.skill): p.read_bytes() for p in self.skill.rglob("*") if p.is_file()}
        with self.http_server() as (endpoint, requests):
            data = self.run_setup("-Scope", "Content", "-Endpoint", endpoint, "-PythonPath", sys.executable)
        self.assertTrue(data["ContentRuntimeReady"])
        self.assertEqual(requests, [])
        self.assertIsNone(data["MetadataReady"])
        after = {p.relative_to(self.skill): p.read_bytes() for p in self.skill.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_missing_explicit_python_gives_action_without_writes(self):
        data = self.run_setup("-Scope", "Content", "-PythonPath", str(self.folder / "missing.exe"), "-Strict", expected=1)
        self.assertFalse(data["Ready"])
        self.assertIn("python.org", next(c for c in data["Checks"] if c["Name"] == "Python")["Action"])
        self.assertFalse((self.skill / ".venv").exists())

    def test_remote_endpoint_rejected_before_request(self):
        data = self.run_setup("-Scope", "Metadata", "-Endpoint", "https://example.invalid/")
        self.assertFalse(data["MetadataReady"])
        self.assertIn("loopback", next(c for c in data["Checks"] if c["Name"] == "Everything HTTP")["Detail"])

    def test_ready_environment_skips_every_install_step(self):
        result = self.run_functions('''
function Resolve-Python { return 'ready-python.exe' }
function Invoke-FindPythonProbe { return [pscustomobject]@{ supported=$true; fts5=$true; packages=@([pscustomobject]@{ready=$true}) } }
function Invoke-SetupPythonCommand { throw 'Installation must not be called' }
Install-FindPythonPackages | ConvertTo-Json
''')
        self.assertEqual(json.loads(result.stdout)["Status"], "skipped")
        self.assertFalse((self.skill / ".venv").exists())

    def test_package_install_uses_only_local_venv_then_skips_on_repeat(self):
        result = self.run_functions('''
$script:installed = $false
$script:calls = [System.Collections.Generic.List[object]]::new()
function Resolve-Python { return 'base-python.exe' }
function Invoke-FindPythonProbe {
    param($Python)
    $ready = $script:installed -and $Python -ne 'base-python.exe'
    $prefix = [IO.Path]::GetDirectoryName([IO.Path]::GetDirectoryName($Python))
    return [pscustomobject]@{ supported=$true; fts5=$true; is_venv=$true; prefix=$prefix; packages=@([pscustomobject]@{ready=$ready}) }
}
function Invoke-SetupPythonCommand {
    param($Python, $Arguments)
    $script:calls.Add([pscustomobject]@{Python=$Python; Arguments=$Arguments})
    if ($Arguments[1] -eq 'venv') {
        New-Item -ItemType Directory -Path (Join-Path $Arguments[2] 'Scripts') -Force | Out-Null
        New-Item -ItemType File -Path (Join-Path $Arguments[2] 'Scripts\\python.exe') | Out-Null
    } elseif ($Arguments[1] -eq 'pip') { $script:installed=$true }
}
$first = Install-FindPythonPackages
$second = Install-FindPythonPackages
[pscustomobject]@{First=$first; Second=$second; Calls=@($script:calls.ToArray())} | ConvertTo-Json -Depth 6
''')
        data = json.loads(result.stdout)
        self.assertEqual(data["First"]["Status"], "installed")
        self.assertEqual(data["Second"]["Status"], "skipped")
        self.assertEqual(len(data["Calls"]), 2)
        pip_call = data["Calls"][1]
        # Windows temp paths may use an 8.3 alias while PowerShell expands it.
        self.assertTrue(Path(pip_call["Python"]).samefile(self.skill / ".venv/Scripts/python.exe"))
        self.assertEqual(pip_call["Arguments"][:3], ["-m", "pip", "install"])

    def test_incomplete_venv_is_not_overwritten(self):
        (self.skill / ".venv").mkdir()
        marker = self.skill / ".venv/keep.txt"
        marker.write_text("keep", encoding="utf-8")
        result = self.run_functions('''
function Resolve-Python { return 'base-python.exe' }
function Invoke-FindPythonProbe { return [pscustomobject]@{supported=$true; fts5=$true; packages=@([pscustomobject]@{ready=$false})} }
function Invoke-SetupPythonCommand { throw 'Must not install' }
try { Install-FindPythonPackages; exit 9 } catch { $_.Exception.Message }
''')
        self.assertIn("incomplete .venv", result.stdout)
        self.assertEqual(marker.read_text(), "keep")

    def test_foreign_interpreter_is_not_modified(self):
        (self.skill / ".venv/Scripts").mkdir(parents=True)
        (self.skill / ".venv/Scripts/python.exe").touch()
        result = self.run_functions('''
function Resolve-Python { return 'base-python.exe' }
function Invoke-FindPythonProbe { return [pscustomobject]@{supported=$true; fts5=$true; is_venv=$false; packages=@([pscustomobject]@{ready=$false})} }
function Invoke-SetupPythonCommand { throw 'Must not install' }
try { Install-FindPythonPackages; exit 9 } catch { $_.Exception.Message }
''')
        self.assertIn("does not belong", result.stdout)

    def test_cmd_launcher_finds_installed_shell_outside_path(self):
        system32 = Path(os.environ["SystemRoot"]) / "System32"
        env = dict(os.environ, PATH=str(system32))
        result = subprocess.run([str(system32 / "cmd.exe"), "/d", "/c", str(self.skill / "scripts/setup.cmd"),
                                 "-Scope", "Content", "-PythonPath", sys.executable, "-Json"],
                                capture_output=True, env=env, timeout=15)
        if result.returncode and b"about_Execution_Policies" in result.stderr:
            self.skipTest("Located shell is blocked by host execution policy")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout.decode("utf-8-sig"))["ContentRuntimeReady"])

    def test_windows_powershell_51_content_check(self):
        shell = Path(os.environ["SystemRoot"]) / "System32/WindowsPowerShell/v1.0/powershell.exe"
        if not shell.exists():
            self.skipTest("Windows PowerShell 5.1 not installed")
        result = subprocess.run([str(shell), "-NoProfile", "-File", str(self.skill / "scripts/setup.ps1"),
                                 "-Scope", "Content", "-PythonPath", sys.executable, "-Json"],
                                capture_output=True, encoding="utf-8-sig", timeout=30)
        if result.returncode and "about_Execution_Policies" in result.stderr:
            self.skipTest("Host execution policy blocks Windows PowerShell scripts; policy was not changed or bypassed")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(json.loads(result.stdout)["ContentRuntimeReady"])


if __name__ == "__main__":
    unittest.main()
