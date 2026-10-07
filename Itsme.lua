local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RepStorage   = game:GetService("ReplicatedStorage")

local player   = Players.LocalPlayer
local configB  = script.Parent.Parent.ConfigButton
local configF  = script.Parent.Parent.ConfigFrame
local template = configF.Template

-- RemoteEvent para setar config
local SetConfigEvent = RepStorage:WaitForChild("SetConfig")

--------------------------------------------------
-- UI EFFECTS
--------------------------------------------------

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

--------------------------------------------------
-- HELPERS
--------------------------------------------------

local function getConfigValue(key)
	local pdata = player:FindFirstChild("PlayerData")
	if not pdata then return false end
	local config = pdata:FindFirstChild("Config")
	if not config then return false end
	local val = config:FindFirstChild(key)
	return val and val.Value or false
end

local function setConfigValue(key, value)
	SetConfigEvent:FireServer(key, value)
end

local function makeToggle(name, labelPrefix, desc, onChange)
	local card = template:Clone()
	card.Name             = name
	card.Visible          = true
	card.Label.Text       = labelPrefix .. tostring(getConfigValue(name))
	card.Parent           = template.Parent
	card.Description.Text = "(" .. tostring(desc) .. ")"

	applyEffects(card.Execute)

	card.Execute.MouseButton1Click:Connect(function()
		local new = not getConfigValue(name)
		setConfigValue(name, new)
		card.Label.Text = labelPrefix .. tostring(new)
		if onChange then onChange(new) end
	end)

	-- Monitora mudancas vindas do servidor
	local pdata = player:FindFirstChild("PlayerData")
	if pdata then
		local config = pdata:WaitForChild("Config", 5)
		if config then
			local val = config:FindFirstChild(name)
			if val then
				val:GetPropertyChangedSignal("Value"):Connect(function()
					card.Label.Text = labelPrefix .. tostring(val.Value)
					if onChange then onChange(val.Value) end
				end)
			end
		end
	end

	return card
end

--------------------------------------------------
-- CONFIG BUTTON
--------------------------------------------------

applyEffects(configB)

configB.MouseButton1Click:Connect(function()
	local now    = not configF.Visible
	local tsInfo = TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
	if now == false then
		local tween = TweenService:Create(configF, tsInfo, { Size = UDim2.new(0, 0, 0, 0) })
		tween:Play()
		tween.Completed:Connect(function()
			configF.Visible = false
		end)
	else
		configF.Visible = true
		local tween = TweenService:Create(configF, tsInfo, { Size = UDim2.new(0.3, 0, 0.699, 0) })
		tween:Play()
	end
end)

--------------------------------------------------
-- WORLD LISTENERS
--------------------------------------------------

-- Gerencia transparencia das hitboxes ao serem criadas
workspace:WaitForChild("Hitboxes").ChildAdded:Connect(function(box)
	-- Logica de ShowBoxes
	if getConfigValue("ShowBoxes") == false then
		box.Transparency = 1
	end

	-- Logica de HitLinger (faz desaparecer rapido)
	if getConfigValue("HitLinger") == true then
		wait(0.03)
		box.Transparency = 1
	end
end)

-- Gerencia caixas de colisao (QueryBox)
workspace.DescendantAdded:Connect(function(box)
	if box.Name ~= "QueryBox" then return end
	if getConfigValue("ShowColision") == true then
		box.Transparency = 0.5
	else
		box.Transparency = 1
	end
end)

--------------------------------------------------
-- TOGGLES SETUP
--------------------------------------------------

makeToggle("ShowBoxes", "Show hitboxes: ", "This option show/hide hitboxes")

makeToggle("ShowVersionInfo", "Show Version Info: ", "This option show/hide game version", function(new)
	local mainGui    = player.PlayerGui:FindFirstChild("Main")
	local versionLog = mainGui and mainGui:FindFirstChild("VersionLog")
	if versionLog then
		versionLog.Visible = new
	end
end)

makeToggle("ShowColision", "Show Colision Boxes: ", "this option show/hide players collision boxes")
makeToggle("SkipCutscene", "Skip Cutscenes: ", "This option skip intro cutscenes")
makeToggle("HitLinger", "Disable Hitbox Linger: ", "This option causes hitboxes to disappear immediately")

local mainGui    = player.PlayerGui:FindFirstChild("Main")
local versionLog = mainGui and mainGui:FindFirstChild("VersionLog")
if versionLog then
	versionLog.Visible = game.Players.LocalPlayer.PlayerData.Config.ShowVersionInfo.Value
end
