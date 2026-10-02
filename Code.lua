--------------------------------------------------
-- SERVICES
--------------------------------------------------
local Players           = game:GetService("Players")
local DataStoreService  = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
--------------------------------------------------
-- CONFIG
--------------------------------------------------
local config         = require(game.ServerStorage.Config.DataSaver)
local initial        = config.Initial
 
local DATASTORE_NAME = config.DATASTORENAME
local AUTOSAVE_RATE  = 60
local Debug          = false
 
local BASE_XP        = 100
local XP_STEP        = 75
 
local store          = DataStoreService:GetDataStore(DATASTORE_NAME)
 
--------------------------------------------------
-- REMOTES
--------------------------------------------------
local events              = ReplicatedStorage:WaitForChild("Events")
local buyCharacterEvent   = events:WaitForChild("BuyCharacter")
local buySkinEvent        = events:WaitForChild("BuySkin")
local equipCharacterEvent = events:WaitForChild("EquipCharacter")
local equipSkinEvent      = events:WaitForChild("EquipSkin")
local notificationEvent   = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("Notification")
 
local SetConfigEvent = ReplicatedStorage:FindFirstChild("SetConfig")
if not SetConfigEvent then
    SetConfigEvent = Instance.new("RemoteEvent")
    SetConfigEvent.Name = "SetConfig"
    SetConfigEvent.Parent = ReplicatedStorage
end
 
--------------------------------------------------
-- ASSETS
--------------------------------------------------
local assets         = ReplicatedStorage:WaitForChild("Assets")
local killerAssets   = assets:WaitForChild("Killers")
local survivorAssets = assets:WaitForChild("Survivors")
 
--------------------------------------------------
-- GUARD DE REENTRÂNCIA
--------------------------------------------------
local xpGuard = {}
 
local function guardKey(player, characterName)
    return tostring(player.UserId) .. "_" .. characterName
end
 
--------------------------------------------------
-- HELPERS - DATASAVER
--------------------------------------------------
 
local function GetLeader(plr) return plr:FindFirstChild("leaderstats") end
local function GetPData(plr)  return plr:FindFirstChild("PlayerData")  end
local function GetActors(plr)
    local pd = GetPData(plr)
    return pd and pd:FindFirstChild("Actors")
end
 
local function skinExists(characterName, skinName, isKiller)
    local base        = isKiller and killerAssets or survivorAssets
    local charFolder  = base:FindFirstChild(characterName)
    if not charFolder then return false end
    local skinsFolder = charFolder:FindFirstChild("Skins")
    if not skinsFolder then return false end
    return skinsFolder:FindFirstChild(skinName) ~= nil
end
 
local function characterExists(characterName, isKiller)
    local base       = isKiller and killerAssets or survivorAssets
    local charFolder = base:FindFirstChild(characterName)
    if not charFolder then return false end
    return charFolder:FindFirstChild("Default") ~= nil
end
 
--------------------------------------------------
-- HELPERS - CHARACTER HANDLER
--------------------------------------------------
 
local function getModuleScript(characterName, isKiller, skinName)
    local base       = isKiller and killerAssets or survivorAssets
    local charFolder = base:FindFirstChild(characterName)
    if not charFolder then return nil end
    if skinName then
        local skins = charFolder:FindFirstChild("Skins")
        return skins and skins:FindFirstChild(skinName)
    end
    return charFolder:FindFirstChild("Default")
end
 
local function isPlayerAdmin(player)
    return player:GetAttribute("Admin") == true
end
 
local function getCharFolder(player, isKiller)
    local pd     = player:FindFirstChild("PlayerData")
    local actors = pd and pd:FindFirstChild("Actors")
    return actors and actors:FindFirstChild(isKiller and "Killer" or "Survivor")
end
 
local function getEquippedFolder(player)
    local pd     = player:FindFirstChild("PlayerData")
    local actors = pd and pd:FindFirstChild("Actors")
    return actors and actors:FindFirstChild("Equipped")
end
 
local function getEquippedCharValue(player, isKiller)
    local eq = getEquippedFolder(player)
    return eq and eq:FindFirstChild(isKiller and "Killer" or "Survivor")
end
 
