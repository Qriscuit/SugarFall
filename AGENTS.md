# Area production workflow

Before creating or substantially extending a Sugarfall area, read the workspace-root `AREA_CHECKLIST.md`.

- An area is a themed campaign; a tray is one board within an area.
- Create or update `PLINKO/docs/areas/<area_id>_checklist.md` using the root template. Keep the template itself blank.
- For existing areas, start with `AREA_STATUS.md` and the area's populated checklist. Update the linked AF fix and workbook audit rows as work is completed; preserve earlier evidence and intentional omissions.
- Track Built, Integrated and Verified independently. Record evidence, intentional reuse/omissions and remaining gaps during the work.
- For an extra tray in an existing area, update that area's tray register and affected requirements; do not require an unrelated new art pack.
- Use the user's choices over template defaults and record the resulting scope. The checklist does not introduce an approval stop for already authorized work.
- Do not report an area complete while required integration, assets or verification remain open. Distinguish a delivered test APK from a phone-verified, completed area.
- Keep the existing launch tracker and related design/release records consistent when area work changes them. Use isolated profiles for save tests.

# Preview delivery preference

- After meaningful game content changes, build and verify a new Android preview APK and replace the existing APK in the user's Google Drive testing folder before reporting the work complete. This is standing user authorization; do not ask again for a routine build or replacement.
- Preserve the existing preview package/signing identity, Drive file ID, folder and sharing permissions. Increment the preview version/code, verify the exact APK, and confirm the upload by reading back Drive metadata.
- Keep build links, release records and the launch tracker current. A delivered build does not establish physical-phone acceptance. If delivery is blocked, state what remains blocked rather than presenting a source-only change as delivered.
