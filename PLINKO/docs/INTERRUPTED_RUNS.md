# Interrupted runs in v0.3

This checkpoint preserves the v0.2 content and economy. The added work concerns phone interruptions and a reduced-motion preference, not additional boards or live monetization.

## Save contract

Progression and an active-run snapshot share one JSON transaction, written to a temporary file then renamed over the save. Save schema 2 accepts schema 1 progression and pending completed results. Runtime snapshots have their own version and a content fingerprint. The Android release keeps the main game's package/signing identity, increments versionCode to 3 and retains its save filename; actual Android installation upgrade has not been tested on a device.

Snapshots include pegs, balls, pickups, bins, timer, aim, counters, pending special shot, cooldowns and RNG state. Vectors are numeric pairs; RNG state is a decimal string, avoiding JSON integer-precision loss. Cosmetic particles/floating labels/audio are not restored. A resumed run always opens paused and does not subtract time spent outside the app.

The game checkpoints at run start, every five seconds of active play, explicit pause, application focus loss/background notification and orderly close. A sudden crash or forced termination before a checkpoint can lose progress since the latest successful checkpoint. This is not a guarantee of recovery from every OS kill or storage failure.

Completed results take precedence over active snapshots. The reward amount, bank update and removal of pending state are stored together; a claimed run cannot be restored as an unpaid active run. Trial runtime remains separate from the sanitized campaign profile, and completed Trial results do not grant campaign credits.

## Failure handling

Snapshot validation rejects unknown versions/content fingerprints, oversized arrays, invalid fields, non-finite values and impossible runtime states. A rejected run displays a message while keeping readable, valid workshop progression. A wholly corrupt or unreadable save cannot guarantee progression recovery. File-size checks bound parsing; this is defensive validation, not a tamper-proof economy or cloud backup.

## Controls

Pause includes Resume, Sound, Reduced Motion, and End Shift. Ending early requires a confirmation; cancel preserves the paused run. Reduced Motion suppresses decorative particles, floating reward labels, pickup pulsing, hit flashes and ball trails while preserving moving gameplay balls, peg boundaries, HP arcs, timers and controls. It does not change physics or RNG consumption. This is not a screen-reader implementation or comprehensive accessibility certification.

## Verification

See the independent resume QA and visual interruption reports for the final tested scope. Physical Android process-kill/lifecycle behavior, device performance and real install-upgrade remain unverified until a device is available.
