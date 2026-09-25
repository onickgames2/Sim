--// SERVICES
local Players            = game:GetService("Players")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local TweenService       = game:GetService("TweenService")
local MarketplaceService = game:GetService("MarketplaceService") -- [NOVO]

--// PLAYER
local player     = Players.LocalPlayer
local playerData = player:WaitForChild("PlayerData")
local actors     = playerData:WaitForChild("Actors")
local equipped   = actors:WaitForChild("Equipped")

--// REMOTES
local events              = ReplicatedStorage:WaitForChild("Events")
local buyCharacterEvent   = events:WaitForChild("BuyCharacter")
local buySkinEvent        = events:WaitForChild("BuySkin")
local equipCharacterEvent = events:WaitForChild("EquipCharacter")
local equipSkinEvent      = events:WaitForChild("EquipSkin")

--// ASSETS
local killerAssets   = ReplicatedStorage.Assets.Killers
local survivorAssets = ReplicatedStorage.Assets.Survivors

--// UI
local ui = script.Parent.Parent

local shopBtn       = ui.ShopButton
local shopFrame     = ui.ShopFrame
local shopScroll    = shopFrame.Scroll
local shopTemplate  = shopScroll.Template
local shopDetails   = shopFrame.DetailsFrame
local shopDescFrame = shopFrame.DescFrame
local buySkinFrame  = shopFrame.BuySkinFrame
local shopKillerBtn = shopFrame.Killers
local shopSurvBtn   = shopFrame.Survivors

local invBtn        = ui.InventoryButton
local invFrame      = ui.InventoryFrame
local invScroll     = invFrame.Scroll
local invTemplate   = invScroll.Template
local invDetails    = invFrame.DetailsFrame
local invDescFrame  = invFrame.DescFrame
local confirmFrame  = invFrame.ConfirmFrame
local invKillerBtn  = invFrame.Killers
local invSurvBtn    = invFrame.Survivors

-- [NOVO] Botão e frame de compra de Robux
local robuxBtn   = ui.RobuxButton
local robuxFrame = ui.RobuxFrame

-- [NOVO] Os dois botões de gamepass dentro do RobuxFrame
local robuxPass1Btn = robuxFrame.ImageButton
local robuxPass2Btn = robuxFrame.ImageButton2

-- [NOVO] Troque pelos IDs reais dos seus gamepasses
local ROBUX_GAMEPASS_1_ID = 0000000
local ROBUX_GAMEPASS_2_ID = 0000000

-------------------------------------------------
-- [PATCH] CAUSA RAIZ: DescFrame tinha o mesmo ZIndex do DetailsFrame,
-- então o DetailsFrame (desenhado depois no Explorer) ficava por cima
-- e escondia a descrição, mesmo com ela Visible = true e com texto certo.
-- Aqui garantimos que o DescFrame sempre desenhe acima do DetailsFrame.
-------------------------------------------------

shopDescFrame.ZIndex = shopDetails.ZIndex + 1
invDescFrame.ZIndex  = invDetails.ZIndex + 1

-------------------------------------------------
-- SONS
-------------------------------------------------

local clickSound = Instance.new("Sound")
clickSound.SoundId = "rbxassetid://720166642"
clickSound.Volume  = 0.5
clickSound.Parent  = ui

local hoverSound = Instance.new("Sound")
hoverSound.SoundId = "rbxassetid://6042053626"
hoverSound.Volume  = 0.3
hoverSound.Parent  = ui

-------------------------------------------------
-- TAMANHOS ORIGINAIS
-------------------------------------------------

local origSizes = {}
local function storeOrigSize(obj)
	origSizes[obj] = obj.Size
end
local function getOrigSize(obj)
	return origSizes[obj] or obj.Size
end

storeOrigSize(shopFrame)
storeOrigSize(invFrame)
storeOrigSize(shopDescFrame)
storeOrigSize(invDescFrame)
storeOrigSize(buySkinFrame)
storeOrigSize(confirmFrame)
storeOrigSize(robuxFrame) -- [NOVO]

-------------------------------------------------
-- TWEEN HELPERS
-------------------------------------------------

