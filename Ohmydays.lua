local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local SoundService      = game:GetService("SoundService")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local ContentProvider   = game:GetService("ContentProvider") -- pra descobrir a duração do som de LMS

local ActorModule  = require(ReplicatedStorage.Modules.Actors)
local Config       = require(script.RoundConfig)
local RoundRewards = require(script.RoundRewards)
local functions    = require(script.Functions)

local roundStats     = ReplicatedStorage.Assets.RoundStats
local mapsFolder     = ServerStorage.Maps
local musicsLMS      = ServerStorage.Musics.LMS
local musicsChase    = ServerStorage.Musics.Chase
local sound30sTemplate = ServerStorage.Musics:FindFirstChild("30s") -- ajuste o nome se for diferente
if sound30sTemplate then
	sound30sTemplate.Playing = false -- proteção: o template nunca deve tocar sozinho
end

local GenEvents            = ReplicatedStorage.RemoteEvents.GeneratorEvents
local RE_FlowLayerComplete = GenEvents.FlowLayerComplete
local RE_Exit              = GenEvents.ExitGenerator
local RE_StartPuzzle       = GenEvents.StartPuzzle
local RE_GenUpdated        = GenEvents.GeneratorUpdated
local RE_PuzzleResult      = GenEvents.PuzzleResult
-- RE_ChaseMute e RE_ChaseKillerFilter foram removidos: o novo sistema de áudio
-- decide tudo localmente no client (nome do Sound + atributo IsKiller), sem remotos.

-------------------------------------------------
-- GLOBALS
-------------------------------------------------

_G.SkipRound = false              -- Set true to skip round (surv win)
_G.SkipIntermission = false       -- Set true to skip intermission
_G.RoundTimeOverride = nil        -- Set custom round time (seconds)
_G.IntermissionTimeOverride = nil -- Set custom intermission time (seconds)
_G.LMSTimeOverride = nil          -- Set custom LMS time (seconds)
_G.RoundElapsedTime = nil         -- Change elapsed time during round

-- Helper functions for getting time values
local function GetRoundTime()
	if _G.RoundTimeOverride and _G.RoundTimeOverride > 0 then
		return _G.RoundTimeOverride
	end
	return Config.RoundTime
end

local function GetIntermissionTime()
	if _G.IntermissionTimeOverride and _G.IntermissionTimeOverride > 0 then
		return _G.IntermissionTimeOverride
	end
	return Config.IntermissionTime
end

local function GetLMSTime()
	if _G.LMSTimeOverride and _G.LMSTimeOverride > 0 then
		return _G.LMSTimeOverride
	end
	return Config.LMSTime
end

-- Configuração da Chase Theme / Terror Radius
local CHASE_START_DIST = 20  -- entra em chase de verdade
local CHASE_STOP_DIST  = 75  -- sai do chase, volta pro terror radius

local TERROR_LAYER_3_DIST = 30  -- Layer 3: de 50 até CHASE_START_DIST
local TERROR_LAYER_2_DIST = 50  -- Layer 2: de 70 até 50
local TERROR_LAYER_1_DIST = 70  -- Layer 1: de 100 até 70 (acima disso, silêncio)

-------------------------------------------------
-- GENERATOR SYSTEM
-------------------------------------------------

local GeneratorSystem = {}
GeneratorSystem.__index = GeneratorSystem

function GeneratorSystem.new(config)
	local self = setmetatable({}, GeneratorSystem)
	self.config      = config
	self.generators  = {}
	self.connections = {}
	return self
end

function GeneratorSystem:GetPosition(gen)
	if not gen.SpawnPart then return Vector3.new() end
	return gen.SpawnPart.Position
end

function GeneratorSystem:Count()
	local done, total = 0, 0
	for _, g in pairs(self.generators) do
		total = total + 1
		if g.Complete then done = done + 1 end
	end
	return done, total
end

function GeneratorSystem:AllComplete()
	for _, g in pairs(self.generators) do
		if not g.Complete then return false end
	end
	return next(self.generators) ~= nil
end

function GeneratorSystem:Broadcast()
	local data = {}
	for id, g in pairs(self.generators) do
		if not g.Complete then
			table.insert(data, {
				Id        = id,
				Position  = self:GetPosition(g),
				Layers    = g.Layers,
				MaxLayers = g.MaxLayers,
				Complete  = g.Complete,
			})
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		RE_GenUpdated:FireClient(p, data)
	end
end

function GeneratorSystem:SetPromptEnabled(gen, enabled)
	if gen and gen.Prompt then gen.Prompt.Enabled = enabled end
end

function GeneratorSystem:Setup(map)
	self.generators = {}

	local folder = map:FindFirstChild("GeneratorSpawns")
	if not folder then
		warn("[Generators] No GeneratorSpawns!")
		return
	end

	for _, spawnPart in ipairs(folder:GetChildren()) do
		if spawnPart:IsA("BasePart") then
			local promptPart = spawnPart
			local prompt = Instance.new("ProximityPrompt", promptPart)
			prompt.ActionText            = "Repair"
			prompt.ObjectText            = "Generator"
			prompt.KeyboardKeyCode       = Enum.KeyCode.E
			prompt.MaxActivationDistance = self.config.InteractDistance
			prompt.HoldDuration          = 0.2

			local genName = spawnPart.Name
			self.generators[genName] = {
				SpawnPart    = spawnPart,
				Prompt       = prompt,
				Layers       = 0,
				MaxLayers    = self.config.GeneratorLayers,
				Complete     = false,
				ActivePlayer = nil,
				InitialPos   = nil,
			}

			prompt.Triggered:Connect(function(player)
				self:OnPromptTriggered(player, genName)
			end)
		end
	end

	self:Broadcast()
	self:StartProximityCheck()
