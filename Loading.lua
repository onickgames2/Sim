local gui = script.Parent
local frame = gui.Frame
local lbl = frame.Trying
local img = frame.Image
local skip = frame.Skip -- TextButton

local TweenService = game:GetService("TweenService")

--------------------------------------------------
-- REPLICATED STORAGE
--------------------------------------------------

local rp = game:GetService("ReplicatedStorage")

local folders = {
	["modules"] = rp:WaitForChild("Modules"),
	["animations"] = rp:WaitForChild("Animations"),
	["assets"] = rp:WaitForChild("Assets"),
	["events"] = rp:WaitForChild("Events"),
	["revents"] = rp:WaitForChild("RemoteEvents"),
	["flow"] = rp:WaitForChild("FlowGameManager")
}

--------------------------------------------------
-- TEXTOS
--------------------------------------------------

local indexText = {
	["events"] = "Loading Server Events",
	["flow"] = "Downloading FlowGame Manager",
	["revents"] = "Loading Client Remote Events",
	["assets"] = "Downloading Assets Package",
	["modules"] = "Starting Modules",
	["animations"] = "Downloading Animations and Emotes"
}

--------------------------------------------------
-- ORDEM DE CARREGAMENTO
--------------------------------------------------

local indexSort = {
	[1] = "events",
	[2] = "revents",
	[3] = "assets",
	[4] = "modules",
	[5] = "animations",
	[6] = "flow"
}

--------------------------------------------------
-- IMAGENS DE LOADING
--------------------------------------------------

local loadingImages = {
	"91958826972932",
	"109639920864046",
	"130700686494681",
	"122305989544719",
	"80292093634620",
	"113168388674192",
	"90361552835297"
}

--------------------------------------------------
-- CONFIGURAÇÃO INICIAL
--------------------------------------------------

gui.Enabled = true

-- Coloca a ScreenGui inteira acima das outras
gui.DisplayOrder = 9999
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Configuração FORÇADA do Skip
skip.Visible = true
skip.Active = true
skip.Selectable = true
skip.AutoButtonColor = true
skip.ZIndex = 9999

skip.BackgroundTransparency = 1
skip.TextTransparency = 1

--------------------------------------------------
-- ESTADOS
--------------------------------------------------

local skipClicked = false
local finished = false

--------------------------------------------------
-- DEBUG
--------------------------------------------------

print("====================================")
print("[Loading] Script iniciado")
print("[Loading] Skip:", skip:GetFullName())
print("[Loading] Classe:", skip.ClassName)
print("[Loading] Visible:", skip.Visible)
print("[Loading] Active:", skip.Active)
print("[Loading] ZIndex:", skip.ZIndex)
print("====================================")

--------------------------------------------------
-- AURA DO TEXTO
--------------------------------------------------

local aura = lbl:FindFirstChild("AuraStroke")

if not aura then
	aura = Instance.new("UIStroke")
	aura.Name = "AuraStroke"
	aura.Thickness = 3
	aura.Color = Color3.fromRGB(255, 255, 255)
	aura.LineJoinMode = Enum.LineJoinMode.Round
	aura.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	aura.Parent = lbl
end

aura.Transparency = 1

--------------------------------------------------
-- IMAGEM ALEATÓRIA
--------------------------------------------------