local TWEEN_OPEN  = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_CLOSE = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local TWEEN_HOVER = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_CLICK = TweenInfo.new(0.10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local FALLBACK_DESC_SIZE = UDim2.new(0.3, 0, 1, 0) -- só usado se o tamanho original vier zerado
local FALLBACK_DESC_TEXT = "Sem descrição disponível."

local function frameOpen(frame, ti)
	local target = getOrigSize(frame)

	if target.X.Scale == 0 and target.X.Offset == 0
		and target.Y.Scale == 0 and target.Y.Offset == 0 then
		warn(("[UI] Tamanho original de '%s' estava zerado, usando fallback."):format(frame:GetFullName()))
		target = FALLBACK_DESC_SIZE
		origSizes[frame] = target
	end

	frame.Size    = UDim2.new(0, 0, target.Y.Scale, target.Y.Offset)
	frame.Visible = true
	TweenService:Create(frame, ti or TWEEN_OPEN, { Size = target }):Play()
end

local function frameClose(frame, ti, onComplete)
	local cur = frame.Size
	TweenService:Create(frame, ti or TWEEN_CLOSE, {
		Size = UDim2.new(0, 0, cur.Y.Scale, cur.Y.Offset)
	}):Play()
	task.delay((ti or TWEEN_CLOSE).Time, function()
		frame.Visible = false
		if onComplete then onComplete() end
	end)
end

local function openDetails(frame)
	frame.Visible = true
	TweenService:Create(frame, TWEEN_OPEN, {
		Size = UDim2.new(0.3, 0, 1, 0)
	}):Play()
end

local function closeDetails(frame)
	if not frame.Visible then return end
	TweenService:Create(frame, TWEEN_CLOSE, {
		Size = UDim2.new(0, 0, 1, 0)
	}):Play()
	task.delay(TWEEN_CLOSE.Time, function()
		frame.Visible = false
	end)
end

-------------------------------------------------
-- ADMIN / XP
-------------------------------------------------

local function isPlayerAdmin()
	return player:GetAttribute("Admin") == true
end

local BASE_XP = 100
local XP_STEP = 75

local function xpForNextLevel(level)
	return BASE_XP + (level * XP_STEP)
end

local function getCharacterXPData(characterName, isKiller)
	local folder   = actors:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder  then return nil, nil end
	local charVal  = folder:FindFirstChild(characterName)
	if not charVal then return nil, nil end
	local xpVal    = charVal:FindFirstChild("XP")
	local levelVal = charVal:FindFirstChild("Level")
	if not xpVal or not levelVal then return nil, nil end
	return xpVal.Value, levelVal.Value
end

-------------------------------------------------
-- SAVE DE ABAS (local)
-------------------------------------------------

local savedTab = { shop = true, inv = true }

-------------------------------------------------
-- EFEITOS DE BOTÃO
-------------------------------------------------

local HOVER_SCALE  = 0.01
local toggleColors = {}

local function invertColor(c)
	return Color3.new(1 - c.R, 1 - c.G, 1 - c.B)
end

local function applyEffects(btn)
	if not btn or not btn:IsA("GuiButton") then return end

	local origSize = btn.Size
	local bigSize  = UDim2.new(
		origSize.X.Scale, origSize.X.Offset,
		origSize.Y.Scale + HOVER_SCALE, origSize.Y.Offset
	)
	local origBG   = btn.BackgroundColor3
	local origText = btn:IsA("TextButton") and btn.TextColor3 or nil
	local origImg  = btn:IsA("ImageButton") and btn.ImageColor3 or nil

	local function colorIn()
		TweenService:Create(btn, TWEEN_CLICK, { BackgroundColor3 = invertColor(origBG) }):Play()
		if origText then TweenService:Create(btn, TWEEN_CLICK, { TextColor3  = invertColor(origText) }):Play() end
		if origImg  then TweenService:Create(btn, TWEEN_CLICK, { ImageColor3 = invertColor(origImg)  }):Play() end
	end
	local function colorOut()
		TweenService:Create(btn, TWEEN_CLICK, { BackgroundColor3 = origBG }):Play()
		if origText then TweenService:Create(btn, TWEEN_CLICK, { TextColor3  = origText }):Play() end
		if origImg  then TweenService:Create(btn, TWEEN_CLICK, { ImageColor3 = origImg  }):Play() end
	end

	local infoTI = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	local info   = btn:FindFirstChild("Info")

	btn.MouseButton1Down:Connect(function()
		clickSound:Play()
		colorIn()
	end)
	btn.MouseButton1Up:Connect(function()
		colorOut()
	end)
	btn.MouseEnter:Connect(function()
		hoverSound:Play()
		TweenService:Create(btn, TWEEN_HOVER, { Size = bigSize }):Play()
		if info then
			info.Visible = true
			TweenService:Create(info, infoTI, { Size = UDim2.new(2, 0, 1, 0) }):Play()
		end
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TWEEN_HOVER, { Size = origSize }):Play()
		colorOut()
		if info then
			TweenService:Create(info, infoTI, { Size = UDim2.new(0, 0, 1, 0) }):Play()
			task.delay(0.1, function() info.Visible = false end)
		end
	end)
end

local function setupToggleBtn(btn)
	local origSize = btn.Size
	local bigSize  = UDim2.new(
		origSize.X.Scale, origSize.X.Offset,
		origSize.Y.Scale + HOVER_SCALE, origSize.Y.Offset
	)
	toggleColors[btn] = {
		bg   = btn.BackgroundColor3,
		text = btn:IsA("TextButton") and btn.TextColor3 or nil,
		img  = btn:IsA("ImageButton") and btn.ImageColor3 or nil,
	}
	btn.MouseButton1Down:Connect(function() clickSound:Play() end)
	btn.MouseEnter:Connect(function()
		hoverSound:Play()
		TweenService:Create(btn, TWEEN_HOVER, { Size = bigSize }):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TWEEN_HOVER, { Size = origSize }):Play()
	end)
end

