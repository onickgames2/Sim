--------------------------------------------------
-- ACHIEVEMENT SERVICE
-- Coloque este ModuleScript em ServerStorage (ex: ServerStorage.AchievementService)
--------------------------------------------------
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ACHIEVEMENTS_STORE = DataStoreService:GetDataStore("PlayerAchievements")

local notificationEvent = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Notification")

local events = ReplicatedStorage:WaitForChild("Events")
local loadingFinishedEvent = events:FindFirstChild("LoadingFinished")
if not loadingFinishedEvent then
    loadingFinishedEvent = Instance.new("RemoteEvent")
    loadingFinishedEvent.Name = "LoadingFinished"
    loadingFinishedEvent.Parent = events
end

--------------------------------------------------
-- DEFINIÇÃO DAS CONQUISTAS
-- Adicione novas entradas aqui quando quiser expandir
--------------------------------------------------
local ACHIEVEMENTS = {
    FirstJoin = {
        Title    = "Bem-vindo!",
        Subtitle = "Você entrou no jogo pela primeira vez.",
        Icon     = "0", -- troque pelo ID do asset
    },
    FirstDeath = {
        Title    = "Primeira Queda",
        Subtitle = "Você morreu pela primeira vez em uma partida.",
        Icon     = "0",
    },
    FirstWin = {
        Title    = "Primeira Vitória",
        Subtitle = "Você venceu sua primeira partida!",
        Icon     = "0",
    },
}

local AchievementService = {}

local cache  = {} -- [UserId] = { [achievementId] = true }
local loaded = {} -- [UserId] = true depois de carregar do datastore

local function storeKey(userId)
    return "achievements_" .. tostring(userId)
end

local function Load(player)
    local userId   = player.UserId
    local ok, data = pcall(ACHIEVEMENTS_STORE.GetAsync, ACHIEVEMENTS_STORE, storeKey(userId))
    if ok and type(data) == "table" then
        cache[userId] = data
    else
        cache[userId] = {}
    end
    loaded[userId] = true
end

local function Save(player)
    local userId = player.UserId
    local data   = cache[userId]
    if not data then return end
    local ok, err = pcall(ACHIEVEMENTS_STORE.SetAsync, ACHIEVEMENTS_STORE, storeKey(userId), data)
    if not ok then
        warn("[AchievementService] Erro ao salvar conquistas de " .. player.Name .. ": " .. tostring(err))
    end
end

-- Desbloqueia uma conquista pro player (só dispara notificação na primeira vez)
function AchievementService.Unlock(player, achievementId)
    if not player or not player.Parent then return end

    local def = ACHIEVEMENTS[achievementId]
    if not def then
        warn("[AchievementService] Conquista desconhecida: " .. tostring(achievementId))
        return
    end

    local userId = player.UserId
    if not loaded[userId] then
        Load(player)
    end

    local playerAchievements = cache[userId]
    if playerAchievements[achievementId] then
        return -- já desbloqueada antes, não notifica de novo
    end

    playerAchievements[achievementId] = true

    notificationEvent:FireClient(
        player,
        def.Title,
        def.Subtitle,
        def.Icon
    )

    task.spawn(Save, player)
end

-- Consulta se o player já tem determinada conquista
function AchievementService.HasUnlocked(player, achievementId)
    local userId = player.UserId
    if not loaded[userId] then
        Load(player)
    end
    return cache[userId][achievementId] == true
end

--------------------------------------------------
-- EVENTOS
--------------------------------------------------

Players.PlayerAdded:Connect(Load)

Players.PlayerRemoving:Connect(function(player)
    cache[player.UserId]  = nil
    loaded[player.UserId] = nil
end)

-- Disparado pelo client quando a tela de loading termina
loadingFinishedEvent.OnServerEvent:Connect(function(player)
    AchievementService.Unlock(player, "FirstJoin")
end)

return AchievementService
