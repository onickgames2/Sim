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

local skipClicked = false
local finished = false

-- Função que define a imagem aleatória uma única vez
local function setInitialRandomImage()
	local randomId = loadingImages[math.random(1, #loadingImages)]
	img.Image = "rbxthumb://type=Asset&id=" .. randomId .. "&w=420&h=420"
end

-- Função para criar delays variáveis
local function getRandomDelay()
	return math.random(1, 10) / 10
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
	skip.Activated:Connect(function()
		print("[Skip] clicado") -- pode remover depois de confirmar que funciona
		if skipClicked then return end

		skipClicked = true
		lbl.Text = "Skipping..."

		task.spawn(function()
			task.wait(2)
			lbl.Text = "Loading Complete!"
			task.wait(1)
			finishSequence()
		end)
	end)
end

-- Função principal de loading
local function loadingSequence()
	setInitialRandomImage()

	task.spawn(startSkipTimer)
	setupSkipInput()

	local totalItemsAll = 0
	local folderCounts = {}
	for _, folderKey in ipairs(indexSort) do
		local folder = folders[folderKey]
		local count = folder and #folder:GetChildren() or 0
		folderCounts[folderKey] = count
		totalItemsAll += count
	end

	local processedItems = 0

	for _, folderKey in ipairs(indexSort) do
		if skipClicked then break end

		if folders[folderKey] then
			local folder = folders[folderKey]
			local children = folder:GetChildren()
			local text = indexText[folderKey] or folderKey

			for _, child in ipairs(children) do
				if skipClicked then break end

				processedItems += 1
				local percent = totalItemsAll > 0 and math.floor((processedItems / totalItemsAll) * 100) or 100
				lbl.Text = text .. ": " .. percent .. "%"

				task.wait(getRandomDelay())
			end
		end
	end

	if skipClicked then
		return
	end

	lbl.Text = "Loading Complete!"
	task.wait(1)

	finishSequence()
end

-- Iniciar sequência de loading
loadingSequence()