local function setToggleActive(btn, active)
	local c = toggleColors[btn]
	if not c then return end
	if active then
		TweenService:Create(btn, TWEEN_CLICK, { BackgroundColor3 = invertColor(c.bg) }):Play()
		if c.text then TweenService:Create(btn, TWEEN_CLICK, { TextColor3  = invertColor(c.text) }):Play() end
		if c.img  then TweenService:Create(btn, TWEEN_CLICK, { ImageColor3 = invertColor(c.img)  }):Play() end
	else
		TweenService:Create(btn, TWEEN_CLICK, { BackgroundColor3 = c.bg }):Play()
		if c.text then TweenService:Create(btn, TWEEN_CLICK, { TextColor3  = c.text }):Play() end
		if c.img  then TweenService:Create(btn, TWEEN_CLICK, { ImageColor3 = c.img  }):Play() end
	end
end

setupToggleBtn(shopBtn)
setupToggleBtn(invBtn)
setupToggleBtn(robuxBtn) -- [NOVO]

for _, btn in ipairs({
	shopKillerBtn, shopSurvBtn,
	invKillerBtn,  invSurvBtn,
	shopDetails.Desc,  shopDetails.Buy,  shopDetails.Skins,
	invDetails.Desc,   invDetails.Equip, invDetails.Skins,
	buySkinFrame.Buy,  buySkinFrame.Cancel,
	confirmFrame.Confirm, confirmFrame.Cancel,
	robuxPass1Btn, robuxPass2Btn, -- [NOVO]
	}) do
	applyEffects(btn)
end

-------------------------------------------------
-- STATE
-------------------------------------------------

local shopState = {
	isKiller        = savedTab.shop,
	charModule      = nil,
	skinModule      = nil,
	skinsConnection = nil,
	viewingSkins    = false,
}

local invState = {
	isKiller        = savedTab.inv,
	charModule      = nil,
	viewingSkins    = false,
	skinsConnection = nil,
	lastTapCard     = nil,
	lastTapTime     = 0,
}

local shopIsOpen  = false
local invIsOpen   = false
local robuxIsOpen = false -- [NOVO]

-------------------------------------------------
-- OWNERSHIP & VALIDAÇÃO
-------------------------------------------------

local function moduleExists(module, isKiller)
	local base = isKiller and killerAssets or survivorAssets
	local charFolder = base:FindFirstChild(module.CharacterName)
	if not charFolder then return false end
	if module.IsSkin then
		local skinsFolder = charFolder:FindFirstChild("Skins")
		return skinsFolder and skinsFolder:FindFirstChild(module.RigName) ~= nil
	end
	return charFolder:FindFirstChild("Default") ~= nil
end

local function playerOwns(module, isKillerOverride)
	local isKiller = isKillerOverride ~= nil and isKillerOverride or module.IsKiller
	local folder   = actors:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder then return false end
	if module.IsSkin then
		local charVal = folder:FindFirstChild(module.CharacterName)
		if not charVal then return false end
		local skinsFolder = charVal:FindFirstChild("Skins")
		if not skinsFolder then return false end
		return skinsFolder:FindFirstChild(module.CharacterName .. "_" .. module.RigName) ~= nil
	end
	return folder:FindFirstChild(module.CharacterName) ~= nil
end

local function cleanInvalidSkins(isKiller)
	local folder = actors:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder then return end
	for _, charVal in ipairs(folder:GetChildren()) do
		if not charVal:IsA("BoolValue") then continue end
		local skinsFolder = charVal:FindFirstChild("Skins")
		if not skinsFolder then continue end
		for _, skinBool in ipairs(skinsFolder:GetChildren()) do
			if not skinBool:IsA("BoolValue") then continue end
			local parts = string.split(skinBool.Name, "_")
			if #parts < 2 then continue end
			local skinName    = parts[2]
			local base        = isKiller and killerAssets or survivorAssets
			local charFolder  = base:FindFirstChild(charVal.Name)
			if not charFolder then skinBool:Destroy(); continue end
			local skinsAssets = charFolder:FindFirstChild("Skins")
			if not skinsAssets or not skinsAssets:FindFirstChild(skinName) then
				skinBool:Destroy()
			end
		end
	end
end

-------------------------------------------------
-- CHECAGEM DE CONTEÚDO
-------------------------------------------------

local function characterHasSkins(charModule, isKiller, forInventory)
	local assetsFolder = (isKiller and killerAssets or survivorAssets):FindFirstChild(charModule.CharacterName)
	if not assetsFolder then return false end
	local skinsFolder = assetsFolder:FindFirstChild("Skins")
	if not skinsFolder then return false end
	for _, skinScript in ipairs(skinsFolder:GetChildren()) do
		if not skinScript:IsA("ModuleScript") then continue end
		local ok, skinMod = pcall(require, skinScript)
		if not ok then continue end
		if skinMod.Admin    and not isPlayerAdmin()              then continue end
		if not forInventory and skinMod.Exclusive                then continue end
		if forInventory     and not playerOwns(skinMod, isKiller) then continue end
		return true
	end
	return false
end