local function getEquippedSkinValue(player, isKiller, characterName)
    local eq      = getEquippedFolder(player)
    if not eq then return nil end
    local skinsEq = eq:FindFirstChild("Skins")
    if not skinsEq then return nil end
    local folder  = skinsEq:FindFirstChild(isKiller and "Killer" or "Survivor")
    return folder and folder:FindFirstChild(characterName)
end
 
local function getCharValue(player, isKiller, characterName)
    local charFolder = getCharFolder(player, isKiller)
    return charFolder and charFolder:FindFirstChild(characterName)
end
 
local function getSkinsFolder(player, isKiller, characterName)
    local charVal = getCharValue(player, isKiller, characterName)
    if not charVal then return nil end
    local skinsFolder = charVal:FindFirstChild("Skins")
    if not skinsFolder then
        skinsFolder        = Instance.new("Folder")
        skinsFolder.Name   = "Skins"
        skinsFolder.Parent = charVal
    end
    return skinsFolder
end
 
--------------------------------------------------
-- LEVEL UP / MILESTONE ICONS
--------------------------------------------------
 
local MILESTONE_ICON = "122674199843438"
local LEVELUP_ICON   = "122674199843438" -- troque pelo ID de imagem que quiser usar pro level up genérico
 
local function getCharacterRenderImage(characterName, isKiller)
    local base        = isKiller and killerAssets or survivorAssets
    local charFolder   = base:FindFirstChild(characterName)
    if not charFolder then return nil end
    local moduleScript = charFolder:FindFirstChild("Default")
    if not moduleScript then return nil end
    local ok, mod = pcall(require, moduleScript)
    if ok and type(mod) == "table" then
        return mod.CharacterRenderImage
    end
    return nil
end
 
--------------------------------------------------
-- MILESTONE SYSTEM
--------------------------------------------------
 
local function checkMilestones(player, isKiller, characterName, level)
    local base            = isKiller and killerAssets or survivorAssets
    local charAssetFolder = base:FindFirstChild(characterName)
    if not charAssetFolder then return end
    
    local skinsAssetFolder = charAssetFolder:FindFirstChild("Skins")
    if not skinsAssetFolder then return end
    
    for _, skinModule in ipairs(skinsAssetFolder:GetChildren()) do
        local ok, skinData = pcall(require, skinModule)
        if not ok or type(skinData) ~= "table" then continue end
        
        if skinData.MilestoneLevel ~= level then continue end
        
        local skinsFolder = getSkinsFolder(player, isKiller, characterName)
        if not skinsFolder then continue end
        
        local skinKey = skinData.CharacterName .. "_" .. skinData.RigName
        
        if skinsFolder:FindFirstChild(skinKey) then continue end
        
        local sk   = Instance.new("BoolValue")
        sk.Name    = skinKey
        sk.Value   = true
        sk.Parent  = skinsFolder
        
        local skinVal = getEquippedSkinValue(player, isKiller, characterName)
        if not skinVal then
            local eq      = getEquippedFolder(player)
            local skinsEq = eq and eq:FindFirstChild("Skins")
            local folder  = skinsEq and skinsEq:FindFirstChild(isKiller and "Killer" or "Survivor")
            if folder then
                local val   = Instance.new("StringValue")
                val.Name    = characterName
                val.Value   = "Default"
                val.Parent  = folder
            end
        end
        
        notificationEvent:FireClient(
        player,
        "You gained a Milestone Skin!",
        "Congratulations! You reached level " .. level .. " and unlocked the " .. skinData.RigName .. " skin!",
        skinData.CharacterRenderImage or MILESTONE_ICON
        )
        
        if Debug then
            print("[MILESTONE] 🎉 " .. player.Name .. " desbloqueou: " .. skinKey .. " (Level " .. level .. ")")
        end
    end
end
 
--------------------------------------------------
-- XP SYSTEM
--------------------------------------------------
 
local function xpForNextLevel(currentLevel)
    return BASE_XP + (currentLevel * XP_STEP)
end
 
