-- A minimal Forever client for Reagent Uses under fengari. Only what the addon touches; tests
-- change the fixture tables (Player, Skills, Window, RecipeInfo, Keys) and fire events.

time = os.time

-- Counts every issecretvalue question (common.lua defines it; Core.lua keeps this wrapper), so a test
-- can prove a value was checked even where a type test would also have rejected the stub secret.
local realIsSecret = issecretvalue
SecretAsks = 0
function issecretvalue(v)
	SecretAsks = SecretAsks + 1
	return realIsSecret(v)
end

Combat, Instance = false, false
function InCombatLockdown()
	return Combat
end
function IsInInstance()
	return Instance, Instance and "party" or "none"
end

-- ---------------------------------------------------------------- character

Player = { name = "Krool", realm = "Forever", class = "MAGE" }
function UnitName(unit)
	if unit == "player" then
		return Player.name
	end
end
function GetRealmName()
	return Player.realm
end
function UnitClass(unit)
	if unit == "player" then
		return "Mage", Player.class, 8
	end
end

-- Skills[skill line id] = rank, as C_SkillInfo reports it.
Skills = {}
C_SkillInfo = {
	GetNumSkillLines = function()
		local n = 0
		for _ in pairs(Skills) do
			n = n + 1
		end
		return n
	end,
	GetSkillLineInfoByID = function(id)
		local rank = Skills[id]
		if rank == nil then
			return nil
		end
		return { skillID = id, rank = rank, modifier = 0, maxRank = 300 }
	end,
}

-- Blizzard_ProfessionsTemplates' check: not NPC, guild, guild member or linked.
Professions = {
	InLocalCraftingMode = function()
		return not (Window and (Window.npc or Window.linked))
	end,
}

-- The crafting window: Window = { base = ProfessionInfo, child = ProfessionInfo, npc, linked } or nil.
Window = nil
RecipeInfo = {} -- recipe id -> TradeSkillRecipeInfo (only learned matters here)
RecipeInfoCalls = 0
C_TradeSkillUI = {
	GetBaseProfessionInfo = function()
		return Window and Window.base or nil
	end,
	GetChildProfessionInfo = function()
		return Window and Window.child or nil
	end,
	IsNPCCrafting = function()
		return Window and Window.npc or false
	end,
	GetRecipeInfo = function(id)
		RecipeInfoCalls = RecipeInfoCalls + 1
		if not Window then
			return nil
		end
		return RecipeInfo[id]
	end,
	GetProfessionInfoBySkillLineID = function()
		return nil -- outside the window this answers nothing here; C_SkillInfo carries the rank
	end,
	GetTradeSkillDisplayName = function()
		return nil -- falls back to the English name in Data.lua
	end,
}

SpellNames = {
	[3839] = "Bolt of Silk Cloth",
	[7928] = "Silk Bandage",
	[7929] = "Heavy Silk Bandage",
	[3959] = "Discombobulator Ray",
	[3962] = "Iron Grenade",
	[8243] = "Flash Bomb",
	[9273] = "Goblin Jumper Cables",
	[12586] = "Solid Dynamite",
	[23069] = "EZ-Thro Dynamite II",
	[1266916] = "EZ-Thro Grenade",
}
C_Spell = {
	GetSpellName = function(id)
		return SpellNames[id] or ("Recipe " .. id)
	end,
}

-- ---------------------------------------------------------------- keys and timers

Keys = { CTRL = false, ALT = false, SHIFT = false }
function IsControlKeyDown()
	return Keys.CTRL
end
function IsAltKeyDown()
	return Keys.ALT
end
function IsShiftKeyDown()
	return Keys.SHIFT
end

