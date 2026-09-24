local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")
local SoundService       = game:GetService("SoundService")
local Debris             = game:GetService("Debris")

local RE_Emote           = ReplicatedStorage.RemoteEvents.Emote
local emotesSoundsFolder = ServerStorage.Musics:WaitForChild("Emotes")

-------------------------------------------------
-- EMOTE SOUND
-------------------------------------------------

-- Toca globalmente (todo mundo ouve) o som configurado pro emote, se existir um
-- Sound com o mesmo nome do emote dentro de ServerStorage.Musics.Emotes
RE_Emote.OnServerEvent:Connect(function(player, emoteName)
    if typeof(emoteName) ~= "string" then return end

    local soundTemplate = emotesSoundsFolder:FindFirstChild(emoteName)
    if not soundTemplate or not soundTemplate:IsA("Sound") then return end

    local clone = soundTemplate:Clone()
    clone.Name   = "EmoteSound_" .. emoteName
    clone.Parent = SoundService
    clone:Play()

    Debris:AddItem(clone, clone.TimeLength > 0 and (clone.TimeLength + 1) or 10)
end)

-------------------------------------------------
-- STOP EMOTE ON MOVEMENT (andar ou pular)
-------------------------------------------------

-- Espera o AnimationHandler expor a API global (roda em outro Script, então
-- esperamos aparecer pra evitar erro de ordem de execução)
local function WaitForAnimationLite()
    while not _G.AnimationLite do
        task.wait()
    end
    return _G.AnimationLite
end

local AnimationLite = WaitForAnimationLite()

local function IsMovementState(state)
    return state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
end

local function StopEmoteIfPlaying(character)
    if character:GetAttribute("AnimationLitePlaying") then
        AnimationLite.Stop(character)
    end
end

local function SetupCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid then return end

    -- Andar (WASD / joystick): dispara com MoveDirection diferente de zero
    humanoid.Running:Connect(function(speed)
        if speed > 0 then
            StopEmoteIfPlaying(character)
        end
    end)

    -- Pular
    humanoid.StateChanged:Connect(function(_, newState)
        if IsMovementState(newState) then
            StopEmoteIfPlaying(character)
        end
    end)
end

local function OnPlayerAdded(player)
    player.CharacterAdded:Connect(SetupCharacter)
    if player.Character then
        SetupCharacter(player.Character)
    end
end

Players.PlayerAdded:Connect(OnPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    OnPlayerAdded(player)
end
