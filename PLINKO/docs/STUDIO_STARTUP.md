# Studio startup

Updated 3 November 2026 · warm-light/hum source revision verified separately below; latest delivered preview v0.7.4 (code 29) · phone acceptance pending

Sugarfall opens with the supplied studio stamp in a soft warm spotlight, a gentle double heartbeat with an original hum, and the shared cream wipe into the restored destination. This is an application-start sequence. In the [current screen layout](SCREEN_LAYOUT.md), Home Play uses its tray zoom/morph and end-of-run results appear over the darkened frozen board; neither uses a cream wipe or replays the studio logo. Ordinary menu navigation retains the [0.62-second cream transition](MENU_TRANSITIONS.md).

## Artwork and provenance

[studio_stamp.png](../data/art/branding/studio_stamp.png) is the original 301×855 RGBA image copied byte-for-byte. Its SHA-256 is `a7e295efc6232750e58fc230372987b7382da3c102ac445dbf8d7e91cd3a2d53`. Its lettering, silhouette and grain were not regenerated or repainted. The image was supplied by the user; no AI image generation was used.

The [stamp shader](../data/art/branding/studio_stamp.gdshader) suppresses the photographed paper at draw time using red-ink chroma. The heartbeat interpolates dark plum ink toward luminous warm copper, with a subtle vertical light gradient and a uniform scale increase of at most 5.5%. The pivot is the bottom center, so the base of the stamp stays planted. The original PNG retains all its pixels. A separate [spotlight shader](../data/art/branding/studio_spotlight.gdshader) supplies the soft amber pool and warm plum edges; both shaders use the same heartbeat phase. No new logo image or AI-generated replacement was used.

[studio_boot.png](../data/art/branding/studio_boot.png) is a 720×1280 native Godot GPU render of the same stamp and shader at rest. It supplies the static image shown before the runtime loader can animate. The [current native rendering script](../../verification/warm-studio-20261103/render_boot.gd), [accepted rest/peak render](../../verification/warm-studio-20261103/boot-04/render.log) and [current asset record](../../verification/warm-studio-20261103/assets.json) distinguish this derivative from the unchanged original. The [original studio provenance](../../concept-art/studio-startup-v1/sources.json) remains historical evidence for the first dark-background revision.

## Engine boot configuration

The production [project settings](../project.godot) use Godot 4.6.3's direct PNG path and current stretch property:

```ini
[application]
run/main_scene="res://startup.tscn"
boot_splash/image="res://data/art/branding/studio_boot.png"
boot_splash/show_image=true
boot_splash/stretch_mode=1
boot_splash/use_filter=true
boot_splash/bg_color=Color(0.145,0.121,0.145,1)
boot_splash/minimum_display_time=0
```

`stretch_mode=1` preserves the image aspect ratio. The static engine phase adds no deliberate delay. A direct resource path avoids an early UID-cache lookup; an absent/invalid custom image can fall back to Godot's splash, so packaging must verify this PNG. `show_image=false` would show only the configured background. `fullsize` is the older setting and is not used here. The four settings `show_image=true`, `stretch_mode=1`, `use_filter=true` and `minimum_display_time=0` are also the pinned engine defaults, so an exported binary configuration may omit them; package inspection must record that distinction. [Godot 4.6 ProjectSettings](https://docs.godotengine.org/en/4.6/classes/class_projectsettings.html), [exact 4.6.3 boot implementation](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/main/main.cpp).

## Startup and handoff

[startup.tscn](../startup.tscn) and [startup.gd](../scripts/startup.gd) implement the visible loading stage. The current roster warms 102 real resources, including the main scene and the three areas' shared/themed presentation assets, with at most three outstanding top-level requests. Completed resources remain referenced until the initialized game takes over. There is no displayed percentage or simulated progress bar.

Normal motion uses a 0.9-second cycle: one strong beat, a smaller second thump, and a quiet interval. The stamp stays visible for at least 1.8 seconds of foreground startup time, covering two cycles. Loading can extend that duration. Once resources and main initialization are ready, the controller waits until the current beat has settled and one quiet frame has actually been presented before handing that frame to the cream transition. It does not cut from a bright/expanded stamp mid-beat.

