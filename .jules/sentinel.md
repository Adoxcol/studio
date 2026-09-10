## 2024-05-18 - Prevent DoS in Equalizer Import
**Vulnerability:** Equalizer text files were read directly into memory without file size limits, allowing arbitrary sized files to be parsed, potentially causing Out Of Memory (OOM) Denial of Service.
**Learning:** Dart's FilePicker gives a raw file path, but reading its contents via `readAsString()` on gigabyte-sized txt files can crash the app or block UI resources.
**Prevention:** Always implement a sane, maximum file size check (e.g., 1 MB) using `await file.length()` before reading file contents into memory.
