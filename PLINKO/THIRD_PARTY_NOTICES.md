# Third-party notices

Sugarfall includes authored game code, generated theme artwork, a user-supplied studio stamp, original synthesized sound effects, and the fonts listed below. Asset provenance is retained beside the art and in the workspace concept-art records. Historical source paths identify creation inputs; runtime assets are included in the repository. The studio heartbeat hum is synthesized by tools/generate_studio_hum.py; it contains no sampled commercial game audio.

Exports contain the Godot Engine, distributed under the MIT license, and its bundled third-party components. Full engine license and bundled-component copyright notices are included in [data/licenses/GODOT_LICENSE.txt](data/licenses/GODOT_LICENSE.txt) and [data/licenses/GODOT_COPYRIGHT.txt](data/licenses/GODOT_COPYRIGHT.txt). Retain applicable notices when redistributing exports.

The original Fraunces and Nunito font files are distributed under the SIL Open Font License 1.1. Their notices are [Fraunces-OFL.txt](data/fonts/Fraunces-OFL.txt) and [Nunito-OFL.txt](data/fonts/Nunito-OFL.txt); exact font sources and hashes are in [the font record](data/fonts/README.txt). Keep those notices with redistributed fonts.

Export-toolchain-only dependencies are documented in docs/EXPORT_NOTES.md. Android Preview uses an expendable development key. Public release candidates use a separate private release identity; no private signing key, service credential or personal player save belongs in source delivery. This notice does not grant a new license to the game's original code or artwork.

## Poing AdMob

The Android ad integration vendors Poing Studios Godot AdMob plugin 5.1.0 and its Android native ads/core libraries under the MIT license. The complete notice is retained in [addons/admob/LICENSE](addons/admob/LICENSE). Sugarfall pins the Google GMA Next-Gen dependency to 1.6.0 and disables automatic native-library downloads during export. Google Mobile Ads and UMP are separate Google SDK dependencies under their published SDK terms; this notice does not relicense them. Integration provenance and verification are recorded in [docs/monetization/ADMOB_PROVIDER.md](docs/monetization/ADMOB_PROVIDER.md).

## Godot Google Play Billing

The Android purchase integration vendors GodotGooglePlayBilling 3.3.0, copyright Godot Engine contributors, under the MIT license. Its full notice is retained in [addons/GodotGooglePlayBilling/LICENSE](addons/GodotGooglePlayBilling/LICENSE) and the exported [data/licenses/GodotGooglePlayBilling-MIT.txt](data/licenses/GodotGooglePlayBilling-MIT.txt). The plugin uses Google Play Billing 9.1.0 under Google's published SDK terms. [Source and dependency provenance](docs/NATIVE_BILLING_PLUGIN.json).
