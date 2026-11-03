FOOD UI TYPE SYSTEM
Selected 2026-10-23 from the official Google Fonts repository.

Art fit
The rounded, soft serif of Fraunces echoes the plump food shapes, hand-finished
ceramic and vintage bakery materials. Nunito's rounded terminals continue that
warmth while keeping counters, prices, timers and compact labels easy to read.
Keep wording short and in title case. Let artwork carry the decoration.

Ready-to-use Godot resources
res://data/fonts/Fraunces-Display.tres
  Short titles and primary action labels. Weight 650, SOFT 70, opsz 36, WONK 1.
  Titles 36-48 px, primary actions 26-30 px at the 720 x 1280 design resolution.
  Do not use this display face for dense instructions or changing numeric values.

res://data/fonts/Nunito-Semibold.tres
  Short labels, secondary actions and supporting copy. Weight 600.
  Functional labels 18-22 px; do not shrink important instructions below 18 px.

res://data/fonts/Nunito-Bold.tres
  HUD numbers, multipliers, prices and important compact values. Weight 750.
  HUD figures 32-36 px; compact prices 22-26 px.
  Nunito has equal-width default decimal numerals; no extra tnum feature is needed.

These resources wrap original variable fonts, with explicit axis settings.
The .tres dictionaries use numeric OpenType tags: wght = 2003265652,
SOFT = 1397704276, WONK = 1464815179, opsz = 1869640570. In the bundled
Godot 4.6.3 build, string tag keys produced empty TextServer coordinates and
silently rendered the raw defaults. Numeric keys were checked against actual
TextServer coordinates and rendered string widths, not just resource values.
Do not preload the raw TTFs as UI styles: their original default weights are
Fraunces 900 and Nunito 200, which do not match this game's chosen styling.
Use native size, normal transform and default spacing; do not stretch letters.
Avoid wide tracking, all-caps paragraphs, simulated bold and outlined body text.

Coverage and icons
Verified in Godot 4.6.3: both fonts contain ASCII, decimal digits, punctuation,
the multiplication symbol (U+00D7), and the accented Latin sample e-acute,
n-tilde and u-umlaut. Fraunces reports 624 supported characters; Nunito 937.
Nunito's default digits all measured 20 px wide at 34 px in the bundled font.
Fraunces digits are proportional; use Nunito for live counters.
Neither font contains the tested check mark, four arrows, star, gear, play,
pause or heart Unicode symbols. Use the game's dedicated icon artwork/drawing
for controls instead of relying on those Unicode glyphs. Do not depend on
these families for CJK, Arabic, emoji or other unverified writing systems;
add and test a compatible fallback when localization requires one.

Source files (downloaded without modifying font data)
Fraunces-Variable.ttf
  https://raw.githubusercontent.com/google/fonts/main/ofl/fraunces/Fraunces%5BSOFT,WONK,opsz,wght%5D.ttf
  Upstream: https://github.com/undercasetype/Fraunces
  SHA-256: 177ff6c0f14e5550a3c624247cd1189611d4eb65d000b14944c63d967958abbb
Nunito-Variable.ttf
  https://raw.githubusercontent.com/google/fonts/main/ofl/nunito/Nunito%5Bwght%5D.ttf
  Upstream: https://github.com/googlefonts/nunito
  SHA-256: bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207

Licenses
Both original fonts are distributed under the SIL Open Font License 1.1.
Keep Fraunces-OFL.txt and Nunito-OFL.txt with the font files in distributions.
No system installation was performed; these fonts are bundled with the project.
License sources:
  https://github.com/google/fonts/blob/main/ofl/fraunces/OFL.txt
  https://github.com/google/fonts/blob/main/ofl/nunito/OFL.txt

Official family descriptions and integration reference:
  https://github.com/google/fonts/blob/main/ofl/fraunces/article/ARTICLE.en_us.html
  https://github.com/google/fonts/blob/main/ofl/nunito/DESCRIPTION.en_us.html
  https://docs.godotengine.org/en/stable/classes/class_fontvariation.html
