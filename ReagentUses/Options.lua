-- Settings panel (Esc > Options > AddOns > Reagent Uses), /ru, and the addon compartment entry.

local _, ns = ...

local KEY_NAMES = { CTRL = "Ctrl", ALT = "Alt", SHIFT = "Shift", NONE = "Always Show" }

function ns.BuildSettings()
	if ns.category or not (Settings and Settings.RegisterVerticalLayoutCategory) then
		return
	end
	local category = Settings.RegisterVerticalLayoutCategory("Reagent Uses")
	ns.category = category
	local opt = ns.opt
	local function Register(key, varType, label)
		return Settings.RegisterAddOnSetting(category, "ReagentUses_" .. key, key, opt, varType, label, ns.DEFAULTS[key])
	end

	local modifier = Register("modifier", Settings.VarType.String, "Show With")
	Settings.CreateDropdown(category, modifier, function()
		local c = Settings.CreateControlTextContainer()
		for _, k in ipairs(ns.MODIFIERS) do
			c:Add(k, KEY_NAMES[k])
		end
		return c:GetData()
	end, "The key to hold over a crafting material to list the recipes that use it. Always Show lists them on every material's tooltip.")

	Settings.CreateCheckbox(
		category,
		Register("hint", Settings.VarType.Boolean, "Show Hint"),
		"While the key is up, one line on the tooltip says how many recipes use the material."
	)
	Settings.CreateCheckbox(
		category,
		Register("alts", Settings.VarType.Boolean, "Show Other Characters"),
		"Names your other characters who know each recipe. A character is remembered after it opens its own profession window with this addon on."
	)
	Settings.CreateCheckbox(
		category,
		Register("hideGrey", Settings.VarType.Boolean, "Hide Grey Recipes"),
		"Leaves out recipes that can no longer give you a skill point."
	)

	local count = Register("maxRecipes", Settings.VarType.Number, "Recipes Shown")
	local options = Settings.CreateSliderOptions(5, 50, 1)
	if options.SetLabelFormatter and MinimalSliderWithSteppersMixin then
		options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
	end
	Settings.CreateSlider(category, count, options, "How many recipes the tooltip lists. Past that, each profession only shows its count.")

	Settings.RegisterAddOnCategory(category)
end

function ns.OpenSettings()
	if ns.category and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(ns.category:GetID())
	end
end

-- ------------------------------------------------------------------ /ru

local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys)
	return keys
end

local function ListCharacters()
	local keys = SortedKeys(ns.db.chars)
	if #keys == 0 then
		ns.Print("no characters remembered yet. Open a profession window to record one.")
		return
	end
	for _, key in ipairs(keys) do
		local c = ns.db.chars[key]
		local parts = {}
		for _, line in ipairs(SortedKeys(type(c.skills) == "table" and c.skills or {})) do
			local set = type(c.known) == "table" and c.known[line]
			local n = 0
			if type(set) == "table" then
				for _ in pairs(set) do
					n = n + 1
				end
			end
			parts[#parts + 1] = ns.LineName(line) .. " " .. tostring(c.skills[line]) .. " (" .. n .. " recipes)"
		end
		ns.Print(key .. (key == ns.meKey and " (this character)" or "") .. ": " .. (#parts > 0 and table.concat(parts, ", ") or "no professions"))
	end
end

local function Forget(name)
	name = (name or ""):lower()
	if name == "" then
		ns.Print("/ru forget <name>: which character?")
		return
	end
	local gone = 0
	for _, key in ipairs(SortedKeys(ns.db.chars)) do
		local c = ns.db.chars[key]
		local short = type(c) == "table" and type(c.name) == "string" and c.name:lower() or ""
		if key ~= ns.meKey and (key:lower() == name or short == name) then
			ns.db.chars[key] = nil
			gone = gone + 1
			ns.Print("forgot " .. key .. ".")
		end
	end
	if gone == 0 then
		ns.Print("no other character called " .. name .. ". /ru chars lists them.")
	end
end

local function ListErrors()
	local list = ns.db.errors
	if #list == 0 then
		ns.Print("no errors logged.")
		return
	end
	for i, e in ipairs(list) do
		ns.Print(i .. ". " .. tostring(e.where) .. ": " .. tostring(e.msg))
	end
end

local HELP = {
	"/ru: open the settings.",
	"/ru chars: the characters remembered, with their professions.",
	"/ru forget <name>: drop a character you deleted or renamed.",
	"/ru errors: errors the addon caught, newest first.",
}

function ns.Slash(msg)
	msg = type(msg) == "string" and msg or ""
	local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
	cmd = (cmd or ""):lower()
	if cmd == "" or cmd == "options" or cmd == "settings" then
		ns.OpenSettings()
	elseif cmd == "chars" then
		ListCharacters()
	elseif cmd == "forget" then
		Forget(rest)
	elseif cmd == "errors" then
		ListErrors()
	else
		for _, line in ipairs(HELP) do
			ns.Print(line)
		end
	end
end

SLASH_REAGENTUSES1 = "/ru"
SLASH_REAGENTUSES2 = "/reagentuses"
SlashCmdList.REAGENTUSES = function(msg)
	if ns.db then
		ns.Try("slash", ns.Slash, msg)
	end
end

function ReagentUses_OnCompartmentClick()
	ns.Try("compartment", ns.OpenSettings)
end
