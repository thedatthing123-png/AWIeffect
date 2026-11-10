# Rig authoring progress — Build 29

Branch: `feat/rig-authoring-overhaul`. Build 28 (`89fd5c9`) passed full validation: 679 passed, 0 failed, 1 skipped. The owner tested that build and reported workflow and deformation issues; a green suite did not establish phone usability.

Build 29 keeps both separate-piece Rig and continuous-artwork Bone / Weight. It adds Whole artwork binding alongside Near bones, resolves piece-based controllers to their artwork, provides optional vertex weights for connected pieces, and excludes a rig from colliding with its own artwork and controls. New rigs use explicit external-solid collision opt-in. Existing saved weights and old MLS projects remain unchanged until an explicit binding update.

Pose origins translate their branch; tips rotate. The shared precision pad uses the displayed parent projection, including mirrored/rotated parents and Auto Orient, rather than reconstructing a different frame. It does not change normal Position or invert all touch input. Own-artwork attachment opens weighting instead of creating a parenting cycle. Long-chain bend direction now handles an already bent setup.

Focused validation at `25ef7fa`: run `42650548902`, 113 passed, 0 failed, 0 skipped. Reviewed the piece-controller binding UI, Pose origin UI, weight-brush panel and a contact sheet from the 60-frame textured wide-arm render. No stationary strips or disconnected mesh edges appeared in that fixture. Controller pad direction through rotation, mirroring and Auto Orient is covered. See the final validation below; intermediate failed runs and fixes are recorded in RIG_PHONE_FEEDBACK.md.

Final validation: source `87920d20b07ff14876b626aeb5ea8f93189b1d35`, full run `42739361809`, 694 passed, 0 failed, 1 skipped; archive and IPA packaging succeeded. Reviewed graph Repeat/Back & Forth/Bounce interaction screenshots and Bend mode motion contact sheets, plus rig/weight panels. Verified the IPA bundle version is 29 and its icon/resources/Metal library are present. IPA SHA-256: `f0502453276d0b73883b8dd25d928141dacf531726d9ba042aa9bf339a68368c`. Phone performance remains unmeasured. Automatic weights remain distance-based on a regular grid; contour-aware topology, preserve-volume bending and IK soft reach/stretch remain unfinished. Deformation amount is not stretch or touch sensitivity.

See [RIG_PHONE_FEEDBACK.md](RIG_PHONE_FEEDBACK.md) for the user workflows, confirmed findings, limitations and Blender/Spine primary sources. Motion Sketch, AI Link settings and user projects were not changed.

Build 29 also includes the expanded phone feedback batch: explicit brush coverage, AI mask orientation, 0–10 stabilizer labeling, normal Rig/Puppet pad gain, a distinct Bone / Weight creation workflow, no gallery item cap, editable bounded 2D mask containers, Bend sides/tuning and up to 1,000 loop cycles. Graph loop dragging uses logarithmic travel so low counts remain usable. Music/beat detection is the next phase.
