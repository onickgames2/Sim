local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local ServerStorage      = game:GetService("ServerStorage")
local SoundService       = game:GetService("SoundService")

local RE_Emote           = ReplicatedStorage.RemoteEvents.Emote
local emotesSoundsFolder = ServerStorage.Musics:WaitForChild("Emotes")

-- [NOVO] Guarda o som ativo de cada jogador, pra poder parar instantaneamente
local activeEmoteSounds = {}

-------------------------------------------------
-- EMOTE SOUND
-------------------------------------------------

local function StopPlayerEmoteSound(player)
    local sound = activeEmoteSounds[player]
    if sound then
        sound:Stop()
        sound:Destroy()
        activeEmoteSounds[player] = nil
    end
end

-- Toca globalmente (todo mundo ouve, em loop) o som configurado pro emote, se
-- existir um Sound com o mesmo nome do emote dentro de ServerStorage.Musics.Emotes
RE_Emote.OnServerEvent:Connect(function(player, emoteName)
    if typeof(emoteName) ~= "string" then return end

    StopPlayerEmoteSound(player) -- corta qualquer som de emote anterior desse jogador

    local soundTemplate = emotesSoundsFolder:FindFirstChild(emoteName)
    if not soundTemplate or not soundTemplate:IsA("Sound") then return end

    local clone = soundTemplate:Clone()
    clone.Name   = "EmoteSound_" .. emoteName
    clone.Looped = true -- [NOVO] repete enquanto o emote estiver ativo
    clone.Parent = SoundService
    clone:Play()

    activeEmoteSounds[player] = clone
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

    -- [NOVO] Para o som do emote junto, instantaneamente
    local player = Players:GetPlayerFromCharacter(character)
    if player then
        StopPlayerEmoteSound(player)
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

Players.PlayerRemoving:Connect(function(player)
    StopPlayerEmoteSound(player) -- [NOVO] limpa se o jogador sair com emote tocando
    activeEmoteSounds[player] = nil
end)

Players.PlayerAdded:Connect(OnPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    OnPlayerAdded(player)
end