local function processLevelUps(xpValue, levelValue, player, isKiller, characterName)
    local currentXP    = xpValue.Value
    local currentLevel = levelValue.Value
    
    local milestoneLevels = {}
    local needed          = xpForNextLevel(currentLevel)
    
    while currentXP >= needed do
        currentXP    -= needed
        currentLevel += 1
        table.insert(milestoneLevels, currentLevel)
        
        if Debug then
            print(string.format(
            "[LEVEL UP!] %s → Level %d em %s (XP restante: %d)",
            player.Name, currentLevel, characterName, currentXP
            ))
        end
        
        needed = xpForNextLevel(currentLevel)
    end
    
    if #milestoneLevels == 0 then return end
    
    local key = guardKey(player, characterName)
    xpGuard[key] = true
    
    xpValue.Value    = currentXP
    levelValue.Value = currentLevel
    
    xpGuard[key] = nil
    
    local renderImage = getCharacterRenderImage(characterName, isKiller)
    
    for _, lvl in ipairs(milestoneLevels) do
        -- 🔔 Notificação de level up (dispara pra cada nível ganho)
        notificationEvent:FireClient(
        player,
        "Level Up!",
        characterName .. " alcançou o nível " .. lvl .. "!",
        renderImage or LEVELUP_ICON
        )
        
        checkMilestones(player, isKiller, characterName, lvl)
    end
    
    if Debug then
        print(string.format(
        "[XP] %s ganhou %d level(s) em %s → Level %d (XP: %d / Próximo: %d)",
        player.Name, #milestoneLevels, characterName,
        currentLevel, currentXP, xpForNextLevel(currentLevel)
        ))
    end
end
 
--------------------------------------------------
-- XP LISTENERS
--------------------------------------------------
 
local function setupXPListener(player, charVal, isKiller, characterName)
    local xp    = charVal:FindFirstChild("XP")
    local level = charVal:FindFirstChild("Level")
    if not xp or not level then return end
    
    xp:GetPropertyChangedSignal("Value"):Connect(function()
        local key = guardKey(player, characterName)
        if xpGuard[key] then return end
        
        processLevelUps(xp, level, player, isKiller, characterName)
    end)
    
    if Debug then
        print("[XP Listener] Ativado: " .. player.Name .. " → " .. characterName)
    end
end
 
local function setupAllXPListeners(player)
    local killerFolder = getCharFolder(player, true)
    local survFolder   = getCharFolder(player, false)
    
    if killerFolder then
        for _, charVal in ipairs(killerFolder:GetChildren()) do
            if not charVal:IsA("Folder") and charVal:FindFirstChild("XP") then
                setupXPListener(player, charVal, true, charVal.Name)
            end
        end
        killerFolder.ChildAdded:Connect(function(child)
            if child:IsA("Folder") then return end
            task.wait(0.1)
            if child:FindFirstChild("XP") then
                setupXPListener(player, child, true, child.Name)
            end
        end)
    end
    
    if survFolder then
        for _, charVal in ipairs(survFolder:GetChildren()) do
            if not charVal:IsA("Folder") and charVal:FindFirstChild("XP") then
                setupXPListener(player, charVal, false, charVal.Name)
            end
        end
        survFolder.ChildAdded:Connect(function(child)
            if child:IsA("Folder") then return end
            task.wait(0.1)
            if child:FindFirstChild("XP") then
                setupXPListener(player, child, false, child.Name)
            end
        end)
    end
end
 
--------------------------------------------------
-- SERIALIZE
--------------------------------------------------
 