local function characterHasDescription(charModule)
	local desc = charModule.CharacterDescription
	return desc ~= nil and desc ~= ""
end

-------------------------------------------------
-- EQUIPPED HELPERS
-------------------------------------------------

local function getEquippedChar(isKiller)
	local val = equipped:FindFirstChild(isKiller and "Killer" or "Survivor")
	return val and val.Value or ""
end

local function getEquippedSkin(isKiller, characterName)
	local skinsEq = equipped:FindFirstChild("Skins")
	if not skinsEq then return "Default" end
	local folder = skinsEq:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder then return "Default" end
	local val = folder:FindFirstChild(characterName)
	return val and val.Value or "Default"
end

-------------------------------------------------
-- SCROLL HELPERS
-------------------------------------------------

local function clearScroll(scroll, template)
	for _, v in ipairs(scroll:GetChildren()) do
		if v:IsA("GuiObject") and v ~= template then v:Destroy() end
	end
end

-- Shop SkinInfo
local function setShopSkinInfo(text)
	local label = shopScroll:FindFirstChild("SkinInfo") or shopFrame:FindFirstChild("SkinInfo")
	if not label then return end
	if text then
		label.Text    = text
		label.Visible = true
	else
		label.Visible = false
	end
end

-- Inventory SkinInfo
local function setSkinInfo(text)
	local label = invScroll:FindFirstChild("SkinInfo") or invFrame:FindFirstChild("SkinInfo")
	if not label then return end
	if text then
		label.Text    = text
		label.Visible = true
	else
		label.Visible = false
	end
end

local function makeCard(template, scroll, module)
	local card = template:Clone()
	card.Visible = true
	card.CharacterName.Text = (module.IsSkin and module.RigName) or module.CharacterName
	card.RenderImage.Image  = "rbxthumb://type=Asset&id=" .. (module.CharacterRenderImage or "0") .. "&w=420&h=420"
	if card:FindFirstChild("Price") then
		card.Price.Text = module.CharacterPrice or "Free"
	end
	if module.IsSkin then
		local info = card:FindFirstChild("Info")
		if info then
			local label = info:FindFirstChildWhichIsA("TextLabel")
				or info:FindFirstChildWhichIsA("TextButton")
			if label then
				label.Text = tostring(module.RapidCharacterInfo or "")
			elseif info:IsA("TextLabel") or info:IsA("TextButton") then
				info.Text = tostring(module.RapidCharacterInfo or "")
			end
		end
	end
	card.Parent = scroll
	applyEffects(card)
	return card
end

-------------------------------------------------
-- FORWARD DECLARATIONS
-------------------------------------------------

local shopShowCharacter
local invShowCharacter
local invLoadSection

-------------------------------------------------
-- SHOP
-------------------------------------------------

local function shopSetBtnStates(charModule, isKiller)
	shopDetails.Buy.Visible = not playerOwns(charModule, isKiller)
end

local function shopCloseDetails()
	shopState.charModule   = nil
	shopState.skinModule   = nil
	shopState.viewingSkins = false
	setShopSkinInfo(nil)
	if shopDescFrame.Visible then frameClose(shopDescFrame) end
	if buySkinFrame.Visible  then frameClose(buySkinFrame)  end
	closeDetails(shopDetails)
end

local function shopRepopulateChars(isKiller)
	clearScroll(shopScroll, shopTemplate)
	setShopSkinInfo(nil)
	local folder = isKiller and killerAssets or survivorAssets
	for _, charFolder in ipairs(folder:GetChildren()) do
		local defaultModule = charFolder:FindFirstChild("Default")
		if not defaultModule then continue end
		local ok, module = pcall(require, defaultModule)
		if not ok then continue end
		if module.Admin    and not isPlayerAdmin() then continue end
		if module.Exclusive                        then continue end
		local card  = makeCard(shopTemplate, shopScroll, module)
		local owned = card:FindFirstChild("Owned")
		if owned then owned.Visible = playerOwns(module, isKiller) end
		card.MouseButton1Click:Connect(function()
			shopShowCharacter(defaultModule, isKiller)
		end)
	end
end

local function shopShowSkins(charModule, isKiller)
	shopState.viewingSkins = true
	clearScroll(shopScroll, shopTemplate)
	setShopSkinInfo(charModule.CharacterName)
	local assetsFolder = (isKiller and killerAssets or survivorAssets):FindFirstChild(charModule.CharacterName)
	if not assetsFolder then return end
	local skinsFolder = assetsFolder:FindFirstChild("Skins")
	if not skinsFolder then return end
	for _, skinScript in ipairs(skinsFolder:GetChildren()) do
		if not skinScript:IsA("ModuleScript") then continue end
		local ok, skinModule = pcall(require, skinScript)
		if not ok then continue end
		if skinModule.Admin    and not isPlayerAdmin() then continue end
		if skinModule.Exclusive                        then continue end
		local card  = makeCard(shopTemplate, shopScroll, skinModule)
		local owned = card:FindFirstChild("Owned")
		if owned then owned.Visible = playerOwns(skinModule, isKiller) end
		card.MouseButton1Click:Connect(function()
			if playerOwns(skinModule, isKiller) then return end
			shopState.skinModule       = skinModule
			shopState.skinModuleScript = skinScript
			frameOpen(buySkinFrame)
			if buySkinFrame:FindFirstChild("Price") then
				buySkinFrame.Price.Text = "Price: " .. (skinModule.CharacterPrice or "Free")
			end
			if buySkinFrame:FindFirstChild("RenderImage") then
				buySkinFrame.RenderImage.Image = "rbxthumb://type=Asset&id=" .. (skinModule.CharacterRenderImage or "0") .. "&w=420&h=420"
			end
		end)
	end
