# Rig authoring progress — Build 29

Branch: `feat/rig-authoring-overhaul`. Build 28 (`89fd5c9`) passed full validation: 679 passed, 0 failed, 1 skipped. The owner tested that build and reported workflow and deformation issues; a green suite did not establish phone usability.

Build 29 keeps both separate-piece Rig and continuous-artwork Bone / Weight. It adds Whole artwork binding alongside Near bones, resolves piece-based controllers to their artwork, provides optional vertex weights for connected pieces, and excludes a rig from colliding with its own artwork and controls. New rigs use explicit external-solid collision opt-in. Existing saved weights and old MLS projects remain unchanged until an explicit binding update.

Pose origins translate their branch; tips rotate. The shared precision pad uses the displayed parent projection, including mirrored/rotated parents and Auto Orient, rather than reconstructing a different frame. It does not change normal Position or invert all touch input. Own-artwork attachment opens weighting instead of creating a parenting cycle. Long-chain bend direction now handles an already bent setup.

Focused validation at `25ef7fa`: run `42650548902`, 113 passed, 0 failed, 0 skipped. Reviewed the piece-controller binding UI, Pose origin UI, weight-brush panel and a contact sheet from the 60-frame textured wide-arm render. No stationary strips or disconnected mesh edges appeared in that fixture. Latest source `47fb213` also tests controller pad direction through rotation, mirroring and Auto Orient; full run `42653473792` is pending.

Release gate: latest full CI green, final artifact and screenshot review, and verification that the IPA identifies Build 29. No Build 29 IPA has been released yet. Phone performance remains unmeasured. Automatic weights remain distance-based on a regular grid; contour-aware topology, preserve-volume bending and IK soft reach/stretch remain unfinished. Deformation amount is not stretch or touch sensitivity.

See [RIG_PHONE_FEEDBACK.md](RIG_PHONE_FEEDBACK.md) for the user workflows, confirmed findings, limitations and Blender/Spine primary sources. Motion Sketch, AI Link settings and user projects were not changed.