The loader instantiates ordinary [main.tscn](../main.tscn); gameplay progression stays in [main.gd](../scripts/main.gd). The existing page controller captures the final studio frame, covers it with the native white cream artwork, and reveals the destination restoration already selected: Home, a paused interrupted run, or an unclaimed Result. Startup does not force a fresh Home page, reset an area, start a run, or claim a reward. Handoff happens once. The same [cream wave](../data/art/transitions/cream_wave.png) serves all three areas.

Saved Reduced Motion is read before the first heartbeat. It keeps the stamp static, skips the 1.8-second presentation minimum, and switches to the initialized destination without the wave when loading is ready. The early preference read follows the existing canonical/legacy discovery order, bounds file sizes, and does not migrate or write a profile. Main remains responsible for authoritative loading and any existing migration.

Failed loads show Retry and Close beneath a smaller stamp. Retry collects a failed threaded request before issuing a new one and retains healthy queued, pending and completed work. Main remains held while error controls receive GUI input. Failed-resource cleanup follows engine token ownership: requesting the same uncollected token reuses it rather than starting a new attempt. [Godot 4.6.3 ResourceLoader](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/core/io/resource_loader.cpp).

## Original warm hum

The [studio hum](../data/audio/studio_warm_hum.wav) is original deterministic additive synthesis, with no sampled or third-party game audio. Its [generator](../tools/generate_studio_hum.py) and [provenance](../data/audio/studio_warm_hum.provenance.json) record a 0.900-second, 44.1 kHz stereo 16-bit loop: two soft peaks at the visual beat times, followed by a quiet 0.25-second tail. Source peak is −6.02 dBFS, with no clipped samples; the startup player adds −7 dB gain. The actual captured runtime mix peaks at approximately −13.02 dBFS.

One startup-owned AudioStreamPlayer plays a private looping stream. Before its first sample, the read-only profile peek reads the actual saved `sound` key, alongside Reduced Motion, using the same canonical/legacy discovery order. Sound off prevents playback entirely; an unreadable/corrupt profile stays silent. Backgrounding pauses both the hum and the heartbeat; resume seeks the same player to the retained heartbeat phase rather than starting another voice. A loading error stops the hum. Retry can restart that stopped player without duplicating it.

Every normal cycle has a silent interval on both sides of phase zero, matching the settled-frame handoff. Normal handoff stops in that quiet interval. If Reduced Motion becomes ready during a note, it changes page immediately while the startup-owned player releases for at most 80 ms, then stops and is freed; the sound never imposes a loading delay. A background event also silences this short release. This is startup sound only, not new gameplay music or a per-area soundtrack.

## Save and lifecycle contract

Main is instantiated beneath the studio layer with `startup_blocked=true`. This holds touch, Back, direct Start, processing, physics, onboarding reveal and checkpoint clocks. `profile_initialization_complete=false` prevents a focus/background/close notification during synchronous restoration from saving fresh default values over an existing profile. Once restoration is complete, normal lifecycle saving preserves the initialized state.

Background/focus loss suspends startup. Resume discards its first delta so time spent away cannot jump the heartbeat forward. No handoff occurs while suspended. The cream controller then supplies its established input/time freeze and final settling frame. Backgrounding during the wipe settles presentation and retains normal paused-save behavior. A hot return to an existing game does not reconstruct the startup scene.

These are transient presentation fields. No profile version, run schema, balance number, area fee, upgrade ownership rule, package identity or save-directory identity changes for this feature. The original save remains protected when profile loading is blocked or corrupt.

## Android launch screen distinction

Android 12 and later show a separate operating-system launch window on cold and warm starts; a hot start does not show it. That system phase precedes the Godot-rendered boot frame and runtime heartbeat. Godot's boot settings do not remove the Android window. [Android splash-screen behavior](https://developer.android.com/develop/ui/views/launch/splash-screen).

The installed 4.6.3 template calls `SplashScreen.installSplashScreen`, and its launch Activity uses `GodotAppSplashTheme`. The existing APK's theme references Sugarfall's `@mipmap/icon_foreground`, with the API-31 background referencing `@mipmap/icon_background`. Those are game launcher resources, not the default Godot engine logo. The current non-Gradle build keeps them. Independently changing that system icon would use `[splash]` theme attributes in `gradle_build/custom_theme_attributes` and requires a Gradle build; that is outside this studio-animation change. [Godot 4.6.3 Android exporter](https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/platform/android/export/export_plugin.cpp).

## Adding another area

