# Application assets

## Issue #7 preserved preview assets

`images/home/` contains original PNG layer exports from the user's
[Yorisoi Figma design](https://www.figma.com/design/uiTEgE5aP1YTZCTijhhoEn/Yorisoi---App-UI),
retrieved on 2026-10-20 at 2× with Figma's **Copy as PNG** action.
These are original design layer exports, not screenshots used as entire screens,
substitute artwork, or AI-generated replacements. No new license for the Figma
artwork is inferred from the repository's license.

| File | Original Figma node | Logical layer size |
| --- | --- | --- |
| bg_home.png | 2:94 — 03 Background (`bg_home`) | 390 × 844 |
| yorisoi_logo.png | 2:96 — 03 Logo | 89.8 × 38 |
| settings_button.png | 2:101 — 03 Settings button | 46 × 46 plus exported shadow |
| pet_group.png | 2:112 — 03 Pets / Group | 230 × 135 |
| mic_button.png | 2:118 — 03 Mic button | 54 × 54 plus clipped left shadow |
| share_heart.png | 2:126 — 03 Primary button icon | 18 × 18 |
| bg_analysis_loading.png | 2:129 — 03-A Background | 390 × 844 |
| loading_glow.png | 2:144 — 03-A Glow | 300 × 200 |
| loading_pet_group.png | 2:145 — 03-A Pets / Group | 300 × 176 |
| loading_paw_trail.png | 2:146 — 03-A Paw trail | 130 × 22 |

PNG exports can include shadow outsets and integer pixel rounding. Source layer
sizes and exported file sizes are distinguished in the Flutter preview code.
Visual comparison is **unfinished**; export work and visual refinement were paused
at the user's request. See [Issue #7 specification](../docs/home_emotion_screen_spec.md).

## Issue #12 temporary Story List pet layers

`images/pets/` contains unmodified original layer exports retrieved from the same
Figma file on 2026-11-08 via the Figma asset export tool (node export settings).
These are character layers only, not screenshots of playback screens.

| File | Original node | Logical size |
| --- | --- | --- |
| cat.png | 2:268 — Pet / Cat | 221 × 290 |
| rabbit.png | 2:299 — Pet / Rabbit | 172 × 300 |
| dog.png | 2:330 — Pet / Dog | 247 × 285 |
| dolphin.png | 2:361 — Pet / Dolphin | 174 × 300 |

The **new temporary** Story List card arrangement is not an approved Figma frame.
Character proportions are preserved with `BoxFit.contain`. No artwork redesign,
AI substitute, or additional redistribution license is inferred.

## Restored authentication assets

`images/auth/` uses original assets from Figma Login `2:54` and Sign Up `2:2`,
retrieved on 2026-11-08. Background source files are JPEG despite their temporary
download URLs ending in `.png`; the local `.jpg` extension reflects the original
bytes. No background or character image has been redrawn or altered.

| Asset | Original Figma source |
| --- | --- |
| bg_signup.jpg | 2:3 — Sign Up background image fill |
| bg_login.jpg | 2:55 — Login background image fill |
| pets_group.png | Shared original image fill, 2:13 / 2:66 |
| heart_signup.svg | 2:8 — original 20 × 20 heart |
| heart_login.svg | 2:60 — original 23 × 23 heart |
| icon_user.svg | 2:24 — nickname icon, 18 × 18 |
| icon_email.svg | 2:31 / 2:76 — email icon, 18 × 18 |
| icon_lock.svg | 2:38 / 2:83 — password icon, 18 × 18 |

Branding text uses the bundled fonts with Figma sizes/weights/letter spacing,
plus original SVG hearts. Full logo frame PNG exports included an opaque paper
rectangle and are deliberately not used as implementation assets. Temporary
exports were preserved outside the repository in `/tmp/yorisoi_auth_unused_exports`.
No temporary Figma URL is used at runtime. No additional artwork license is
inferred from the repository license.

## Fonts

Bundled, unmodified fonts from the official [Google Fonts repository](https://github.com/google/fonts):

- `fonts/zen_maru_gothic/`: [Zen Maru Gothic](https://github.com/google/fonts/tree/main/ofl/zenmarugothic),
  Regular 400, Medium 500, Bold 700, Black 900.
- `fonts/yomogi/`: [Yomogi](https://github.com/google/fonts/tree/main/ofl/yomogi), Regular 400.

Each directory includes its original `OFL.txt` (SIL Open Font License 1.1).
Font paths/weights and image paths are registered in root `pubspec.yaml`.
No private Firebase configuration or Issue #4 audio fixture is bundled here.
