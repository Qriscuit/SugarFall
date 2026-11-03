# Source backup and recovery

Verified 3 November 2026. The workspace is now a Git repository connected to [Qriscuit/SugarFall](https://github.com/Qriscuit/SugarFall). The repository was empty before the first authorized source push.

| Record | Value |
| --- | --- |
| Branch | `main` |
| Initial source commit | `1ab3cef673ab8fa9a78271cd0fc01bf8f90a6a70` |
| Release tag | [`v0.8.0-rc1`](https://github.com/Qriscuit/SugarFall/tree/v0.8.0-rc1) |
| Tagged commit | `1bf3632dc9f5568bb1d29ac254b42c089a2ffb02` |
| Tracked files recovered at that tag | 881 |
| Recovery checks | 13 passed, 0 failed |

An independent checkout was downloaded from GitHub into `verification/github-sync-20261103/recovery`. It fetched and checked out the release tag, passed `git fsck --full --strict`, contained every tracked file, and had a clean working tree. The clone is complete, with no shallow-history restriction or alternate local object store. Original studio artwork, generated boot still, original hum and the workbook were also compared byte-for-byte with the tagged repository objects. The exact local report is `verification/github-sync-20261103/recovery-verification.json`.

Source, runtime art, concept provenance, authored tools, tests, design records and the production workbook are backed up. Private signing material, personal player saves, downloaded tools, editor caches, raw QA archives and build artifacts are excluded. The source candidate scan found no matching private-key or service-token patterns; ignore rules were separately checked against actual private and build paths.

This verifies recovery of the source and assets. It does not establish a fresh-machine Android build or recovery of the private signing key. Follow [the release build procedure](ANDROID_RELEASE_BUILD.md) to configure a new build machine and [the signing recovery instructions](RELEASE_SIGNING.md) to back up the owner-held key and password separately. Neither APK/AAB binaries nor a Play Store release were published by this source push.

The final tracker update follows the release tag as a documentation-only commit on `main`; the tagged runtime corresponds to the [signed release-candidate manifest](ANDROID_SUGARFALL_v0.8.0-rc1.json).
