# Sugarfall v0.7.13 Windows preview

Built 5 November 2026 for 64-bit Windows. Drive delivery is blocked: the connector rejected the ZIP because it exceeds its 100 MiB file limit. The earlier Drive file remains unchanged.

The game uses left-click hold and movement over the tray to steer. Release to stop steering. Click a time circle, or drag over it while holding the button, to collect it. Menus use clicks; maps support dragging and the mouse wheel. Extract the ZIP and open `Sugarfall.exe`.

| Artifact | Size | SHA-256 |
|---|---:|---|
| `Sugarfall.exe` | 200,958,232 bytes | `2d2de6d030ab378b00a3dc58cfc7b5760407e879311e23fe8d9bc3aecb648bd9` |
| `Sugarfall-v0.7.13-Windows-Preview-2026-11-05.zip` | 132,097,294 bytes | `d23bf1918f8bcf7c8729fe9ebe78da8810f034cb08d0a77ac9c6665757512888` |

The ZIP contains the executable, control instructions and third-party notices. Its executable's SHA-256 matches the standalone file. The release export completed successfully; Windows file metadata reports version 0.7.13. The executable is unsigned.

The exact executable launched with isolated APPDATA and LOCALAPPDATA, initialized native OpenGL and loaded game resources. It ran in a noninteractive sandbox session, so live mouse interaction and visual acceptance of the packaged executable remain unverified. The focused simulated-input checks passed 13/13 across areas, first-run guide checks passed 160/160, and corrected upgrade-graph checks passed 62/62. These source tests do not substitute for a live mouse test.
