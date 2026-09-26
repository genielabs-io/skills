"""Read-only dependency probe. Uses an in-memory SQLite database, not user data."""
import importlib
import importlib.metadata
import json
from pathlib import Path
import re
import sys


MODULES = {"python-docx": "docx", "python-pptx": "pptx", "openpyxl": "openpyxl", "pypdf": "pypdf"}


def check_packages(requirements):
    results = []
    for line in requirements.read_text(encoding="utf-8-sig").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        match = re.fullmatch(r"([\w-]+)>=([\d.]+),<([\d.]+)", line.strip())
        if not match:
            raise ValueError("Unsupported requirement syntax: " + line)
        name, lower, upper = match.groups()
        item = {"name": name, "requirement": line, "ready": False, "version": None, "detail": ""}
        try:
            version = importlib.metadata.version(name)
            item["version"] = version
            # Only stable, numeric releases satisfy this distribution's simple bounds.
            if not re.fullmatch(r"\d+(?:\.\d+)*", version):
                raise ValueError("A stable numeric package version is required")
            def version_tuple(text):
                parts = tuple(int(x) for x in text.split("."))
                return parts + (0,) * max(0, 3 - len(parts))
            if not version_tuple(lower) <= version_tuple(version) < version_tuple(upper):
                raise ValueError("Installed version is outside " + line)
            importlib.import_module(MODULES[name])
            item["ready"] = True
            item["detail"] = "Installed and importable; skip installation."
        except Exception as exc:
            item["detail"] = str(exc)
        results.append(item)
    return results


def probe():
    result = {"executable": sys.executable, "version": sys.version.split()[0],
              "supported": sys.version_info >= (3, 10), "fts5": False, "fts5_error": "", "packages": [],
              "is_venv": sys.prefix != sys.base_prefix, "prefix": str(Path(sys.prefix).resolve())}
    try:
        import sqlite3
        with sqlite3.connect(":memory:") as db:
            db.execute("CREATE VIRTUAL TABLE probe USING fts5(text)")
        result["fts5"] = True
    except Exception as exc:
        result["fts5_error"] = str(exc)
    result["packages"] = check_packages(Path(__file__).resolve().parent.parent / "requirements.txt")
    return result


if __name__ == "__main__":
    print(json.dumps(probe(), ensure_ascii=True))
