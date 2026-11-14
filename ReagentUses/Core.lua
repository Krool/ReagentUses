-- Reagent Uses: saved data, the player's profession skills, and the recipes each character knows.
-- Tooltip.lua draws the tooltip; Options.lua the settings panel and /ru. Data.lua is generated.
--
-- ReagentUsesDB = {
--   options = { modifier, hint, alts, hideGrey, maxRecipes },
--   chars = { ["Name-Realm"] = { name, realm, class, seen, skills = { [line] = rank },
--             known = { [line] = { [recipe] = true } } } },
--   errors = { { where, msg, at } },   -- newest first, /ru errors
-- }
-- A character's known recipes are read when it opens its own profession window, and when it learns
-- one (NEW_RECIPE_LEARNED). Nothing is ever sent anywhere; the addon only reads and draws tooltips.

local addonName, ns = ...

ns.DEFAULTS = {
	modifier = "CTRL", -- CTRL, ALT, SHIFT, or NONE (always shown)
	hint = true,
	alts = true,
	hideGrey = false,
	maxRecipes = 15,
}
ns.MODIFIERS = { "CTRL", "ALT", "SHIFT", "NONE" }

local ERRORS_MAX = 20
local SCAN_DELAY = 0.3

-- ------------------------------------------------------------------ helpers

local issecret = issecretvalue

-- Secret values (Midnight-era restriction) may not be compared, tested or indexed: check first.
function ns.Secret(v)
	return issecret ~= nil and issecret(v) == true
end
local Secret = ns.Secret

function ns.Num(v)
	if Secret(v) or type(v) ~= "number" then
		return nil
	end
	return v
end
local Num = ns.Num

function ns.Str(v)
	if Secret(v) or type(v) ~= "string" or v == "" then
		return nil
	end
	return v
end

-- Calls an API that may be missing or may error; the first two results, or nil.
function ns.Call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, a, b = pcall(fn, ...)
	if ok then
		return a, b
	end
	return nil
end
local Call = ns.Call

function ns.Print(msg)
	local chat = DEFAULT_CHAT_FRAME
	if chat and chat.AddMessage then
		chat:AddMessage("|cff33ff99Reagent Uses|r: " .. tostring(msg))
	end
end

function ns.LogError(where, err)
	local msg = tostring(err)
	local db = ns.db
	if db and type(db.errors) == "table" then
		table.insert(db.errors, 1, { where = where, msg = msg, at = time and time() or 0 })
		while #db.errors > ERRORS_MAX do
			table.remove(db.errors)
		end
	end
	return msg
end

local reported = {}

