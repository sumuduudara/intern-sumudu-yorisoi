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

## Authentication assets (2026-10-29)

`images/auth/` contains unmodified source PNG/SVG assets returned by the
original Figma file's design context through the authorized internship account.
They are individual layers, **not full-screen screenshots or replacement art**.
The original fonts above are reused. No additional redistribution license is inferred.

| Local file | Figma layer / usage |
| --- | --- |
| bg_registration.png | 2:3 — Sign Up Background |
| bg_auth.png | 2:55 / 23:3 / 23:50 / 23:104 / 23:170 — authentication Background |
| pets_group.png | 2:13 / 2:66 / 23:177 — original Cat, Dog, Rabbit, Dolphin group |
| rabbit.png | 23:28 — Forgot Password rabbit |
| dog.png | 23:75 — Check Your Email dog |
| cat.png | 23:129 — Set New Password cat |
| heart_registration.svg | 2:8 — Sign Up wordmark heart |
| heart_login.svg | 2:60 — Login wordmark heart |
| nickname.svg | 2:24 — optional nickname field icon |
| email.svg | 2:31 / 2:76 / 23:40 — email icon |
| lock.svg | 2:38 / 2:45 / 2:83 / 23:138 / 23:145 — password icon |
| back.svg | 23:6 / 23:53 / 23:107 — back arrow |
| paw_active.svg | 23:9 / 23:56 / 23:110 — active progress paw |
| paw_idle.svg | 23:15 / 23:68 — inactive progress paw |
| envelope.svg | 23:76 — envelope |
| paw_tip.svg | 23:88 — spam-folder tip paw |
| check_small.svg | 23:152 — password rule check |
| glow.svg | 23:172 — success glow |
| sparkle_left.svg | 23:173 — success sparkle |
| sparkle_right.svg | 23:175 — success sparkle |
| check_success.svg | 23:180 — password updated check |

Images are bundled locally through `pubspec.yaml`; temporary Figma asset URLs
are not used at runtime. Original SVG geometry is preserved. Backgrounds use
cover cropping as specified by Figma. See `docs/auth_ui_integration.md` for
functional differences and actual verification evidence.
