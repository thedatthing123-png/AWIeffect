# AWIeffect change rules

The owner's standing rule: **know the existing app before changing it.**

Before adding or remaking any feature:

1. Inspect the existing model, UI entry point, implementation and relevant tests. Check other studios/tools, not only the effects registry.
2. Record what already exists, the precise missing capability or defect, the owning subsystem and the integration dependencies.
3. If the capability already exists, use or improve that system. Do not add a weaker duplicate, wrapper, renamed preset or parallel implementation to inflate the effect count.
4. Text Studio owns text animation, transforms, progress, selectors, per-letter styling, counters, path layout and future 3D-text expansion. Standalone text effects must add a genuinely missing visual operation, not repeat those controls.
5. Art Studio owns painting/selection; shape tools own editable geometry; Physics Studio owns simulations; scene tools own cameras/lights/models. Evaluate overlap with each before adding catalog effects.
6. Treat delivered build 7 as the restart baseline. Do not remake its newly implemented effects without a specific demonstrated defect. Preserve older saved-project behavior in any real remake.
7. Compare reference behavior and controls against primary documentation or supplied examples. Similar names do not prove identical implementations. Distinguish artistic approximations, data outputs and physical simulations.
8. Reuse shared render, animation, keyframe, undo, save/export and cache systems. Validate interactions, not just isolated output.
9. Batch testing is welcome: shared effect/control regressions plus grouped semantic assertions. No placeholders or unused controls. Inspect rendered output before packaging.
10. Report catalog entries separately from new capabilities, remakes, presets and tool enhancements. Do not claim the 600-effect goal or full-device validation from a partial batch.

The abandoned `feat/effects-large-batch` branch is preserved for reference, not an approved source for merging. Re-audit any reusable work against these rules first.
