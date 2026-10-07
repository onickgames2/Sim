--// SERVICES
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

--// PLAYER
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

--// UI
local ui        = script.Parent.Parent
local specBtn   = ui.SpecButton
local specFrame = ui.SpecFrame
local nextBtn   = specFrame.Next
local backBtn   = specFrame.Back
local label     = specFrame.Label

-------------------------------------------------
-- HELPERS DE COMPATIBILIDADE (2016)
-------------------------------------------------

-- FindFirstChildOfClass nao existia: procura pelo ClassName
local function findChildOfClass(parent, className)
	for _, c in ipairs(parent:GetChildren()) do
		if c.ClassName == className then return c end
	end
	return nil
end

-- Attributes nao existiam: le um StringValue filho com esse nome
local function getStringValue(obj, name)
	local v = obj:FindFirstChild(name)
	if v and v.Value ~= "" then return v.Value end
	return nil
end

-------------------------------------------------
-- UI EFFECTS (mesmo padrao do ShopInventory)
-------------------------------------------------

local HOVER_SCALE = 0.01
local TWEEN_HOVER = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local TWEEN_CLICK = TweenInfo.new(0.1,  Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function invertColor(c)
	return Color3.new(1 - c.r, 1 - c.g, 1 - c.b)
end

local function applyEffects(btn)
	if not btn or not btn:IsA("GuiButton") then return end

	local origSize = btn.Size
	local bigSize  = UDim2.new(
		origSize.X.Scale, origSize.X.Offset,
		origSize.Y.Scale + HOVER_SCALE, origSize.Y.Offset
	)

	local origBG   = btn.BackgroundColor3
	local extraIn  = { BackgroundColor3 = invertColor(origBG) }
	local extraOut = { BackgroundColor3 = origBG }
	local enter    = { Size = UDim2.new(2, 0, 1, 0) }
	local out      = { Size = UDim2.new(0, 0, 1, 0) }
	local infoTI   = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

	if btn:IsA("TextButton") then
		local origText      = btn.TextColor3
		extraIn.TextColor3  = invertColor(origText)
		extraOut.TextColor3 = origText
	elseif btn:IsA("ImageButton") then
		local origImg        = btn.ImageColor3
		extraIn.ImageColor3  = invertColor(origImg)
		extraOut.ImageColor3 = origImg
	end

	local click = false
	local info  = btn:FindFirstChild("Info")
	local have  = info and true or false

	btn.MouseButton1Click:Connect(function()
		click = not click
		if click then
			TweenService:Create(btn, TWEEN_CLICK, extraIn):Play()
		else
			TweenService:Create(btn, TWEEN_CLICK, extraOut):Play()
		end
	end)

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TWEEN_HOVER, { Size = bigSize }):Play()
		if have then
			btn.Info.Visible = true
			TweenService:Create(btn.Info, infoTI, enter):Play()
		end
	end)

	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TWEEN_HOVER, { Size = origSize }):Play()
		if have then
			TweenService:Create(btn.Info, infoTI, out):Play()
			delay(0.1, function()
				btn.Info.Visible = false
			end)
		end
	end)
end

applyEffects(specBtn)
applyEffects(nextBtn)
applyEffects(backBtn)

-------------------------------------------------
-- STATE
-------------------------------------------------

local isSpectating  = false
local currentIndex  = 1
local aliveList     = {} -- { playerName, charName, actor }
local specPart      = nil
local heartbeatConn = nil

-------------------------------------------------
-- HELPERS
-------------------------------------------------

local function isActorInGame(actor)
	if not actor or not actor.Parent then return false end

	local playersFolder = workspace:FindFirstChild("Players")
	if not playersFolder then return false end

	local survivorsFolder = playersFolder:FindFirstChild("Survivors")
	local killersFolder   = playersFolder:FindFirstChild("Killers")

	if survivorsFolder and actor.Parent == survivorsFolder then return true end
	if killersFolder and actor.Parent == killersFolder then return true end

	return false
end

local function isInLobby()
	-- Verifica se o player tem um character ativo no jogo
	local char = player.Character
	if not char then return true end

	-- Se o character esta em Survivors ou Killers, nao esta no lobby
	return not isActorInGame(char)
end