end

shopShowCharacter = function(moduleScript, isKiller)
	shopState.viewingSkins     = false
	shopState.skinModule       = nil
	shopState.skinModuleScript = nil
	setShopSkinInfo(nil)
	if shopDescFrame.Visible then frameClose(shopDescFrame) end
	if buySkinFrame.Visible  then frameClose(buySkinFrame)  end
	local ok, module = pcall(require, moduleScript)
	if not ok then return end
	module.__ModuleScript = moduleScript
	shopState.charModule  = module
	shopDetails.CharacterName.Text = module.CharacterName or "???"
	shopDetails.Photo.Image = "rbxthumb://type=Asset&id=" .. (module.CharacterRenderImage or "0") .. "&w=420&h=420"
	shopDetails.RapidInfo.Text = tostring(module.RapidCharacterInfo or "")
	if shopDetails:FindFirstChild("Price") then
		shopDetails.Price.Text = "Price: " .. (module.CharacterPrice or "Free")
	end
	shopSetBtnStates(module, isKiller)
	openDetails(shopDetails)
	if shopState.skinsConnection then shopState.skinsConnection:Disconnect() end
	shopState.skinsConnection = shopDetails.Skins.MouseButton1Click:Connect(function()
		if shopState.viewingSkins then
			shopState.viewingSkins = false
			shopRepopulateChars(shopState.isKiller)
			return
		end
		if not characterHasSkins(shopState.charModule, shopState.isKiller, false) then return end
		shopShowSkins(shopState.charModule, shopState.isKiller)
	end)
end

shopDetails.Desc.MouseButton1Click:Connect(function()
	if not shopState.charModule then return end
	if not characterHasDescription(shopState.charModule) then return end
	if shopDescFrame.Visible then
		frameClose(shopDescFrame)
	else
		shopDescFrame.Label.Text = shopState.charModule.CharacterDescription or FALLBACK_DESC_TEXT
		frameOpen(shopDescFrame)
	end
end)

shopDetails.Buy.MouseButton1Click:Connect(function()
	if not shopState.charModule then return end
	buyCharacterEvent:FireServer(shopState.charModule.CharacterName, shopState.isKiller)
end)

buySkinFrame.Buy.MouseButton1Click:Connect(function()
	if not shopState.skinModule then return end
	local m = shopState.skinModule
	buySkinEvent:FireServer(m.CharacterName, m.RigName, shopState.isKiller)
	frameClose(buySkinFrame, nil, function()
		task.wait(0.3)
		if shopState.charModule then
			shopShowSkins(shopState.charModule, shopState.isKiller)
		end
	end)
end)

buySkinFrame.Cancel.MouseButton1Click:Connect(function()
	frameClose(buySkinFrame)
end)

local function shopLoadSection(isKiller)
	savedTab.shop       = isKiller
	shopState.isKiller  = isKiller
	shopCloseDetails()
	cleanInvalidSkins(isKiller)
	shopRepopulateChars(isKiller)
	TweenService:Create(shopKillerBtn, TWEEN_CLICK, {
		BackgroundColor3 = isKiller and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
	}):Play()
	TweenService:Create(shopSurvBtn, TWEEN_CLICK, {
		BackgroundColor3 = (not isKiller) and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
	}):Play()
end

shopKillerBtn.MouseButton1Click:Connect(function() shopLoadSection(true)  end)
shopSurvBtn.MouseButton1Click:Connect(function()   shopLoadSection(false) end)

-------------------------------------------------
-- INVENTORY
-------------------------------------------------

local function invCloseConfirm()
	if confirmFrame.Visible then frameClose(confirmFrame) end
end

local function invRefreshEquipButton(module, isKiller)
	local isEq              = getEquippedChar(isKiller) == module.CharacterName
	invDetails.Equip.Text   = isEq and "Equipped" or "Equip"
	invDetails.Equip.Active = not isEq
end

local function invUpdateXPDisplay(characterName, isKiller)
	local xp, level = getCharacterXPData(characterName, isKiller)
	local label = invDetails:FindFirstChild("XP")
	if not xp or not level then
		if label then label.Visible = false end
		return
	end
	if not label then
		label = Instance.new("TextLabel")
		label.Name                   = "XP"
		label.Size                   = UDim2.new(1, 0, 0.15, 0)
		label.Position               = UDim2.new(0, 0, 0.75, 0)
		label.BackgroundTransparency = 1
		label.TextColor3             = Color3.fromRGB(255, 255, 255)
		label.TextScaled             = true
		label.Font                   = Enum.Font.GothamBold
		label.Parent                 = invDetails
	end
	label.Visible = true
	label.Text    = string.format("XP: %d/%d\nLevel: %d", xp, xpForNextLevel(level), level)
