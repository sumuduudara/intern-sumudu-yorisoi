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

## Fonts

Bundled, unmodified fonts from the official [Google Fonts repository](https://github.com/google/fonts):

- `fonts/zen_maru_gothic/`: [Zen Maru Gothic](https://github.com/google/fonts/tree/main/ofl/zenmarugothic),
  Regular 400, Medium 500, Bold 700, Black 900.
- `fonts/yomogi/`: [Yomogi](https://github.com/google/fonts/tree/main/ofl/yomogi), Regular 400.

Each directory includes its original `OFL.txt` (SIL Open Font License 1.1).
Font paths/weights and image paths are registered in root `pubspec.yaml`.
No private Firebase configuration or Issue #4 audio fixture is bundled here.
