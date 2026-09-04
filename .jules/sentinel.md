## 2024-05-24 - [MEDIUM] Fix insecure temporary file creation in POSIX PcmFifo
**Vulnerability:** Predictable named pipe creation in global `/tmp` directory. The code used `${Directory.systemTemp.path}/studio-fft-$pid-...pcm` which is vulnerable to symlink and time-of-check-to-time-of-use attacks because `/tmp` is world-writable.
**Learning:** Temporary files should not be directly created in the global temporary directory with predictable names.
**Prevention:** Always use `Directory.systemTemp.createTemp(prefix)` to securely create a process-exclusive temporary directory first, and then place any required files inside it.