end

local function invRefreshBadges(isKiller)
	if invState.viewingSkins and invState.charModule then
		local eqSkin = getEquippedSkin(isKiller, invState.charModule.CharacterName)
		for _, c in ipairs(invScroll:GetChildren()) do
			if c:IsA("GuiObject") and c ~= invTemplate then
				local badge = c:FindFirstChild("EquippedBadge")
				if badge then badge.Visible = (c.CharacterName.Text == eqSkin) end
			end
		end
	else
		local eqChar = getEquippedChar(isKiller)
		for _, c in ipairs(invScroll:GetChildren()) do
			if c:IsA("GuiObject") and c ~= invTemplate then
				local badge = c:FindFirstChild("EquippedBadge")
				if badge then badge.Visible = (c.CharacterName.Text == eqChar) end
			end
		end
	end
	if invState.charModule then
		invRefreshEquipButton(invState.charModule, isKiller)
	end
end

local DOUBLE_TAP = 0.4

local function invEquipSkin(skinModule, isKiller)
	if skinModule then
		equipSkinEvent:FireServer(skinModule.CharacterName, skinModule.RigName, isKiller)
	elseif invState.charModule then
		equipSkinEvent:FireServer(invState.charModule.CharacterName, "Default", isKiller)
	end
	task.wait(0.2)
	invRefreshBadges(isKiller)
end

local function invRepopulateChars(isKiller)
	clearScroll(invScroll, invTemplate)
	setSkinInfo(nil)
	local folder = isKiller and killerAssets or survivorAssets
	for _, charFolder in ipairs(folder:GetChildren()) do
		local defaultModule = charFolder:FindFirstChild("Default")
		if not defaultModule then continue end
		local ok, module = pcall(require, defaultModule)
		if not ok then continue end
		if not playerOwns(module, isKiller) then continue end
		local card  = makeCard(invTemplate, invScroll, module)
		local badge = card:FindFirstChild("EquippedBadge")
		if badge then badge.Visible = (getEquippedChar(isKiller) == module.CharacterName) end
		card.MouseButton1Click:Connect(function()
			invShowCharacter(defaultModule, isKiller)
		end)
	end
end

local function invShowSkins(charModule, isKiller)
	invState.viewingSkins = true
	clearScroll(invScroll, invTemplate)
	setSkinInfo(charModule.CharacterName)

	local eqSkin = getEquippedSkin(isKiller, charModule.CharacterName)

	local defaultMod = {
		CharacterName        = "Default",
		RigName              = "Default",
		CharacterRenderImage = charModule.CharacterRenderImage,
		CharacterPrice       = "Free",
		IsSkin               = false,
	}
	local defaultCard = makeCard(invTemplate, invScroll, defaultMod)
	local defBadge    = defaultCard:FindFirstChild("EquippedBadge")
	if defBadge then defBadge.Visible = (eqSkin == "Default") end

	defaultCard.MouseButton1Click:Connect(function()
		local now = tick()
		if invState.lastTapCard == defaultCard and (now - invState.lastTapTime) <= DOUBLE_TAP then
			invEquipSkin(nil, isKiller)
			invState.lastTapCard = nil
			invState.lastTapTime = 0
		else
			invState.lastTapCard = defaultCard
			invState.lastTapTime = now
		end
	end)

	local assetsFolder = (isKiller and killerAssets or survivorAssets):FindFirstChild(charModule.CharacterName)
	if not assetsFolder then return end
	local skinsFolder = assetsFolder:FindFirstChild("Skins")
	if not skinsFolder then return end

	for _, skinScript in ipairs(skinsFolder:GetChildren()) do
		if not skinScript:IsA("ModuleScript") then continue end
		local ok, skinModule = pcall(require, skinScript)
		if not ok then continue end
		if skinModule.Admin and not isPlayerAdmin()       then continue end
		if not playerOwns(skinModule, isKiller)           then continue end
		if not moduleExists(skinModule, isKiller)         then continue end

		local card  = makeCard(invTemplate, invScroll, skinModule)
		local badge = card:FindFirstChild("EquippedBadge")
		if badge then badge.Visible = (eqSkin == skinModule.RigName) end

		card.MouseButton1Click:Connect(function()
			local now = tick()
			if invState.lastTapCard == card and (now - invState.lastTapTime) <= DOUBLE_TAP then
				invEquipSkin(skinModule, isKiller)
				invState.lastTapCard = nil
				invState.lastTapTime = 0
			else
				invState.lastTapCard = card
				invState.lastTapTime = now
			end
		end)
	end
end

