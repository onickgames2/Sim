-- Lua 5.1
local Players = game:GetService("Players")
local config  = require(game.ServerStorage.Config.DataSaver)
local initial = config.Initial

local function CreateFolder(name, parent)
	local f  = Instance.new("Folder")
	f.Name   = name
	f.Parent = parent
	return f
end

local function CreateString(name, value, parent)
	local v  = Instance.new("StringValue")
	v.Name   = name
	v.Value  = value
	v.Parent = parent
	return v
end

local function CreateNumber(name, value, parent)
	local v  = Instance.new("NumberValue")
	v.Name   = name
	v.Value  = value
	v.Parent = parent
	return v
end

local function CreateInt(name, value, parent)
	local v  = Instance.new("IntValue")
	v.Name   = name
	v.Value  = value
	v.Parent = parent
	return v
end

local function CreateBool(name, value, parent)
	local v  = Instance.new("BoolValue")
	v.Name   = name
	v.Value  = value
	v.Parent = parent
	return v
end

Players.PlayerAdded:Connect(function(plr)

	--> leaderstats
	local leader = CreateFolder("leaderstats", plr)
	CreateNumber("Points",       initial.Points, leader)
	CreateNumber("KillerChance", 0,              leader)

	--> PlayerData
	local playerData = CreateFolder("PlayerData", plr)
	CreateInt("TimePlayed", 0, playerData)

	--> Round
	local round = CreateFolder("Round", playerData)
	CreateInt("KillerLoses",   0, round)
	CreateInt("SurvivorLoses", 0, round)
	CreateInt("KillerWins",    0, round)
	CreateInt("SurvivorWins",  0, round)

	--> Config (substituiu Achievements)
	local configFolder = CreateFolder("Config", playerData)
	CreateBool("ShowBoxes",       true,  configFolder)
	CreateBool("ShowVersionInfo", false, configFolder)
	CreateBool("ShowColision",    false, configFolder)
	CreateBool("SkipCutscene",    false, configFolder)
	CreateBool("HitLinger",       false, configFolder)

	--> Actors
	local actors = CreateFolder("Actors", playerData)

	-- Killer
	local killerFolder = CreateFolder("Killer", actors)
	local initKiller   = CreateBool(initial.Killer, true, killerFolder)
	CreateInt("XP", 0, initKiller)
	CreateInt("Level", 0, initKiller)
	local initKillerSkins = CreateFolder("Skins", initKiller)

	-- Survivor
	local survFolder = CreateFolder("Survivor", actors)
	local initSurv   = CreateBool(initial.Survivor, true, survFolder)
	CreateInt("XP", 0, initSurv)
	CreateInt("Level", 0, initSurv)
	local initSurvSkins = CreateFolder("Skins", initSurv)

	-- Equipped
	local equipped = CreateFolder("Equipped", actors)
	CreateString("Killer",   initial.Killer,   equipped)
	CreateString("Survivor", initial.Survivor, equipped)

	local skinsEq    = CreateFolder("Skins",    equipped)
	local killerSkEq = CreateFolder("Killer",   skinsEq)
	local survSkEq   = CreateFolder("Survivor", skinsEq)

	CreateString(initial.Killer,   "Default", killerSkEq)
	CreateString(initial.Survivor, "Default", survSkEq)
end)

-- ===== INICIO DO TRECHO DE PROXIMITYPROMPT (apague se der erro) =====
for _, d in ipairs(game:GetDescendants()) do
	if d:IsA("ProximityPrompt") then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end

game.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end)
-- ===== FIM DO TRECHO DE PROXIMITYPROMPT =====