local function Serialize(plr)
    local leader = GetLeader(plr)
    local pdata  = GetPData(plr)
    local actors = GetActors(plr)
    if not (leader and pdata and actors) then return nil end
    
    local round      = pdata:FindFirstChild("Round")
    local config     = pdata:FindFirstChild("Config")
    local equipped   = actors:FindFirstChild("Equipped")
    local skinsEq    = equipped and equipped:FindFirstChild("Skins")
    local killerSkEq = skinsEq  and skinsEq:FindFirstChild("Killer")
    local survSkEq   = skinsEq  and skinsEq:FindFirstChild("Survivor")
    
    local function ReadCharFolder(charFolder, isKiller)
        local chars = {}
        if not charFolder then return chars end
        for _, child in ipairs(charFolder:GetChildren()) do
            if child:IsA("Folder") then continue end
            if not characterExists(child.Name, isKiller) then
                warn("[DataSaver] Personagem não existe mais, ignorando: " .. child.Name)
                continue
            end
            
            local xpVal    = child:FindFirstChild("XP")
            local levelVal = child:FindFirstChild("Level")
            
            local charSkinsFolder = child:FindFirstChild("Skins")
            local skinsSaved = {}
            if charSkinsFolder then
                for _, sk in ipairs(charSkinsFolder:GetChildren()) do
                    if sk:IsA("BoolValue") then
                        local parts = string.split(sk.Name, "_")
                        if #parts >= 2 then
                            local skinName = parts[2]
                            if skinExists(child.Name, skinName, isKiller) then
                                skinsSaved[sk.Name] = true
                            else
                                warn("[DataSaver] Skin não existe mais, ignorando: " .. sk.Name)
                            end
                        end
                    end
                end
            end
            
            chars[child.Name] = {
            XP    = xpVal    and xpVal.Value    or 0,
            Level = levelVal and levelVal.Value or 0,
            Skins = skinsSaved,
            }
        end
        return chars
    end
    
    local function ReadEquippedSkins(folder)
        local t = {}
        if not folder then return t end
        for _, val in ipairs(folder:GetChildren()) do
            if val:IsA("StringValue") then
                t[val.Name] = val.Value
            end
        end
        return t
    end
    
    local function ReadConfig(configFolder)
        local cfg = {}
        if not configFolder then return cfg end
        for _, val in ipairs(configFolder:GetChildren()) do
            if val:IsA("BoolValue") then
                cfg[val.Name] = val.Value
            end
        end
        return cfg
    end
    
    local killerFolder = actors:FindFirstChild("Killer")
    local survFolder   = actors:FindFirstChild("Survivor")
    
    return {
    Points       = leader:FindFirstChild("Points")       and leader.Points.Value       or 0,
    KillerChance = leader:FindFirstChild("KillerChance") and leader.KillerChance.Value or 0,
    
    TimePlayed = pdata:FindFirstChild("TimePlayed") and pdata.TimePlayed.Value or 0,
    
    KillerLoses   = round and round:FindFirstChild("KillerLoses")   and round.KillerLoses.Value   or 0,
    SurvivorLoses = round and round:FindFirstChild("SurvivorLoses") and round.SurvivorLoses.Value or 0,
    KillerWins    = round and round:FindFirstChild("KillerWins")    and round.KillerWins.Value    or 0,
    SurvivorWins  = round and round:FindFirstChild("SurvivorWins")  and round.SurvivorWins.Value  or 0,
    
    Config   = ReadConfig(config),
    Killers   = ReadCharFolder(killerFolder, true),
    Survivors = ReadCharFolder(survFolder, false),
    
    EquippedKiller        = equipped and equipped:FindFirstChild("Killer")   and equipped.Killer.Value   or initial.Killer,
    EquippedSurvivor      = equipped and equipped:FindFirstChild("Survivor") and equipped.Survivor.Value or initial.Survivor,
    EquippedKillerSkins   = ReadEquippedSkins(killerSkEq),
    EquippedSurvivorSkins = ReadEquippedSkins(survSkEq),
    }
end
 
--------------------------------------------------
-- APPLY
--------------------------------------------------
 
