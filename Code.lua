local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local BODY_TIME = 15
local FADE_TIME = 3

-- Retorna a parte central do corpo, seja R6 (Torso) ou R15 (UpperTorso)
local function GetRootLimb(corpse)
	return corpse:FindFirstChild("UpperTorso") or corpse:FindFirstChild("Torso")
end

local function Ragdoll(character)
	print("[Ragdoll] Iniciando pra", character.Name)

	-- Alguns kits desativam Archivable por segurança, o que faz Clone() retornar nil
	character.Archivable = true

	local corpse = character:Clone()
	if not corpse then
		warn("[Ragdoll] Clone falhou pra", character.Name, "- Archivable ainda false em algum descendente?")
		return
	end

	corpse.Name = character.Name.."_Corpse"
	corpse.Parent = workspace

	-- Destrói o personagem original: sem isso, ele continua no workspace do jeito
	-- que morreu (parado, sem cair) e fica sobreposto ao corpse, dando a impressão
	-- de que o corpo "morre todo duro"
	character:Destroy()

	-- Remove scripts
	for _, v in ipairs(corpse:GetDescendants()) do
		if v:IsA("Script") or v:IsA("LocalScript") then
			v:Destroy()
		end
	end

	local hum = corpse:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.BreakJointsOnDeath = false
		hum.PlatformStand = true
		hum.Health = 0
	end

	-- Remove o RootPart pra o corpo ficar solto
	local root = corpse:FindFirstChild("HumanoidRootPart")
	if root then
		root:Destroy()
	end

	-- Converte Motor6D em BallSocketConstraint, agora com limites de ângulo
	-- (sem limites, os membros podiam dobrar de jeitos anti-naturais)
	for _, joint in ipairs(corpse:GetDescendants()) do
		if joint:IsA("Motor6D") and joint.Part0 and joint.Part1 then
			local att0 = Instance.new("Attachment")
			att0.CFrame = joint.C0
			att0.Parent = joint.Part0

			local att1 = Instance.new("Attachment")
			att1.CFrame = joint.C1
			att1.Parent = joint.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Attachment0 = att0
			socket.Attachment1 = att1
			socket.LimitsEnabled = true
			socket.UpperAngle = 60
			socket.TwistLimitsEnabled = true
			socket.TwistUpperAngle = 30
			socket.TwistLowerAngle = -30
			socket.Parent = joint.Parent

			joint:Destroy()
		end
	end

	-- Física
	for _, part in ipairs(corpse:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = true
		end
	end

	-- Fixa o dono de rede no servidor pra física ficar consistente entre clientes
	pcall(function()
		corpse.PrimaryPart = GetRootLimb(corpse)
		if corpse.PrimaryPart then
			corpse.PrimaryPart:SetNetworkOwner(nil)
		end
	end)

	print("[Ragdoll] Juntas convertidas, corpo deveria cair agora")

	-- Pulinho de impacto
	local rootLimb = GetRootLimb(corpse)
	if rootLimb then
		rootLimb.AssemblyLinearVelocity = Vector3.new(
			math.random(-4, 4), 12, math.random(-4, 4)
		)
		rootLimb.AssemblyAngularVelocity = Vector3.new(
			math.random(-10, 10), math.random(-10, 10), math.random(-10, 10)
		)
	end

	-- Espera o corpo ficar no chão
	task.wait(BODY_TIME)

	-- Corpo pode já ter sido destruído por outro motivo enquanto esperava
	if not corpse or not corpse.Parent then
		return
	end

	-- Fade com TweenService (mais leve que um loop manual com task.wait a cada frame)
	local tweenInfo = TweenInfo.new(FADE_TIME, Enum.EasingStyle.Linear)
	for _, obj in ipairs(corpse:GetDescendants()) do
		if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
			TweenService:Create(obj, tweenInfo, { Transparency = 1 }):Play()
		end
	end

	task.wait(FADE_TIME)
	corpse:Destroy()
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.BreakJointsOnDeath = false

		humanoid.Died:Connect(function()
			print("[Ragdoll] Died disparou pra", character.Name)
			task.spawn(Ragdoll, character)
		end)
	end)
end)