local function buildAliveList()
	aliveList = {}
	local playersFolder = workspace:FindFirstChild("Players")
	if not playersFolder then return end

	for _, roleFolder in ipairs(playersFolder:GetChildren()) do
		if roleFolder.Name == "Survivors" or roleFolder.Name == "Killers" then
			for _, actor in ipairs(roleFolder:GetChildren()) do
				-- Actor esta vivo se esta dentro da pasta
				if actor.Parent then
					local owner    = Players:GetPlayerFromCharacter(actor)
					local pName    = owner and owner.Name or actor.Name
					-- antes era actor:GetAttribute("CharName"); agora e um StringValue "CharName"
					local charName = getStringValue(actor, "CharName") or actor.Name
					table.insert(aliveList, {
						playerName = pName,
						charName   = charName,
						actor      = actor,
					})
				end
			end
		end
	end
end

local function updateLabel()
	if #aliveList == 0 then
		label.Text = "No alive players"
		return
	end
	local data = aliveList[currentIndex]
	label.Text = data.playerName .. " | " .. data.charName
		.. " (" .. currentIndex .. "/" .. #aliveList .. ")"
end

local function stopSpectating()
	isSpectating = false

	if heartbeatConn then
		heartbeatConn:disconnect()
		heartbeatConn = nil
	end

	if specPart and specPart.Parent then
		specPart:Destroy()
		specPart = nil
	end

	-- Restaura camera
	camera.CameraType = Enum.CameraType.Custom
	local char = player.Character
	if char then
		camera.CameraSubject = findChildOfClass(char, "Humanoid")
	end

	specFrame.Visible = false
end

local function startSpectating()
	buildAliveList()

	if #aliveList == 0 then
		label.Text = "No players alive to spectate"
		stopSpectating()
		return
	end

	isSpectating      = true
	currentIndex      = 1
	specFrame.Visible = true
	updateLabel()

	-- Cria o SpecPart
	specPart              = Instance.new("Part")
	specPart.Name         = "SpecPart"
	specPart.Size         = Vector3.new(0.1, 0.1, 0.1)
	specPart.Anchored     = true
	specPart.CanCollide   = false
	specPart.Transparency = 1
	specPart.Parent       = workspace

	-- Camera segue o SpecPart
	camera.CameraType    = Enum.CameraType.Custom
	camera.CameraSubject = specPart

	-- Heartbeat: SpecPart segue o HRP do ator atual
	heartbeatConn = RunService.Heartbeat:Connect(function()
		if not isSpectating then return end

		-- Remove atores mortos da lista (atores que nao existem mais no workspace)
		for i = #aliveList, 1, -1 do
			local entry = aliveList[i]
			if not entry.actor or not entry.actor.Parent then
				table.remove(aliveList, i)
				if currentIndex > #aliveList then
					currentIndex = math.max(1, #aliveList)
				end
				updateLabel()
			end
		end

		if #aliveList == 0 then
			stopSpectating()
			return
		end

		local data = aliveList[currentIndex]
		if not data then return end

		local hrp = data.actor and data.actor:FindFirstChild("HumanoidRootPart")
		if hrp and specPart and specPart.Parent then
			specPart.CFrame = hrp.CFrame
		end
	end)
end

-------------------------------------------------
-- BUTTONS
-------------------------------------------------

specBtn.MouseButton1Click:Connect(function()
	if not isInLobby() then return end

	if isSpectating then
		stopSpectating()
	else
		startSpectating()
	end
end)

nextBtn.MouseButton1Click:Connect(function()
	if not isSpectating or #aliveList == 0 then return end
	currentIndex = (currentIndex % #aliveList) + 1
	updateLabel()
end)

backBtn.MouseButton1Click:Connect(function()
	if not isSpectating or #aliveList == 0 then return end
	currentIndex = ((currentIndex - 2) % #aliveList) + 1
	updateLabel()
end)

-------------------------------------------------
-- Esconde o botao se nao estiver no lobby
-------------------------------------------------

local function checkLobbyVisibility()
	specBtn.Visible = isInLobby()
	if not isInLobby() and isSpectating then
		stopSpectating()
	end
end

player.CharacterAdded:Connect(function(char)
	char:WaitForChild("Humanoid")
	wait(0.5)
	checkLobbyVisibility()
end)

checkLobbyVisibility()