-- Runs fn under pcall. An error is logged for /ru errors and printed once per session per place.
function ns.Try(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		local msg = ns.LogError(where, err)
		if not reported[where] then
			reported[where] = true
			ns.Print("error in " .. where .. ": " .. msg .. " (/ru errors lists them)")
		end
	end
	return ok
end

-- Tooltips: log only, never print (a tooltip redraws many times a second).
function ns.TryQuiet(where, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		ns.LogError(where, err)
	end
	return ok
end

-- ------------------------------------------------------------------ saved data

local VALID_MODIFIER = { CTRL = true, ALT = true, SHIFT = true, NONE = true }

function ns.InitDB()
	local db = type(ReagentUsesDB) == "table" and ReagentUsesDB or {}
	ReagentUsesDB = db
	db.options = type(db.options) == "table" and db.options or {}
	for k, v in pairs(ns.DEFAULTS) do
		if type(db.options[k]) ~= type(v) then
			db.options[k] = v
		end
	end
	if not VALID_MODIFIER[db.options.modifier] then
		db.options.modifier = ns.DEFAULTS.modifier
	end
	db.chars = type(db.chars) == "table" and db.chars or {}
	db.errors = type(db.errors) == "table" and db.errors or {}
	ns.db = db
	ns.opt = db.options
end

-- "Name-Realm" for the logged-in character, plus its name and realm.
function ns.MyKey()
	local name = ns.Str(Call(UnitName, "player"))
	local realm = ns.Str(Call(GetRealmName))
	if not (name and realm) then
		return nil
	end
	return name .. "-" .. realm, name, realm
end

-- This character's saved record, created on first use.
function ns.Me()
	if ns.me then
		return ns.me
	end
	local key, name, realm = ns.MyKey()
	if not (key and ns.db) then
		return nil
	end
	local c = ns.db.chars[key]
	if type(c) ~= "table" then
		c = {}
		ns.db.chars[key] = c
	end
	c.name, c.realm = name, realm
	local _, class = Call(UnitClass, "player")
	c.class = ns.Str(class) or c.class
	c.skills = type(c.skills) == "table" and c.skills or {}
	c.known = type(c.known) == "table" and c.known or {}
	ns.me, ns.meKey = c, key
	return c
end

-- ------------------------------------------------------------------ skills

local function RankOf(id)
	local S = C_SkillInfo
	local info = S and Call(S.GetSkillLineInfoByID, id)
	if type(info) ~= "table" then
		return nil
	end
	local rank = Num(info.rank)
	return rank and rank > 0 and rank or nil
end

local function LevelOf(info)
	if type(info) ~= "table" then
		return nil
	end
	local lvl = Num(info.skillLevel)
	return lvl and lvl > 0 and lvl or nil
end
ns.LevelOf = LevelOf

-- The player's skill in a profession (its base skill line), or nil without the profession. Forever
-- keeps the skill on a child line ("Classic Tailoring"); both are asked and the higher wins.
function ns.ReadSkill(line)
	local d = ns.Data.lines[line]
	local child = d and d[2] or 0
	local best
	local function Take(r)
		if r and (not best or r > best) then
			best = r
		end
	end
	Take(RankOf(line))
	if child > 0 then
		Take(RankOf(child))
		local T = C_TradeSkillUI
		if T then
			Take(LevelOf(Call(T.GetProfessionInfoBySkillLineID, child)))
		end
	end
	return best
end

local skillCache = {}

-- ReadSkill, remembered until the skills change.
function ns.MySkill(line)
	local v = skillCache[line]
	if v == nil then
		v = ns.ReadSkill(line) or false
		skillCache[line] = v
	end
	return v or nil
end

-- Re-reads every profession skill into this character's record, so other characters see it.
function ns.RefreshSkills()
	for k in pairs(skillCache) do
		skillCache[k] = nil
	end
	local me = ns.Me()
	if not me then
		return
	end
	for line in pairs(ns.Data.lines) do
		local r = ns.MySkill(line)
		if r then
			me.skills[line] = r
		end
	end
	me.seen = time and time() or me.seen
end

-- ------------------------------------------------------------------ known recipes

local byLine -- line -> { recipe ids }, built on first use

function ns.RecipesOf(line)
	if not byLine then
		byLine = {}
		for id, r in pairs(ns.Data.recipes) do
			local l = r[1]
			byLine[l] = byLine[l] or {}
			table.insert(byLine[l], id)
		end
	end
	return byLine[line] or {}
end

-- The profession the crafting window shows, as a base line in the data; plus the window's skill.
function ns.OpenLine()
	local T = C_TradeSkillUI
	if not T then
		return nil
	end
	local base, child = Call(T.GetBaseProfessionInfo), Call(T.GetChildProfessionInfo)
	local bid = type(base) == "table" and Num(base.professionID) or nil
	local cid = type(child) == "table" and Num(child.professionID) or nil
	local shown = LevelOf(child) or LevelOf(base)
	if bid and ns.Data.lines[bid] then
		return bid, shown
	end
	for line, d in pairs(ns.Data.lines) do
		if (cid and (d[2] == cid or line == cid)) or (bid and d[2] == bid) then
			return line, shown
		end
	end
	return nil
end

-- True when the window shows the player's own profession: not a chat link, a guild view or an NPC.
local function LocalCrafting(line, shown)
	local T = C_TradeSkillUI
	if T and Call(T.IsNPCCrafting) == true then
		return false
	end
	local P = Professions
	if type(P) == "table" and type(P.InLocalCraftingMode) == "function" then
		local ok, isLocal = pcall(P.InLocalCraftingMode)
		if ok and not Secret(isLocal) and isLocal == false then
			return false
		end
	end
	local mine = ns.ReadSkill(line)
	if not mine then
		return false -- someone else's profession: this character does not have it
	end
	return shown == nil or shown == mine
end

-- Records which recipes of the open profession this character knows.
function ns.ScanOpen()
	local T = C_TradeSkillUI
	local me = ns.Me()
	if not (T and me) then
		return
	end
	local line, shown = ns.OpenLine()
	if not line or not LocalCrafting(line, shown) then
		return
	end
	local set, answered, count = {}, 0, 0
	for _, id in ipairs(ns.RecipesOf(line)) do
		local info = Call(T.GetRecipeInfo, id)
		if type(info) == "table" then
			answered = answered + 1
			local learned = info.learned
			if not Secret(learned) and learned == true then
				set[id] = true
				count = count + 1
			end
		end
	end
	if answered == 0 then
		return -- the list has not loaded yet; keep what we had
	end
	me.known[line] = set
	me.skills[line] = ns.ReadSkill(line)
	ns.lastScan = { line = line, known = count, answered = answered }
end

local scanPending = false
function ns.QueueScan()
	if scanPending then
		return
	end
	scanPending = true
	local after = C_Timer and C_Timer.After
	local function Run()
		scanPending = false
		ns.Try("scan", ns.ScanOpen)
	end
	if after then
		after(SCAN_DELAY, Run)
	else
		Run()
	end
end

function ns.OnRecipeLearned(id)
	id = Num(id)
	local r = id and ns.Data.recipes[id]
	local me = ns.Me()
	if not (r and me) then
		return
	end
	local line = r[1]
	me.known[line] = me.known[line] or {}
	me.known[line][id] = true
end

-- Other characters (not this one) who know a recipe: { { name, realm, class, rank }, ... } or nil.
function ns.AltsKnowing(line, id)
	local list
	for key, c in pairs(ns.db.chars) do
		if key ~= ns.meKey and type(c) == "table" and type(c.known) == "table" then
			local set = c.known[line]
			if type(set) == "table" and set[id] then
				list = list or {}
				list[#list + 1] = {
					name = c.name or key,
					realm = c.realm,
					class = c.class,
					rank = type(c.skills) == "table" and c.skills[line] or nil,
				}
			end
		end
	end
	if list then
		table.sort(list, function(a, b)
			return a.name < b.name
		end)
	end
	return list
end

-- True when another character has this profession (or knows any of its recipes).
function ns.AltHasLine(line)
	for key, c in pairs(ns.db.chars) do
		if key ~= ns.meKey and type(c) == "table" then
			if (type(c.skills) == "table" and c.skills[line]) or (type(c.known) == "table" and c.known[line]) then
				return true
			end
		end
	end
	return false
end

-- ------------------------------------------------------------------ events

local handlers = {}

function handlers.ADDON_LOADED(name)
	if name ~= addonName then
		return
	end
	ns.InitDB()
	ns.Try("settings", ns.BuildSettings)
end

function handlers.PLAYER_LOGIN()
	ns.Me()
	ns.RefreshSkills()
	ns.Try("tooltip hook", ns.HookTooltips)
end

function handlers.SKILL_LINES_CHANGED()
	ns.RefreshSkills()
end

function handlers.TRADE_SKILL_SHOW()
	ns.QueueScan()
end

function handlers.TRADE_SKILL_LIST_UPDATE()
	ns.QueueScan()
end

function handlers.NEW_RECIPE_LEARNED(id)
	ns.OnRecipeLearned(id)
end

function handlers.MODIFIER_STATE_CHANGED(key, down)
	ns.TryQuiet("modifier", ns.OnModifier, key, down)
end
ns.handlers = handlers -- test seam

local frame = CreateFrame("Frame")
-- One line: the API lint checks the names of a list it can see beside the RegisterEvent.
-- stylua: ignore
for _, event in ipairs({ "ADDON_LOADED", "PLAYER_LOGIN", "SKILL_LINES_CHANGED", "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "NEW_RECIPE_LEARNED", "MODIFIER_STATE_CHANGED" }) do
	frame:RegisterEvent(event)
end
frame:SetScript("OnEvent", function(_, event, ...)
	local fn = handlers[event]
	if fn then
		ns.Try(event, fn, ...)
	end
end)