local function Apply(plr, data)
    local leader = GetLeader(plr)
    local pdata  = GetPData(plr)
    local actors = GetActors(plr)
    if not (leader and pdata and actors) then return end
    
    if leader:FindFirstChild("Points")       then leader.Points.Value       = data.Points       end
    if leader:FindFirstChild("KillerChance") then leader.KillerChance.Value = data.KillerChance end
    if pdata:FindFirstChild("TimePlayed")    then pdata.TimePlayed.Value    = data.TimePlayed   end
    
    local round = pdata:FindFirstChild("Round")
    if round then
        if round:FindFirstChild("KillerLoses")   then round.KillerLoses.Value   = data.KillerLoses   end
        if round:FindFirstChild("SurvivorLoses") then round.SurvivorLoses.Value = data.SurvivorLoses end
        if round:FindFirstChild("KillerWins")    then round.KillerWins.Value    = data.KillerWins    end
        if round:FindFirstChild("SurvivorWins")  then round.SurvivorWins.Value  = data.SurvivorWins  end
    end
    
    local config = pdata:FindFirstChild("Config")
    if config and data.Config then
        for configName, configValue in pairs(data.Config) do
            local configVal = config:FindFirstChild(configName)
            if configVal and configVal:IsA("BoolValue") then
                configVal.Value = configValue
            end
        end
    end
    
    local equipped = actors:FindFirstChild("Equipped")
    local skinsEq  = equipped and equipped:FindFirstChild("Skins")
    if equipped then
        if equipped:FindFirstChild("Killer")   then equipped.Killer.Value   = data.EquippedKiller   end
        if equipped:FindFirstChild("Survivor") then equipped.Survivor.Value = data.EquippedSurvivor end
    end
    
    local function ApplyCharacters(charFolder, savedChars, eqSkinsFolder, eqSkins, isKiller)
        if not charFolder then return end
        for charName, charData in pairs(savedChars) do
            if not characterExists(charName, isKiller) then
                warn("[DataSaver] Personagem não existe, ignorando: " .. charName)
                continue
            end
            
            local charVal = charFolder:FindFirstChild(charName)
            if not charVal then
                charVal        = Instance.new("BoolValue")
                charVal.Name   = charName
                charVal.Value  = true
                charVal.Parent = charFolder
            end
            
            local xpVal = charVal:FindFirstChild("XP")
            if not xpVal then
                xpVal        = Instance.new("IntValue")
                xpVal.Name   = "XP"
                xpVal.Parent = charVal
            end
            xpVal.Value = charData.XP or 0
            
            local levelVal = charVal:FindFirstChild("Level")
            if not levelVal then
                levelVal        = Instance.new("IntValue")
                levelVal.Name   = "Level"
                levelVal.Parent = charVal
            end
            levelVal.Value = charData.Level or 0
            
            local charSkinsFolder = charVal:FindFirstChild("Skins")
            if not charSkinsFolder then
                charSkinsFolder        = Instance.new("Folder")
                charSkinsFolder.Name   = "Skins"
                charSkinsFolder.Parent = charVal
            end
            
            for skinKey in pairs(charData.Skins or {}) do
                local parts = string.split(skinKey, "_")
                if #parts >= 2 then
                    local skinName = parts[2]
                    if skinExists(charName, skinName, isKiller) then
                        if not charSkinsFolder:FindFirstChild(skinKey) then
                            local sk   = Instance.new("BoolValue")
                            sk.Name    = skinKey
                            sk.Value   = true
                            sk.Parent  = charSkinsFolder
                        end
                    else
                        warn("[DataSaver] Skin não existe, ignorando: " .. skinKey)
                    end
                end
            end
            
            if eqSkinsFolder then
                local eqSkinVal = eqSkinsFolder:FindFirstChild(charName)
                if not eqSkinVal then
                    eqSkinVal        = Instance.new("StringValue")
                    eqSkinVal.Name   = charName
                    eqSkinVal.Parent = eqSkinsFolder
                end
                eqSkinVal.Value = (eqSkins and eqSkins[charName]) or "Default"
            end
        end
    end
    
    local killerFolder = actors:FindFirstChild("Killer")
    local survFolder   = actors:FindFirstChild("Survivor")
    local killerSkEq   = skinsEq and skinsEq:FindFirstChild("Killer")
    local survSkEq     = skinsEq and skinsEq:FindFirstChild("Survivor")
    
    ApplyCharacters(killerFolder, data.Killers   or {}, killerSkEq, data.EquippedKillerSkins, true)
    ApplyCharacters(survFolder,   data.Survivors or {}, survSkEq,   data.EquippedSurvivorSkins, false)
end
 
--------------------------------------------------
-- SAVE / LOAD
--------------------------------------------------
 
local function Save(plr)
    local key  = "player_" .. plr.UserId
    local data = Serialize(plr)
    if not data then
        warn("[DataSaver] Falhou ao serializar: " .. plr.Name)
        return
    end
    local ok, err = pcall(store.SetAsync, store, key, data)
    if ok then
        if Debug then print("[DataSaver] ✔ Salvo: " .. plr.Name) end
    else
        warn("[DataSaver] ✘ Erro ao salvar " .. plr.Name .. ": " .. tostring(err))
    end
end
 
local function Load(plr)
    local key      = "player_" .. plr.UserId
    local ok, data = pcall(store.GetAsync, store, key)
    if not ok then
        warn("[DataSaver] ✘ Erro ao carregar " .. plr.Name .. ": " .. tostring(data))
        return
    end
    if data then
        Apply(plr, data)
        if Debug then print("[DataSaver] ✔ Carregado: " .. plr.Name) end
    else
        if Debug then print("[DataSaver] ★ Dados novos: " .. plr.Name) end
    end
