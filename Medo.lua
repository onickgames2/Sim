-- Lua 5.1 (Roblox 2016)
local Config    = require(game.ReplicatedStorage.Modules.Animation:WaitForChild("Config"))
local Functions = require(game.ReplicatedStorage.Modules.Animation:WaitForChild("Functions"))

local RunSvc     = game:GetService("RunService")
local RepStorage = game:GetService("ReplicatedStorage")
local Players    = game:GetService("Players")

local PlayAnimationState = RepStorage:WaitForChild("PlayAnimationState", 20)
local SyncCharacterType  = RepStorage:WaitForChild("SyncCharacterType",  20)

if not PlayAnimationState or not SyncCharacterType then return end

local LocalPlayer       = Players.LocalPlayer
local CharacterStates   = {}
local StrafingRotations = {}
local NeckOriginalC0    = {}
local AnimationOffsets  = {}
local AnimLitePaused    = {}
local R6SequencePlayer  = Functions.R6SequencePlayer

-------------------------------------------------
-- Helpers (Attributes -> ValueObjects filhos do personagem)
-------------------------------------------------

local function getValue(obj, name)
	local v = obj:FindFirstChild(name)
	if v and v:IsA("ValueBase") then return v.Value end
	return nil
end

-- Chama fn quando o ValueObject "name" for criado, removido ou mudar
local function onValueChanged(obj, name, fn)
	for _, c in ipairs(obj:GetChildren()) do
		if c.Name == name and c:IsA("ValueBase") then
			c.Changed:Connect(fn)
		end
	end
	obj.ChildAdded:Connect(function(c)
		if c.Name == name then
			if c:IsA("ValueBase") then c.Changed:Connect(fn) end
			fn()
		end
	end)
	obj.ChildRemoved:Connect(function(c)
		if c.Name == name then fn() end
	end)
end

local function isSpectating(character)
	return character and character.Parent and character.Parent.Name == "Spectating"
end

local function getRoleFromCharacter(character)
	return getValue(character, "IsKiller") and "Killers" or "Survivors"
end

local function getCharacterNameForPlayer(character)
	if not character then return "Default", nil end

	local charName = getValue(character, "CharName") or "Default"
	local skinName = getValue(character, "Character") or "Default"
	local isSkin   = getValue(character, "IsSkin") == true

	-- Se nao e skin customizada, skinName deve ser nil
	if not isSkin or skinName == "Default" then
		skinName = nil
	end

	return charName, skinName
end

local function loadAnimations(characterName, skinName, role)
	local AnimationsFolder = RepStorage:FindFirstChild("Animations")
	if not AnimationsFolder then return nil end
	local roleFolder = AnimationsFolder:FindFirstChild(role)
	if not roleFolder then return nil end

	local animFolder = nil

	if skinName and skinName ~= "" then
		local charFolder = roleFolder:FindFirstChild(characterName)
		if charFolder then
			local skinsF = charFolder:FindFirstChild("Skins")
			if skinsF then
				local skinF = skinsF:FindFirstChild(skinName)
				if skinF then animFolder = skinF end
			end
		end
	end

	if not animFolder then
		local charFolder = roleFolder:FindFirstChild(characterName)
		if charFolder then
			local def = charFolder:FindFirstChild("Default")
			if def then animFolder = def end
		end
	end

	if not animFolder then
		local defChar = roleFolder:FindFirstChild("Default")
		if defChar then animFolder = defChar:FindFirstChild("Default") end
	end

	if not animFolder then return nil end

	if role == "Killers" then
		return {
			Idle = animFolder:FindFirstChild("Idle"),
			Walk = animFolder:FindFirstChild("Walk"),
			Run  = animFolder:FindFirstChild("Run"),
		}
	else
		return {
			Idle         = animFolder:FindFirstChild("Idle"),
			Idle_Injured = animFolder:FindFirstChild("Idle_Injured"),
			Walk         = animFolder:FindFirstChild("Walk"),
			Walk_Injured = animFolder:FindFirstChild("Walk_Injured"),
			Run          = animFolder:FindFirstChild("Run"),
			Run_Injured  = animFolder:FindFirstChild("Run_Injured"),
		}
	end
end

-------------------------------------------------
-- Strafing
-------------------------------------------------

-- Animator nao existia em 2016: so remove o script Animate
local function disableDefaultAnims(character)
	local animate = character:FindFirstChild("Animate")
	if animate then animate:Destroy() end
end

local function initStrafing(character)
	if StrafingRotations[character] then return end
	local torso = character:FindFirstChild("Torso")
	if torso then
		local neck = torso:FindFirstChild("Neck")
		if neck then NeckOriginalC0[character] = neck.C0 end
	end
	local function emptySet()
		return {
			RootJoint = CFrame.new(), Neck = CFrame.new(),
			RightShoulder = CFrame.new(), LeftShoulder = CFrame.new(),
			RightHip = CFrame.new(), LeftHip = CFrame.new(),
		}
	end
	StrafingRotations[character] = { Target = emptySet(), Current = emptySet() }
	AnimationOffsets[character]  = {}
