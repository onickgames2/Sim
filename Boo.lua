-- Lua 5.1 (Roblox 2016)
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

local GenEvents            = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("GeneratorEvents")
local RE_StartPuzzle       = GenEvents:WaitForChild("StartPuzzle")
local RE_FlowLayerComplete = GenEvents:WaitForChild("FlowLayerComplete")
local RE_Exit              = GenEvents:WaitForChild("ExitGenerator")
local RE_PuzzleResult      = GenEvents:WaitForChild("PuzzleResult")

local manager  = ReplicatedStorage:WaitForChild("FlowGameManager")
local FlowGame = require(manager:WaitForChild("FlowGame"))

local currentGame  = nil
local currentGenId = nil

-- Atributo "CompletedGenPuzzle" virou variavel local
local completedGenPuzzle = false

-- Fecha o puzzle atual sem disparar callback
local function ClosePuzzle()
	if currentGame then
		currentGame:EndGame(nil)
		currentGame  = nil
		currentGenId = nil
	end
end

-- Abre um novo puzzle
local function OpenPuzzle(genId, gridSize, currentProgress)
	ClosePuzzle() -- fecha qualquer puzzle aberto antes

	currentGenId = genId

	local proto = manager:FindFirstChild("PuzzleUI")
	if not proto then warn("[GeneratorClient] PuzzleUI nao encontrado!"); return end

	local gui = proto:Clone()
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Barra de progresso ao lado da UI (maximo 4)
	local progressContainer = gui:WaitForChild("Container")

	local progressBarBG = Instance.new("Frame")
	progressBarBG.Name = "ProgressLayersBG"
	progressBarBG.Size = UDim2.new(0, 20, 0.8, 0)
	progressBarBG.Position = UDim2.new(1, 15, 0.1, 0)
	progressBarBG.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	progressBarBG.BorderColor3 = Color3.fromRGB(0, 0, 0)
	progressBarBG.BorderSizePixel = 2
	progressBarBG.Parent = progressContainer

	local progress = currentProgress or 0
	if progress > 4 then progress = 4 end
	if progress < 0 then progress = 0 end

	local progressFill = Instance.new("Frame")
	progressFill.Name = "Fill"
	progressFill.Size = UDim2.new(1, 0, progress / 4, 0)
	progressFill.Position = UDim2.new(0, 0, 1, 0)
	progressFill.AnchorPoint = Vector2.new(0, 1)
	progressFill.BackgroundColor3 = Color3.fromRGB(255, 170, 0)
	progressFill.BorderSizePixel = 0
	progressFill.Parent = progressBarBG

	if not completedGenPuzzle then
		gui.Container.Tutorial.Visible = true
		gui.Container.Position = UDim2.new(0.5, 0, 0.55, 0)
	else
		local ok, tut = pcall(function() return gui.Container.Tutorial end)
		if ok and tut then tut.Visible = false end
	end

	-- AutoRestart = false: servidor controla o fluxo
	currentGame = FlowGame.new(gui, gridSize, { AutoRestart = false })

	-- Callback direto (sem BindableEvent)
	currentGame._onComplete = function(reason)
		local gId = currentGenId
		currentGame  = nil
		currentGenId = nil

		if reason == "finishedPuzzle" then
			completedGenPuzzle = true
			RE_FlowLayerComplete:FireServer(gId)
		elseif reason == "leaveGenerator" then
			RE_Exit:FireServer(gId)
		end
	end
end

-- Servidor manda abrir puzzle
RE_StartPuzzle.OnClientEvent:Connect(function(genId, gridSize, currentProgress)
	OpenPuzzle(genId, gridSize, currentProgress)
end)

-- Servidor manda fechar: gerador completo ou player se moveu
RE_PuzzleResult.OnClientEvent:Connect(function(success, message)
	if message == "GENERATOR_COMPLETE" or message == "PLAYER_MOVED" then
		ClosePuzzle()
	end
end)
