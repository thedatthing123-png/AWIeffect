# AWIeffect working rules

- Inspect the existing model, renderer, UI interactions and related tools before changing a feature.
- Improve the function of existing controls before adding buttons, tabs or duplicate workflows. Tap targets, numeric entry, gestures and selection must work together on a phone.
- Preserve Text Studio and other established advanced systems; do not replace them with simpler effect wrappers.
- Groups show one container row in the outer timeline. Open a group to edit its children. Ungroup removes container-only effects/masks and retains each child's own effects; Undo restores the group.
- XY/Z movement uses the existing position fields: field background selects the mode, while tapping the number also opens numeric entry. Do not add a separate XY/Z toggle row.
- Validate changes against related editing workflows, saved projects and rendering, not just isolated compilation.