end

local function updateStrafing(character)
	if not Config.STRAFING.Enabled then return end
	local data = StrafingRotations[character]
	if not data then return end
	local humanoid = character:FindFirstChild("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local torso    = character:FindFirstChild("Torso")
	if not humanoid or not rootPart or not torso then return end

	local moveDir     = humanoid.MoveDirection
	local relativeDir = Vector3.new(0, 0, 0)
	if moveDir.Magnitude > 0.1 then
		relativeDir = rootPart.CFrame:VectorToObjectSpace(moveDir)
	end

	if relativeDir.Magnitude < 0.1 then
		data.Target.RootJoint     = CFrame.new()
		data.Target.Neck          = CFrame.new()
		data.Target.RightShoulder = CFrame.new()
		data.Target.LeftShoulder  = CFrame.new()
		data.Target.RightHip      = CFrame.new()
		data.Target.LeftHip       = CFrame.new()
	else
		local ft  = math.rad(-relativeDir.Z * Config.STRAFING.ForwardTilt)      * Config.STRAFING.TiltIntensity
		local st  = math.rad(-relativeDir.X * Config.STRAFING.SideTilt)         * Config.STRAFING.TiltIntensity
		local shr = math.rad(-relativeDir.X * Config.STRAFING.ShoulderRotation) * Config.STRAFING.TiltIntensity
		local hr  = math.rad(-relativeDir.X * Config.STRAFING.HipRotation)      * Config.STRAFING.TiltIntensity
		data.Target.RootJoint     = CFrame.Angles(ft, 0, st)
		data.Target.Neck          = CFrame.Angles(-ft * Config.STRAFING.NeckCompensation, 0, -st * Config.STRAFING.NeckCompensation)
		data.Target.RightShoulder = CFrame.Angles(0, shr, 0)
		data.Target.LeftShoulder  = CFrame.Angles(0, shr, 0)
		data.Target.RightHip      = CFrame.Angles(0, hr,  0)
		data.Target.LeftHip       = CFrame.Angles(0, hr,  0)
	end

	local ls = Config.STRAFING.LerpSpeed
	local hs = Config.STRAFING.HeadFollowSpeed
	data.Current.RootJoint     = data.Current.RootJoint:Lerp(data.Target.RootJoint, ls)
	data.Current.Neck          = data.Current.Neck:Lerp(data.Target.Neck, hs)
	data.Current.RightShoulder = data.Current.RightShoulder:Lerp(data.Target.RightShoulder, ls)
	data.Current.LeftShoulder  = data.Current.LeftShoulder:Lerp(data.Target.LeftShoulder, ls)
	data.Current.RightHip      = data.Current.RightHip:Lerp(data.Target.RightHip, ls)
	data.Current.LeftHip       = data.Current.LeftHip:Lerp(data.Target.LeftHip, ls)
end

local function getStrafingRotation(character, motorName)
	local strafingOffset = CFrame.new()
	if Config.STRAFING.Enabled then
		local data = StrafingRotations[character]
		if data then strafingOffset = data.Current[motorName] or CFrame.new() end
	end
	local animOffset = CFrame.new()
	if AnimationOffsets[character] and AnimationOffsets[character][motorName] then
		animOffset = AnimationOffsets[character][motorName]
	end
	return strafingOffset * animOffset
end

local function setAnimationOffset(character, motorName, offset)
	if not AnimationOffsets[character] then AnimationOffsets[character] = {} end
	AnimationOffsets[character][motorName] = offset
end

RunSvc.Heartbeat:Connect(function()
	for character in pairs(StrafingRotations) do
		if character and character.Parent then
			updateStrafing(character)
		else
			StrafingRotations[character] = nil
			NeckOriginalC0[character]    = nil
			AnimationOffsets[character]  = nil
		end
	end
end)

-------------------------------------------------
-- Setup de personagem remoto
-------------------------------------------------

local function setupCharacter(character, owner)
	if owner == LocalPlayer then return nil end
	if isSpectating(character) then return nil end

	disableDefaultAnims(character)
	initStrafing(character)

	local role = getRoleFromCharacter(character)
	local characterName, skinName = getCharacterNameForPlayer(character)
	local animations = loadAnimations(characterName, skinName, role)
	if not animations then return nil end

	local animPlayers = {}
	for stateName, animAsset in pairs(animations) do
		if animAsset then
			animPlayers[stateName] = R6SequencePlayer.new(character, animAsset, true)
		end
	end
	for _, p in pairs(animPlayers) do
		pcall(function() p:Load(Config) end)
	end

	local stateTable = {
		Players          = animPlayers,
		PlayingAnimation = "Idle",
		LastAnimation    = "",
		DesiredState     = "Idle",
	}
	CharacterStates[character] = stateTable
	AnimLitePaused[character]  = false

	local humanoid = character:FindFirstChild("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			CharacterStates[character]   = nil
			StrafingRotations[character] = nil
			AnimationOffsets[character]  = nil
			AnimLitePaused[character]    = nil
		end)
	end

	return stateTable
end

-------------------------------------------------
-- Stop / Apply
-------------------------------------------------

local function stopCurrentAnimation(data)
	local p = data.Players[data.PlayingAnimation]
	if p and p.IsPlaying then
		pcall(function() p:Stop(Config) end)
	end
	data.LastAnimation    = data.PlayingAnimation
	data.PlayingAnimation = ""
end

local function applyState(character, newState)
	if not character or not character.Parent then return end
	if isSpectating(character) then return end
	local data = CharacterStates[character]
	if not data then return end

	data.DesiredState = newState
	if AnimLitePaused[character] then return end
	if data.PlayingAnimation == newState then return end

	stopCurrentAnimation(data)

	local playerToPlay = data.Players[newState]
	if playerToPlay and not playerToPlay.IsDead then
		pcall(function()
			playerToPlay:Play(Config, function(char, motorName, offset)
				setAnimationOffset(char, motorName, offset)
				return getStrafingRotation(char, motorName)
			end)
			data.PlayingAnimation = newState
		end)
	end
end

-------------------------------------------------
-- AnimationLite
-- (agora e um ValueObject "AnimationLitePlaying" dentro do personagem:
--  existe = animacao do AnimationLite tocando)
-------------------------------------------------

local function isAnimLiteActive(character)
	if not character or not character.Parent then return false end
	return character:FindFirstChild("AnimationLitePlaying") ~= nil
end

local function watchAnimLite(character)
	onValueChanged(character, "AnimationLitePlaying", function()
		local active = isAnimLiteActive(character)
		if active and not AnimLitePaused[character] then
			AnimLitePaused[character] = true
			local data = CharacterStates[character]
			if data then stopCurrentAnimation(data) end
		elseif not active and AnimLitePaused[character] then
			AnimLitePaused[character] = false
			local data = CharacterStates[character]
			if data then
				data.PlayingAnimation = ""
				applyState(character, data.DesiredState or "Idle")
			end
		end
	end)
end

-------------------------------------------------
-- Monitoramento de mudanca de personagem
-------------------------------------------------

local function setupAttributeMonitoring(character, owner)
	local lastCharName, lastSkinName = getCharacterNameForPlayer(character)

	local function checkCharacterChange()
		if not character or not character.Parent then return end

		local currentCharName, currentSkinName = getCharacterNameForPlayer(character)

		-- Detectou mudanca de personagem
		if currentCharName ~= lastCharName then
			local data = CharacterStates[character]
			if data then
				data.PlayingAnimation = ""
				data.DesiredState = "Idle"
				applyState(character, "Idle")
			end
		end

		lastCharName = currentCharName
		lastSkinName = currentSkinName
	end

	onValueChanged(character, "CharName",  checkCharacterChange)
	onValueChanged(character, "Character", checkCharacterChange)
	onValueChanged(character, "IsSkin",    checkCharacterChange)
end

-------------------------------------------------
-- Verificacao periodica
-------------------------------------------------

spawn(function()
	while true do
		wait(1)
		for character, data in pairs(CharacterStates) do
			if character and character.Parent then
				if isAnimLiteActive(character) then
					if not AnimLitePaused[character] then
						AnimLitePaused[character] = true
						stopCurrentAnimation(data)
					end
				elseif data.PlayingAnimation ~= data.DesiredState then
					data.PlayingAnimation = ""
					applyState(character, data.DesiredState or "Idle")
				end
			end
		end
	end
end)

-------------------------------------------------
-- RemoteEvents
-------------------------------------------------

PlayAnimationState.OnClientEvent:Connect(function(targetPlayer, newState)
	if targetPlayer == LocalPlayer then return end
	if targetPlayer.Character then
		applyState(targetPlayer.Character, newState)
	end
end)

SyncCharacterType.OnClientEvent:Connect(function(targetPlayer)
	if targetPlayer == LocalPlayer then return end
	if targetPlayer.Character then
		CharacterStates[targetPlayer.Character]   = nil
		StrafingRotations[targetPlayer.Character] = nil
		AnimationOffsets[targetPlayer.Character]  = nil
		AnimLitePaused[targetPlayer.Character]    = nil
		setupCharacter(targetPlayer.Character, targetPlayer)
	end
end)

-------------------------------------------------
-- Player added
-------------------------------------------------

local function onPlayerAdded(player)
	if player == LocalPlayer then return end

	local function onCharacterAdded(character)
		wait(0.5)
		setupCharacter(character, player)
		setupAttributeMonitoring(character, player)
		watchAnimLite(character)
		applyState(character, "Idle")
	end

	if player.Character then
		spawn(function() onCharacterAdded(player.Character) end)
	end

	player.CharacterAdded:Connect(onCharacterAdded)
end

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
