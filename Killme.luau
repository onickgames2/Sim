
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

local BODY_TIME = 15
local FADE_TIME = 3
local RESPAWN_TIME = 5

local CORPSE_GROUP = "Corpse"

--------------------------------------------------
-- COLLISION GROUP
--------------------------------------------------

pcall(function()
	PhysicsService:RegisterCollisionGroup(CORPSE_GROUP)
end)

PhysicsService:CollisionGroupSetCollidable(
	CORPSE_GROUP,
	CORPSE_GROUP,
	false
)

PhysicsService:CollisionGroupSetCollidable(
	CORPSE_GROUP,
	"Default",
	true
)

--------------------------------------------------
-- ROOT DO CORPO
--------------------------------------------------

local function GetRootLimb(character)
	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------
-- PREPARA O CADÁVER
--------------------------------------------------

local function Ragdoll(corpse)

	if not corpse or not corpse.Parent then
		return
	end

	print("[Ragdoll] Preparando", corpse.Name)

	-- Remove scripts para impedir que alterem a física.
	for _, obj in ipairs(corpse:GetDescendants()) do
		if obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript") then
			obj:Destroy()
		end
	end

	local hum = corpse:FindFirstChildOfClass("Humanoid")

	if hum then
		hum.DisplayDistanceType =
			Enum.HumanoidDisplayDistanceType.None

		hum.BreakJointsOnDeath = false
		hum.PlatformStand = true
		hum.AutoRotate = false
	end

	-- Remove o RootPart do cadáver.
	local root = corpse:FindFirstChild("HumanoidRootPart")

	if root then
		root:Destroy()
	end

	--------------------------------------------------
	-- MOTOR6D -> BALL SOCKET
	--------------------------------------------------

	for _, joint in ipairs(corpse:GetDescendants()) do
		if joint:IsA("Motor6D")
			and joint.Part0
			and joint.Part1 then

			local att0 = Instance.new("Attachment")
			att0.Name = "RagdollAttachment0"
			att0.CFrame = joint.C0
			att0.Parent = joint.Part0

			local att1 = Instance.new("Attachment")
			att1.Name = "RagdollAttachment1"
			att1.CFrame = joint.C1
			att1.Parent = joint.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = "RagdollConstraint"
			socket.Attachment0 = att0
			socket.Attachment1 = att1

			socket.LimitsEnabled = true
			socket.UpperAngle = 60

			socket.TwistLimitsEnabled = true
			socket.TwistUpperAngle = 30
			socket.TwistLowerAngle = -30

			socket.MaxFrictionTorque = 100
			socket.Restitution = 0
			socket.Parent = joint.Parent

			joint:Destroy()
		end
	end

	--------------------------------------------------
	-- COLISÃO E FÍSICA
	--------------------------------------------------

	for _, part in ipairs(corpse:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.Massless = false

			part.CanCollide = true
			part.CanTouch = true
			part.CanQuery = true

			part.CollisionGroup = CORPSE_GROUP

			part.CustomPhysicalProperties =
				PhysicalProperties.new(0.7, 0.6, 0, 1, 1)
		end
	end

	--------------------------------------------------
	-- CONTROLE DA FÍSICA PELO SERVIDOR
	--------------------------------------------------

	for _, part in ipairs(corpse:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
		end
	end

	--------------------------------------------------
	-- IMPACTO INICIAL
	--------------------------------------------------

	local rootLimb = GetRootLimb(corpse)

	if rootLimb then
		rootLimb.AssemblyLinearVelocity = Vector3.new(
			math.random(-4, 4),
			12,
			math.random(-4, 4)
		)

		rootLimb.AssemblyAngularVelocity = Vector3.new(
			math.random(-10, 10),
			math.random(-10, 10),
			math.random(-10, 10)
		)
	end

	print("[Ragdoll] Cadáver ativo:", corpse.Name)

	--------------------------------------------------
	-- TEMPO NO MAPA
	--------------------------------------------------

	task.wait(BODY_TIME)

	if not corpse.Parent then
		return
	end

	--------------------------------------------------
	-- FADE
	--------------------------------------------------

	local tweenInfo = TweenInfo.new(
		FADE_TIME,
		Enum.EasingStyle.Linear
	)

	for _, obj in ipairs(corpse:GetDescendants()) do
		if obj:IsA("BasePart")
			or obj:IsA("Decal")
			or obj:IsA("Texture") then

			TweenService:Create(
				obj,
				tweenInfo,
				{Transparency = 1}
			):Play()
		end
	end

	task.wait(FADE_TIME)

	if corpse.Parent then
		corpse:Destroy()
	end
end

--------------------------------------------------
-- MORTE E RESPAWN
--------------------------------------------------

local function OnCharacterAdded(player, character)

	local humanoid = character:WaitForChild("Humanoid")
	humanoid.BreakJointsOnDeath = false

	humanoid.Died:Connect(function()

		if character:GetAttribute("DeathHandled") then
			return
		end

		character:SetAttribute("DeathHandled", true)

		print("[Ragdoll] Morte detectada:", player.Name)

		--------------------------------------------------
		-- GUARDA A CÓPIA ANTES DO RESPAWN
		--------------------------------------------------

		character.Archivable = true

		local corpse = character:Clone()

		if not corpse then
			warn("[Ragdoll] Não foi possível clonar", player.Name)
			return
		end

		corpse.Name = player.Name .. "_Corpse"

		-- Guarda a posição do personagem morto.
		local originalPivot = character:GetPivot()

		-- Mantém o cadáver fora do Workspace até o respawn.
		corpse.Parent = nil

		--------------------------------------------------
		-- ESPERA O RESPAWN
		--------------------------------------------------

		task.delay(RESPAWN_TIME, function()

			if not player.Parent then
				corpse:Destroy()
				return
			end

			-- Confirma que o jogador realmente renasceu.
			local newCharacter = player.Character

			if not newCharacter or newCharacter == character then
				-- Não cria o cadáver sobre o personagem antigo.
				corpse:Destroy()
				warn("[Ragdoll] O novo personagem ainda não apareceu.")
				return
			end

			--------------------------------------------------
			-- CRIA O CADÁVER APÓS O RESPAWN
			--------------------------------------------------

			corpse:PivotTo(originalPivot)
			corpse.Parent = workspace

			task.spawn(Ragdoll, corpse)

		end)
	end)
end

--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

local function SetupPlayer(player)

	player.CharacterAdded:Connect(function(character)
		OnCharacterAdded(player, character)
	end)

	if player.Character then
		task.spawn(OnCharacterAdded, player, player.Character)
	end
end

Players.PlayerAdded:Connect(SetupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	SetupPlayer(player)
end
