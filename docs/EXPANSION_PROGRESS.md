# Expansion progress

The current working branch retains the accepted Build 30 editor and the Build 22
shape-contents rebuild. AI training is paused; no training process or model export
is part of this work.

## Batch 30 — first backgrounds set (Build 31 candidate)

Twelve original generators: Solid Sunburst, Spiral Bands, Chevron Stripes, Woven
Pattern, Arc Tiles, Contour Map, Scallop Pattern, Diamond Lattice, Dot Waves, Cross
Grid, Ribbon Gradient, Horizon Gradient. These are the first set of the backgrounds
batch, not a claim that the full expansion or suggested 60–120 effects is complete.

All expose keyframeable numeric controls, center and rotation, two colors, signed
animation speed, Blend and Effect Only. Zero speed holds a pattern. The kernel is
one bounded compute pass; the largest neighborhood is three scallop rows. No
large-radius blur loops, bitmap overlays or new panels. Missing saved parameters
fall back to the definition defaults.

The existing browser keeps live tiles and one-tap selection; the New row features
the new backgrounds. Shapes, Liquid and Procedural sections receive explicit
placements. Keyers, blurs and glitches no longer get misfiled because their summary
happens to contain another section's keyword. Existing IDs and project data stay
unchanged. Time is reserved for later time effects and hidden while empty.

The supplied AE Motion starburst parameter metadata was inspected for center,
rotation, progress and pattern controls. Our solid-wedge shader is written from
scratch; it is distinct from the existing light-ray Sunburst.

## Acceptance before delivery

Run `build.yml` with `validation=all`. Inspect `background-renders` (12-effect
contact sheet, five animated previews and extracted frames), existing shape logo
renders, and `ui-screenshots` (browser and effect card). Check numeric wiring,
saved-parameter fallbacks, transparent colors, Blend bypass and zero-speed hold.
Retune weak defaults from the renders before calling the set ready. Device preview
frame rate has not been measured by these simulator checks.

Next: complete/judge batch 30, then batch 31's distinct glitches with motion styles.
Presets follow the effect batches; final device profiling follows presets.
