local gui = script.Parent
local lbl = gui.Frame.Trying
local img = gui.Frame.Image
local frame = gui.Frame 
local skip = gui.Frame.Skip -- TextButton

local TweenService = game:GetService("TweenService")

-- folders
local rp = game.ReplicatedStorage
local folders = {
	["modules"] = rp.Modules,
	["animations"] = rp.Animations,
	["assets"] = rp.Assets,
	["events"] = rp.Events,
	["revents"] = rp.RemoteEvents,
	["flow"] = rp.FlowGameManager
}

-- tabela de textos
local indexText = {
	["events"] = "Loading Server Events",
	["flow"] = "Downloading FlowGame Manager",
	["revents"] = "Loading Client Remote Events",
	["assets"] = "Downloading Assets Package",
	["modules"] = "Starting Modules",
	["animations"] = "Downloading Animations and Emotes"
}

-- ordem de carregamento
local indexSort = {
	[1] = "events",
	[2] = "revents",
	[3] = "assets",
	[4] = "modules",
	[5] = "animations",
	[6] = "flow"
}

-- IDs de imagem
local loadingImages = {
	"91958826972932",
	"109639920864046",
	"130700686494681",
	"122305989544719",
	"80292093634620",
	"113168388674192",
	"90361552835297"
}

gui.Enabled = true

-- Garante visibilidade + remove fundo + começa transparente
skip.Visible = true
skip.BackgroundTransparency = 1
skip.AutoButtonColor = false
skip.TextTransparency = 1

-- DEBUG temporário: confirma estado real do Skip assim que o script roda
print("[Debug] Skip existe?", skip ~= nil, "| Classe:", skip.ClassName)
print("[Debug] Skip Active:", skip.Active, "| Visible:", skip.Visible, "| ZIndex:", skip.ZIndex)
print("[Debug] Skip caminho completo:", skip:GetFullName())

local skipClicked = false
local finished = false

-- Cria (ou pega) o UIStroke da aura no texto de loading
local aura = lbl:FindFirstChild("AuraStroke")
if not aura then
	aura = Instance.new("UIStroke")
	aura.Name = "AuraStroke"
	aura.Thickness = 3
	aura.Color = Color3.fromRGB(255, 255, 255) -- muda a cor da aura aqui
	aura.LineJoinMode = Enum.LineJoinMode.Round
	aura.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	aura.Parent = lbl
end
aura.Transparency = 1 -- começa invisível

-- Função que define a imagem aleatória uma única vez
local function setInitialRandomImage()
	local randomId = loadingImages[math.random(1, #loadingImages)]
	img.Image = "rbxthumb://type=Asset&id=" .. randomId .. "&w=420&h=420"
end

-- Função para criar delays variáveis
local function getRandomDelay()
	return math.random(1, 10) / 10
end

-- Acende a aura e depois faz fade out em 0.5s
local function auraFadeOut()
	aura.Transparency = 0 -- acende na hora

	local fadeInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(aura, fadeInfo, { Transparency = 1 })
	tween:Play()
	tween.Completed:Wait()
end

-- Função que faz fade em TODOS os objetos 🌸
local function fadeObject(object, tweenInfo)
	local goals = {}

	if object:IsA("Frame") then
		goals.BackgroundTransparency = 1
	end

	if object:IsA("TextLabel") or object:IsA("TextButton") or object:IsA("TextBox") then
		goals.TextTransparency = 1
		if object ~= skip then
			goals.BackgroundTransparency = 1
		end
	end

	if object:IsA("ImageLabel") or object:IsA("ImageButton") then
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
		local tween = TweenService:Create(object, tweenInfo, goals)
		tween:Play()
	end
end

-- Função que gerencia o Fade Out geral ✨
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

-- Garante que a finalização só rode uma vez
local function finishSequence()
	if finished then return end
	finished = true

	fadeOutUI()
	gui.Enabled = false
end

-- Fade in do Skip depois de 6 segundos
local function startSkipTimer()
	task.wait(6)

	if skipClicked then return end

	local fadeInInfo = TweenInfo.new(
		0.5,
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)

	local tween = TweenService:Create(skip, fadeInInfo, {
		TextTransparency = 0
	})
	tween:Play()
end

-- Detecta clique/toque/gamepad no Skip
local function setupSkipInput()
	skip.MouseEnter:Connect(function()
		print("[Debug] Mouse entrou na área do Skip")
	end)

	skip.InputBegan:Connect(function(input)
		print("[Debug] InputBegan no Skip:", input.UserInputType)
	end)

	skip.Activated:Connect(function()
		print("[Debug] Skip.Activated disparou!")

		if skipClicked then return end

		skipClicked = true
		lbl.Text = "Skipping..."

		task.spawn(function()
			task.wait(2)
			lbl.Text = "Loading Complete! 100%"
			auraFadeOut()
			finishSequence()
		end)
	end)

	print("[Debug] setupSkipInput() rodou e conectou os eventos")
end

-- Função principal de loading
local function loadingSequence()
	setInitialRandomImage()

	task.spawn(startSkipTimer)
	setupSkipInput()

	local totalItems = 0
	for _, folderKey in ipairs(indexSort) do
		if folders[folderKey] then
			totalItems += #folders[folderKey]:GetChildren()
		end
	end

	local loadedItems = 0

	for _, folderKey in ipairs(indexSort) do
		if skipClicked then break end

		if folders[folderKey] then
			local folder = folders[folderKey]
			local children = folder:GetChildren()
			local text = indexText[folderKey] or folderKey

			for _, child in ipairs(children) do
				if skipClicked then break end

				loadedItems += 1
				local percent = totalItems > 0 and math.floor((loadedItems / totalItems) * 100) or 100
				lbl.Text = text .. ": " .. percent .. "%"
				task.wait(getRandomDelay())
			end
		end
	end

	if skipClicked then
		return
	end

	lbl.Text = "Loading Complete! 100%"
	auraFadeOut()

	finishSequence()
end

-- Iniciar sequência de loading
loadingSequence()