end

function GeneratorSystem:OnPromptTriggered(player, genName)
	local gen = self.generators[genName]
	if not gen or gen.Complete or gen.ActivePlayer ~= nil then return end

	if self.isKillerCallback and self.isKillerCallback(player) then
		RE_PuzzleResult:FireClient(player, false, "Killers cannot repair generators!")
		return
	end

	local char = player.Character
	local hrp  = char and char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	gen.InitialPos   = hrp.Position
	gen.ActivePlayer = player
	self:SetPromptEnabled(gen, false)

	RE_StartPuzzle:FireClient(player, genName, self.config.GridSize)
end

function GeneratorSystem:OnLayerComplete(player, genId, giveRewardsCallback)
	local gen = self.generators[genId]
	if not gen or gen.Complete then return end

	gen.ActivePlayer = nil
	gen.Layers       = gen.Layers + 1
	gen.Complete     = true

	if giveRewardsCallback then
		giveRewardsCallback(
			player, false,
			self.config.Points.GenLayer + self.config.Points.GenFull,
			self.config.XP.GenLayer + self.config.XP.GenFull
		)
	end

	if gen.Prompt and gen.Prompt.Parent then
		gen.Prompt:Destroy()
		gen.Prompt = nil
	end

	RE_PuzzleResult:FireClient(player, true, "GENERATOR_COMPLETE")
	self:Broadcast()

	return self.config.TimePerLayer
end

function GeneratorSystem:OnPlayerExit(player, genId)
	local gen = self.generators[genId]
	if not gen then return end
	if gen.ActivePlayer == player then
		gen.ActivePlayer = nil
		gen.InitialPos   = nil
	end
	if not gen.Complete then
		self:SetPromptEnabled(gen, true)
	end
end

function GeneratorSystem:StartProximityCheck()
	local c = RunService.Heartbeat:Connect(function()
		for _, gen in pairs(self.generators) do
			local p = gen.ActivePlayer

			if p then
				local shouldCancel = false

				if not p:IsDescendantOf(Players) then
					shouldCancel = true
				else
					local char = p.Character
					local hrp  = char and char:FindFirstChild("HumanoidRootPart")

					if not hrp then
						shouldCancel = true
					else
						local dist = (hrp.Position - self:GetPosition(gen)).Magnitude
						if dist > self.config.InteractDistance + 4 then
							shouldCancel = true
						end

						if gen.InitialPos and (hrp.Position - gen.InitialPos).Magnitude > 3 then
							shouldCancel = true
						end
					end
				end

				if shouldCancel then
					gen.ActivePlayer = nil
					gen.InitialPos   = nil
					if not gen.Complete then
						self:SetPromptEnabled(gen, true)
					end
					RE_PuzzleResult:FireClient(p, false, "PLAYER_MOVED")
				end
			end
		end
	end)

	table.insert(self.connections, c)
end

function GeneratorSystem:SetKillerCheck(callback)
	self.isKillerCallback = callback
end

function GeneratorSystem:Cleanup()
	for _, conn in ipairs(self.connections) do
		if conn then conn:Disconnect() end
	end
	self.connections = {}
	self.generators  = {}
end

-------------------------------------------------
-- ROUND STATE
-------------------------------------------------

local RoundState = {
	active        = false,
	killer        = nil,
	killerActor   = nil,
	killerAlive   = true,
	survivors     = {},
	connections   = {},
	lmsTriggered  = false,
	lmsSound      = nil,
	timeBonus     = 0,
	timeReduction = 0,
	genSystem     = nil,
	chaseConnection        = nil,
	killerChaseActive      = false, -- true = killer deve ouvir a Chase agora
	killerChaseSound       = nil,   -- instância de Sound exclusiva do killer
	mapMusic               = nil,   -- Sound de ambiente do mapa atual
	mapMusicOriginalVolume = nil,   -- volume original, pra saber pra onde restaurar depois do duck
	sound30sPlayed         = false,
	sound30sRef            = nil,
}

-------------------------------------------------
-- HELPERS
-------------------------------------------------

local function UpdateStats(state)
	roundStats.Value = state
end

local function UpdateGeneratorStats()
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		assetsFolder = Instance.new("Folder")
		assetsFolder.Name = "Assets"
		assetsFolder.Parent = ReplicatedStorage
	end

	local generatorStats = assetsFolder:FindFirstChild("GeneratorStats")
	if not generatorStats then
		generatorStats = Instance.new("StringValue")
		generatorStats.Name = "GeneratorStats"
		generatorStats.Parent = assetsFolder
	end

	if RoundState.genSystem then
		local done, total = RoundState.genSystem:Count()
		if total > 0 then
			generatorStats.Value = string.format("Generators: %d/%d Completed", done, total)
		else
			generatorStats.Value = ""
		end
	else
		generatorStats.Value = ""
	end
