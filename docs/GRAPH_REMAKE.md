# Graph editor — Build 23

Inspected the existing EaseCurve / Animated / FlowGraph / CurveEditor implementations, timing and reversal tests,
shared remap easing popup, property/effect targets, saved curves and MotionTools loop expressions before editing.

## Research and reference inspection

- Alight Motion: https://support.alightmotion.com/hc/en-us/articles/10536934703889-Animation-Easing-Curves
  Cyclic easing repeats progression between the surrounding values, either one way or back and forth. Bounce and
  elastic are separate mathematical families, not Bezier curves with a point at every joint.
- Adobe: https://helpx.adobe.com/after-effects/desktop/work-with-expressions/expression-language-reference/expression-language-reference.html
  AE cycle/pingpong loop expressions continue a keyed sequence after its boundary. That existing MotionTools behavior
  remains separate from this task's segment-level cyclic easing.
- Supplied AE Motion 2.5.ipa: static ZIP inspection of en.lproj/Localizable.strings found Cyclic, Repeat, Oscillate,
  Sawtooth, Bounce, Elastic and related labels, plus EditEasingPanelVC compiled nib resources. The IPA does not contain
  readable graph implementation source. No claims about its exact handle equations are inferred from labels alone.

## Behavior

Easing exposes editable Bezier ease-in/out, Linear and Hold. Motion exposes parameterized Bounce, Elastic and
Overshoot variants. Loops exposes Repeat (instant return) and Back & Forth (continuous return). Two graph handles
control count and shape; the same values can be scrubbed or typed. No handles at every bounce joint.

Cycles counts forward passes: Repeat N has N ramps; Back & Forth N has N forward passes and N-1 return passes.
Both start at the first key and land exactly on the second key. Smoothness 0 is linear/sharp, 1 is cosine-rounded.
The loop only occupies its selected segment. It does not silently install a layer expression or retime footage.

Legacy math curves and saved curves remain decodable and keep their output. Redundant fixed power-family tiles
are omitted from the new catalog; saved versions remain accessible. Copy/Paste/Save are direct buttons.
Signed speed plots show reverse movement instead of taking absolute velocity.

Time Remap retains its existing source-time system and shared easing popup; loop catalog entries are unavailable
there. No Motion Sketch, AI Link settings, or user projects are modified/deleted.

## Verification

GraphRemakeTests checks repeat resets, continuous return, smooth turn velocity, frequency, handle translation,
serialization, preview/runtime agreement and reversal. GraphRemakeUITests drags the semantic handles and captures
screenshots. Run focused timing diagnostics first, then full validation=all before publishing an IPA.
