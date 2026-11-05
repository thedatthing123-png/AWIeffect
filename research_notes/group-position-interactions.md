# Build 9: existing controls and group interaction

Scope: fix the reported XY/Z interaction and group timeline behavior before resuming the animation/timing rework.

- The X/Y/Z fields select the existing swipe pad's mode. Number taps still open numeric input. No extra XY/Z toggle row. Highlight the selected field(s).
- Show root rows only in the outer timeline. Existing Open Group opens the editable children on the transparent group canvas; closing returns to the parent.
- Header range selection and reordering use the same visible row list. Delete, duplicate and precompose include a selected group's hidden subtree.
- Ungroup removes the container and its masks/effects/blending treatments, per the owner's clarification. Child effects remain; existing transform baking and Undo remain available.
- New, duplicated and pasted containers receive varied saved timeline tags. Existing duplicate tags are repaired on opening (up to the six available tag colors), without changing artwork colors.
- Keep the larger animation/timing work isolated in the `feat/animation-timing` stash until this build is validated.

Added unit regressions cover containment, inside editing, ungroup/undo, range selection, subtree duplication/reordering/deletion, precomposing a group and color persistence. UI regressions exercise field activation/numeric entry and group open/close. Full simulator tests and an archive are required before delivery; phone validation remains necessary.