end

local function DisconnectAll()
	for _, conn in ipairs(RoundState.connections) do
		if conn then conn:Disconnect() end
	end
	RoundState.connections = {}
end

local function FormatTime(seconds)
	local s = math.ceil(seconds)
	local m = math.floor(s / 60)
	s = s - m * 60
	return string.format("%d:%02d", m, s)
end

-- Baixa (duck) ou restaura o volume da música ambiente do mapa.
-- Fica baixa sempre que Chase, aviso de 30s, ou LMS estiverem ativos.
local MAP_MUSIC_DUCK_MULTIPLIER = 0.25 -- 25% do volume original enquanto abaixado
local MAP_MUSIC_DUCK_FADE_TIME  = 1

local function UpdateMapMusicDuck()
	if not RoundState.mapMusic or not RoundState.mapMusicOriginalVolume then return end

	local shouldDuck = RoundState.killerChaseActive or RoundState.sound30sPlayed or RoundState.lmsTriggered
	local targetVolume = shouldDuck
		and (RoundState.mapMusicOriginalVolume * MAP_MUSIC_DUCK_MULTIPLIER)
		or RoundState.mapMusicOriginalVolume

	TweenService:Create(RoundState.mapMusic, TweenInfo.new(MAP_MUSIC_DUCK_FADE_TIME), {Volume = targetVolume}):Play()
end

-------------------------------------------------
-- WORKSPACE FOLDERS
-------------------------------------------------

local function GetPlayersFolder()
	local folder = workspace:FindFirstChild("Players")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Players"
		folder.Parent = workspace
	end
	return folder
end

local function GetSurvivorsFolder()
	local playersFolder = GetPlayersFolder()
	local f = playersFolder:FindFirstChild("Survivors")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Survivors"
		f.Parent = playersFolder
	end
	return f
end

local function GetKillersFolder()
	local playersFolder = GetPlayersFolder()
	local f = playersFolder:FindFirstChild("Killers")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Killers"
		f.Parent = playersFolder
	end
	return f
end

-------------------------------------------------
-- COUNT HELPERS
-------------------------------------------------

local function CountAliveSurvivors()
	local count, lastData = 0, nil
	for _, data in ipairs(RoundState.survivors) do
		if data.isAlive then
			count    = count + 1
			lastData = data
		end
	end
	return count, lastData
end

-------------------------------------------------
-- EQUIPPED HELPERS
-------------------------------------------------

local function GetEquippedCharName(player, isKiller)
	local pd     = player:FindFirstChild("PlayerData")
	local actors = pd and pd:FindFirstChild("Actors")
	local eq     = actors and actors:FindFirstChild("Equipped")
	if not eq then return nil end
	local slot = eq:FindFirstChild(isKiller and "Killer" or "Survivor")
	return slot and slot.Value ~= "" and slot.Value or nil
end

local function GetEquippedSkin(player, isKiller, charName)
	if not charName then return "Default" end
	local pd     = player:FindFirstChild("PlayerData")
	local actors = pd and pd:FindFirstChild("Actors")
	local eq     = actors and actors:FindFirstChild("Equipped")
	local skins  = eq and eq:FindFirstChild("Skins")
	if not skins then return "Default" end
	local folder  = skins:FindFirstChild(isKiller and "Killer" or "Survivor")
	local skinVal = folder and folder:FindFirstChild(charName)
	return (skinVal and skinVal.Value ~= "") and skinVal.Value or "Default"
end

-------------------------------------------------
-- CHASE MUSIC / TERROR RADIUS
-------------------------------------------------

-- Usa o Humanoid pra achar o RootPart, em vez de procurar "HumanoidRootPart" pelo nome.
-- Mais confiável com rigs diferentes (R6/R15/custom) e evita falhas silenciosas.
local function GetActorRoot(actor)
	if not actor then return nil end
	local humanoid = actor:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.RootPart then
		return humanoid.RootPart
	end
	return actor:FindFirstChild("HumanoidRootPart") -- fallback
end

local function GetClosestSurvivorDistance(killerRoot)
	-- (mantido só como utilitário caso outra parte do código precise no futuro)
	local closest = math.huge
	for _, data in ipairs(RoundState.survivors) do
		if data.isAlive and data.actor and data.actor.Parent then
			local hrp = GetActorRoot(data.actor)
			if hrp then
				local dist = (hrp.Position - killerRoot.Position).Magnitude
				if dist < closest then
					closest = dist
				end
			end
		end
	end
	return closest
end

