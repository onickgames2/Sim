-- Lua 5.1
local Player = game.Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Camera = workspace.CurrentCamera
local TweenService = game:GetService("TweenService")

local introRemote = game.ReplicatedStorage.Events.Intro

local UI = Player.PlayerGui:WaitForChild("UI")

local introFrame = script.Parent.Parent.IntroFrame
local survFrame = script.Parent.Parent.SurvWinFrame
local playerName = introFrame:WaitForChild("PlayerName")
local rigName = introFrame:WaitForChild("RigName")
local skinName = introFrame:WaitForChild("SkinName")
local titleLabel = introFrame:WaitForChild("TextLabel") -- "This round's killer is..."
local kFrame = script.Parent.Parent.KillerWinFrame

-- AJUSTE: precisa existir um Frame preto cobrindo a tela toda,
-- irmao da introFrame/survFrame/kFrame, chamado "BlackScreen".
-- BackgroundColor3 = preto, Size = UDim2.new(1,0,1,0), Visible = true,
-- BackgroundTransparency comecando em 1 (invisivel).
local blackScreen = script.Parent.Parent:WaitForChild("BlackScreen")
blackScreen.BackgroundTransparency = 1

local originals = {}

local function isSpectating()
	local char = Player.Character
	return char and char.Parent and char.Parent.Name == "Spectating"
end

local function hide()
	if not isSpectating() then return end

	local inGame = Player.PlayerGui:FindFirstChild("InGameUI")
	local ablUI = Player.PlayerGui:FindFirstChild("AbilityGui")

	originals["UI"] = UI.Enabled
	if inGame and ablUI then
		originals["inGame"] = inGame.Enabled
		originals["ablUI"] = ablUI.Enabled
		inGame.Enabled = false
		ablUI.Enabled = false
	end

	UI.Enabled = false
end

local function restore()
	if not isSpectating() then return end

	local inGame = Player.PlayerGui:FindFirstChild("InGameUI")
	local ablUI = Player.PlayerGui:FindFirstChild("AbilityGui")

	UI.Enabled = originals["UI"] ~= nil and originals["UI"] or true

	if inGame and ablUI then
		inGame.Enabled = originals["inGame"] ~= nil and originals["inGame"] or true
		ablUI.Enabled = originals["ablUI"] ~= nil and originals["ablUI"] or true
	end

	originals = {}
end

-- Fade em um elemento de texto
local function fadeElement(obj, fromAlpha, toAlpha, duration)
	local steps = 20
	local stepTime = duration / steps
	for i = 0, steps do
		local alpha = fromAlpha + (toAlpha - fromAlpha) * (i / steps)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			obj.TextTransparency = alpha
			obj.TextStrokeTransparency = alpha
		end
		wait(stepTime)
	end
end

-- Fade em TODOS os elementos visuais de um Frame
local function fadeFrame(frame, fromAlpha, toAlpha, duration)
	local steps = 20
	local stepTime = duration / steps
	for i = 0, steps do
		local alpha = fromAlpha + (toAlpha - fromAlpha) * (i / steps)
		for _, obj in ipairs(frame:GetDescendants()) do
			if obj:IsA("TextLabel") or obj:IsA("TextButton") then
				obj.TextTransparency = alpha
				obj.TextStrokeTransparency = alpha
			end
			if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
				obj.ImageTransparency = alpha
			end
		end
		if frame:IsA("Frame") and frame.BackgroundTransparency < 1 then
			frame.BackgroundTransparency = alpha
		end
		wait(stepTime)
	end
end

local function setFrameAlpha(frame, alpha)
	for _, obj in ipairs(frame:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			obj.TextTransparency = alpha
			obj.TextStrokeTransparency = alpha
		end
		if obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
			obj.ImageTransparency = alpha
		end
	end
end

-- Fade da tela preta (via TweenService, fica mais suave)
local function fadeBlack(toTransparency, duration)
	local tween = TweenService:Create(
		blackScreen,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = toTransparency }
	)
	tween:Play()
	wait(duration) -- mais seguro que Completed:Wait()
end

