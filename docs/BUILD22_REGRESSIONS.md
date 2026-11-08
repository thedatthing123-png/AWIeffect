# Build 22 regression correction

The accepted pre-change baseline is Build 21 (98b86df). The user clarified that restoring the old layout meant the
transport/playback bar, not replacing the newer timeline header. Build 22 incorrectly reduced the header to 60pt,
removed its Lock/Solo controls, hid simple automatic cutout behind box drawing, and eagerly built all lane metadata
for normal timeline rows. Green tests did not establish usability.

This correction restores the 132pt eye/lock/solo header and keeps Build 21 timeline interactions. The restored
transport and shape rebuild are retained. Short-clip expand arrows stay within the visible clip. Normal marker
lookups no longer build expanded lane metadata or every effect's markers. Edge edits no longer reload media and
rescan bake files; ordinary playback does not launch a second refinement frame decoder per tick.

Remove BG opens without changing the layer. Auto Remove Background invokes the existing live AI matte path with
one tap. People/Object/Anime are direct mode choices. Keep/Cut/Auto Box are optional refinement tools; no brush is
armed on entry. Restore Original disables the cutout without deleting stored mattes, and Undo restores it.

The unreleased graph work is saved separately on feat/effects-remake (checkpoint 086b9fc); this stability branch
starts from delivered Build 22 and does not include the graph remake. No user projects or AI Link settings are changed.

Check short clips, expanded rows, header range selection, layer scrolling/reordering, auto cutout and remap editing
in focused stability CI, then full validation=all. Inspect screenshots and actual interaction outcomes. A simulator
pass is not evidence of 60fps on the user's phone or of perfect subject segmentation on every image.