end
 
--------------------------------------------------
-- BUY CHARACTER
--------------------------------------------------
 
buyCharacterEvent.OnServerEvent:Connect(function(player, characterName, isKiller)
    if type(characterName) ~= "string" or type(isKiller) ~= "boolean" then
        warn("[CharacterHandler] Tipo inválido em BuyCharacter")
        return
    end
    
    local moduleScript = getModuleScript(characterName, isKiller, nil)
    if not moduleScript then
        warn("[CharacterHandler] ModuleScript não encontrado: " .. characterName)
        return
    end
    
    local ok, module = pcall(require, moduleScript)
    if not ok or module.IsSkin then
        warn("[CharacterHandler] Erro ao carregar módulo ou é uma skin: " .. characterName)
        return
    end
    
    if module.Exclusive then
        warn("[CharacterHandler] Character Exclusive bloqueado: " .. characterName)
        notificationEvent:FireClient(
        player,
        "Character Locked",
        "This character is exclusive and cannot be purchased.",
        module.CharacterRenderImage or "0"
        )
        return
    end
    
    if module.Admin and not isPlayerAdmin(player) then
        warn("[CharacterHandler] Character Admin bloqueado para: " .. player.Name)
        notificationEvent:FireClient(
        player,
        "Admin Only",
        "This character is only available for administrators.",
        module.CharacterRenderImage or "0"
        )
        return
    end
    
    local charFolder = getCharFolder(player, isKiller)
    if not charFolder then
        warn("[CharacterHandler] CharFolder não encontrado: " .. player.Name)
        return
    end
    
    if charFolder:FindFirstChild(module.CharacterName) then
        warn("[CharacterHandler] " .. player.Name .. " já possui: " .. module.CharacterName)
        return
    end
    
    if module.CharacterPrice ~= "Free" and module.CharacterPrice > player.leaderstats.Points.Value then
        warn("[CharacterHandler] " .. player.Name .. " não possui dinheiro para comprar")
        return
    end
    
    if module.CharacterPrice ~= "Free" then
        player.leaderstats.Points.Value = player.leaderstats.Points.Value - module.CharacterPrice
    end
    
    local charVal      = Instance.new("BoolValue")
    charVal.Name       = module.CharacterName
    charVal.Value      = true
    charVal.Parent     = charFolder
    
    local xp           = Instance.new("IntValue")
    xp.Name            = "XP"
    xp.Value           = 0
    xp.Parent          = charVal
    
    local lvl          = Instance.new("IntValue")
    lvl.Name           = "Level"
    lvl.Value          = 0
    lvl.Parent         = charVal
    
    local skinsFolder  = Instance.new("Folder")
    skinsFolder.Name   = "Skins"
    skinsFolder.Parent = charVal
    
    local eq      = getEquippedFolder(player)
    local skinsEq = eq and eq:FindFirstChild("Skins")
    local folder  = skinsEq and skinsEq:FindFirstChild(isKiller and "Killer" or "Survivor")
    if folder and not folder:FindFirstChild(module.CharacterName) then
        local val   = Instance.new("StringValue")
        val.Name    = module.CharacterName
        val.Value   = "Default"
        val.Parent  = folder
    end
    
    setupXPListener(player, charVal, isKiller, module.CharacterName)
    
    notificationEvent:FireClient(
    player,
    "Character Purchased",
    "You successfully purchased " .. module.CharacterName .. "!",
    module.CharacterRenderImage or "0"
    )
    
    if Debug then
        print("[CharacterHandler] ✔ " .. player.Name .. " comprou: " .. module.CharacterName)
    end
end)
 
--------------------------------------------------
-- BUY SKIN
--------------------------------------------------
 
