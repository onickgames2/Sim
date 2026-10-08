local RunSvc = game:GetService("RunService")
local Players = game:GetService("Players")
local RepStorage = game:GetService("ReplicatedStorage")

-- Threshold em porcentagem (50% = quando vida cai abaixo de 50% da MaxHealth)
local INJURED_THRESHOLD = 0.50

local PlayAnimationState = RepStorage:FindFirstChild("PlayAnimationState")
if not PlayAnimationState then
    PlayAnimationState = Instance.new("RemoteEvent")
    PlayAnimationState.Name = "PlayAnimationState"
    PlayAnimationState.Parent = RepStorage
end

local SyncCharacterType = RepStorage:FindFirstChild("SyncCharacterType")
if not SyncCharacterType then
    SyncCharacterType = Instance.new("RemoteEvent")
    SyncCharacterType.Name = "SyncCharacterType"
    SyncCharacterType.Parent = RepStorage
end

local SetAnimationState = RepStorage:FindFirstChild("SetAnimationState")
if not SetAnimationState then
    SetAnimationState = Instance.new("RemoteEvent")
    SetAnimationState.Name = "SetAnimationState"
    SetAnimationState.Parent = RepStorage
end

local PlayerCharacterTypes = {}
local PlayerCurrentStates = {}
local PlayerIsInjured = {}

local VALID_STATES = {
    Idle = true,
    Idle_Injured = true,
    Walk = true,
    Walk_Injured = true,
    Run = true,
    Run_Injured = true
}

local function getCharacterType(character)
    if not character then return "Survivor", "Default", nil end

    local charName = character:GetAttribute("CharName") or "Default"
    local skinName = character:GetAttribute("Character") or "Default"
    local isKiller = character:GetAttribute("IsKiller") == true
    local isSkin = character:GetAttribute("IsSkin") == true

    -- Se não é skin customizada, skinName deve ser nil
    if not isSkin or skinName == "Default" then
        skinName = nil
    end

    return isKiller and "Killer" or "Survivor", charName, skinName
end

local function validateState(player, state)
    if not VALID_STATES[state] then
        return false
    end
    return true
end

local function fireToAllClients(playerOwner, newState)
    for _, player in ipairs(Players:GetPlayers()) do
        PlayAnimationState:FireClient(player, playerOwner, newState)
    end
end

local function syncCharacterTypeToAll(playerOwner, characterType, characterName)
    for _, player in ipairs(Players:GetPlayers()) do
        SyncCharacterType:FireClient(player, playerOwner, characterType, characterName)
    end
end

local function getStateWithInjuryStatus(baseState, isInjured)
    if not isInjured then
        return (baseState:gsub("_Injured$", ""))
    else
        if not baseState:match("_Injured$") then
            return baseState .. "_Injured"
        end
        return baseState
    end
end

local function getBaseState(state)
    return (state:gsub("_Injured$", ""))
end

local function setupHealthMonitoring(player, character)
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return end

    local characterType = PlayerCharacterTypes[player]
    if not characterType or characterType.Type ~= "Survivor" then
        return
    end

    PlayerIsInjured[player] = false

    local function updateInjuredState()
        if not humanoid or not humanoid.Parent then return end
        if humanoid.Health <= 0 then return end

        local healthPercent = humanoid.Health / humanoid.MaxHealth
        local wasInjured = PlayerIsInjured[player]
        local isInjured = healthPercent < INJURED_THRESHOLD

        if isInjured ~= wasInjured then
            PlayerIsInjured[player] = isInjured

            local currentState = PlayerCurrentStates[player] or "Idle"
            local baseState = getBaseState(currentState)
            local newState = getStateWithInjuryStatus(baseState, isInjured)

            if validateState(player, newState) then
                PlayerCurrentStates[player] = newState
                fireToAllClients(player, newState)
            end
        end
    end

    humanoid.HealthChanged:Connect(updateInjuredState)
    updateInjuredState()
end

local function setupAttributeMonitoring(player, character)
    local function reloadCharacterType()
        if not character or not character.Parent then return end

        local characterType, characterName, skinName = getCharacterType(character)

        local oldType = PlayerCharacterTypes[player]
        if oldType and oldType.Type == characterType and oldType.Name == characterName and oldType.Skin == skinName then
            return
        end

        -- Detectou mudança de personagem: reseta animação e injured
        local personagemTrocou = oldType and oldType.Name ~= characterName

        PlayerCharacterTypes[player] = {
            Type = characterType,
            Name = characterName,
            Skin = skinName
        }

        -- Se trocou de personagem, reseta estado para Idle
        if personagemTrocou then
            PlayerCurrentStates[player] = "Idle"
            PlayerIsInjured[player] = false
            fireToAllClients(player, "Idle")
        end

        syncCharacterTypeToAll(player, characterType, characterName)
    end

    -- Monitora todos os atributos relevantes
    character:GetAttributeChangedSignal("CharName"):Connect(reloadCharacterType)
    character:GetAttributeChangedSignal("Character"):Connect(reloadCharacterType)
    character:GetAttributeChangedSignal("IsKiller"):Connect(reloadCharacterType)
    character:GetAttributeChangedSignal("IsSkin"):Connect(reloadCharacterType)
end

local function handleCharacterAdded(character, player)
    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    task.wait(0.3)
    player:SetAttribute("Stunned", false)
    local humanoid = character:FindFirstChild("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if not humanoid or not rootPart then
        return
    end

    humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
    humanoid.BreakJointsOnDeath = false
    humanoid.DisplayName = ""
    humanoid.Health = humanoid.MaxHealth

    local characterType, characterName, skinName = getCharacterType(character)

    PlayerCharacterTypes[player] = {
        Type = characterType,
        Name = characterName,
        Skin = skinName
    }

    syncCharacterTypeToAll(player, characterType, characterName)

    PlayerCurrentStates[player] = "Idle"

    setupAttributeMonitoring(player, character)
    setupHealthMonitoring(player, character)

    task.wait(0.2)

    fireToAllClients(player, "Idle")

    humanoid.Died:Connect(function()
        task.wait(0.1)
        PlayerCurrentStates[player] = nil
        PlayerIsInjured[player] = nil
    end)
end

local function onPlayerRemoving(player)
    PlayerCharacterTypes[player] = nil
    PlayerCurrentStates[player] = nil
    PlayerIsInjured[player] = nil
end

local function onPlayerAdded(player)
    player.CharacterAdded:Connect(function(c)
        handleCharacterAdded(c, player)
    end)

    player.CharacterRemoving:Connect(function()
        PlayerCharacterTypes[player] = nil
        PlayerCurrentStates[player] = nil
        PlayerIsInjured[player] = nil
    end)

    if player.Character then
        handleCharacterAdded(player.Character, player)
    end
end

SetAnimationState.OnServerEvent:Connect(function(player, newState)
    if not player or not player.Parent then return end
    if not player.Character or not player.Character.Parent then return end

    if not validateState(player, newState) then
        return
    end

    local characterType = PlayerCharacterTypes[player]
    if characterType and characterType.Type == "Survivor" then
        local isInjured = PlayerIsInjured[player] or false
        newState = getStateWithInjuryStatus(newState, isInjured)
    end

    if PlayerCurrentStates[player] == newState then
        return
    end

    PlayerCurrentStates[player] = newState

    fireToAllClients(player, newState)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in pairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