introRemote.OnClientEvent:Connect(function(type, config)
	print("[Intro] Evento recebido, type =", type)
	Character.HumanoidRootPart.Anchored = true

	if type == 2 then

		repeat wait() until game.Players.LocalPlayer.Character.Parent.Name == "Spectating"

		wait()

		if config.pos ~= nil then
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = config.pos
		end

		survFrame.Visible = true
		wait(config.duration)
		survFrame.Visible = false

		Camera.CameraType = Enum.CameraType.Custom

		if Player.Character and Player.Character:FindFirstChild("Humanoid") then
			Camera.CameraSubject = Player.Character.Humanoid
		end

	elseif type == 3 then
		-- ===== TELA DE VITORIA DO KILLER =====

		if config.pos ~= nil then
			Camera.CameraType = Enum.CameraType.Scriptable
			Camera.CFrame = config.pos
		end

		kFrame.rigName.Text = tostring(config.CharName)
		kFrame.skinName.Text = "( " .. tostring(config.RigName) .. " )"
		kFrame.playerName.Text = tostring(config.Player)

		kFrame.Visible = true
		hide()

		-- Fade in da tela preta cobrindo a troca de tela
		fadeBlack(0, 0.2)
		-- 0.1s depois, fade out revelando a KillerWinFrame
		wait(0.1)
		fadeBlack(1, 0.2)

		-- Espera 3 segundos, ou ate o player clicar em "OK"
		-- AJUSTE: troque "OkButton" pelo nome real do botao dentro da kFrame
		local skipped = false
		local okButton = kFrame:FindFirstChild("OkButton")
		local connection

		if okButton then
			connection = okButton.MouseButton1Click:Connect(function()
				skipped = true
			end)
		end

		local waited = 0
		while waited < 3 and not skipped do
			wait(0.1)
			waited = waited + 0.1
		end

		if connection then connection:Disconnect() end

		-- Fade in final da tela preta
		fadeBlack(0, 0.3)

		restore()
		kFrame.Visible = false

		-- Reseta a tela preta pra proxima transicao
		fadeBlack(1, 0.2)

		Camera.CameraType = Enum.CameraType.Custom

		if Player.Character and Player.Character:FindFirstChild("Humanoid") then
			Camera.CameraSubject = Player.Character.Humanoid
		end

	elseif type == 1 then
		-- ===== INTRODUCAO DO KILLER =====
		print("[Intro] Entrou no bloco type 1")

		if not game.Players.LocalPlayer.PlayerData.Config.SkipCutscene.Value then
			if config.pos ~= nil then
				Camera.CameraType = Enum.CameraType.Scriptable
				Camera.CFrame = config.pos
			end
		end

		rigName.Text = tostring(config.characterName)
		skinName.Text = "( " .. tostring(config.rigName) .. " )"
		playerName.Text = tostring(config.player)

		-- Esconde o nome do killer pra dar o efeito de fade in depois
		rigName.TextTransparency = 1
		rigName.TextStrokeTransparency = 1
		skinName.TextTransparency = 1
		skinName.TextStrokeTransparency = 1
		playerName.TextTransparency = 1
		playerName.TextStrokeTransparency = 1

		-- Garante que o "This round's killer is..." sempre apareca cheio
		titleLabel.TextTransparency = 0
		titleLabel.TextStrokeTransparency = 0

		-- A BlackScreen comeca opaca e a intro e revelada por tras dela
		blackScreen.BackgroundTransparency = 0

		introFrame.Visible = true
		hide()
		print("[Intro] introFrame.Visible =", introFrame.Visible)

		-- Fade out do BlackScreen revelando a intro
		print("[Intro] CHECKPOINT 1 - antes do fade out inicial do BlackScreen")
		fadeBlack(1, 0.3)
		print("[Intro] CHECKPOINT 2 - depois do fade out inicial do BlackScreen")

		-- 1.5s depois, fade in rapido do nome do killer
		wait(1.5)
		print("[Intro] Passou os 1.5s, iniciando fade do nome")
		spawn(function() fadeElement(rigName, 1, 0, 0.3) end)
		spawn(function() fadeElement(skinName, 1, 0, 0.3) end)
		spawn(function() fadeElement(playerName, 1, 0, 0.3) end)
		wait(0.3)

		-- IntroFrame fica visivel por 2.5 segundos
		wait(2.5)
		print("[Intro] CHECKPOINT 3 - antes do fade in do BlackScreen (troca de camera)")

		-- Fade in da BlackScreen: troca a camera e destrava o player sem o corte aparecer
		fadeBlack(0, 0.3)

		Camera.CameraType = Enum.CameraType.Custom
		if Player.Character and Player.Character:FindFirstChild("Humanoid") then
			Camera.CameraSubject = Player.Character.Humanoid
		end
		Character.HumanoidRootPart.Anchored = false
		print("[Intro] CHECKPOINT 4 - player destravado, Anchored =", Character.HumanoidRootPart.Anchored)

		-- Fade out da BlackScreen, revelando a introFrame de novo
		fadeBlack(1, 0.2)

		-- IntroFrame fica mais 2 segundos
		wait(2)
		print("[Intro] CHECKPOINT 5 - antes do fade out final da introFrame")

		-- Fade out final de tudo (introFrame inteira)
		fadeFrame(introFrame, 0, 1, 0.5)
		print("[Intro] CHECKPOINT 6 - fade out final terminou, Fim do bloco type 1")

		restore()
		introFrame.Visible = false
	end

	Character.HumanoidRootPart.Anchored = false
end)

Player.CharacterAdded:Connect(function(Char)
	Character = Char
end)
