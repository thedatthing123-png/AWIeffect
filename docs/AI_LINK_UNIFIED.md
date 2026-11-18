# AWIeffect Build 30 — Unified MCP Editor

## Architecture
- Base: Build 29 of feat/rig-authoring-overhaul. Preserve working renderer, UI and user files.
- MCP now advertises exactly one tool: **use_awieffect**. Operations: guide, discover, call, batch, status.
- The Cloudflare Worker retains its existing Durable Object and phone WebSocket bridge. Existing commands remain internally available via action=call. No private settings or keys are exposed.
- Native iPhone API additions: POST /editor/rig, POST /editor/layer/patch, GET /editor/capabilities.
- Inline skill index based on the supplied AWIeffect editor ZIP. Topics: core, rig, mask_cutout, animation, effects, manga, typography, audio and qa.
- The editing skill prohibits AI-created art, random geometry and automatic coloring in place of user-authored assets and native edits.

## Example tool calls

Read the guide and discover command schemas:
- {"action":"guide","topic":"rig"}
- {"action":"discover"}
- {"action":"call","command":"get_project","args":{}}
- {"action":"call","command":"get_catalog","args":{}}

Native bone workflow:
- {"action":"call","command":"rig.add_bone","args":{"artwork":"REAL_ARTWORK_UUID","start":[90,200],"end":[150,260]}}
- {"action":"call","command":"rig.add_bone","args":{"artwork":"REAL_ARTWORK_UUID","parent":"REAL_WRIST_UUID","start":[150,260],"end":[175,275]}}
- {"action":"call","command":"rig.bind_mesh","args":{"artwork":"REAL_ARTWORK_UUID","detail":48,"coverage":"whole"}}
- {"action":"call","command":"rig.paint_weights","args":{"artwork":"REAL_ARTWORK_UUID","bone":"REAL_ELBOW_UUID","brush":"paint","radius":38,"dabs":[{"center":[112,95],"amount":0.25}]}}
- {"action":"call","command":"rig.pose_bone","args":{"bone":"REAL_ELBOW_UUID","point":[500,350]}}
- {"action":"call","command":"render_frame","args":{"t":1.2}}

Group layers natively using {"action":"call","command":"group","args":{"command":"create","layers":["UUID1","UUID2"]}}; ungroup using {"action":"call","command":"group","args":{"command":"ungroup","group":"GROUP_UUID"}}.\n\nAdd effects using the exact IDs/settings from get_catalog. Edit supported native masks, cutouts, paths and other layer fields:
- {"action":"call","command":"patch_layer","args":{"id":"REAL_LAYER_UUID","set":{"clipToBelow":true}}}

Never invent object UUIDs. Use prior tool responses or rig.inspect. Child bone start is snapped to the parent tip by the native engine. Batch is sequential, not atomic. After edits, render and inspect.

## Updating the EXISTING Cloudflare Worker

The file relay/worker.js is self-contained and can be pasted into the existing Cloudflare Workers module editor. Keep the existing Worker name, Durable Object LINK binding and secret keys. Do NOT create a fresh Durable Object or paste secret values into ChatGPT.

Recommended CLI:
1. Check out the latest branch or merge.
2. On your computer sign into Cloudflare with your own account using: npx wrangler login
3. Change directory into relay and run: npx wrangler deploy
4. Let your AWIeffect iPhone app reconnect to the same Worker.
5. Refresh the custom MCP connector to discover the new single tool.

A new iPhone IPA built from this branch is needed for new /editor/rig and /editor/layer/patch operations. The Cloudflare Worker cannot be deployed through the available connection in this chat.

## Verification and limits
- GitHub Actions executes a stateless Node smoke test for MCP tool discovery and skill, then existing Xcode simulator tests and unsigned IPA build.
- Real phone responsiveness and effect appearance still need device testing. Passing CI is not equivalent to a polished edit.
- Preserve project IDs, media and unrelated layers; prefer native operations to wholesale project JSON replacement.
- No native editing command may read or mutate AWIeffect Settings, Cloudflare keys, pairing code, or account data.
- Build 29 still documents mesh topology/preserve-volume and IK soft/stretch limitations.
