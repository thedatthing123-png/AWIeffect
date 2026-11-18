// node --experimental-default-type=module relay/test-unified.mjs
// Self-contained smoke test; no phone, Cloudflare secrets or network required.
import assert from "node:assert/strict";
import worker, { Link, EDITOR_SKILL, findEditorGuide } from "./worker.js";

const state = {
  getWebSockets: () => [],
  storage: {get: async () => null, put: async () => {}},
  id: {toString:()=> "a".repeat(64)}
};
const link = new Link(state);
const list = await link.handle({jsonrpc:"2.0",id:1,method:"tools/list"});
assert.equal(list.result.tools.length, 2);
assert.equal(list.result.tools[0].name, "editor_function");
assert.equal(list.result.tools[1].name, "editing_skills");
assert.ok(list.result.tools[0].description.includes("Settings"));
const init = await link.handle({jsonrpc:"2.0",id:2,method:"initialize",params:{protocolVersion:"2025-03-26"}});
assert.match(init.result.instructions, /editing_skills/);
assert.ok(Object.keys(EDITOR_SKILL.topics).includes("rig"));
assert.match(JSON.stringify(findEditorGuide("manga")), /Do not generate/);
const guide = await link.handle({jsonrpc:"2.0",id:3,method:"tools/call",
  params:{name:"editor_function",arguments:{action:"guide",topic:"rig"}}});
assert.match(guide.result.content[0].text, /native|edit/i);
const discovery = await link.handle({jsonrpc:"2.0",id:4,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"discover"}}});
assert.match(discovery.result.content[0].text, /rig\.add_bone/);
assert.match(discovery.result.content[0].text, /draw_strokes/);
assert.match(discovery.result.content[0].text, /start_export/);
assert.match(discovery.result.content[0].text, /cutoutSubject/);
assert.match(discovery.result.content[0].text, /patch_layer/);
const forbidden = await link.handle({jsonrpc:"2.0",id:5,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"call",command:"nonexistent-private-setting",args:{}}}});
assert.equal(forbidden.result.isError, true);
const offline = await link.handle({jsonrpc:"2.0",id:6,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"call",command:"rig.add_bone",args:{artwork:"x"}}}});
assert.equal(offline.result.isError, true);
const noop = await link.handle({jsonrpc:"2.0",id:7,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"batch",steps:[]}}});
assert.equal(noop.result.isError, true);
assert.equal(typeof worker.fetch, "function");
const skills = await link.handle({jsonrpc:"2.0",id:8,method:"tools/call",params:{name:"editing_skills",arguments:{action:"index"}}});
assert.match(skills.result.content[0].text, /effects/);
const skillRead = await link.handle({jsonrpc:"2.0",id:9,method:"tools/call",params:{name:"editing_skills",arguments:{action:"read",topic:"manga",maxChars:2000}}});
assert.match(skillRead.result.content[0].text, /SOURCE/);
// Guard against regressions where the relay advertises a route the iOS app never handles.
const {readFileSync} = await import("node:fs");
const nativeSource = ["App/AILink.swift","App/AILinkEditor.swift","App/AILinkAdvanced.swift","App/AILinkArtStudio.swift"]
  .map(path=>readFileSync(new URL("../"+path, import.meta.url),"utf8")).join("\n");
const requiredNative = ["/text/animators","/timeline","/layers/graph","/keyframes/velocity",
  "/layers/expression","/layers/remap","/layers/batch-patch","/masks/path",
  "/physics/soft-body","/physics/bake","/rig/ik","/rig/remove",
  "/layers/model","/layers/text3d","/puppet/pin",
  "/export/start","/export/status","/export/cancel","/draw/strokes","/draw/layer"];
for (const route of requiredNative) assert.ok(nativeSource.includes('"'+route+'"'), "Missing native AI Link route: "+route);
const typographyGuide = await link.handle({jsonrpc:"2.0",id:10,method:"tools/call",
  params:{name:"editing_skills",arguments:{action:"read",topic:"typography",maxChars:1000}}});
assert.ok(typographyGuide.result.content[0].text.length > 100, "Guide reads must never silently return empty");
assert.match(typographyGuide.result.content[0].text,/nextOffset|text|type|SOURCE/i);
console.log("AWIeffect unified MCP smoke tests passed");