invShowCharacter = function(moduleScript, isKiller)
	invState.viewingSkins = false
	invState.lastTapCard  = nil
	invState.lastTapTime  = 0
	if invDescFrame.Visible then frameClose(invDescFrame) end
	invCloseConfirm()
	setSkinInfo(nil)

	local ok, module = pcall(require, moduleScript)
	if not ok then return end
	module.__ModuleScript = moduleScript
	invState.charModule   = module

	invDetails.CharacterName.Text = module.CharacterName or "???"
	invDetails.Photo.Image        = "rbxthumb://type=Asset&id=" .. (module.CharacterRenderImage or "0") .. "&w=420&h=420"
	invDetails.RapidInfo.Text     = tostring(module.RapidCharacterInfo or "")
	if invDetails:FindFirstChild("Price") then
		invDetails.Price.Text = "Price: " .. (module.CharacterPrice or "Free")
	end

	invRefreshEquipButton(module, isKiller)
	invUpdateXPDisplay(module.CharacterName, isKiller)
	openDetails(invDetails)

	if invState.skinsConnection then invState.skinsConnection:Disconnect() end
	invState.skinsConnection = invDetails.Skins.MouseButton1Click:Connect(function()
		if invState.viewingSkins then
			invState.viewingSkins = false
			invRepopulateChars(invState.isKiller)
			return
		end
		if not characterHasSkins(invState.charModule, invState.isKiller, true) then return end
		invShowSkins(invState.charModule, invState.isKiller)
	end)
end

invDetails.Desc.MouseButton1Click:Connect(function()
	if not invState.charModule then return end
	if not characterHasDescription(invState.charModule) then return end
	if invDescFrame.Visible then
		frameClose(invDescFrame)
	else
		invDescFrame.Label.Text = invState.charModule.CharacterDescription or FALLBACK_DESC_TEXT
		frameOpen(invDescFrame)
	end
end)

invDetails.Equip.MouseButton1Click:Connect(function()
	if not invState.charModule then return end
	equipCharacterEvent:FireServer(invState.charModule.CharacterName, invState.isKiller)
end)

confirmFrame.Confirm.MouseButton1Click:Connect(function() end)
confirmFrame.Cancel.MouseButton1Click:Connect(function()
	invCloseConfirm()
end)

invLoadSection = function(isKiller)
	savedTab.inv          = isKiller
	invState.isKiller     = isKiller
	invState.viewingSkins = false
	invState.lastTapCard  = nil
	invState.lastTapTime  = 0
	invCloseConfirm()
	if invDescFrame.Visible then frameClose(invDescFrame) end
	invState.charModule = nil
	cleanInvalidSkins(isKiller)
	closeDetails(invDetails)
	invRepopulateChars(isKiller)
	TweenService:Create(invKillerBtn, TWEEN_CLICK, {
		BackgroundColor3 = isKiller and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
	}):Play()
	TweenService:Create(invSurvBtn, TWEEN_CLICK, {
		BackgroundColor3 = (not isKiller) and Color3.fromRGB(255,255,255) or Color3.fromRGB(0,0,0)
	}):Play()
end

invKillerBtn.MouseButton1Click:Connect(function() invLoadSection(true)  end)
invSurvBtn.MouseButton1Click:Connect(function()   invLoadSection(false) end)

-------------------------------------------------
-- BOTÕES TOGGLE
-------------------------------------------------

shopBtn.MouseButton1Click:Connect(function()
	local opening = not shopIsOpen
	shopIsOpen = opening

	if invIsOpen then
		invIsOpen = false
		setToggleActive(invBtn, false)
		frameClose(invFrame)
		closeDetails(invDetails)
	end

	-- [NOVO] fecha o Robux se estiver aberto
	if robuxIsOpen then
		robuxIsOpen = false
		setToggleActive(robuxBtn, false)
		frameClose(robuxFrame)
	end

	if opening then
		setToggleActive(shopBtn, true)
		frameOpen(shopFrame)
		shopLoadSection(savedTab.shop)
	else
		setToggleActive(shopBtn, false)
		frameClose(shopFrame, nil, function() shopCloseDetails() end)
	end
end)

invBtn.MouseButton1Click:Connect(function()
	local opening = not invIsOpen
	invIsOpen = opening

	if shopIsOpen then
		shopIsOpen = false
		setToggleActive(shopBtn, false)
		frameClose(shopFrame)
		shopCloseDetails()
	end

	-- [NOVO] fecha o Robux se estiver aberto
	if robuxIsOpen then
		robuxIsOpen = false
		setToggleActive(robuxBtn, false)
		frameClose(robuxFrame)
	end

	if opening then
		setToggleActive(invBtn, true)
		frameOpen(invFrame)
		invLoadSection(savedTab.inv)
	else
		setToggleActive(invBtn, false)
		frameClose(invFrame, nil, function() closeDetails(invDetails) end)
	end
end)

