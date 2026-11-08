from __future__ import annotations

import copy
import json
import math
import os
from pathlib import Path
import sqlite3
import stat
import subprocess
import sys
import tempfile
import unittest

from scripts import cloudflare_snapshot as snapshot


OFFSET = "2026-11-07T10:00:00.123456+05:30"
UTC = "2026-11-07T04:30:00.123456Z"
SCRIPT = Path(__file__).with_name("cloudflare_snapshot.py")


def fixture():
    return {"tables": {
        "workspaces": [
            {"id": "b", "created_at": OFFSET, "label": None},
            {"id": "a", "created_at": OFFSET, "label": "健康 🌻"},
        ],
        "devices": [{"device_id": "d", "first_seen_at": OFFSET,
                     "last_seen_at": OFFSET, "app_version": None}],
        "workspace_devices": [
            {"workspace_id": w, "device_id": "d", "created_at": OFFSET,
             "last_seen_at": OFFSET, "label": None} for w in ("b", "a")
        ],
        "access_tokens": [{"id": "t", "workspace_id": "a", "kind": "ingest",
                           "token_hash": "synthetic-opaque-value", "created_at": OFFSET,
                           "last_used_at": None, "revoked_at": None}],
        "sync_batches": [
            {"workspace_id": w, "export_id": "e", "device_id": "d",
             "generated_at": OFFSET, "received_at": OFFSET, "schema_version": 1,
             "timezone": "Asia/Kolkata", "source": "fixture", "date_range_start": OFFSET,
             "date_range_end": OFFSET, "metrics_count": 1, "workouts_count": 1}
            for w in ("b", "a")
        ],
        "health_metrics": [
            {"workspace_id": w, "device_id": "d", "id": "same", "type": "fixture",
             "value": 1.2345678901234567, "unit": "fixture", "start_at": OFFSET,
             "end_at": OFFSET, "source_name": "fixture", "source_bundle_id": None,
             "metadata": {"z": [None, {"β": "é", "a": 0.12345678901234566}], "a": True},
             "export_id": "e"} for w in ("b", "a")
        ],
        "health_workouts": [
            {"workspace_id": w, "device_id": "d", "id": "same", "activity_type": "fixture",
             "start_at": OFFSET, "end_at": OFFSET, "duration_seconds": 12.123456789012345,
             "total_energy_kcal": None, "active_energy_kcal": 0.0, "distance_meters": None,
             "source_name": "fixture", "source_bundle_id": None, "metadata": {},
             "export_id": "e"} for w in ("b", "a")
        ],
    }}


SCHEMA = """
CREATE TABLE workspaces (id TEXT PRIMARY KEY, created_at TEXT NOT NULL, label TEXT);
CREATE TABLE devices (device_id TEXT PRIMARY KEY, first_seen_at TEXT, last_seen_at TEXT, app_version TEXT);
CREATE TABLE workspace_devices (workspace_id TEXT REFERENCES workspaces(id),
 device_id TEXT REFERENCES devices(device_id), created_at TEXT, last_seen_at TEXT, label TEXT,
 PRIMARY KEY(workspace_id, device_id));
CREATE TABLE access_tokens (id TEXT PRIMARY KEY, workspace_id TEXT REFERENCES workspaces(id),
 kind TEXT CHECK(kind IN ('ingest', 'agent_read')), token_hash TEXT UNIQUE, created_at TEXT,
 last_used_at TEXT, revoked_at TEXT);
CREATE TABLE sync_batches (workspace_id TEXT REFERENCES workspaces(id), export_id TEXT,
 device_id TEXT REFERENCES devices(device_id), generated_at TEXT, received_at TEXT,
 schema_version INTEGER, timezone TEXT, source TEXT, date_range_start TEXT, date_range_end TEXT,
 metrics_count INTEGER, workouts_count INTEGER, PRIMARY KEY(workspace_id, export_id));
CREATE TABLE health_metrics (workspace_id TEXT REFERENCES workspaces(id), device_id TEXT REFERENCES devices(device_id),
 id TEXT, type TEXT, value REAL, unit TEXT, start_at TEXT, end_at TEXT, source_name TEXT,
 source_bundle_id TEXT, metadata TEXT, export_id TEXT, PRIMARY KEY(workspace_id, device_id, id),
 FOREIGN KEY(workspace_id, export_id) REFERENCES sync_batches(workspace_id, export_id));
CREATE TABLE health_workouts (workspace_id TEXT REFERENCES workspaces(id), device_id TEXT REFERENCES devices(device_id),
 id TEXT, activity_type TEXT, start_at TEXT, end_at TEXT, duration_seconds REAL,
 total_energy_kcal REAL, active_energy_kcal REAL, distance_meters REAL, source_name TEXT,
 source_bundle_id TEXT, metadata TEXT, export_id TEXT, PRIMARY KEY(workspace_id, device_id, id),
 FOREIGN KEY(workspace_id, export_id) REFERENCES sync_batches(workspace_id, export_id));
"""


class SnapshotTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "snapshot.json"
        self.schema = self.root / "schema.sql"
        self.database = self.root / "snapshot.sqlite"
        self.schema.write_text(SCHEMA, encoding="utf-8")
        self.write_source(fixture())

    def write_source(self, data):
        self.source.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")

    def cli(self, *args):
        return subprocess.run([sys.executable, str(SCRIPT), *map(str, args)],
                              capture_output=True, text=True, check=False)

    def test_manifest_equivalent_offsets_recursive_json_keys_and_row_order(self):
        original = fixture()
        equivalent = copy.deepcopy(original)
        for rows in equivalent["tables"].values():
            rows.reverse()
            for row in rows:
                for key, value in list(row.items()):
                    if value == OFFSET:
                        row[key] = UTC
        equivalent["tables"]["health_metrics"][0]["metadata"] = {
            "a": True, "z": [None, {"a": 0.12345678901234566, "β": "é"}]}
        self.assertEqual(snapshot.create_manifest(original), snapshot.create_manifest(equivalent))

    def test_canonical_preserves_microseconds_null_unicode_and_float_precision(self):
        result = snapshot.canonical_snapshot(fixture())["tables"]
        self.assertEqual(result["workspaces"][0], {"id": "a", "created_at": UTC, "label": "健康 🌻"})
        self.assertEqual(result["health_metrics"][0]["value"], 1.2345678901234567)
        self.assertEqual(result["health_metrics"][0]["metadata"]["z"][1]["a"], 0.12345678901234566)
        self.assertIsNone(result["health_workouts"][0]["total_energy_kcal"])
        self.assertEqual([r["workspace_id"] for r in result["health_metrics"]], ["a", "b"])

    def test_canonical_accepts_variable_fractional_timestamp_precision(self):
        data = fixture()
        result_row = data["tables"]["workspaces"][1]
        for digits in range(1, 7):
            fraction = "123456"[:digits]
            micros = fraction.ljust(6, "0")
            for offset, hour, minute in (("Z", "19", "00"), ("+05:30", "13", "30")):
                with self.subTest(digits=digits, offset=offset):
                    result_row["created_at"] = f"2026-11-07T19:00:00.{fraction}{offset}"
                    canonical = snapshot.canonical_snapshot(data)
                    self.assertEqual(canonical["tables"]["workspaces"][0]["created_at"],
                                     f"2026-11-07T{hour}:{minute}:00.{micros}Z")
        result_row["created_at"] = None
        self.assertIsNone(snapshot.canonical_snapshot(data)["tables"]["workspaces"][0]["created_at"])

    def test_rejects_invalid_timestamp_dates(self):
        data = fixture()
        data["tables"]["workspaces"][0]["created_at"] = "2026-02-30T19:00:00.1Z"
        with self.assertRaises(ValueError):
            snapshot.canonical_snapshot(data)

    def test_manifest_only_counts_and_digests(self):
        manifest = snapshot.create_manifest(fixture())
        self.assertEqual(set(manifest), {"tables"})
        for table, entry in manifest["tables"].items():
            self.assertEqual(set(entry), {"count", "sha256"})
            self.assertEqual(entry["count"], len(fixture()["tables"][table]))
            self.assertRegex(entry["sha256"], r"^[a-f0-9]{64}$")
        self.assertNotIn("synthetic-opaque-value", json.dumps(manifest))

    def test_corruption_and_microsecond_or_float_changes_are_detected(self):
        for column, value in (("value", 1.234567890123456), ("start_at", "2026-11-07T04:30:00.123457Z")):
            with self.subTest(column=column):
                changed = fixture()
                changed["tables"]["health_metrics"][0][column] = value
                self.assertFalse(snapshot.verify_snapshot(changed, snapshot.create_manifest(fixture())))

    def test_rejects_unknown_identifiers_and_incomplete_table_sets(self):
        for mutation in ("table", "column", "missing", "missing_key", "duplicate"):
            with self.subTest(mutation=mutation):
                data = fixture()
                if mutation == "table":
                    data["tables"]["unexpected; DROP TABLE workspaces"] = []
                elif mutation == "column":
                    data["tables"]["workspaces"][0]["unexpected"] = "value"
                elif mutation == "missing":
                    del data["tables"]["devices"]
                elif mutation == "missing_key":
                    del data["tables"]["workspace_devices"][0]["device_id"]
                else:
                    data["tables"]["workspaces"].append(data["tables"]["workspaces"][0].copy())
                with self.assertRaises(ValueError):
                    snapshot.create_manifest(data)

    def test_rejects_naive_timestamps_and_nonfinite_floats(self):
        for column, value in (("start_at", "2026-11-07T04:30:00.123456"), ("value", float("nan")),
                              ("value", float("inf"))):
            with self.subTest(column=column, finite=isinstance(value, str)):
                data = fixture()
                data["tables"]["health_metrics"][0][column] = value
                with self.assertRaises(ValueError):
                    snapshot.create_manifest(data)

    def test_sqlite_round_trip_preserves_all_values_and_composite_keys(self):
        snapshot.sqlite_import(self.source, self.database, self.schema)
        output = self.root / "export.json"
        snapshot.sqlite_export(self.database, output)
        result = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(result, snapshot.canonical_snapshot(fixture()))
        self.assertEqual(snapshot.create_manifest(result), snapshot.create_manifest(fixture()))
        with sqlite3.connect(self.database) as connection:
            timestamp, metadata = connection.execute("SELECT start_at, metadata FROM health_metrics LIMIT 1").fetchone()
            self.assertEqual(timestamp, UTC)
            self.assertIsInstance(metadata, str)
            self.assertEqual(json.loads(metadata), fixture()["tables"]["health_metrics"][0]["metadata"])
            connection.execute("UPDATE health_metrics SET metadata = ?", (json.dumps(json.loads(metadata), indent=2),))
        snapshot.sqlite_export(self.database, output)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8")), result)

    def test_metadata_json_string_is_not_reinterpreted_as_an_object(self):
        data = fixture()
        data["tables"]["health_metrics"][0]["metadata"] = '{"literal":"scalar"}'
        self.write_source(data)
        snapshot.sqlite_import(self.source, self.database, self.schema)
        output = self.root / "export.json"
        snapshot.sqlite_export(self.database, output)
        self.assertEqual(json.loads(output.read_text(encoding="utf-8")), snapshot.canonical_snapshot(data))

    def test_signed_zero_float_columns_round_trip_without_changing_metadata(self):
        data = fixture()
        for row in data["tables"]["health_metrics"]:
            row["value"] = -0.0
            row["metadata"] = {"signed_zero": -0.0}
        for row in data["tables"]["health_workouts"]:
            for column in ("duration_seconds", "total_energy_kcal", "active_energy_kcal", "distance_meters"):
                row[column] = -0.0
        self.write_source(data)
        snapshot.sqlite_import(self.source, self.database, self.schema)
        output = self.root / "export.json"
        snapshot.sqlite_export(self.database, output)
        result = json.loads(output.read_text(encoding="utf-8"))
        self.assertEqual(snapshot.create_manifest(result), snapshot.create_manifest(data))
        canonical = snapshot.canonical_snapshot(data)
        for table, columns in (("health_metrics", ("value",)),
                               ("health_workouts", ("duration_seconds", "total_energy_kcal", "active_energy_kcal", "distance_meters"))):
            for row in canonical["tables"][table]:
                for column in columns:
                    self.assertEqual(math.copysign(1.0, row[column]), 1.0)
        for row in result["tables"]["health_metrics"]:
            self.assertEqual(math.copysign(1.0, row["metadata"]["signed_zero"]), -1.0)

    def test_empty_snapshot_round_trips(self):
        data = {"tables": {table: [] for table in fixture()["tables"]}}
        self.write_source(data)
        snapshot.sqlite_import(self.source, self.database, self.schema)
        output = self.root / "export.json"
        snapshot.sqlite_export(self.database, output)
        self.assertEqual(json.loads(output.read_text()), data)

    def test_import_refuses_populated_destination_without_changes(self):
        snapshot.sqlite_import(self.source, self.database, self.schema)
        before = self.database.read_bytes()
        with self.assertRaises(ValueError):
            snapshot.sqlite_import(self.source, self.database, self.schema)
        self.assertEqual(self.database.read_bytes(), before)

    def test_foreign_key_and_unique_violations_roll_back(self):
        for mutation in ("foreign_key", "unique", "check"):
            with self.subTest(mutation=mutation):
                database = self.root / (mutation + ".sqlite")
                data = fixture()
                if mutation == "foreign_key":
                    data["tables"]["health_metrics"][0]["export_id"] = "missing"
                elif mutation == "unique":
                    token = data["tables"]["access_tokens"][0].copy()
                    token["id"] = "second"
                    data["tables"]["access_tokens"].append(token)
                else:
                    data["tables"]["access_tokens"][0]["kind"] = "invalid"
                self.write_source(data)
                with self.assertRaises((ValueError, sqlite3.IntegrityError)):
                    snapshot.sqlite_import(self.source, database, self.schema)
                if database.exists():
                    with sqlite3.connect(database) as connection:
                        self.assertEqual(connection.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall(), [])

    def test_import_uses_no_more_than_100_binds_per_statement(self):
        data = fixture()
        data["tables"]["workspaces"].extend(
            {"id": f"extra-{n}", "created_at": OFFSET, "label": None} for n in range(150))
        self.write_source(data)
        real_connect = sqlite3.connect

        class LimitedConnection(sqlite3.Connection):
            def execute(self, sql, parameters=()):
                if len(parameters) > 100:
                    raise sqlite3.OperationalError("too many SQL variables")
                return super().execute(sql, parameters)

        def limited_connect(*args, **kwargs):
            return real_connect(*args, factory=LimitedConnection, **kwargs)

        from unittest.mock import patch
        with patch.object(snapshot.sqlite3, "connect", side_effect=limited_connect):
            snapshot.sqlite_import(self.source, self.database, self.schema)
        with real_connect(self.database) as connection:
            self.assertEqual(connection.execute("SELECT COUNT(*) FROM workspaces").fetchone()[0], 152)

    def test_cli_manifest_verify_import_export_and_private_output_modes(self):
        manifest = self.root / "manifest.json"
        exported = self.root / "export.json"
        mask = os.umask(0)
        self.addCleanup(os.umask, mask)
        for args in (("manifest", self.source, manifest), ("verify", self.source, manifest),
                     ("sqlite-import", self.source, self.database, self.schema),
                     ("sqlite-export", self.database, exported)):
            result = self.cli(*args)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")
        for path in (manifest, self.database, exported):
            self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)
        os.chmod(exported, 0o666)
        self.assertEqual(self.cli("sqlite-export", self.database, exported).returncode, 0)
        self.assertEqual(stat.S_IMODE(exported.stat().st_mode), 0o600)

    def test_cli_errors_do_not_expose_input_values_or_paths(self):
        manifest = self.root / "manifest.json"
        self.assertEqual(self.cli("manifest", self.source, manifest).returncode, 0)
        data = fixture()
        data["tables"]["access_tokens"][0]["token_hash"] = "PRIVATE_TEST_MARKER"
        self.write_source(data)
        result = self.cli("verify", self.source, manifest)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PRIVATE_TEST_MARKER", result.stdout + result.stderr)
        self.assertNotIn(str(self.root), result.stdout + result.stderr)
        self.source.write_text('{"PRIVATE_TEST_MARKER": invalid')
        result = self.cli("manifest", self.source, manifest)
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PRIVATE_TEST_MARKER", result.stdout + result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        result = self.cli("PRIVATE_TEST_MARKER")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PRIVATE_TEST_MARKER", result.stdout + result.stderr)

    def test_sqlite_export_refuses_missing_database_and_unknown_columns(self):
        output = self.root / "export.json"
        with self.assertRaises((ValueError, sqlite3.DatabaseError, FileNotFoundError)):
            snapshot.sqlite_export(self.database, output)
        self.assertFalse(self.database.exists())
        self.assertFalse(output.exists())
        snapshot.sqlite_import(self.source, self.database, self.schema)
        with sqlite3.connect(self.database) as connection:
            connection.execute("ALTER TABLE workspaces ADD COLUMN unexpected TEXT")
        with self.assertRaises(ValueError):
            snapshot.sqlite_export(self.database, output)
        self.assertFalse(output.exists())

    def test_rejects_duplicate_json_keys_without_overwriting_manifest(self):
        manifest = self.root / "manifest.json"
        manifest.write_text("existing output")
        data = json.dumps(fixture())
        self.source.write_text(data.replace('"label": null', '"label": "discarded", "label": null', 1))
        result = self.cli("manifest", self.source, manifest)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(manifest.read_text(), "existing output")

    def test_outputs_must_not_overwrite_inputs_even_through_aliases(self):
        alias = self.root / "alias.json"
        os.link(self.source, alias)
        before = self.source.read_bytes()
        self.assertNotEqual(self.cli("manifest", self.source, alias).returncode, 0)
        self.assertEqual(self.source.read_bytes(), before)
        snapshot.sqlite_import(self.source, self.database, self.schema)
        before = self.database.read_bytes()
        with self.assertRaises(ValueError):
            snapshot.sqlite_export(self.database, self.database)
        self.assertEqual(self.database.read_bytes(), before)

    def test_rejects_unknown_database_table_with_sqlite_prefix_lookalike(self):
        snapshot.sqlite_import(self.source, self.database, self.schema)
        with sqlite3.connect(self.database) as connection:
            connection.execute("CREATE TABLE sqliteXunexpected (id TEXT)")
        with self.assertRaises(ValueError):
            snapshot.sqlite_export(self.database, self.root / "export.json")

    def test_export_ignores_exact_managed_d1_tables(self):
        snapshot.sqlite_import(self.source, self.database, self.schema)
        with sqlite3.connect(self.database) as connection:
            for table in ("_cf_METADATA", "d1_migrations"):
                connection.execute(f'CREATE TABLE "{table}" (managed TEXT REFERENCES managed_missing(id))')
                connection.execute(f'INSERT INTO "{table}" VALUES (?)', ("synthetic managed state",))
        output = self.root / "export.json"
        snapshot.sqlite_export(self.database, output)
        self.assertEqual(json.loads(output.read_text()), snapshot.canonical_snapshot(fixture()))

    def test_managed_d1_tables_are_not_allowed_in_import_or_as_lookalikes(self):
        for table in ("_cf_METADATA", "d1_migrations", "_cf_METADATA_extra", "d1_migrations_extra"):
            with self.subTest(table=table):
                database = self.root / (table + ".sqlite")
                with sqlite3.connect(database) as connection:
                    connection.execute(f'CREATE TABLE "{table}" (managed TEXT)')
                with self.assertRaises(ValueError):
                    snapshot.sqlite_import(self.source, database, self.schema)
        snapshot.sqlite_import(self.source, self.database, self.schema)
        for table in ("_cf_METADATA_extra", "d1_migrations_extra"):
            with self.subTest(table=table):
                with sqlite3.connect(self.database) as connection:
                    connection.execute(f'CREATE TABLE "{table}" (managed TEXT)')
                with self.assertRaises(ValueError):
                    snapshot.sqlite_export(self.database, self.root / "export.json")
                with sqlite3.connect(self.database) as connection:
                    connection.execute(f'DROP TABLE "{table}"')


if __name__ == "__main__":
    unittest.main()