local function setInitialRandomImage()
	local randomId = loadingImages[math.random(1, #loadingImages)]

	img.Image =
		"rbxthumb://type=Asset&id="
		.. randomId
		.. "&w=420&h=420"
end

--------------------------------------------------
-- DELAY ALEATÓRIO
--------------------------------------------------

local function getRandomDelay()
	return math.random(1, 10) / 10
end

--------------------------------------------------
-- FADE DA AURA
--------------------------------------------------

local function auraFadeOut()

	aura.Transparency = 0

	local fadeInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(
		aura,
		fadeInfo,
		{
			Transparency = 1
		}
	)

	tween:Play()
	tween.Completed:Wait()
end

--------------------------------------------------
-- FADE DOS OBJETOS
--------------------------------------------------

local function fadeObject(object, tweenInfo)

	local goals = {}

	if object:IsA("Frame") then
		goals.BackgroundTransparency = 1
	end

	if object:IsA("TextLabel")
		or object:IsA("TextButton")
		or object:IsA("TextBox") then

		goals.TextTransparency = 1

		if object ~= skip then
			goals.BackgroundTransparency = 1
		end
	end

	if object:IsA("ImageLabel")
		or object:IsA("ImageButton") then

		goals.ImageTransparency = 1
		goals.BackgroundTransparency = 1
	end

	if object:IsA("UIStroke") then
		goals.Transparency = 1
	end

	if object:IsA("ScrollingFrame") then
		goals.BackgroundTransparency = 1
		goals.ScrollBarImageTransparency = 1
	end

	if next(goals) then

		local tween = TweenService:Create(
			object,
			tweenInfo,
			goals
		)

		tween:Play()
	end
end

--------------------------------------------------
-- FADE OUT DA GUI
--------------------------------------------------

local function fadeOutUI()

	local fadeTime = 1

	local tweenInfo = TweenInfo.new(
		fadeTime,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	fadeObject(frame, tweenInfo)

	for _, obj in ipairs(frame:GetDescendants()) do
		fadeObject(obj, tweenInfo)
	end

	task.wait(fadeTime)
end

--------------------------------------------------
-- FINALIZAR
--------------------------------------------------

local function finishSequence()

	if finished then
		return
	end

	finished = true

	print("[Loading] Finalizando loading...")

	fadeOutUI()

	gui.Enabled = false

	print("[Loading] GUI desativada!")
end

--------------------------------------------------
-- SKIP
--------------------------------------------------

local function activateSkip()

	if skipClicked then
		return
	end

	skipClicked = true

	print("[Loading] SKIP ATIVADO!")

	lbl.Text = "Skipping..."

	task.spawn(function()

		task.wait(2)

		if finished then
			return
		end

		lbl.Text = "Loading Complete! 100%"

		auraFadeOut()

		finishSequence()
	end)
end

--------------------------------------------------
-- INPUT DO SKIP
--------------------------------------------------

local function setupSkipInput()

	-- Clique do mouse
	skip.MouseButton1Click:Connect(function()

		print("[Loading] MouseButton1Click!")

		activateSkip()
	end)

	-- Touch / Gamepad / input geral
	skip.Activated:Connect(function()

		print("[Loading] Activated!")

		activateSkip()
	end)

	-- Debug: mouse entrou
	skip.MouseEnter:Connect(function()

		print("[Loading] Mouse entrou no Skip")

	end)

	-- Debug: qualquer input
	skip.InputBegan:Connect(function(input)

		print(
			"[Loading] InputBegan:",
			input.UserInputType
		)

	end)

	print("[Loading] Eventos do Skip conectados!")
end

--------------------------------------------------
-- TIMER DO SKIP
--------------------------------------------------

local function startSkipTimer()

	task.wait(6)

	if skipClicked or finished then
		return
	end

	print("[Loading] Mostrando botão Skip!")

	skip.Visible = true
	skip.Active = true
	skip.Selectable = true
	skip.ZIndex = 9999

	local fadeInInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(
		skip,
		fadeInInfo,
		{
			TextTransparency = 0
		}
	)

	tween:Play()
end

--------------------------------------------------
-- LOADING PRINCIPAL
--------------------------------------------------

local function loadingSequence()

	setInitialRandomImage()

	-- Configura os inputs antes de começar
	setupSkipInput()

	-- Começa o timer do Skip
	task.spawn(startSkipTimer)

	--------------------------------------------------
	-- CALCULAR TOTAL
	--------------------------------------------------

	local totalItems = 0

	for _, folderKey in ipairs(indexSort) do

		if folders[folderKey] then

			totalItems += #folders[folderKey]:GetChildren()

		end
	end

	local loadedItems = 0

	--------------------------------------------------
	-- CARREGAMENTO
	--------------------------------------------------

	for _, folderKey in ipairs(indexSort) do

		if skipClicked then
			break
		end

		local folder = folders[folderKey]

		if folder then

			local children = folder:GetChildren()

			local text =
				indexText[folderKey]
				or folderKey

			for _, child in ipairs(children) do

				if skipClicked then
					break
				end

				loadedItems += 1

				local percent = 100

				if totalItems > 0 then

					percent = math.floor(
						(loadedItems / totalItems) * 100
					)

				end

				lbl.Text =
					text
					.. ": "
					.. percent
					.. "%"

				task.wait(getRandomDelay())

			end
		end
	end

	--------------------------------------------------
	-- SE FOI PULADO
	--------------------------------------------------

	if skipClicked then
		return
	end

	--------------------------------------------------
	-- FINAL NORMAL
	--------------------------------------------------

	lbl.Text = "Loading Complete! 100%"

	auraFadeOut()

	finishSequence()
end

--------------------------------------------------
-- INICIAR
--------------------------------------------------

loadingSequence()
