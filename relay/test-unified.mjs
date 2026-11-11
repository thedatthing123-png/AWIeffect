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
assert.equal(list.result.tools.length, 1);
assert.equal(list.result.tools[0].name, "use_awieffect");
assert.ok(list.result.tools[0].description.includes("Settings"));
const init = await link.handle({jsonrpc:"2.0",id:2,method:"initialize",params:{protocolVersion:"2025-03-26"}});
assert.match(init.result.instructions, /guide/);
assert.ok(Object.keys(EDITOR_SKILL.topics).includes("rig"));
assert.match(JSON.stringify(findEditorGuide("manga")), /Do not generate/);
const guide = await link.handle({jsonrpc:"2.0",id:3,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"guide",topic:"rig"}}});
assert.match(guide.result.content[0].text, /native/i);
const discovery = await link.handle({jsonrpc:"2.0",id:4,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"discover"}}});
assert.match(discovery.result.content[0].text, /rig\.add_bone/);
assert.match(discovery.result.content[0].text, /patch_layer/);
const forbidden = await link.handle({jsonrpc:"2.0",id:5,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"call",command:"get_upload_url",args:{}}}});
assert.equal(forbidden.result.isError, true);
const offline = await link.handle({jsonrpc:"2.0",id:6,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"call",command:"rig.add_bone",args:{artwork:"x"}}}});
assert.equal(offline.result.isError, true);
const noop = await link.handle({jsonrpc:"2.0",id:7,method:"tools/call",
  params:{name:"use_awieffect",arguments:{action:"batch",steps:[]}}});
assert.equal(noop.result.isError, true);
assert.equal(typeof worker.fetch, "function");
console.log("AWIeffect unified MCP smoke tests passed");