-- Busca o som certo em ServerStorage.Musics.Chase.<Killer>[.Skins.<Skin>].<stageName>
-- stageName = "Layer 1" | "Layer 2" | "Layer 3" | "Chase"
-- Fallback: pasta "Default" se o killer não tiver o estágio específico.
local function GetChaseSound(killerPlayer, stageName)
	local killerChar = GetEquippedCharName(killerPlayer, true) or "Unknown"
	local killerSkin = GetEquippedSkin(killerPlayer, true, killerChar)

	local soundToPlay = nil
	local killerFolder = musicsChase:FindFirstChild(killerChar)

	if killerFolder then
		if killerSkin ~= "Default" then
			local skinsFolder = killerFolder:FindFirstChild("Skins")
			local skinFolder  = skinsFolder and skinsFolder:FindFirstChild(killerSkin)
			if skinFolder then
				local s = skinFolder:FindFirstChild(stageName)
				if s and s:IsA("Sound") then soundToPlay = s end
			end
		end

		if not soundToPlay then
			local s = killerFolder:FindFirstChild(stageName)
			if s and s:IsA("Sound") then soundToPlay = s end
		end
	end

	if not soundToPlay then
		local defFolder = musicsChase:FindFirstChild("Default")
		local s = defFolder and defFolder:FindFirstChild(stageName)
		if s and s:IsA("Sound") then soundToPlay = s end
	end

	return soundToPlay
end

-- Duração da transição suave entre estágios (terror radius <-> chase)
local CHASE_FADE_TIME = 1

-- Troca (com fade) o som PESSOAL de UM sobrevivente. stageName == nil -> silêncio.
-- Cada sobrevivente tem seu próprio clone (nome inclui o UserId dele), então nunca
-- depende do que está acontecendo com nenhum outro sobrevivente.
local function SetSurvivorStage(data, stageName)
	if stageName == data.stage then return end

	local previous = data.sound
	if previous then
		local fadeOut = TweenService:Create(previous, TweenInfo.new(CHASE_FADE_TIME), {Volume = 0})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			previous:Stop()
			previous:Destroy()
		end)
	end
	data.sound = nil
	data.stage = stageName
	if not stageName then return end

	local template = GetChaseSound(RoundState.killer, stageName)
	if not template then
		warn("[Chase] Nenhum som encontrado pro estágio '" .. stageName .. "'")
		return
	end

	local targetVolume = template.Volume

	local clone = template:Clone()
	clone.Name   = "PersonalChase_" .. data.player.UserId -- exclusivo desse sobrevivente
	clone.Looped = true
	clone.Volume = 0 -- começa mudo e sobe suavemente
	clone.Parent = SoundService
	clone:Play()

	local fadeIn = TweenService:Create(clone, TweenInfo.new(CHASE_FADE_TIME), {Volume = targetVolume})
	fadeIn:Play()

	data.sound = clone
end

-- Decide o estágio (Layer 1/2/3/Chase/nil) pra UM sobrevivente, com histerese própria
-- (uma vez que ele entra em Chase, só sai quando o killer se afasta o suficiente DELE).
local function DetermineStage(data, dist)
	if data.chaseActive then
		if dist >= CHASE_STOP_DIST then
			data.chaseActive = false
		else
			return "Chase"
		end
	end

	if dist <= CHASE_START_DIST then
		data.chaseActive = true
		return "Chase"
	elseif dist <= TERROR_LAYER_3_DIST then
		return "Layer 3"
	elseif dist <= TERROR_LAYER_2_DIST then
		return "Layer 2"
	elseif dist <= TERROR_LAYER_1_DIST then
		return "Layer 1"
	else
		return nil
	end
end

-- Liga/desliga o tema de Chase do killer. Ele NUNCA ouve Layers — só a Chase,
-- e só quando pelo menos um sobrevivente estiver no estágio "Chase" agora.
local function SetKillerChaseActive(active)
	if active == RoundState.killerChaseActive then return end
	RoundState.killerChaseActive = active
	UpdateMapMusicDuck()

	local previous = RoundState.killerChaseSound
	if previous then
		local fadeOut = TweenService:Create(previous, TweenInfo.new(CHASE_FADE_TIME), {Volume = 0})
		fadeOut:Play()
		fadeOut.Completed:Connect(function()
			previous:Stop()
			previous:Destroy()
		end)
	end
	RoundState.killerChaseSound = nil

	if not active then return end

	local template = GetChaseSound(RoundState.killer, "Chase")
	if not template then return end

	local targetVolume = template.Volume
	local clone = template:Clone()
	clone.Name   = "KillerChaseSound" -- só o client do killer deixa esse tocar (ver LocalScript)
	clone.Looped = true
	clone.Volume = 0
	clone.Parent = SoundService
	clone:Play()

	local fadeIn = TweenService:Create(clone, TweenInfo.new(CHASE_FADE_TIME), {Volume = targetVolume})
	fadeIn:Play()

	RoundState.killerChaseSound = clone
end

local function StopChaseDetection()
	if RoundState.chaseConnection then
		RoundState.chaseConnection:Disconnect()
		RoundState.chaseConnection = nil
	end

	for _, data in ipairs(RoundState.survivors) do
		SetSurvivorStage(data, nil)
	end
	SetKillerChaseActive(false)
end

local function StartChaseDetection()
	if not RoundState.killerActor then return end

	RoundState.killerChaseActive = false
	RoundState.killerChaseSound  = nil

	RoundState.chaseConnection = RunService.Heartbeat:Connect(function()
		if not RoundState.active or not RoundState.killerAlive then return end

		local killerActor = RoundState.killerActor
		if not killerActor or not killerActor.Parent then return end

		local killerRoot = GetActorRoot(killerActor)
		if not killerRoot then return end

		local anyChase = false

		for _, data in ipairs(RoundState.survivors) do
			if data.isAlive then
				local dist = math.huge
				if data.actor and data.actor.Parent then
					local hrp = GetActorRoot(data.actor)
					if hrp then
						dist = (hrp.Position - killerRoot.Position).Magnitude
					end
				end

				local stage = DetermineStage(data, dist)
				SetSurvivorStage(data, stage)

				if stage == "Chase" then
					anyChase = true
				end
			end
		end

		SetKillerChaseActive(anyChase)
	end)
