--// FORSAKEN STYLE UPDATE LOG
--// LocalScript (Lua 5.1)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Evita que o script inicie novamente após o reset character
if player:FindFirstChild("ForsakenLogLoadedAlready") then
	return
end

if playerGui:FindFirstChild("ForsakenLog") then
	playerGui.ForsakenLog:Destroy()
end

--// GUI

local gui = Instance.new("ScreenGui")
gui.Name = "ForsakenLog"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

--// MAIN FRAME

local frame = Instance.new("Frame")
frame.Parent = gui
frame.AnchorPoint = Vector2.new(0.5,0.5)
frame.Position = UDim2.new(0.5,0,0.5,0)
frame.Size = UDim2.new(0,640,0,430)
frame.BackgroundColor3 = Color3.fromRGB(0,0,0)
frame.BorderSizePixel = 0
frame.ClipsDescendants = true

-- Imagem de Fundo
local backgroundImage = Instance.new("ImageLabel")
backgroundImage.Parent = frame
backgroundImage.BackgroundTransparency = 1
backgroundImage.Image = "rbxthumb://type=Asset&id=79252087565074&w=420&h=420"
backgroundImage.Size = UDim2.new(1, 0, 1, 0)
backgroundImage.Position = UDim2.new(0, 0, 0, 0)
backgroundImage.ImageTransparency = 0.75
backgroundImage.ScaleType = Enum.ScaleType.Crop
backgroundImage.ZIndex = 1
backgroundImage.BorderSizePixel = 0

-- Borda principal em vermelho
local stroke = Instance.new("UIStroke")
stroke.Parent = frame
stroke.Color = Color3.new(1,0,0)
stroke.Thickness = 2

--// INNER BORDER

local inner = Instance.new("Frame")
inner.Parent = frame
inner.BackgroundTransparency = 1
inner.Position = UDim2.new(0,10,0,10)
inner.Size = UDim2.new(1,-20,1,-20)
inner.ZIndex = 2

local innerStroke = Instance.new("UIStroke")
innerStroke.Parent = inner
innerStroke.Color = Color3.new(1,0,0)
innerStroke.Thickness = 0

--// MAIN SCROLL

local MAIN_SCROLL_EXTRA = 40

local mainScroll = Instance.new("ScrollingFrame")
mainScroll.Parent = frame
mainScroll.BackgroundTransparency = 1
mainScroll.Position = UDim2.new(0,0,0,0)
mainScroll.Size = UDim2.new(1,0,1,0)
mainScroll.CanvasSize = UDim2.new(0,0,0,430 + MAIN_SCROLL_EXTRA)
mainScroll.ScrollBarThickness = 2
mainScroll.ScrollBarImageColor3 = Color3.new(1,0,0)
mainScroll.BorderSizePixel = 0
mainScroll.ZIndex = 3

--// GAME TITLE

local logo = Instance.new("TextLabel")
logo.Parent = mainScroll
logo.BackgroundTransparency = 1
logo.Position = UDim2.new(0,0,0,10)
logo.Size = UDim2.new(1,0,0,40)
logo.Text = "Bells of Demise"
logo.Font = Enum.Font.SpecialElite
logo.TextColor3 = Color3.new(1,1,1)
logo.TextSize = 34
logo.ZIndex = 3

--// GAME IMAGE

local gameImage = Instance.new("ImageLabel")
gameImage.Parent = mainScroll
gameImage.BackgroundTransparency = 1
gameImage.Image = "rbxthumb://type=Asset&id=79252087565074&w=420&h=420"
gameImage.Size = UDim2.new(0,240,0,90)
gameImage.Position = UDim2.new(0.5,-120,0,48)
gameImage.ScaleType = Enum.ScaleType.Fit
gameImage.BorderSizePixel = 0
gameImage.ZIndex = 3

--// PATCH TITLE

local title = Instance.new("TextLabel")
title.Parent = mainScroll
title.BackgroundTransparency = 1
title.Position = UDim2.new(0,40,0,140)
title.Size = UDim2.new(1,-80,0,70)
title.Text = "The Final Version (or not)"
title.Font = Enum.Font.SpecialElite
title.TextWrapped = true
title.TextColor3 = Color3.new(1,1,1)
title.TextSize = 24
title.ZIndex = 3

--// DATE

local date = Instance.new("TextLabel")
date.Parent = mainScroll
date.BackgroundTransparency = 1
date.Position = UDim2.new(0,0,0,195)
date.Size = UDim2.new(1,0,0,40)
date.Text = "7-18-26"
date.Font = Enum.Font.SpecialElite
date.TextColor3 = Color3.new(1,1,1)
date.TextSize = 32
date.ZIndex = 3

--// CLOSE BUTTON