buySkinEvent.OnServerEvent:Connect(function(player, characterName, skinName, isKiller)
    if type(characterName) ~= "string" or type(skinName) ~= "string" or type(isKiller) ~= "boolean" then
        warn("[CharacterHandler] Tipo inválido em BuySkin")
        return
    end
    
    local moduleScript = getModuleScript(characterName, isKiller, skinName)
    if not moduleScript then
        warn("[CharacterHandler] ModuleScript de skin não encontrado: " .. skinName)
        return
    end
    
    local ok, module = pcall(require, moduleScript)
    if not ok or not module.IsSkin then
        warn("[CharacterHandler] Erro ao carregar skin ou não é uma skin")
        return
    end
    
    if module.MilestoneLevel then
        warn("[CharacterHandler] Skin de milestone não pode ser comprada: " .. skinName)
        return
    end
    
    if module.Exclusive then
        warn("[CharacterHandler] Skin Exclusive bloqueada: " .. skinName)
        notificationEvent:FireClient(
        player,
        "Skin Locked",
        "This skin is exclusive and cannot be purchased.",
        module.CharacterRenderImage or "0"
        )
        return
    end
    
    if module.Admin and not isPlayerAdmin(player) then
        warn("[CharacterHandler] Skin Admin bloqueada para: " .. player.Name)
        notificationEvent:FireClient(
        player,
        "Admin Only",
        "This skin is only available for administrators.",
        module.CharacterRenderImage or "0"
        )
        return
    end
    
    local charFolder = getCharFolder(player, isKiller)
    if not charFolder or not charFolder:FindFirstChild(module.CharacterName) then
        warn("[CharacterHandler] " .. player.Name .. " não possui: " .. module.CharacterName)
        return
    end
    
    local skinsFolder = getSkinsFolder(player, isKiller, module.CharacterName)
    if not skinsFolder then 
        warn("[CharacterHandler] skinsFolder não encontrado para: " .. player.Name)
        return 
    end
    
    local skinKey = module.CharacterName .. "_" .. module.RigName
    if skinsFolder:FindFirstChild(skinKey) then
        warn("[CharacterHandler] " .. player.Name .. " já possui skin: " .. skinKey)
        return
    end
    
    if module.CharacterPrice ~= "Free" and module.CharacterPrice > player.leaderstats.Points.Value then
        warn("[CharacterHandler] " .. player.Name .. " não possui dinheiro para comprar")
        return
    end
    
    if module.CharacterPrice ~= "Free" then
        player.leaderstats.Points.Value = player.leaderstats.Points.Value - module.CharacterPrice
    end
    
    local sk = Instance.new("BoolValue")
    sk.Name = skinKey
    sk.Value = true
    sk.Parent = skinsFolder
    
    notificationEvent:FireClient(
    player,
    "Skin Purchased",
    "You successfully purchased " .. module.RigName .. "!",
    module.CharacterRenderImage or "0"
    )
    
    if Debug then
        print("[CharacterHandler] ✔ " .. player.Name .. " comprou skin: " .. skinKey)
    end
end)
 
--------------------------------------------------
-- EQUIP CHARACTER
--------------------------------------------------
 
equipCharacterEvent.OnServerEvent:Connect(function(player, characterName, isKiller)
    if type(characterName) ~= "string" or type(isKiller) ~= "boolean" then
        warn("[CharacterHandler] Tipo inválido em EquipCharacter")
        return
    end
    
    local moduleScript = getModuleScript(characterName, isKiller, nil)
    if not moduleScript then
        warn("[CharacterHandler] ModuleScript não encontrado: " .. characterName)
        return
    end
    
    local ok, module = pcall(require, moduleScript)
    if not ok or module.IsSkin then
        warn("[CharacterHandler] Erro ao carregar ou é uma skin")
        return
    end
    
    if module.Admin and not isPlayerAdmin(player) then
        notificationEvent:FireClient(player, "Admin Only", "Inventory",
        module.CharacterRenderImage or "0",
        "This character can only be equipped by administrators.")
        return
    end
    
    local charFolder = getCharFolder(player, isKiller)
    if not charFolder or not charFolder:FindFirstChild(module.CharacterName) then
        warn("[CharacterHandler] " .. player.Name .. " não possui: " .. module.CharacterName)
        return
    end
    
    local equippedVal = getEquippedCharValue(player, isKiller)
    if equippedVal then
        equippedVal.Value = module.CharacterName
        if Debug then
            print("[CharacterHandler] ✔ " .. player.Name .. " equipou: " .. module.CharacterName)
        end
    else
        warn("[CharacterHandler] EquippedVal não encontrado")
    end
end)
 
--------------------------------------------------
-- EQUIP SKIN
--------------------------------------------------
 