-- [NOVO] Toggle do Robux, seguindo o mesmo padrão do Shop/Inventário
robuxBtn.MouseButton1Click:Connect(function()
	local opening = not robuxIsOpen
	robuxIsOpen = opening

	if shopIsOpen then
		shopIsOpen = false
		setToggleActive(shopBtn, false)
		frameClose(shopFrame)
		shopCloseDetails()
	end

	if invIsOpen then
		invIsOpen = false
		setToggleActive(invBtn, false)
		frameClose(invFrame)
		closeDetails(invDetails)
	end

	if opening then
		setToggleActive(robuxBtn, true)
		frameOpen(robuxFrame)
	else
		setToggleActive(robuxBtn, false)
		frameClose(robuxFrame)
	end
end)

-- [NOVO] Cada ImageButton abre a tela de compra de um gamepass diferente
robuxPass1Btn.MouseButton1Click:Connect(function()
	MarketplaceService:PromptGamePassPurchase(player, ROBUX_GAMEPASS_1_ID)
end)

robuxPass2Btn.MouseButton1Click:Connect(function()
	MarketplaceService:PromptGamePassPurchase(player, ROBUX_GAMEPASS_2_ID)
end)

-------------------------------------------------
-- WATCHERS
-------------------------------------------------

equipped:WaitForChild("Killer").Changed:Connect(function()
	if invIsOpen and invState.isKiller then invRefreshBadges(true) end
end)

equipped:WaitForChild("Survivor").Changed:Connect(function()
	if invIsOpen and not invState.isKiller then invRefreshBadges(false) end
end)

local function watchSkinValues(isKiller)
	local skinsEq = equipped:WaitForChild("Skins")
	local folder  = skinsEq:WaitForChild(isKiller and "Killer" or "Survivor")
	local function connect(val)
		val.Changed:Connect(function()
			if invIsOpen and invState.isKiller == isKiller then
				invRefreshBadges(isKiller)
			end
		end)
	end
	for _, val in ipairs(folder:GetChildren()) do connect(val) end
	folder.ChildAdded:Connect(connect)
end
watchSkinValues(true)
watchSkinValues(false)

local function watchNewCharacters(isKiller)
	local folder = actors:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder then return end
	folder.ChildAdded:Connect(function()
		task.wait(0.1)
		if invIsOpen  and invState.isKiller  == isKiller then invLoadSection(isKiller)  end
		if shopIsOpen and shopState.isKiller == isKiller then shopLoadSection(isKiller) end
	end)
end
watchNewCharacters(true)
watchNewCharacters(false)

local function watchNewSkins(isKiller)
	local folder = actors:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder then return end
	local function monitorSkinFolder(skinsFolder, characterName)
		skinsFolder.ChildAdded:Connect(function()
			task.wait(0.1)
			if invIsOpen and invState.viewingSkins and
				invState.charModule and invState.charModule.CharacterName == characterName and
				invState.isKiller == isKiller then
				invShowSkins(invState.charModule, isKiller)
			end
			if shopIsOpen and shopState.viewingSkins and shopState.charModule and
				shopState.charModule.CharacterName == characterName and
				shopState.isKiller == isKiller then
				shopShowSkins(shopState.charModule, isKiller)
			end
		end)
	end
	local function monitorCharacter(charVal)
		if not charVal:IsA("BoolValue") then return end
		local skinsFolder = charVal:FindFirstChild("Skins")
		if not skinsFolder then
			charVal.ChildAdded:Connect(function(child)
				if child.Name == "Skins" and child:IsA("Folder") then
					monitorSkinFolder(child, charVal.Name)
				end
			end)
		else
			monitorSkinFolder(skinsFolder, charVal.Name)
		end
	end
	for _, charVal in ipairs(folder:GetChildren()) do monitorCharacter(charVal) end
	folder.ChildAdded:Connect(function(charVal) monitorCharacter(charVal) end)
end
watchNewSkins(true)
watchNewSkins(false)

local function watchXPChanges(isKiller)
	local folder = actors:FindFirstChild(isKiller and "Killer" or "Survivor")
	if not folder then return end
	local function monitorCharXP(charVal)
		if not charVal:IsA("BoolValue") then return end
		local function setupWatchers()
			local xp    = charVal:FindFirstChild("XP")
			local level = charVal:FindFirstChild("Level")
			if xp then
				xp.Changed:Connect(function()
					if invState.charModule and invState.charModule.CharacterName == charVal.Name
						and invState.isKiller == isKiller and invIsOpen then
						invUpdateXPDisplay(charVal.Name, isKiller)
					end
				end)
			end
			if level then
				level.Changed:Connect(function()
					if invState.charModule and invState.charModule.CharacterName == charVal.Name
						and invState.isKiller == isKiller and invIsOpen then
						invUpdateXPDisplay(charVal.Name, isKiller)
					end
				end)
			end
		end
		setupWatchers()
		charVal.ChildAdded:Connect(function(child)
			if child.Name == "XP" or child.Name == "Level" then setupWatchers() end
		end)
	end
	for _, charVal in ipairs(folder:GetChildren()) do monitorCharXP(charVal) end
	folder.ChildAdded:Connect(function(charVal) monitorCharXP(charVal) end)
end
watchXPChanges(true)
watchXPChanges(false)

-------------------------------------------------
-- START
-------------------------------------------------

shopLoadSection(savedTab.shop)
invLoadSection(savedTab.inv)
