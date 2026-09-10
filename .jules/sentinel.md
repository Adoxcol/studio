## 2024-05-18 - Prevent DoS in Equalizer Import
**Vulnerability:** Equalizer text files were read directly into memory without file size limits, allowing arbitrary sized files to be parsed, potentially causing Out Of Memory (OOM) Denial of Service.
**Learning:** Dart's FilePicker gives a raw file path, but reading its contents via `readAsString()` on gigabyte-sized txt files can crash the app or block UI resources.
**Prevention:** Always implement a sane, maximum file size check (e.g., 1 MB) using `await file.length()` before reading file contents into memory.
## 2024-05-24 - [Fix SQL injection in Drift PRAGMA table_info]
**Vulnerability:** The `_columnNames` method in `lib/library/database.dart` used raw string interpolation (`PRAGMA table_info($table)`) in a `customSelect` query without validating the `table` argument. This is a classic SQL injection vector if user-controlled input were ever passed to this method.
**Learning:** SQLite does not support bind parameters (e.g., `?`) for identifiers like table names or within `PRAGMA` statements. Therefore, when these must be dynamic, string interpolation is functionally required.
**Prevention:** When using string interpolation for SQL identifiers that cannot use bind parameters, always validate the input string against a strict allowlist (e.g., `RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(table)`) before execution.
