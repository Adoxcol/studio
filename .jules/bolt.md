## 2024-05-14 - Optimize FolderCover.find to be Asynchronous
**Learning:** Using synchronous I/O operations like `Directory.listSync` can block the event loop and potentially lead to UI stutters, especially if the directory contains a large number of files.
**Action:** When interacting with the file system in Dart, prefer using asynchronous variants like `Directory.list` and `File.length` over their `Sync` counterparts to keep the application responsive. Ensure the surrounding methods using these calls are `async` and appropriately `await` the results.
