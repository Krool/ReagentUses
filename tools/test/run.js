// ReagentUses test runner.
// 1. Syntax-checks every file the TOC loads (Lua 5.1 grammar, the client's dialect).
// 2. Checks Data.lua was generated for the build the API allowlist was made from.
// 3. For each suite folder here (tools/test/<suite>/ with stubs.lua + test.lua): a fresh fengari
//    state loads common.lua (the shared Secret() stub), then that folder's stubs.lua, then EVERY
//    TOC file in order with the ("ReagentUses", ns) varargs the client passes (ns is one table
//    per suite, also the global __ns for the tests), then runs test.lua. A stubs.lua may build on
//    another suite's with __include("other/stubs.lua").
// 4. A suite must report its checks ("N checks, M failed") and N must be above zero: a test.lua
//    that returns early cannot pass.
// Usage: node run.js [suite] [--verbose]. Passing lines ("ok: ...") print only with --verbose.
const fs = require("fs");
const path = require("path");
const luaparse = require("luaparse");
const { lua, lauxlib, lualib, to_luastring } = require("fengari");

const ADDON = "ReagentUses";
const addonDir = path.join(__dirname, "..", "..", ADDON);
const tocPath = path.join(addonDir, ADDON + "_Forever.toc");
if (!fs.existsSync(tocPath)) {
  console.log(`NO TOC: ${tocPath} not found`);
  process.exit(1);
}
const toc = fs.readFileSync(tocPath, "utf8");
const files = toc
  .split(/\r?\n/)
  .map((l) => l.trim())
  .filter((l) => l && !l.startsWith("#"))
  .map((l) => l.replace(/\\/g, "/"));

let failed = false;
const sources = {};
for (const f of files) {
  const p = path.join(addonDir, f);
  if (!fs.existsSync(p)) {
    console.log("MISSING: the TOC lists " + f + " but " + p + " does not exist");
    failed = true;
    continue;
  }
  sources[f] = fs.readFileSync(p, "utf8");
  try {
    luaparse.parse(sources[f], { luaVersion: "5.1" });
  } catch (e) {
    console.log("SYNTAX FAIL: " + f + ": " + e.message);
    failed = true;
  }
}
if (failed) process.exit(1);
console.log(`syntax ok: ${files.length} files`);

// Build-specific data must match the build the API allowlist was made from: when a new client
// drops and the allowlist is rebuilt, this fails until the data is regenerated too.
const apiBuild = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "forever-api", "forever-api.json"), "utf8")).version;
const dataBuild = ((sources["Data.lua"] || "").match(/build = "([^"]+)"/) || [])[1];
if (dataBuild !== apiBuild) {
  console.log(`DATA STALE: Data.lua is build ${dataBuild}, the API allowlist is ${apiBuild}.`);
  console.log(`  Regenerate it: node tools/data/gen-data.js ${apiBuild}`);
  process.exit(1);
}
console.log(`data ok: Data.lua matches build ${apiBuild}`);

const args = process.argv.slice(2);
const verbose = args.includes("--verbose");
const only = args.find((a) => !a.startsWith("--"));
const suites = fs
  .readdirSync(__dirname, { withFileTypes: true })
  .filter(
    (d) =>
      d.isDirectory() &&
      d.name !== "node_modules" &&
      (!only || d.name === only) &&
      fs.existsSync(path.join(__dirname, d.name, "stubs.lua")) &&
      fs.existsSync(path.join(__dirname, d.name, "test.lua"))
  )
  .map((d) => d.name);
if (suites.length === 0) {
  console.log(
    only
      ? `NO SUITE "${only}": expected tools/test/${only}/stubs.lua and tools/test/${only}/test.lua`
      : "NO SUITES: add tools/test/<suite>/stubs.lua and test.lua"
  );
  process.exit(1);
}

function runSuite(name) {
  const dir = path.join(__dirname, name);
  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  const output = [];
  lua.lua_register(L, to_luastring("__rawprint"), (L) => {
    output.push(lua.lua_tojsstring(L, 1));
    return 0;
  });
  const shim =
    "print = function(...) local t = {} for i = 1, select('#', ...) do t[#t + 1] = tostring((select(i, ...))) end __rawprint(table.concat(t, '\\t')) end";
  lauxlib.luaL_dostring(L, to_luastring(shim));

  const shown = () => output.filter((l) => verbose || !/^ok:\s/.test(l)).join("\n");
  const fail = (label) => {
    console.log(shown());
    console.log(`[${name}] LUA FAIL in ${label}: ${lua.lua_tojsstring(L, -1)}`);
    return false;
  };
  const exec = (label, src, withVarargs) => {
    if (lauxlib.luaL_loadbuffer(L, to_luastring(src), null, to_luastring("@" + label)) !== lua.LUA_OK) return fail(label);
    let nargs = 0;
    if (withVarargs) {
      lua.lua_pushstring(L, to_luastring(ADDON));
      lua.lua_getglobal(L, to_luastring("__ns"));
      nargs = 2;
    }
    if (lua.lua_pcall(L, nargs, 0, 0) !== lua.LUA_OK) return fail(label);
    return true;
  };

  lua.lua_register(L, to_luastring("__include"), (L) => {
    const rel = lua.lua_tojsstring(L, 1);
    if (!exec(rel, fs.readFileSync(path.join(__dirname, rel), "utf8"))) lauxlib.luaL_error(L, to_luastring("include failed: " + rel));
    return 0;
  });
  if (!exec("common.lua", fs.readFileSync(path.join(__dirname, "common.lua"), "utf8"))) return false;
  if (!exec(name + "/stubs.lua", fs.readFileSync(path.join(dir, "stubs.lua"), "utf8"))) return false;
  lua.lua_newtable(L);
  lua.lua_setglobal(L, to_luastring("__ns"));
  for (const f of files) if (!exec(f, sources[f], true)) return false;
  let ok = exec(name + "/test.lua", fs.readFileSync(path.join(dir, "test.lua"), "utf8"));
  if (ok) {
    console.log(shown());
    const m = output.join("\n").match(/(\d+) checks, (\d+) failed/);
    if (!m || Number(m[1]) === 0) {
      console.log(`[${name}] ran no checks: test.lua must end by printing "N checks, M failed"`);
      ok = false;
    } else if (Number(m[2]) > 0) {
      ok = false;
    }
  }
  console.log(ok ? `[${name}] PASSED` : `[${name}] FAILED`);
  return ok;
}

let allOk = true;
for (const s of suites) allOk = runSuite(s) && allOk;
console.log(allOk ? "ALL TESTS PASSED" : "TESTS FAILED");
process.exit(allOk ? 0 : 1);