end

-------------------------------------------------
-- ALIVE DETECTION
-------------------------------------------------

local function SetupSurvivorsDetection()
	local conn = GetSurvivorsFolder().ChildRemoved:Connect(function(actorModel)
		if not RoundState.active then return end
		for _, data in ipairs(RoundState.survivors) do
			if data.actor == actorModel and data.isAlive then
				data.isAlive = false
				RoundState.timeBonus = RoundState.timeBonus + Config.KillTimeBonus
				SetSurvivorStage(data, nil) -- para o som pessoal dele direto, sem remoto
				print("[Death] Survivor", actorModel.Name, "died")
				break
			end
		end
	end)
	table.insert(RoundState.connections, conn)
end

local function SetupKillerDetection()
	local conn = GetKillersFolder().ChildRemoved:Connect(function(actorModel)
		if not RoundState.active then return end
		if actorModel == RoundState.killerActor and RoundState.killerAlive then
			RoundState.killerAlive = false
			StopChaseDetection()
			print("[Death] Killer died")
		end
	end)
	table.insert(RoundState.connections, conn)
end

-------------------------------------------------
-- LMS MUSIC
-------------------------------------------------

local function StopLMSMusic()
	if RoundState.lmsSound then
		RoundState.lmsSound:Stop()
		RoundState.lmsSound:Destroy()
		RoundState.lmsSound = nil
	end
end

-- Só ACHA o som certo pra essa dupla killer/sobrevivente, sem tocar ainda
-- (separado de PlayLMSMusic pra dar pra descobrir a duração antes de decidir o totalTime da LMS)
local function ResolveLMSSound(killerPlayer, lastSurvivorPlayer)
	local killerChar = GetEquippedCharName(killerPlayer, true)  or "Unknown"
	local killerSkin = GetEquippedSkin(killerPlayer, true, killerChar)
	local survChar   = GetEquippedCharName(lastSurvivorPlayer, false) or "Unknown"
	local survSkin   = GetEquippedSkin(lastSurvivorPlayer, false, survChar)

	local soundToPlay = nil

	local killerFolder = musicsLMS:FindFirstChild(killerChar)
	if killerFolder then
		if killerSkin ~= "Default" then
			local skinsFolder = killerFolder:FindFirstChild("Skins")
			if skinsFolder then
				local skinFolder = skinsFolder:FindFirstChild(killerSkin)
				if skinFolder then
					local s = skinFolder:FindFirstChild(survChar .. "_" .. survSkin)
					if s and s:IsA("Sound") then soundToPlay = s end
					if not soundToPlay then
						local s2 = skinFolder:FindFirstChild(survChar)
						if s2 and s2:IsA("Sound") then soundToPlay = s2 end
					end
					if not soundToPlay then
						local s3 = skinFolder:FindFirstChild("ALL")
						if s3 and s3:IsA("Sound") then soundToPlay = s3 end
					end
				end
			end
		end

		if not soundToPlay then
			local survivorsFolder = killerFolder:FindFirstChild("Survivors")
			if survivorsFolder then
				local s = survivorsFolder:FindFirstChild(survChar .. "_" .. survSkin)
				if s and s:IsA("Sound") then soundToPlay = s end
				if not soundToPlay then
					local s2 = survivorsFolder:FindFirstChild(survChar)
					if s2 and s2:IsA("Sound") then soundToPlay = s2 end
				end
			end
		end

		if not soundToPlay then
			local s = killerFolder:FindFirstChild("ALL")
			if s and s:IsA("Sound") then soundToPlay = s end
		end
	end

	if not soundToPlay then
		local def = musicsLMS:FindFirstChild("Default")
		if def and def:IsA("Sound") then soundToPlay = def end
	end

	if not soundToPlay then
		warn("[LMS] No sound found for", killerChar, "vs", survChar)
	end

	return soundToPlay
end

-- Descobre a duração (em segundos) de um Sound, pré-carregando se precisar.
-- Retorna nil se não conseguir descobrir (asset não carrega, som não encontrado, etc).
local function GetSoundDuration(soundTemplate)
	if not soundTemplate then return nil end

	if soundTemplate.TimeLength and soundTemplate.TimeLength > 0 then
		return soundTemplate.TimeLength
	end

	local ok = pcall(function()
		ContentProvider:PreloadAsync({ soundTemplate })
	end)

	if ok and soundTemplate.TimeLength and soundTemplate.TimeLength > 0 then
		return soundTemplate.TimeLength
	end

	return nil
end

local function PlayLMSMusic(killerPlayer, soundTemplate)
	StopLMSMusic()

	if not soundTemplate then
		return -- ResolveLMSSound já deu warn se não achou nada
	end

	local clone = soundTemplate:Clone()
	clone.TimePosition = 0
	clone.Parent = SoundService
	clone:Play()
	RoundState.lmsSound = clone

	require(game.ReplicatedStorage.Modules.Layers).RemovePlayerMusic(killerPlayer)

	print("[LMS] Playing:", soundTemplate:GetFullName())
