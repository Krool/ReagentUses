# CurseForge listing

The text and settings for the CurseForge project. The game version on every file must be
**Forever 1.60.1**. CurseForge's web uploader picks Retail by itself, so check it on each file.

- **Game:** World of Warcraft. Forever is listed under it.
- **Name:** Reagent Uses
- **Logo:** `docs/logo.png` (512x512), a placeholder the owner can swap.
- **Main category:** Professions. **More:** Tooltip.
- **License:** MIT.
- **Source:** https://github.com/Krool/ReagentUses (Automatic Packaging off: `release.ps1 -Publish`
  uploads the tested zip).
- **Donation:** Ko-fi, `kroolworld`, the same as Krool World Forever. Only in that setting, never
  in the description.
- **Relations:** none. It needs no other addon.

## Summary (256 max)

Hold Ctrl over a crafting material to see every recipe that uses it, colored by your skill, with where each recipe is learned and which of your characters know it. Built from WoW Forever's own recipe data.

## Description

Hold Ctrl over a crafting material and its tooltip lists every recipe that uses it, grouped by profession. Your own professions come first.

- Recipe names take the crafting window's colors for your skill: orange, yellow, green, grey. Red means your skill is still below the level the recipe is learned at.
- The right side says who knows the recipe: you, and your other characters. Otherwise it says where the recipe is learned (Trainer, Vendor, Drop, Fishing, Quest, Recipe) and at what skill.
- "x4" is how many of the material a recipe takes. "(used in 95)" means what the recipe makes goes into 95 more recipes, so Silk Cloth leads you to Bolt of Silk Cloth.
- A clicked chat link shows the list without the key.

Settings (Esc > Options > AddOns > Reagent Uses, or /ru):
- **Show With:** Ctrl, Alt, Shift, or Always Show.
- **Show Hint:** a one-line hint while the key is up.
- **Show Other Characters:** name your other characters who know each recipe.
- **Hide Grey Recipes:** leave out recipes that give no skill points.
- **Recipes Shown:** how many recipes to list.

Your other characters show up after each one opens its own profession window once.

The recipe data comes from WoW Forever's own game files, including the roughly 900 recipes Forever added to the Vanilla set. Trainer levels and recipe sources come from the cmangos classic database. A recipe whose source isn't known yet shows as "Recipe".

Inspired by MasterTradeSkills for Vanilla and Turtle WoW. This is a fresh write for Forever.

Open source (MIT): https://github.com/Krool/ReagentUses

## State (2026-11-14)

- **Project:** 1804597, created with the fields above. It is awaiting moderation, and CurseForge
  hides it until approved.
- **0.1.0:** uploaded by `release.ps1 -Publish` through the API, tagged 1.60.1.
- **Left for the owner:**
  - Answer moderation if CurseForge asks anything.
  - Swap the placeholder logo for your own if you want.
  - Add in-game screenshots under Media.
- **Comments:** Allow Comments is off, as CurseForge sets it. Turn it on under General to take
  feedback there.
