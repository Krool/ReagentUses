# ReagentUses

One addon, **Reagent Uses** (`ReagentUses/`), for World of Warcraft: Forever. Hold a key over a
crafting material and the tooltip lists the recipes that use it. It was built 2026-11-14 for a
friend of the owner, as a Forever rebuild of MasterTradeSkills (Vanilla/Turtle). It is a fresh write
with no code from it.

Sibling of `..\WoWForeverMods` (Krool World Forever). Its CLAUDE.md holds the platform facts that
apply here too:
- Forever is a Mainline client, Interface 16001.
- Secret values: `issecretvalue` first, before any other test.
- Protected calls need a hardware event.
- The live build changes every few days.

Read it before changing client code.

## Rules

- **Read-only addon.** It reads data and adds tooltip lines. It never clicks, crafts, buys or
  deletes for the player.
- **Never let an error reach the client.** Event handlers run under `ns.Try` (prints once, logs to
  `ReagentUsesDB.errors`), tooltips under `ns.TryQuiet` (log only). Check secrets before anything.
- **Never write Blizzard globals** (taint). The test stubs provide `SlashCmdList` and friends.
- **APIs:** check a `C_*` function or event against `tools/forever-api/forever-api.json` before
  using it. The API lint fails anything not in Forever's docs. An event registered in a loop must
  come from a literal list on the lines just above it.
- **Data.lua is generated.**
  - Run `node tools/data/gen-data.js <build>`. Inputs are cached in `tools/data/cache/<build>/`
    (wago.tools CSVs) and `tools/data/sqlcache/` (cmangos classic-db), both git-ignored.
  - Forever's own tables decide which recipes exist. Categories without a parent are Season of
    Discovery leftovers, and are dropped along with test and unnamed spells.
  - The classic DB only fills trainer learn levels and recipe-item sources. A vanilla trainer level is
    shifted by Forever's change to that recipe's yellow (Classic Era's SkillLineAbility, build
    `ERA_BUILD` in the generator), since Forever's own recipe items moved their required skill the
    same way. One still above Forever's yellow is dropped.
  - Recipes whose crafted item the client hides (Forever's set pieces) stay, with item 0. Recipes
    taught only by items missing from the client are dropped; the generator prints their names.
  - `run.js` fails when Data.lua's build differs from the API allowlist's.

## Tests and release

- `cd tools\test; npm test` runs the fengari stub-client suite (`tools/test/tooltip/`) and then
  the API lint.
- `scripts\release.ps1 -Version x.y.z [-Publish]`, same flow as the bundle's:
  - Write the `## x.y.z` CHANGELOG section and commit the addon first.
  - It syncs the TOC version, tests, commits TOC and CHANGELOG by pathspec, tags, builds
    `dist\ReagentUses-x.y.z.zip` from the tag, pushes and creates the GitHub release.
  - `-Publish` uploads to CurseForge through `scripts\publish.ps1`. That needs
    `## X-Curse-Project-ID` in the TOC and the user env var `CF_API_KEY`. Never write or echo the
    token.
  - Check that every CurseForge file is tagged Forever 1.60.1, not Retail.
- Commit messages: write the file as UTF-8 without BOM, then `git commit -F`. Stage only paths you
  touched; never `git add -A`.
- `scripts\link-addon.ps1` junctions `ReagentUses\` into `_forever_\Interface\AddOns` for testing in
  game.
