-- Reagent Uses under the stub client: the data, the tooltip, the known-recipe scan, other
-- characters, options and /ru. Fixture facts come from Data.lua for build 1.60.1.70938.

local ns = __ns
local checks, failed = 0, 0
local function Check(cond, label)
	checks = checks + 1
	if cond then
		print("ok: " .. label)
	else
		failed = failed + 1
		print("FAIL: " .. label)
	end
end

local function Plain(s)
	return ((s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- The first tooltip line whose plain left text matches pattern (and its index).
local function Find(lines, pattern)
	for i, l in ipairs(lines) do
		if Plain(l.left):find(pattern) then
			return l, i
		end
	end
	return nil
end

local function Count(lines, pattern)
	local n = 0
	for _, l in ipairs(lines) do
		if Plain(l.left):find(pattern) then
			n = n + 1
		end
	end
	return n
end

local SILK = 4306 -- Silk Cloth
local LINEN = 2589 -- Linen Cloth
local BOLT = 3839 -- Bolt of Silk Cloth: Tailoring, yellow 110, grey 120, makes 4305, trainer
local BANDAGE = 7928 -- Silk Bandage: First Aid, yellow 150, grey 210, trainer at 150
local HEAVY = 7929 -- Heavy Silk Bandage: First Aid, yellow 180, grey 240, vendor at 180
local D = ns.Data

-- ---------------------------------------------------------------- data

Check(type(D) == "table" and D.build == "1.60.1.70938", "Data.lua loads with its build")
do
	local bad, recipes, used = 0, 0, 0
	for id, r in pairs(D.recipes) do
		recipes = recipes + 1
		if
			type(r) ~= "table"
			or type(D.lines[r[1]]) ~= "table"
			or type(r[2]) ~= "number"
			or type(r[3]) ~= "number"
			or type(r[4]) ~= "number"
			or type(r[5]) ~= "string"
			or not r[5]:match("^[STVDFQR]*$")
			or type(r[6]) ~= "number"
			or (r[6] > 0 and r[2] > 0 and r[6] > r[2])
		then
			bad = bad + 1
		end
	end
	for item, list in pairs(D.uses) do
		if #list % 2 ~= 0 then
			bad = bad + 1
		end
		for i = 1, #list, 2 do
			used = used + 1
			if not D.recipes[list[i]] or list[i + 1] < 1 then
				bad = bad + 1
			end
		end
	end
	Check(recipes > 2000 and used > 5000, "about 2100 recipes and their materials are in the data")
	Check(bad == 0, "every recipe row is well formed, and every use points at a recipe (" .. bad .. " bad)")
end
Check(ns.UseCount(SILK) == 10, "Silk Cloth is used in 10 recipes")
do
	local seen = {}
	for i = 1, #D.uses[SILK], 2 do
		seen[D.uses[SILK][i]] = D.uses[SILK][i + 1]
	end
	Check(seen[BOLT] == 4, "Bolt of Silk Cloth takes 4 Silk Cloth")
	Check(D.recipes[BOLT][4] == 4305 and ns.UseCount(4305) > 50, "the bolt it makes goes into over 50 recipes")
end
do
	local test, seasonal = false, false
	for line, d in pairs(D.lines) do
		if d[1]:find("DNT") or d[1]:find("Test") then
			test = true
		end
	end
	for id in pairs(D.recipes) do
		if id == 461651 or id == 439500 then -- Season of Discovery leftovers in the client
			seasonal = true
		end
	end
	Check(not test, "no test profession in the data")
	Check(not seasonal, "Season of Discovery recipes are left out")
end

-- ---------------------------------------------------------------- start up

Skills[2948] = 150 -- Tailoring, on Forever's child line
Skills[129] = 100 -- First Aid
Fire("ADDON_LOADED", "ReagentUses")
Fire("PLAYER_LOGIN")
Check(type(ReagentUsesDB) == "table" and ReagentUsesDB.options.modifier == "CTRL", "saved data starts with Ctrl as the key")
Check(#PostCalls == 1 and PostCalls[1].kind == Enum.TooltipDataType.Item, "one item tooltip post-call is registered")
Check(ns.MySkill(197) == 150 and ns.MySkill(129) == 100 and ns.MySkill(202) == nil, "skills read from the skill lines")
Check(ReagentUsesDB.chars["Krool-Forever"].skills[197] == 150, "this character's skills are saved for the others")
Fire("PLAYER_LOGIN")
Check(#PostCalls == 1, "the tooltip hook is added once")

-- ---------------------------------------------------------------- the hint and the key

local lines = ShowItem(GameTooltip, SILK)
Check(#lines == 1 and Plain(lines[1].left) == "Hold Ctrl: 10 recipes use this", "key up: one hint line")
ReagentUsesDB.options.hint = false
lines = ShowItem(GameTooltip, SILK)
Check(#lines == 0, "hint off: key up adds nothing")
ReagentUsesDB.options.hint = true

lines = ShowItem(GameTooltip, 117) -- Tough Jerky: no recipe uses it
Check(#lines == 0, "an item no recipe uses gets nothing")

Keys.CTRL = true
lines = ShowItem(GameTooltip, SILK)
Check(Find(lines, "^Tailoring 150$") ~= nil, "Ctrl held: the Tailoring group with your skill")
local _, tIdx = Find(lines, "^Tailoring")
local _, fIdx = Find(lines, "^First Aid")
local _, eIdx = Find(lines, "^Engineering")
Check(tIdx and fIdx and eIdx and tIdx < fIdx and fIdx < eIdx, "your professions first, higher skill first, then the rest")
local bolt = Find(lines, "Bolt of Silk Cloth")
Check(bolt and Plain(bolt.left):find("x4") and Plain(bolt.left):find("%(used in %d+%)"), "the bolt line shows the count and what the bolt goes into")
Check(bolt and bolt.left:find("|cff808080Bolt of Silk Cloth") ~= nil, "Tailoring 150 against grey 120: the bolt is grey")
Check(bolt and Plain(bolt.right) == "Trainer", "not known: the right side says where it is learned")
local heavy = Find(lines, "Heavy Silk Bandage")
Check(heavy and heavy.left:find("|cffff1a1a") ~= nil, "First Aid 100 under the 180 it is learned at: red")
Check(heavy and Plain(heavy.right) == "Vendor 180" and heavy.right:find("|cffff1a1a180") ~= nil, "learn level shown, red while out of reach")
local eng = Find(lines, "^Engineering$")
Check(eng and Plain(eng.right) == "7 recipes", "a profession you lack has no skill and counts its recipes")
local dyn = Find(lines, "Solid Dynamite")
Check(dyn and dyn.left:find("|cffffffff") ~= nil, "without the profession, names are white")

lines = ShowItem(ShoppingTooltip1, SILK)
Check(#lines == 0, "comparison tooltips are left alone")
Keys.CTRL = false
lines = ShowItem(ItemRefTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil, "a clicked chat link lists the recipes without the key")

-- ---------------------------------------------------------------- scanning the crafting window

local function OpenWindow(level, extra)
	Window = { base = { professionID = 197, skillLevel = level, professionName = "Tailoring" }, child = nil }
	for k, v in pairs(extra or {}) do
		Window[k] = v
	end
end
RecipeInfo = { [BOLT] = { learned = true }, [3914] = { learned = false } }
OpenWindow(150)
Fire("TRADE_SKILL_SHOW")
Fire("TRADE_SKILL_LIST_UPDATE")
Fire("TRADE_SKILL_LIST_UPDATE")
Check(#Timers == 1, "window events queue one scan")
RunTimers()
local me = ReagentUsesDB.chars["Krool-Forever"]
Check(me.known[197] and me.known[197][BOLT] == true and me.known[197][3914] == nil, "the scan records learned recipes only")
Keys.CTRL = true
lines = ShowItem(GameTooltip, SILK)
bolt = Find(lines, "Bolt of Silk Cloth")
Check(bolt and Plain(bolt.right) == "Known", "a known recipe says Known")

-- Someone else's Tailoring (a chat link) shows their skill: it must not overwrite ours.
RecipeInfo = { [BOLT] = { learned = false }, [3865] = { learned = true } }
OpenWindow(300)
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(me.known[197][BOLT] == true and not me.known[197][3865], "a linked profession at another skill is not recorded")
OpenWindow(150, { npc = true })
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(me.known[197][BOLT] == true and not me.known[197][3865], "an NPC crafting window is not recorded")
Window = { base = { professionID = 202, skillLevel = 50 } }
RecipeInfo = { [12586] = { learned = true } }
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(me.known[202] == nil, "a profession this character does not have is not recorded")

-- The list not loaded yet (every GetRecipeInfo nil): keep what we had.
OpenWindow(150)
RecipeInfo = {}
Fire("TRADE_SKILL_SHOW")
RunTimers()
Check(me.known[197][BOLT] == true, "an empty answer keeps the recorded recipes")

-- A secret learned flag is skipped, not tested.
RecipeInfo = { [BOLT] = { learned = true }, [3914] = { learned = Secret() } }
Fire("TRADE_SKILL_SHOW")
local ok = pcall(RunTimers)
Check(ok and me.known[197][BOLT] == true and me.known[197][3914] == nil, "a secret learned flag is skipped")
Window = nil

Fire("NEW_RECIPE_LEARNED", BANDAGE)
Check(me.known[129] and me.known[129][BANDAGE] == true, "learning a recipe records it at once")
Fire("NEW_RECIPE_LEARNED", 999999)
Check(true, "an unknown recipe id is ignored")

-- ---------------------------------------------------------------- other characters

ReagentUsesDB.chars["Bob-Forever"] = {
	name = "Bob",
	realm = "Forever",
	class = "WARRIOR",
	skills = { [202] = 190, [129] = 300 },
	known = { [202] = { [12586] = true }, [129] = { [BANDAGE] = true } },
}
ReagentUsesDB.chars["Amy-Elsewhere"] = {
	name = "Amy",
	realm = "Elsewhere",
	skills = { [129] = 160 },
	known = { [129] = { [BANDAGE] = true } },
}
lines = ShowItem(GameTooltip, SILK)
dyn = Find(lines, "Solid Dynamite")
Check(dyn and Plain(dyn.right) == "Bob", "another character who knows it is named")
Check(dyn and dyn.right:find("|cff40bf40Bob") ~= nil, "named in the color of their own skill (190 is green for 175-195)")
local band = Find(lines, "^  Silk Bandage")
Check(band and Plain(band.right) == "Known, Amy-Elsewhere, Bob", "you first, then others; another realm keeps its realm")
_, eIdx = Find(lines, "^Engineering")
local _, firstEng = Find(lines, "Solid Dynamite")
local _, otherEng = Find(lines, "Iron Grenade")
Check(firstEng and otherEng and firstEng < otherEng, "recipes someone knows come first in their group")
ReagentUsesDB.options.alts = false
lines = ShowItem(GameTooltip, SILK)
dyn = Find(lines, "Solid Dynamite")
Check(dyn and Plain(dyn.right) == "Trainer 175", "Show Other Characters off: back to where it is learned")
ReagentUsesDB.options.alts = true

-- ---------------------------------------------------------------- options

ReagentUsesDB.options.hideGrey = true
lines = ShowItem(GameTooltip, SILK)
Check(Find(lines, "Bolt of Silk Cloth") == nil and Find(lines, "^Tailoring") == nil, "Hide Grey Recipes drops the grey bolt and its empty group")
Check(Find(lines, "Iron Grenade") ~= nil, "Hide Grey keeps recipes of professions you lack")
ReagentUsesDB.options.hideGrey = false

ReagentUsesDB.options.maxRecipes = 2
lines = ShowItem(GameTooltip, SILK)
local rows = 0
for _, l in ipairs(lines) do
	if l.left:find("^  ") and not Plain(l.left):find("more$") then
		rows = rows + 1
	end
end
Check(rows == 2, "Recipes Shown caps the recipe rows")
Check(Find(lines, "^  %+1 more$") ~= nil, "a cut group says how many more")
Check(Find(lines, "^Engineering$") ~= nil, "groups past the cap still show their count")
ReagentUsesDB.options.maxRecipes = 15

Keys.CTRL = false
ReagentUsesDB.options.modifier = "ALT"
lines = ShowItem(GameTooltip, SILK)
Check(#lines == 1 and Plain(lines[1].left):find("^Hold Alt"), "the hint names the chosen key")
Keys.ALT = true
lines = ShowItem(GameTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil, "Alt shows the list when Alt is the key")
Keys.ALT = false
ReagentUsesDB.options.modifier = "NONE"
lines = ShowItem(GameTooltip, SILK)
Check(Find(lines, "^Tailoring") ~= nil and Find(lines, "^Hold") == nil, "Always Show: the list without a key, no hint")
ReagentUsesDB.options.modifier = "CTRL"

-- Two recipes with one name in one profession (faction banners) show as one row.
do
	local both
	for item, list in pairs(D.uses) do
		local a, b = false, false
		for i = 1, #list, 2 do
			a = a or list[i] == 1229504
			b = b or list[i] == 1263425
		end
		if a and b then
			both = item
			break
		end
	end
	if both then
		SpellNames[1229504], SpellNames[1263425] = "Faction Banner", "Faction Banner"
		Keys.CTRL = true
		ReagentUsesDB.options.maxRecipes = 50
		lines = ShowItem(GameTooltip, both)
		Check(Count(lines, "Faction Banner") == 1, "two recipes with one name share a row")
		ReagentUsesDB.options.maxRecipes = 15
		Keys.CTRL = false
	else
		Check(true, "no material is shared by both faction banners")
	end
end

-- ---------------------------------------------------------------- secrets and errors

lines = ShowItem(GameTooltip, nil, { id = Secret() })
Check(#lines == 0, "a secret item id is left alone")
ok = pcall(ns.OnItemTooltip, GameTooltip, "not a table")
Check(ok, "a tooltip without data is left alone")

local realCollect = ns.Collect
ns.Collect = function()
	error("boom")
end
Keys.CTRL = true
local chatBefore = #Chat
ok = pcall(ShowItem, GameTooltip, SILK)
ns.Collect = realCollect
Check(ok and #Chat == chatBefore, "a tooltip error is caught and not printed")
Check(ReagentUsesDB.errors[1] and ReagentUsesDB.errors[1].where == "tooltip" and ReagentUsesDB.errors[1].msg:find("boom"), "it is logged for /ru errors")

-- ---------------------------------------------------------------- the key redraws the tooltip

GameTooltip.shown, GameTooltip.item, GameTooltip.refreshes = true, SILK, 0
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(GameTooltip.refreshes == 1, "pressing Ctrl redraws a material tooltip")
Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
Check(GameTooltip.refreshes == 1, "another key does nothing")
GameTooltip.item = 117
Fire("MODIFIER_STATE_CHANGED", "RCTRL", 0)
Check(GameTooltip.refreshes == 1, "a non-material tooltip is not redrawn")
GameTooltip.item = Secret()
ok = pcall(Fire, "MODIFIER_STATE_CHANGED", "RCTRL", 0)
Check(ok and GameTooltip.refreshes == 1, "a secret item on the tooltip is left alone")
GameTooltip.shown = false
GameTooltip.item = SILK
Fire("MODIFIER_STATE_CHANGED", "LCTRL", 1)
Check(GameTooltip.refreshes == 1, "a hidden tooltip is not redrawn")
Keys.CTRL = false

-- ---------------------------------------------------------------- band edges

local r = { 0, 100, 120, 0, "T", 90 }
Check(ns.Band(89, r) == "red" and ns.Band(90, r) == "orange", "red below the learn level, orange from it")
Check(ns.Band(99, r) == "orange" and ns.Band(100, r) == "yellow", "yellow from the yellow threshold")
Check(ns.Band(109, r) == "yellow" and ns.Band(110, r) == "green", "green from halfway")
Check(ns.Band(119, r) == "green" and ns.Band(120, r) == "grey", "grey from the grey threshold")
Check(ns.Band(nil, r) == nil and ns.Band(150, { 0, 0, 0, 0, "", 0 }) == nil, "no skill or no thresholds: no color")

-- ---------------------------------------------------------------- settings and /ru

Check(SettingsLog.name == "Reagent Uses" and SettingsLog.categories == 1, "the settings category is registered once")
Check(#SettingsLog.settings == 5, "five settings")
Check(SettingsLog.dropdown and #SettingsLog.dropdown == 4 and SettingsLog.dropdown[1].value == "CTRL", "the key dropdown offers Ctrl, Alt, Shift, Always")
for _, s in ipairs(SettingsLog.settings) do
	Check(s.tbl == ReagentUsesDB.options and type(s.default) == s.varType, "setting " .. s.key .. " is stored in the options with a matching default")
end

SlashCmdList.REAGENTUSES("")
Check(SettingsLog.opened == 77, "/ru opens the settings")
local before = #Chat
SlashCmdList.REAGENTUSES("chars")
local listed = table.concat(Chat, "\n", before + 1)
Check(Plain(listed):find("Krool%-Forever %(this character%)") and Plain(listed):find("Bob%-Forever"), "/ru chars lists the characters")
SlashCmdList.REAGENTUSES("forget bob")
Check(ReagentUsesDB.chars["Bob-Forever"] == nil, "/ru forget drops a character by name")
SlashCmdList.REAGENTUSES("forget krool")
Check(ReagentUsesDB.chars["Krool-Forever"] ~= nil, "/ru forget never drops the character you are on")
before = #Chat
SlashCmdList.REAGENTUSES("errors")
Check(#Chat > before and Plain(Chat[before + 1]):find("tooltip: "), "/ru errors lists the log")
before = #Chat
SlashCmdList.REAGENTUSES("what")
Check(#Chat - before == 4, "anything else prints the help")
ReagentUses_OnCompartmentClick()
Check(SettingsLog.opened == 77, "the compartment entry opens the settings")

-- A broken saved variable is repaired at load.
ReagentUsesDB = { options = { modifier = "META", maxRecipes = "lots" }, chars = 5 }
ns.InitDB()
Check(ReagentUsesDB.options.modifier == "CTRL" and ReagentUsesDB.options.maxRecipes == 15 and type(ReagentUsesDB.chars) == "table", "bad saved values fall back to the defaults")

print(checks .. " checks, " .. failed .. " failed")
if failed > 0 then
	error(failed .. " checks failed")
end
