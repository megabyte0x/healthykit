"""Offline, private portable snapshots for the seven HealthSync tables."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import math
import os
from pathlib import Path
import re
import sqlite3
import sys
import tempfile


PRIMARY_KEYS = {
    "workspaces": ("id",),
    "devices": ("device_id",),
    "workspace_devices": ("workspace_id", "device_id"),
    "access_tokens": ("id",),
    "sync_batches": ("workspace_id", "export_id"),
    "health_metrics": ("workspace_id", "device_id", "id"),
    "health_workouts": ("workspace_id", "device_id", "id"),
}
COLUMNS = {
    "workspaces": {"id", "created_at", "label"},
    "devices": {"device_id", "first_seen_at", "last_seen_at", "app_version"},
    "workspace_devices": {"workspace_id", "device_id", "created_at", "last_seen_at", "label"},
    "access_tokens": {"id", "workspace_id", "kind", "token_hash", "created_at", "last_used_at", "revoked_at"},
    "sync_batches": {"workspace_id", "export_id", "device_id", "generated_at", "received_at",
                    "schema_version", "timezone", "source", "date_range_start", "date_range_end",
                    "metrics_count", "workouts_count"},
    "health_metrics": {"workspace_id", "device_id", "id", "type", "value", "unit", "start_at",
                       "end_at", "source_name", "source_bundle_id", "metadata", "export_id"},
    "health_workouts": {"workspace_id", "device_id", "id", "activity_type", "start_at", "end_at",
                        "duration_seconds", "total_energy_kcal", "active_energy_kcal", "distance_meters",
                        "source_name", "source_bundle_id", "metadata", "export_id"},
}
TIMESTAMPS = {"created_at", "first_seen_at", "last_seen_at", "last_used_at", "revoked_at",
              "generated_at", "received_at", "date_range_start", "date_range_end", "start_at", "end_at"}
FLOATS = {"value", "duration_seconds", "total_energy_kcal", "active_energy_kcal", "distance_meters"}


def canonical_json(value):
    return json.dumps(value, sort_keys=True, ensure_ascii=False, separators=(",", ":"), allow_nan=False)


def canonical_snapshot(data):
    if not isinstance(data, dict) or set(data) != {"tables"}:
        raise ValueError("Invalid snapshot structure")
    tables = data["tables"]
    if not isinstance(tables, dict) or set(tables) != set(PRIMARY_KEYS):
        raise ValueError("Snapshot must contain exactly the seven supported tables")
    result = {}
    for table, primary_key in PRIMARY_KEYS.items():
        if not isinstance(tables[table], list):
            raise ValueError("Invalid snapshot table")
        rows = []
        seen = set()
        for source in tables[table]:
            if not isinstance(source, dict) or not set(source) <= COLUMNS[table]:
                raise ValueError("Unsupported snapshot column")
            if any(not isinstance(source.get(key), str) for key in primary_key):
                raise ValueError("Missing or invalid primary key")
            key = tuple(source[key] for key in primary_key)
            if key in seen:
                raise ValueError("Duplicate snapshot primary key")
            seen.add(key)
            row = {}
            for column, value in source.items():
                if column in TIMESTAMPS and value is not None:
                    if not isinstance(value, str):
                        raise ValueError("Invalid timestamp")
                    normalized = re.sub(
                        r"\.(\d{1,5})(?=(?:Z|[+-]\d{2}:\d{2})$)",
                        lambda match: "." + match.group(1).ljust(6, "0"),
                        value,
                    )
                    parsed = datetime.fromisoformat(normalized.replace("Z", "+00:00"))
                    if parsed.tzinfo is None or parsed.utcoffset() is None:
                        raise ValueError("Timestamp must include a timezone")
                    value = parsed.astimezone(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")
                elif column in FLOATS and value is not None:
                    if isinstance(value, bool) or not isinstance(value, (int, float)):
                        raise ValueError("Invalid numeric value")
                    value = float(value)
                    if not math.isfinite(value):
                        raise ValueError("Nonfinite numeric value")
                    if value == 0:
                        value = 0.0
                elif column != "metadata" and isinstance(value, (dict, list)):
                    raise ValueError("Unexpected structured value")
                row[column] = value
            rows.append(row)
        result[table] = sorted(rows, key=lambda row: tuple(row[key] for key in primary_key))
    return json.loads(canonical_json({"tables": result}))


def create_manifest(data):
    canonical = canonical_snapshot(data)
    return {"tables": {
        table: {"count": len(canonical["tables"][table]),
                "sha256": hashlib.sha256(canonical_json(canonical["tables"][table]).encode("utf-8")).hexdigest()}
        for table in PRIMARY_KEYS
    }}


def verify_snapshot(data, manifest):
    return create_manifest(data) == manifest


def parse_json(text):
    def unique_object(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("Duplicate JSON key")
            result[key] = value
        return result

    return json.loads(text, object_pairs_hook=unique_object)


def read_json(path):
    return parse_json(Path(path).read_text(encoding="utf-8"))


def require_distinct_paths(source, output):
    source, output = Path(source), Path(output)
    if source.resolve() == output.resolve() or (source.exists() and output.exists() and os.path.samefile(source, output)):
        raise ValueError("Output must not overwrite an input file")


def write_private_json(path, value):
    path = Path(path)
    descriptor, temporary = tempfile.mkstemp(prefix=".snapshot-", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
            stream.write(canonical_json(value) + "\n")
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def database_tables(connection, allow_managed=False):
    managed = {"_cf_METADATA", "d1_migrations"} if allow_managed else set()
    tables = [row[0] for row in connection.execute("SELECT name FROM sqlite_master WHERE type='table'")
              if not row[0].startswith("sqlite_") and row[0] not in managed]
    if any(table not in PRIMARY_KEYS for table in tables):
        raise ValueError("Unsupported database table")
    return tables


def validate_database(connection, allow_managed=False):
    if set(database_tables(connection, allow_managed=allow_managed)) != set(PRIMARY_KEYS):
        raise ValueError("Database must contain exactly the seven supported tables")
    for table, primary_key in PRIMARY_KEYS.items():
        columns = connection.execute(f'PRAGMA table_info("{table}")').fetchall()
        if any(column[1] not in COLUMNS[table] for column in columns):
            raise ValueError("Unsupported database column")
        actual_key = tuple(column[1] for column in sorted(columns, key=lambda column: column[5]) if column[5])
        if actual_key != primary_key:
            raise ValueError("Unexpected database primary key")


def execute_schema(connection, text):
    statement = ""
    for character in text:
        statement += character
        if character == ";" and sqlite3.complete_statement(statement):
            connection.execute(statement)
            statement = ""
    if statement.strip():
        connection.execute(statement)


def sqlite_import(snapshot_path, database_path, schema_path):
    data = canonical_snapshot(read_json(snapshot_path))
    schema = Path(schema_path).read_text(encoding="utf-8")
    path = Path(database_path)
    descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600) if not path.exists() else None
    if descriptor is not None:
        os.close(descriptor)
    os.chmod(path, 0o600)
    connection = sqlite3.connect(path)
    try:
        connection.execute("PRAGMA foreign_keys = ON")
        connection.execute("BEGIN IMMEDIATE")
        for table in database_tables(connection):
            if connection.execute(f'SELECT 1 FROM "{table}" LIMIT 1').fetchone():
                raise ValueError("Refusing populated destination database")
        execute_schema(connection, schema)
        validate_database(connection)
        for table in PRIMARY_KEYS:
            for row in data["tables"][table]:
                columns = sorted(row)
                names = ",".join(f'"{column}"' for column in columns)
                binds = ",".join("?" for _ in columns)
                values = [canonical_json(row[column]) if column == "metadata" else row[column] for column in columns]
                connection.execute(f'INSERT INTO "{table}" ({names}) VALUES ({binds})', values)
        if connection.execute("PRAGMA foreign_key_check").fetchone():
            raise ValueError("Database foreign key validation failed")
        connection.commit()
    except BaseException:
        connection.rollback()
        raise
    finally:
        connection.close()


def sqlite_export(database_path, output_path):
    require_distinct_paths(database_path, output_path)
    path = Path(database_path).resolve()
    connection = sqlite3.connect(path.as_uri() + "?mode=ro", uri=True)
    try:
        connection.execute("BEGIN")
        validate_database(connection, allow_managed=True)
        if any(connection.execute(f'PRAGMA foreign_key_check("{table}")').fetchone() for table in PRIMARY_KEYS):
            raise ValueError("Database foreign key validation failed")
        tables = {}
        for table in PRIMARY_KEYS:
            cursor = connection.execute(f'SELECT * FROM "{table}"')
            columns = [column[0] for column in cursor.description]
            rows = []
            for record in cursor:
                row = dict(zip(columns, record))
                if "metadata" in row and row["metadata"] is not None:
                    row["metadata"] = parse_json(row["metadata"])
                rows.append(row)
            tables[table] = rows
        write_private_json(output_path, canonical_snapshot({"tables": tables}))
    finally:
        connection.close()


class PrivateArgumentParser(argparse.ArgumentParser):
    def error(self, message):
        self.exit(2, "Invalid snapshot command arguments; use --help for usage.\n")


def main(argv=None):
    parser = PrivateArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command, arguments in {
        "manifest": ("snapshot", "output"),
        "verify": ("snapshot", "manifest"),
        "sqlite-import": ("snapshot", "database", "schema"),
        "sqlite-export": ("database", "output"),
    }.items():
        child = commands.add_parser(command)
        for argument in arguments:
            child.add_argument(argument)
    args = parser.parse_args(argv)
    try:
        if args.command == "manifest":
            require_distinct_paths(args.snapshot, args.output)
            write_private_json(args.output, create_manifest(read_json(args.snapshot)))
        elif args.command == "verify":
            if not verify_snapshot(read_json(args.snapshot), read_json(args.manifest)):
                raise ValueError("Snapshot verification failed")
        elif args.command == "sqlite-import":
            sqlite_import(args.snapshot, args.database, args.schema)
        else:
            sqlite_export(args.database, args.output)
    except (OSError, ValueError, TypeError, OverflowError, sqlite3.Error):
        print("Snapshot operation failed; check inputs and destination integrity.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
