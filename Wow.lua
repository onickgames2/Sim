local TweenService = game:GetService("TweenService")
local Players      = game:GetService("Players")
local Debris       = game:GetService("Debris")
local StarterGui   = game:GetService("StarterGui")

local Active = true

local Positions = {
	Enabled = UDim2.new(0.773, 0, 0.017, 0),
	Unabled = UDim2.new(0.98,  0, 0.017, 0),
}

local Button   = script.Parent.Parent.Players.Min
local Main     = script.Parent.Parent.Players.Main
local Info     = script.Parent.Parent.Players.Info
local Template = Main.Template

local Sizes = {
	Main = Main.Size,
	Info = Info.Size,
}

local TweenInfoMain = TweenInfo.new(0.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)

StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health,     false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

-- ─── Função de Formatação de Números (1k, 1m, 1b) ──────────────────────────
local function formatNumber(num)
	if num >= 1000000000 then
		return string.format("%.1f", num / 1000000000):gsub("%.0$", "") .. "b"
	elseif num >= 1000000 then
		return string.format("%.1f", num / 1000000):gsub("%.0$", "") .. "m"
	elseif num >= 1000 then
		return string.format("%.1f", num / 1000):gsub("%.0$", "") .. "k"
	else
		return tostring(num)
	end
end

-- ─── Função de Formatação de Tempo ──────────────────────────────────────────
local function formatTimePlayed(seconds)
	local days             = math.floor(seconds / 86400)
	local hours            = math.floor((seconds % 86400) / 3600)
	local minutes          = math.floor((seconds % 3600) / 60)
	local remainingSeconds = math.floor(seconds % 60)

	-- Formato Dias:Horas:Minutos:Segundos (00:00:00:00)
	return string.format("%02d:%02d:%02d:%02d", days, hours, minutes, remainingSeconds)
end

-- ─── showMore ──────────────────────────────────────────────────────────────

local function showMore(player)
	local playersFolder = script.Parent.Parent.Players
	local Screen  = playersFolder.Screen
	local close   = Screen.Close
	local BroIMG  = Screen.BroImage
	local deviceI = BroIMG.Device

	-- Verificação de segurança para os dados
	local playerData = player:FindFirstChild("PlayerData")
	if not playerData then return end

	local equipped  = playerData.Actors.Equipped
	local roundData = playerData.Round

	local killer = equipped.Killer.Value
	local surviv = equipped.Survivor.Value
	local skinK  = equipped.Skins.Killer:FindFirstChild(killer) and equipped.Skins.Killer[killer].Value or "None"
	local skinS  = equipped.Skins.Survivor:FindFirstChild(surviv) and equipped.Skins.Survivor[surviv].Value or "None"

	Screen.Player.Text   = player.Name
	Screen.Killer.Text   = "Survivor Equipped: " .. surviv .. " (" .. skinS .. ")"
	Screen.Survivor.Text = "Killer Equipped: "   .. killer .. " (" .. skinK .. ")"

	Screen.SWins.Text  = "Survivor wins: "  .. roundData.SurvivorWins.Value
	Screen.KWins.Text  = "Killer wins: "    .. roundData.KillerWins.Value
	Screen.SLoses.Text = "Survivor loses: " .. roundData.SurvivorLoses.Value
	Screen.KLoses.Text = "Killer loses: "   .. roundData.KillerLoses.Value

	BroIMG.Image = Players:GetUserThumbnailAsync(
		player.UserId,
		Enum.ThumbnailType.HeadShot,
		Enum.ThumbnailSize.Size420x420
	)

	local deviceImages = {
		PC      = "4728059499",
		Mobile  = "110295148080635",
		Console = "126031615463653",
		Unknown = "101346701946159",
	}

	local deviceKey = player:GetAttribute("Device") or "Unknown"
	deviceI.Image = "rbxthumb://type=Asset&id=" .. (deviceImages[deviceKey] or deviceImages.Unknown) .. "&w=420&h=420"

	Screen.Visible = true

	-- Loop em tempo real para atualizar o tempo jogado enquanto a Screen estiver visível
	local timeActive = true
	task.spawn(function()
		while timeActive and Screen.Visible and player.Parent and playerData:FindFirstChild("TimePlayed") do
			local totalSeconds = playerData.TimePlayed.Value
			Screen.Time.Text = "Time Played: " .. formatTimePlayed(totalSeconds)
			task.wait(1)
		end
	end)

	-- Conexão única para evitar múltiplos eventos acumulados
	local connection
	connection = close.MouseButton1Click:Connect(function()
		timeActive = false
		Screen.Visible = false
		connection:Disconnect()
	end)
end

-- ─── Loop de cards ─────────────────────────────────────────────────────────

task.spawn(function()
	local localPlayer = Players.LocalPlayer

	while task.wait(1) do
		-- Remove cards de quem saiu do jogo
		for _, card in ipairs(Main:GetChildren()) do
			if card:IsA("Frame") and card.Name ~= "Template" then
				if not Players:FindFirstChild(card.Name) then
					card:Destroy()
				end
			end
		end

		-- Atualiza ou cria cards
		for _, player in ipairs(Players:GetPlayers()) do
			local leaderstats = player:FindFirstChild("leaderstats")
			local points = leaderstats and leaderstats:FindFirstChild("Points")
			local kc     = leaderstats and leaderstats:FindFirstChild("KillerChance")

			if points and kc then
				local card = Main:FindFirstChild(player.Name)

				-- Se o card não existir, cria um novo
				if not card then
					card = Template:Clone()
					card.Name = player.Name
					card.Parent = Main
					card.Visible = true

					card.E.MouseButton1Click:Connect(function()
						showMore(player)
					end)
				end

				-- Atualiza os textos com formatação
				card.A.Text = player.Name
				card.P.Text = formatNumber(points.Value)
				card.Z.Text = formatNumber(kc.Value)
			end
		end
	end
end)

-- ─── Toggle button ─────────────────────────────────────────────────────────

Button.MouseButton1Click:Connect(function()
	if Active then
		TweenService:Create(Button, TweenInfoMain, { Position = Positions.Unabled }):Play()
		TweenService:Create(Info,   TweenInfoMain, { Size = UDim2.new(0, 0, 0, 0) }):Play()
		TweenService:Create(Main,   TweenInfoMain, { Size = UDim2.new(0, 0, 0, 0) }):Play()
	else
		TweenService:Create(Button, TweenInfoMain, { Position = Positions.Enabled }):Play()
		TweenService:Create(Info,   TweenInfoMain, { Size = Sizes.Info }):Play()
		TweenService:Create(Main,   TweenInfoMain, { Size = Sizes.Main }):Play()
	end

	Active = not Active
end)

local pointCounter = script.Parent.Parent.PointCounter

task.spawn(function()
	while game.Players.LocalPlayer.Parent do
		task.wait(0.1)
		local points = game.Players.LocalPlayer.leaderstats.Points
		pointCounter.Text = formatNumber(points.Value) .. "$"
	end
end)