equipSkinEvent.OnServerEvent:Connect(function(player, characterName, skinName, isKiller)
    if type(characterName) ~= "string" or type(isKiller) ~= "boolean" then
        warn("[CharacterHandler] Tipo inválido em EquipSkin")
        return
    end
    
    local charFolder = getCharFolder(player, isKiller)
    if not charFolder or not charFolder:FindFirstChild(characterName) then
        warn("[CharacterHandler] " .. player.Name .. " não possui: " .. characterName)
        return
    end
    
    local skinVal = getEquippedSkinValue(player, isKiller, characterName)
    if not skinVal then
        warn("[CharacterHandler] SkinVal não encontrado para: " .. characterName)
        return
    end
    
    if not skinName or skinName == "Default" then
        skinVal.Value = "Default"
        if Debug then
            print("[CharacterHandler] ✔ " .. player.Name .. " equipou skin Default em: " .. characterName)
        end
        return
    end
    
    if type(skinName) ~= "string" then
        warn("[CharacterHandler] skinName não é string")
        return
    end
    
    local moduleScript = getModuleScript(characterName, isKiller, skinName)
    if not moduleScript then
        warn("[CharacterHandler] ModuleScript de skin não encontrado: " .. skinName)
        return
    end
    
    local ok, module = pcall(require, moduleScript)
    if not ok or not module.IsSkin then
        warn("[CharacterHandler] Erro ao carregar skin")
        return
    end
    
    if module.Admin and not isPlayerAdmin(player) then
        notificationEvent:FireClient(player, "Admin Only", "Inventory",
        module.CharacterRenderImage or "0",
        "This skin can only be equipped by administrators.")
        return
    end
    
    local skinsFolder = getSkinsFolder(player, isKiller, characterName)
    if not skinsFolder then return end
    
    local skinKey = module.CharacterName .. "_" .. module.RigName
    if not skinsFolder:FindFirstChild(skinKey) then
        warn("[CharacterHandler] " .. player.Name .. " não possui skin: " .. skinKey)
        return
    end
    
    skinVal.Value = module.RigName
    if Debug then
        print("[CharacterHandler] ✔ " .. player.Name .. " equipou skin: " .. skinKey)
    end
end)
 
--------------------------------------------------
-- CONFIG SYSTEM
--------------------------------------------------
 
SetConfigEvent.OnServerEvent:Connect(function(player, configKey, configValue)
    if not player or not player.Parent then return end
    if type(configKey) ~= "string" or type(configValue) ~= "boolean" then return end
    
    local pdata = GetPData(player)
    if not pdata then return end
    
    local config = pdata:FindFirstChild("Config")
    if not config then return end
    
    local configVal = config:FindFirstChild(configKey)
    if configVal then
        configVal.Value = configValue
    end
end)
 
--------------------------------------------------
-- TIMEPLAYED
--------------------------------------------------
 
local function StartTimePlayed(plr)
    task.spawn(function()
        while plr and plr.Parent do
            task.wait(1)
            if not (plr and plr.Parent) then break end
            local pdata = GetPData(plr)
            if pdata and pdata:FindFirstChild("TimePlayed") then
                pdata.TimePlayed.Value += 1
            end
        end
    end)
end
 
--------------------------------------------------
-- AUTO-SAVE
--------------------------------------------------
 
task.spawn(function()
    while true do
        task.wait(AUTOSAVE_RATE)
        local players = Players:GetPlayers()
        if Debug then
            print(string.format("[DataSaver] Auto-save: %d jogador(es)...", #players))
        end
        for _, plr in ipairs(players) do
            Save(plr)
        end
        if Debug then print("[DataSaver] ✔ Auto-save concluído.") end
    end
end)
 
--------------------------------------------------
-- PLAYER EVENTS
--------------------------------------------------
 
Players.PlayerAdded:Connect(function(plr)
    plr:WaitForChild("PlayerData",  15)
    plr:WaitForChild("leaderstats", 15)
    
    Load(plr)
    task.wait(0.5)
    setupAllXPListeners(plr)
    StartTimePlayed(plr)
end)
 
Players.PlayerRemoving:Connect(function(plr)
    Save(plr)
    for key in pairs(xpGuard) do
        if key:sub(1, #tostring(plr.UserId)) == tostring(plr.UserId) then
            xpGuard[key] = nil
        end
    end
end)
 
game:BindToClose(function()
    for _, plr in ipairs(Players:GetPlayers()) do
        Save(plr)
    end
end)
