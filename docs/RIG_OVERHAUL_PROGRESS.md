# Rig authoring overhaul - active work

Base: Build 27 `3fa4695`, branch `feat/rig-authoring-overhaul`. Owner authorized separate-piece Rig and continuous-artwork Bone / Weight, sharing transforms and animation.

Implemented, not released: selection/branching from earlier bones; hierarchy, reparent/cycle rejection, deletion preserving children; rest-joint editing and inverse-bind refresh preserving painted weights; fixed-origin X/Y pad for joints and Puppet; steady gain; live geometry reads; cached frame-wide geometry; localized normalized vertex weights and Metal triangle deformation. Saved Build 27 MLS skins remain unchanged until explicit upgrade. Weight painting is a preview transaction: cancel writes nothing, commit is undoable. Viewport gestures cancel painting. Meshes evaluate shutter/echo poses; copied artwork carries/remaps owned bones and targets. Long uniform chains use FABRIK; reflected/nonuniform chains retain CCD. IK/FK blends local rotation tracks.

Validation: first focused run `42570978631` compiled and reported 91 tests, with one UI failure: the setup precision pad did not move its endpoint. Adjusted panel ordering and retained the movement assertion. Follow-up `42572050808` is running. Newest edits have not yet run in macOS CI. Windows Swift syntax parsing passes; this is not UIKit/Metal runtime validation.

Before delivery: resolve all focused failures; inspect continuous-image motion frames and weight-paint UI screenshots; complete render/reference regressions and full validation. No IPA has been released for the overhaul. Phone performance remains unmeasured. Stretch/soft reach controls are not implemented yet; do not call deformation amount a stretch or touch-sensitivity setting.

Sources: Spine meshes/weights/IK documentation, Adobe Puppet documentation, Blender IK manual, Duik rigging documentation, and Aristidou & Lasenby's original FABRIK paper. The implementation uses standard skeletal/weight math, not extracted proprietary app code.
