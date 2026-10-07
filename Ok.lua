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
-- (em 2016 nao existe rbxthumb://, entao usamos rbxassetid://.
--  Se alguma imagem nao aparecer, use o ID da IMAGEM e nao o do Decal)
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

-- Garante visibilidade + remove fundo + comeca transparente
skip.Visible = true
skip.BackgroundTransparency = 1
skip.AutoButtonColor = false
skip.TextTransparency = 1

local skipClicked = false
local finished = false

-- Funcao que define a imagem aleatoria uma unica vez
local function setInitialRandomImage()
	local randomId = loadingImages[math.random(1, #loadingImages)]
	img.Image = "rbxassetid://" .. randomId
end

-- Funcao para criar delays variaveis
local function getRandomDelay()
	return math.random(1, 10) / 10
end

-- GetDescendants nao existia em 2016: percorre os filhos recursivamente
local function collectDescendants(parent, list)
	for _, child in ipairs(parent:GetChildren()) do
		table.insert(list, child)
		collectDescendants(child, list)
	end
	return list
end

-- Funcao que faz fade em TODOS os objetos
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

	if object:IsA("ScrollingFrame") then
		goals.BackgroundTransparency = 1
		goals.ScrollBarImageTransparency = 1
	end

	if next(goals) then
		local tween = TweenService:Create(object, tweenInfo, goals)
		tween:Play()
	end
end

-- Funcao que gerencia o Fade Out geral
local function fadeOutUI()
	local fadeTime = 1
	local tweenInfo = TweenInfo.new(
		fadeTime,
		Enum.EasingStyle.Linear,
		Enum.EasingDirection.Out
	)

	fadeObject(frame, tweenInfo)

	for _, obj in ipairs(collectDescendants(frame, {})) do
		fadeObject(obj, tweenInfo)
	end

	wait(fadeTime)
end

-- Garante que a finalizacao so rode uma vez
local function finishSequence()
	if finished then return end
	finished = true

	fadeOutUI()
	gui.Enabled = false
end

skip.Active = true
skip.ZIndex = 1000 -- garante que fica por cima de tudo

-- Fade in do Skip depois de 6 segundos
local function startSkipTimer()
	wait(6)

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

-- Detecta clique/toque no Skip
-- (GuiButton.Activated e novo demais; MouseButton1Click funciona com toque tambem)
local function setupSkipInput()
	skip.MouseButton1Click:Connect(function()
		if skipClicked then return end

		skipClicked = true
		lbl.Text = "Skipping..."

		spawn(function()
			wait(2)
			lbl.Text = "Loading Complete!"
			wait(1)
			finishSequence()
		end)
	end)
end

-- Funcao principal de loading
local function loadingSequence()
	setInitialRandomImage()

	spawn(startSkipTimer)
	setupSkipInput()

	local totalItemsAll = 0
	local folderCounts = {}
	for _, folderKey in ipairs(indexSort) do
		local folder = folders[folderKey]
		local count = folder and #folder:GetChildren() or 0
		folderCounts[folderKey] = count
		totalItemsAll = totalItemsAll + count
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

				processedItems = processedItems + 1
				local percent = totalItemsAll > 0 and math.floor((processedItems / totalItemsAll) * 100) or 100
				lbl.Text = text .. ": " .. percent .. "%"

				wait(getRandomDelay())
			end
		end
	end

	if skipClicked then
		return
	end

	lbl.Text = "Loading Complete!"
	wait(1)

	finishSequence()
end

-- Iniciar sequencia de loading
loadingSequence()