Timers = {}
C_Timer = {
	After = function(_, fn)
		Timers[#Timers + 1] = fn
	end,
}
function RunTimers()
	local list = Timers
	Timers = {}
	for _, fn in ipairs(list) do
		fn()
	end
end

-- ---------------------------------------------------------------- frames and events

Frames = {}
local FrameMeta = { __index = {} }
function FrameMeta.__index:RegisterEvent(e)
	self.events[e] = true
end
function FrameMeta.__index:SetScript(which, fn)
	self.scripts[which] = fn
end
function CreateFrame()
	local f = setmetatable({ events = {}, scripts = {} }, FrameMeta)
	Frames[#Frames + 1] = f
	return f
end
function Fire(event, ...)
	for _, f in ipairs(Frames) do
		if f.events[event] and f.scripts.OnEvent then
			f.scripts.OnEvent(f, event, ...)
		end
	end
end

-- ---------------------------------------------------------------- tooltips

Enum = { TooltipDataType = { Item = 0, Unit = 2 } }
PostCalls = {}
TooltipDataProcessor = {
	AddTooltipPostCall = function(kind, fn)
		PostCalls[#PostCalls + 1] = { kind = kind, fn = fn }
	end,
}

local TipMeta = { __index = {} }
function TipMeta.__index:AddLine(text)
	self.lines[#self.lines + 1] = { left = text }
end
function TipMeta.__index:AddDoubleLine(l, r)
	self.lines[#self.lines + 1] = { left = l, right = r }
end
function TipMeta.__index:IsShown()
	return self.shown
end
function TipMeta.__index:GetOwner()
	return self.owner
end
function TipMeta.__index:GetItem()
	return "item", "link", self.item
end
function TipMeta.__index:RefreshData()
	self.refreshes = self.refreshes + 1
end
local function NewTip()
	return setmetatable({ lines = {}, shown = false, item = nil, refreshes = 0 }, TipMeta)
end
GameTooltip = NewTip()
ItemRefTooltip = NewTip()
ShoppingTooltip1 = NewTip()

-- Shows item on tooltip the way the client does: clear, then every item post-call.
function ShowItem(tip, item, data)
	tip.lines = {}
	tip.item = item
	tip.shown = true
	for _, p in ipairs(PostCalls) do
		if p.kind == Enum.TooltipDataType.Item then
			p.fn(tip, data or { id = item })
		end
	end
	return tip.lines
end

-- ---------------------------------------------------------------- settings, chat, slash

SettingsLog = { settings = {}, controls = {}, categories = 0 }
Settings = {
	VarType = { Boolean = "boolean", String = "string", Number = "number" },
	RegisterVerticalLayoutCategory = function(name)
		SettingsLog.name = name
		return {
			GetID = function()
				return 77
			end,
		}
	end,
	RegisterAddOnSetting = function(_, variable, key, tbl, varType, label, default)
		local s = { variable = variable, key = key, tbl = tbl, varType = varType, label = label, default = default }
		SettingsLog.settings[#SettingsLog.settings + 1] = s
		return s
	end,
	CreateCheckbox = function(_, setting)
		SettingsLog.controls[#SettingsLog.controls + 1] = "checkbox:" .. setting.key
	end,
	CreateSlider = function(_, setting)
		SettingsLog.controls[#SettingsLog.controls + 1] = "slider:" .. setting.key
	end,
	CreateDropdown = function(_, setting, options)
		SettingsLog.controls[#SettingsLog.controls + 1] = "dropdown:" .. setting.key
		SettingsLog.dropdown = options()
	end,
	CreateSliderOptions = function(min, max, step)
		return { min = min, max = max, step = step }
	end,
	CreateControlTextContainer = function()
		local c = { data = {} }
		function c:Add(value, label)
			self.data[#self.data + 1] = { value = value, label = label }
		end
		function c:GetData()
			return self.data
		end
		return c
	end,
	RegisterAddOnCategory = function()
		SettingsLog.categories = SettingsLog.categories + 1
	end,
	OpenToCategory = function(id)
		SettingsLog.opened = id
	end,
}

Chat = {}
DEFAULT_CHAT_FRAME = {
	AddMessage = function(_, text)
		Chat[#Chat + 1] = text
	end,
}
SlashCmdList = {}
