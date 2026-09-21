## 2024-06-25 - Batch File Storage Disk Operations
**Learning:** Sequential disk writes inside a loop without debounce or batching can cause massive I/O overhead and UI jank in Flutter apps, especially when whole configurations or files are rewritten each time. Implementing a concurrent save bounded by a throttle limits OS open file descriptors and allows batched operations natively.
**Action:** Always implement a dedicated batching interface in storage layers to process updates concurrently, grouping small disk operations effectively instead of spamming sequential calls that stall execution.