local close = Instance.new("TextButton")
close.Parent = frame
close.Size = UDim2.new(0,70,0,70)
close.Position = UDim2.new(1,-90,0,20)
close.BackgroundColor3 = Color3.new(0,0,0)
close.Text = "X"
close.Font = Enum.Font.SpecialElite
close.TextSize = 42
close.TextColor3 = Color3.new(1,1,1)
close.BorderSizePixel = 0
close.AutoButtonColor = true
close.Active = true
close.Selectable = true
close.ZIndex = 10

local closeCorner = Instance.new("UICorner")
closeCorner.Parent = close

local closeStroke = Instance.new("UIStroke")
closeStroke.Parent = close
closeStroke.Color = Color3.new(1,0,0)
closeStroke.Thickness = 1

--// SCROLL (log)

local scroll = Instance.new("ScrollingFrame")
scroll.Parent = mainScroll
scroll.BackgroundTransparency = 1
scroll.Position = UDim2.new(0,25,0,245)
scroll.Size = UDim2.new(1,-50,1,-270)
scroll.CanvasSize = UDim2.new(0,0,2,0)
scroll.ScrollBarThickness = 2
scroll.ScrollBarImageColor3 = Color3.new(1,0,0)
scroll.BorderSizePixel = 0
scroll.ZIndex = 3

--// TEXT

local text = Instance.new("TextLabel")
text.Parent = scroll
text.BackgroundTransparency = 1
text.Size = UDim2.new(1,-10,0,0)
text.AutomaticSize = Enum.AutomaticSize.Y
text.TextXAlignment = Enum.TextXAlignment.Left
text.TextYAlignment = Enum.TextYAlignment.Top
text.Font = Enum.Font.SpecialElite
text.TextColor3 = Color3.new(1,1,1)
text.TextSize = 20
text.TextWrapped = true
text.ZIndex = 3

text.Text = [[

- New Killers and Survivors
- New Skkns
- Loading Screen Updated
- Description Problem resolved

- Heitor
- Without habilitys for a while...

- Guest 1337
- Added ImageSkin André
- Fixed Charge With no Animation
- Fixing Charge With no Animation On André Skin
- Birthday Hat on André Removed

- Lucky
- Default Skin is Back

- Shedletsky
- Sword bug fixed
- fixing BemMaxy Animations

- Two Time Survivor Added
- Skins for Two Time Will come Soon.
- Custom LMS for Two Time and Azure
- Fixed Ambience OST Bug
- Chase Theme for all Killers Added
- Fixed Charge anim for Guest1337

- DETG (V5) ImageSkin Added
- Azure ImageKiller Added
- 1x4 ImageKiller Added
- Fixed LMS' Butcher Skins
- Added Azure Killer 
- Fixed Butcher not Loading LMS
- New c00lCarnival Map OST
- Rework Destroyed town Map  
- New CrossRoads Map OST
- M1/M2 (1x4) Skin Killer Added
- Dark ambience added
- New LMS for DETG Added 
- Reworking on Generator UI
- Shucks Mellowalley Skin Added
- Azure Intro
 
- Lobby
- Nothing changed LOL
- Herobrine Removed

]]

-- Atualiza tamanho do scroll automaticamente
wait()
if text and text.Parent then
	scroll.CanvasSize = UDim2.new(0, 0, 0, text.AbsoluteSize.Y + 10)
end

--// ESCALA MOBILE

local scale = Instance.new("UIScale")
scale.Parent = frame

local DESIGN_WIDTH = 640
local DESIGN_HEIGHT = 430
local SAFE_PADDING = 40

local mobileScale = 1
local animScale = 0.01

local function applyScale()
	scale.Scale = math.clamp(mobileScale * animScale, 0.001, 10)
end

local function resize()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local view = camera.ViewportSize

	local sx = (view.X - SAFE_PADDING) / DESIGN_WIDTH
	local sy = (view.Y - SAFE_PADDING) / DESIGN_HEIGHT

	mobileScale = math.clamp(math.min(sx, sy, 1), 0.45, 1)

	applyScale()
end

resize()

workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(resize)

--// VALOR AUXILIAR PARA ANIMAR A ESCALA

local animValue = Instance.new("NumberValue")
animValue.Value = animScale

animValue:GetPropertyChangedSignal("Value"):Connect(function()
	animScale = animValue.Value
	applyScale()
end)

--// OPEN ANIMATION

frame.Position = UDim2.new(0.5,0,0.5,0)

TweenService:Create(
	animValue,
	TweenInfo.new(
		0.4,
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	),
	{
		Value = 1
	}
):Play()

--// CLOSE

local closing = false

close.MouseButton1Click:Connect(function()

	if closing then
		return
	end
	closing = true
	close.Active = false

	local tween = TweenService:Create(
		animValue,
		TweenInfo.new(
			0.25,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In
		),
		{
			Value = 0.01
		}
	)

	tween:Play()
	tween.Completed:Wait()

	gui:Destroy()

	local marker = Instance.new("BoolValue")
	marker.Name = "ForsakenLogLoadedAlready"
	marker.Parent = player
end)