end

-------------------------------------------------
-- 30 SECONDS WARNING SOUND
-------------------------------------------------

local function StopSound30s()
	if RoundState.sound30sRef then
		RoundState.sound30sRef:Stop()
		RoundState.sound30sRef:Destroy()
		RoundState.sound30sRef = nil
	end
end

-- Chamado quando um timeBonus empurra o timer de volta pra cima de 30s:
-- dá fade out suave em vez de cortar seco, e libera pra tocar de novo depois.
local function FadeOutSound30s()
	if not RoundState.sound30sRef then return end
	local snd = RoundState.sound30sRef
	RoundState.sound30sRef = nil

	local tween = TweenService:Create(snd, TweenInfo.new(1), {Volume = 0})
	tween:Play()
	tween.Completed:Connect(function()
		snd:Stop()
		snd:Destroy()
	end)
end

local function PlaySound30s()
	if RoundState.sound30sPlayed then return end
	if RoundState.lmsTriggered then return end -- LMS não conta
	if not sound30sTemplate then
		warn("[Warning30s] Som '30s' não encontrado em ServerStorage.Musics")
		return
	end

	RoundState.sound30sPlayed = true
	UpdateMapMusicDuck()

	local clone = sound30sTemplate:Clone()
	clone.Name   = "Warning30sSound"
	clone.Parent = SoundService
	clone:Play()
	RoundState.sound30sRef = clone
end

-------------------------------------------------
-- LMS HIGHLIGHTS
-------------------------------------------------

local function CreateLMSHighlights()
	if RoundState.killerActor and RoundState.killerActor.Parent then
		local h = Instance.new("Highlight")
		h.FillColor           = Color3.fromRGB(255, 30, 30)
		h.OutlineColor        = Color3.fromRGB(200, 0, 0)
		h.FillTransparency    = 0.5
		h.OutlineTransparency = 0
		h.Parent = RoundState.killerActor
		game:GetService("Debris"):AddItem(h, 7)
	end

	local _, lastData = CountAliveSurvivors()
	if lastData and lastData.actor and lastData.actor.Parent then
		local h = Instance.new("Highlight")
		h.FillColor           = Color3.fromRGB(255, 200, 50)
		h.OutlineColor        = Color3.fromRGB(255, 160, 0)
		h.FillTransparency    = 0.5
		h.OutlineTransparency = 0
		h.Parent = lastData.actor
		game:GetService("Debris"):AddItem(h, 7)
	end
end

-------------------------------------------------
-- ACTOR HELPERS
-------------------------------------------------