Review `startup.gd::warmup_paths()` whenever adding area assets or changing their registries. Its current roster covers the main scene, shared UI/host/transition/result assets, Bakery and Gelato food/environment registries, Crystal atlas-region textures, map-art metadata and shared peg resources. Add the new area's required resources to this real readiness path; a preview image alone does not warm the gameplay assets.

Include startup scene/script, both branding shaders, the native studio texture, static engine frame and original hum WAV in the export. Verify the packaged boot configuration and imported resources as part of I09/Q08. The existing 83-item area checklist already covers shared art, navigation, exports and verification; no additional area requirement was created for startup.

## Verification and remaining acceptance

The [original studio software validation](../../verification/studio-startup-20261103/validation.json) passed **1,371 checks** with zero failures: 735 existing regressions, 90 shared page-transition checks, 58 startup-controller checks, 250 actual disk integration checks, and 238 GPU checks. [Six native-asset checks](../../verification/studio-startup-20261103/asset-validation.json) are recorded separately rather than counted again in 1,371.

The accepted independent [profile integration run](../../verification/studio-startup-20261103/profile-qa-04/integration-manifest.json) passed **250 checks across 13 cases** with the actual GL Compatibility renderer. It uses the real startup scene, threaded loading, production main initialization and JSON files in a freshly probed disposable user directory. Its 207 recorded runtime, asset and harness inputs match the tested source. It covers fresh onboarding, Home/paused/Result saves for every area, saved Reduced Motion, corrupt-save preservation, exact run snapshots, interruptions before and after restoration, blocked actions behind the stamp, controlled handoff, and one-time reward claims. [Detailed results](../../verification/studio-startup-20261103/profile-qa-04/profile-results.json), [test implementation](../tests/startup_profile_qa.gd), [isolated runner](../../verification/studio-startup-20261103/run-profile-qa.ps1).

After the responsive viewport and Home/result changes, the [v0.7.4 startup-controller rerun](../../verification/screen-polish-20261103/startup-unit-01/summary.json) again passes 58 checks and the [actual-profile rerun](../../verification/screen-polish-20261103/startup-profile-01/integration-manifest.json) again passes 250 checks across 13 isolated profiles. The latter records 207 matching runtime/art/harness inputs for that revision. These reruns belong to the [1,877-check screen-polish validation](../../verification/screen-polish-20261103/validation.json); the earlier 1,371-check startup total above remains the original dated evidence.

The accepted [controller log](../../verification/studio-startup-20261103/unit-04/startup.log) includes actual GUI Retry input. The [final renderer record](../../verification/studio-startup-20261103/visual-approved/screens/preview-summary.json) contains **48 captures** at 450×800 and 720×1280: static-engine/rest-frame match, pulse peaks/rest/repeated cycles, Reduced Motion, error controls, all-area cream cover/reveal and retained paused/result destinations. Resting, peak and error layouts were also visually reviewed at 450×800. Final source parity covers the 43 shared runtime inputs and the startup files. These captures do not establish physical-phone behavior.

Superseded attempts remain evidence history. Profile attempts 01–03 respectively encountered a test-name collision, the headless renderer's inability to supply viewport snapshots despite passing 250 state assertions, and a runner argument error. The clean actual-renderer profile run above supersedes them. Final controller and visual paths are explicitly linked here.

The original studio delivery was the [v0.7.3 APK](ANDROID_SUGARFALL_v0.7.3.json), code 28, through the existing private Drive link. It passed 498 payload checks and 16 Android metadata checks; [upload readback](../../verification/android-upload-v073/verification.json) passed eight checks after replacement in place. The artifact is 88,957,646 bytes with SHA-256 `4381dd75f0ae7a44ff13fa05da7f4a91841217fc03ae2b5cc1130fa6bd9a1544`. The current [v0.7.4 APK](ANDROID_SUGARFALL_v0.7.4.json), code 29, is delivered through that same link; its layout/flow changes preserve the studio art and loading behavior, with the reruns above. Physical acceptance remains open under [AREA_PLAYTEST.md D14](AREA_PLAYTEST.md): cold/warm/hot launch, the system-icon handoff, smooth pulse/cream animation, saved Reduced Motion, background/resume, cropping and correct retained run/result state. Repeat startup with paused runs and unclaimed results in all three areas, then confirm wallet, upgrades, timer and reward are intact. Desktop notification injection does not establish phone lifecycle or launch performance. D13 continues to cover ordinary menu transitions; AF-008 human pacing and AF-009 phone acceptance remain Ready to test.
