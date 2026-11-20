# Official Story List design references

Source: [Yorisoi - App UI](https://www.figma.com/design/uiTEgE5aP1YTZCTijhhoEn/Yorisoi---App-UI).
Retrieved 2026-11-10. These 390×844 original frame exports are visual references,
not Flutter backgrounds or published story data.

| Reference | Frame |
| --- | --- |
| cat_reference.png | 109:25 — Cat (Sad / Lonely) |
| rabbit_reference.png | 109:125 — Rabbit (Anxious / Stressed) |
| dog_reference.png | 109:225 — Dog (Angry / Happy) |
| dolphin_reference.png | 109:325 — Dolphin (Calm / Other) |
| empty_reference.png | 109:425 — Empty State |

Cat reference was found in the existing `Yorisoi - App UI.zip` download; the
remaining references were obtained using the direct web Export button. The
Story Card component 109:2 was also inspected: width 354, minimum height 133,
padding 14, vertical gap 10, radius 24. See `assets/README.md` for layer provenance.

## Comparison and intentional data differences

All five Flutter variants were rendered locally at 390×844 using bundled fonts
and test-only repository records. Back begins at (18,54); bubble is
(168,128,206,98); first card is (18,364,354,133); Empty card is
(18,350,354,268). This is widget-render evidence, not a live Chrome/Firebase test.

The app has no English story-title field, so English Figma sample titles are
omitted rather than fabricated. Real title, description, duration and count are
bound to repository records. Long text and larger fonts expand/scroll instead of
being clipped. Actual emotion details and the non-diagnostic notice remain below
the reference composition. Cat sad copy refers to sadness rather than loneliness.
For non-Cat empty results, the actual assigned pet remains visible with the common
Empty State layout; the provided Empty reference itself only depicts Cat.

Flutter/font rasterization and wrapping can differ slightly from Figma. Pixel-
perfect equivalence, live published-story selection, playback and native-device
validation are not claimed. No production stories were created or published.