local function GetSpawnCFrame(map, isKiller)
	local folder = map:FindFirstChild(isKiller and "KillerSpawns" or "SurvivorSpawns")
	if not folder then return nil end
	local spawns = folder:GetChildren()
	if #spawns == 0 then return nil end
	return spawns[math.random(1, #spawns)].CFrame
end

local function CreateActor(player, isKiller, map)
	if not player or not player:IsDescendantOf(Players) then return nil end
	local cf       = GetSpawnCFrame(map, isKiller)
	if not cf then return nil end
	local charName = GetEquippedCharName(player, isKiller)
	if not charName then return nil end
	local skin     = GetEquippedSkin(player, isKiller, charName)
	return ActorModule:CreateActor(player, charName, isKiller, skin, cf)
end

-------------------------------------------------
-- MAP
-------------------------------------------------

-- Nome do mapa (em ServerStorage.Maps) -> nome do Sound de ambiente (solto em Workspace).
-- Só precisa de entrada aqui quando o nome for diferente; por padrão, usa o mesmo nome do mapa.
local MAP_MUSIC_OVERRIDES = {
	["The Florest"] = "Florest",
}

local function GetMapMusicName(mapName)
	return MAP_MUSIC_OVERRIDES[mapName] or mapName
end

-- Para a música de ambiente do mapa anterior, se estiver tocando
local function StopMapMusic()
	if RoundState.mapMusic then
		if RoundState.mapMusicOriginalVolume then
			RoundState.mapMusic.Volume = RoundState.mapMusicOriginalVolume -- restaura antes de soltar a referência
		end
		RoundState.mapMusic:Stop()
		RoundState.mapMusic = nil
	end
	RoundState.mapMusicOriginalVolume = nil
end

-- Toca a música de ambiente correspondente ao mapa que acabou de ser selecionado
local function PlayMapMusic(mapName)
	StopMapMusic()

	local musicName = GetMapMusicName(mapName)
	local sound = workspace:FindFirstChild(musicName)

	if sound and sound:IsA("Sound") then
		sound.Looped = true
		sound:Play()
		RoundState.mapMusic = sound
		RoundState.mapMusicOriginalVolume = sound.Volume
		UpdateMapMusicDuck() -- reflete o estado atual (ex: se já tiver LMS ativa por algum motivo)
	else
		warn("[MapMusic] Nenhum Sound chamado '" .. musicName .. "' encontrado em Workspace")
	end
end

local function SelectMap()
	local maps = mapsFolder:GetChildren()
	if #maps == 0 then warn("[Round] No maps!"); return nil end
	local map   = maps[math.random(1, #maps)]
	local clone = map:Clone()
	local folder = workspace:FindFirstChild("Map") or Instance.new("Folder")
	folder.Name   = "Map"
	folder.Parent = workspace
	clone.Parent  = folder
	UpdateStats("Map: " .. clone.Name)
	PlayMapMusic(clone.Name)
	task.wait(3)
	return clone
end

local function DestroyMap(map)
	StopMapMusic()
	if map and map.Parent then map:Destroy() end
end

-------------------------------------------------
-- KILLER SELECTION
-------------------------------------------------

local function SelectKiller()
	local players = Players:GetPlayers()
	if #players == 0 then return nil end
	local best, bestChance = nil, -1
	for _, p in ipairs(players) do
		local ls = p:FindFirstChild("leaderstats")
		local kc = ls and ls:FindFirstChild("KillerChance")
		if kc and kc.Value > bestChance then bestChance = kc.Value; best = p end
	end
	if not best then best = players[math.random(1, #players)] end
	for _, p in ipairs(players) do
		local ls = p:FindFirstChild("leaderstats")
		local kc = ls and ls:FindFirstChild("KillerChance")
		if kc then kc.Value = (p == best) and 0 or (kc.Value + 1) end
	end
	return best
end

-------------------------------------------------
-- ROUND LOOP
-------------------------------------------------

local function BuildStatusText(remaining)
	if RoundState.lmsTriggered then
		return string.format("LMS\nTime: %s", FormatTime(remaining))
	else
		return string.format("Round Ends in %s", FormatTime(remaining))
	end
end

local function RunRound()
	local elapsed   = 0
	local totalTime = GetRoundTime()

	while elapsed < totalTime do
		if _G.RoundElapsedTime and _G.RoundElapsedTime >= 0 then
			elapsed = _G.RoundElapsedTime
		end

		if _G.SkipRound then
			_G.SkipRound = false
			print("[Round] Round skipped (survivors win)")
			return "Survivors"
		end

		if #Players:GetPlayers() < Config.MinPlayers then
			return "Cancelled"
		end

		if RoundState.timeReduction > 0 then
			totalTime = math.max(elapsed + 1, totalTime - RoundState.timeReduction)
			RoundState.timeReduction = 0
		end
		if RoundState.timeBonus > 0 then
			totalTime = totalTime + RoundState.timeBonus
			RoundState.timeBonus = 0
		end

		local alive, lastData = CountAliveSurvivors()

		if not RoundState.killerAlive then
			StopSound30s()
			StopLMSMusic()
			return "Survivors"
		end

		if alive == 0 then
			StopSound30s()
			StopLMSMusic()
			return "Killer"
		end

		if alive == 1 and not RoundState.lmsTriggered then
			RoundState.lmsTriggered = true
			UpdateMapMusicDuck()
			CreateLMSHighlights()
			StopChaseDetection() -- evita sobrepor Chase com a música de LMS
			StopSound30s()       -- LMS não conta pro aviso de 30s

			-- A duração da LMS acompanha o tamanho do som escolhido.
			-- Só cai no GetLMSTime() (RoundConfig) como fallback se não achar som/duração.
			local lmsSoundTemplate = lastData and ResolveLMSSound(RoundState.killer, lastData.player) or nil
			local lmsDuration = GetSoundDuration(lmsSoundTemplate) or GetLMSTime()
			totalTime = elapsed + lmsDuration

			if lastData and RoundState.killer then
				task.spawn(function()
					PlayLMSMusic(RoundState.killer, lmsSoundTemplate)
				end)
			end
		end

		-- Aviso de 30 segundos (não conta durante LMS)
		if not RoundState.lmsTriggered then
			local remaining = totalTime - elapsed
			if remaining <= 30 then
				PlaySound30s()
			elseif RoundState.sound30sPlayed then
				-- timeBonus empurrou o timer de volta pra cima de 30s
				FadeOutSound30s()
				RoundState.sound30sPlayed = false
				UpdateMapMusicDuck()
			end
		end

		UpdateStats(BuildStatusText(totalTime - elapsed))
		UpdateGeneratorStats()
		task.wait(1)
		elapsed = elapsed + 1
	end

	StopSound30s()
	StopLMSMusic()
	return "Survivors"
end

-------------------------------------------------
-- CLEANUP
-------------------------------------------------

local function Cleanup()
	StopChaseDetection()
	StopSound30s()
	StopLMSMusic()
	StopMapMusic()
	DisconnectAll()

	if RoundState.genSystem then
		RoundState.genSystem:Cleanup()
	end

	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if assetsFolder then
		local generatorStats = assetsFolder:FindFirstChild("GeneratorStats")
		if generatorStats then
			generatorStats.Value = ""
		end
	end

	RoundState.active         = false
	RoundState.killer         = nil
	RoundState.killerActor    = nil
	RoundState.killerAlive    = true
	RoundState.survivors      = {}
	RoundState.timeBonus      = 0
	RoundState.timeReduction  = 0
	RoundState.lmsTriggered   = false
	RoundState.lmsSound       = nil
	RoundState.genSystem      = nil
	RoundState.sound30sPlayed = false
	RoundState.sound30sRef    = nil

	for _, player in ipairs(Players:GetPlayers()) do
		ActorModule:DestroyActor(player)
	end
end

-------------------------------------------------
-- INTERMISSION
-------------------------------------------------

local function Intermission()
	local timeLeft = GetIntermissionTime()
	for i = timeLeft, 1, -1 do
		if _G.SkipIntermission then
			_G.SkipIntermission = false
			print("[Intermission] Intermission skipped")
			break
		end

		UpdateStats("Next round in " .. i .. "s")
		task.wait(1)
	end
end

-------------------------------------------------
-- CALLBACKS
-------------------------------------------------

local function IsPlayerKiller(player)
	return player == RoundState.killer
end

local function GiveGenRewards(player, isKiller, points, xp)
	RoundRewards:GivePoints(player, points)
	RoundRewards:GiveCharXP(player, isKiller, xp)
end

-------------------------------------------------
-- REMOTE EVENTS
-------------------------------------------------

RE_FlowLayerComplete.OnServerEvent:Connect(function(player, genId)
	if not RoundState.active or not RoundState.genSystem then return end
	local reduction = RoundState.genSystem:OnLayerComplete(player, genId, GiveGenRewards)
	if reduction then
		RoundState.timeReduction = RoundState.timeReduction + reduction
	end
	UpdateGeneratorStats()
end)

RE_Exit.OnServerEvent:Connect(function(player, genId)
	if RoundState.genSystem then
		RoundState.genSystem:OnPlayerExit(player, genId)
	end
end)

-------------------------------------------------
-- MAIN LOOP
-------------------------------------------------

-- Uma rodada completa. Os "return" no meio substituem os antigos "continue".
local function PlayOneRound()
	local killer = SelectKiller()
	local map    = SelectMap()

	if not killer or not map then
		if map then DestroyMap(map) end
		Cleanup()
		return
	end

	RoundState.active         = true
	RoundState.killer         = killer
	RoundState.killerActor    = nil
	RoundState.killerAlive    = true
	RoundState.survivors      = {}
	RoundState.timeBonus      = 0
	RoundState.timeReduction  = 0
	RoundState.lmsTriggered   = false
	RoundState.lmsSound       = nil
	RoundState.sound30sPlayed = false
	RoundState.sound30sRef    = nil

	for _, p in ipairs(Players:GetPlayers()) do -- pra filtrar layers no client do killer
		p:SetAttribute("IsKiller", p == killer)
	end

	GetPlayersFolder()
	GetSurvivorsFolder()
	GetKillersFolder()

	RoundState.genSystem = GeneratorSystem.new(Config)
	RoundState.genSystem:SetKillerCheck(IsPlayerKiller)
	RoundState.genSystem:Setup(map)

	UpdateStats("Creating Survivors...")
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= killer and player:IsDescendantOf(Players) then
			local actor = CreateActor(player, false, map)
			if actor then
				table.insert(RoundState.survivors, {
					player      = player,
					actor       = actor,
					isAlive     = true,
					stage       = nil,   -- estágio atual ("Layer 1/2/3"/"Chase"/nil)
					chaseActive = false, -- histerese própria desse sobrevivente
					sound       = nil,   -- instância de Sound pessoal dele
				})
			end
		end
	end

	if #RoundState.survivors == 0 then
		warn("[Round] No survivors.")
		DestroyMap(map)
		Cleanup()
		return
	end

	SetupSurvivorsDetection()
	SetupKillerDetection()

	task.wait(1)

	UpdateStats("Creating Killer...")
	if killer:IsDescendantOf(Players) then
		RoundState.killerActor = CreateActor(killer, true, map)
	end

	task.wait(2)

	StartChaseDetection()

	local winner = RunRound()

	if winner == "Cancelled" then
		UpdateStats("Round Cancelled - Not enough players")
		Cleanup()
		task.wait(0.5)
		DestroyMap(map)
		task.wait(Config.ResultDisplayTime)
	elseif winner == "Killer" then
		UpdateStats("Killer Wins!")
		functions:ShowKillerWin(RoundState.killerActor)
		RoundRewards:DistributeRewards(Config, RoundState.killer, RoundState.survivors, winner)
		Cleanup()
		task.wait(0.5)
		DestroyMap(map)
		task.wait(Config.ResultDisplayTime)
	else
		local reason = not RoundState.killerAlive
			and "Killer Eliminated — Survivors Win!"
			or  "Survivors Win!"
		UpdateStats(reason)
		functions:ShowSurvivorsWin()
		task.wait(0.5)
		RoundRewards:DistributeRewards(Config, RoundState.killer, RoundState.survivors, winner)
		Cleanup()
		task.wait(0.5)
		DestroyMap(map)
		task.wait(Config.ResultDisplayTime)
	end
end

task.spawn(function()
	task.wait(2)

	while true do
		repeat
			local count = #Players:GetPlayers()
			UpdateStats(string.format("Waiting for players... (%d/%d)", count, Config.MinPlayers))
			task.wait(1)
		until #Players:GetPlayers() >= Config.MinPlayers

		Intermission()
		PlayOneRound()
	end
end)
