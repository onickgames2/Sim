local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

local BODY_TIME = 15
local FADE_TIME = 3
local RESPAWN_TIME = 5

--------------------------------------------------
-- COLLISION GROUP
--------------------------------------------------

local CORPSE_GROUP = "Corpse"

pcall(function()
	PhysicsService:RegisterCollisionGroup(CORPSE_GROUP)
end)

-- Cadáveres NÃO colidem com eles mesmos (evita que o ragdoll trema ou voe).
PhysicsService:CollisionGroupSetCollidable(
	CORPSE_GROUP,
	CORPSE_GROUP,
	false
)

-- Mantém colisão com o grupo padrão (chão, paredes, outros players).
PhysicsService:CollisionGroupSetCollidable(
	CORPSE_GROUP,
	"Default",
	true
)

--------------------------------------------------
-- RETORNA A PARTE CENTRAL DO CORPO
--------------------------------------------------

local function GetRootLimb(character)
	return character:FindFirstChild("UpperTorso")
		or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
end

--------------------------------------------------
-- RAGDOLL
--------------------------------------------------

local function Ragdoll(character)

	print("[Ragdoll] Iniciando pra", character.Name)

	local player = Players:GetPlayerFromCharacter(character)

	if character:GetAttribute("IsRagdolled") then
		return
	end

	character:SetAttribute("IsRagdolled", true)

	--------------------------------------------------
	-- CLONA ANTES DE MODIFICAR O ORIGINAL
	--------------------------------------------------

	character.Archivable = true

	local corpse = character:Clone()

	if not corpse then
		warn("[Ragdoll] Falha ao clonar", character.Name)
		return
	end

	corpse.Name = character.Name .. "_Corpse"
	corpse:SetAttribute("IsRagdolled", true)
	corpse.Parent = workspace

	--------------------------------------------------
	-- REMOVE O ORIGINAL
	--------------------------------------------------

	character:Destroy()

	--------------------------------------------------
	-- RESPAWN
	--------------------------------------------------

	if player then
		task.delay(RESPAWN_TIME, function()
			if player.Parent then
				player:LoadCharacter()
			end
		end)
	end

	--------------------------------------------------
	-- REMOVE O HUMANOIDROOTPART DO CADÁVER
	--------------------------------------------------

	local root = corpse:FindFirstChild("HumanoidRootPart")

	if root then
		root:Destroy()
	end

	--------------------------------------------------
	-- REMOVE SCRIPTS
	-- (ex: Animate, pra não brigar com a física do ragdoll)
	--------------------------------------------------

	for _, v in ipairs(corpse:GetDescendants()) do

		if v:IsA("LocalScript")
			or v:IsA("Script") then

			if v.Name ~= "DeathHandler" then
				v:Destroy()
			end

		end

	end

	--------------------------------------------------
	-- HUMANOID
	--------------------------------------------------

	local hum = corpse:FindFirstChildOfClass("Humanoid")

	if hum then

		hum.DisplayDistanceType =
			Enum.HumanoidDisplayDistanceType.None

		hum.BreakJointsOnDeath = false

		hum.PlatformStand = true

		hum.AutoRotate = false

	end

	--------------------------------------------------
	-- MOTOR6D -> BALL SOCKET
	--------------------------------------------------

	for _, joint in ipairs(corpse:GetDescendants()) do

		if joint:IsA("Motor6D")
			and joint.Part0
			and joint.Part1 then

			local part0 = joint.Part0
			local part1 = joint.Part1

			local att0 = Instance.new("Attachment")
			att0.Name = "RagdollAttachment0"
			att0.CFrame = joint.C0
			att0.Parent = part0

			local att1 = Instance.new("Attachment")
			att1.Name = "RagdollAttachment1"
			att1.CFrame = joint.C1
			att1.Parent = part1

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
	-- FÍSICA + COLISÃO EM TODAS AS PARTES
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
				PhysicalProperties.new(
					0.7, -- Density
					0.6, -- Friction
					0,   -- Elasticity
					100, -- FrictionWeight
					100  -- ElasticityWeight
				)

		end

	end

	--------------------------------------------------
	-- NETWORK OWNERSHIP
	--
	-- O cadáver não pertence a nenhum Player, então
	-- o servidor assume a física de todas as partes.
	--------------------------------------------------

	local rootLimb = GetRootLimb(corpse)

	if rootLimb then
		corpse.PrimaryPart = rootLimb
	end

	for _, part in ipairs(corpse:GetDescendants()) do

		if part:IsA("BasePart") then

			pcall(function()
				part:SetNetworkOwner(nil)
			end)

		end

	end

	print(
		"[Ragdoll] Física configurada para",
		corpse.Name
	)

	--------------------------------------------------
	-- IMPACTO INICIAL
	--------------------------------------------------

	if rootLimb then

		rootLimb.AssemblyLinearVelocity =
			Vector3.new(
				math.random(-4, 4),
				12,
				math.random(-4, 4)
			)

		rootLimb.AssemblyAngularVelocity =
			Vector3.new(
				math.random(-10, 10),
				math.random(-10, 10),
				math.random(-10, 10)
			)

	end

	--------------------------------------------------
	-- TEMPO DO CADÁVER
	--------------------------------------------------

	task.wait(BODY_TIME)

	if not corpse.Parent then
		return
	end

	--------------------------------------------------
	-- FADE
	--------------------------------------------------

	local tweenInfo =
		TweenInfo.new(
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
				{ Transparency = 1 }
			):Play()

		end

	end

	--------------------------------------------------
	-- DESTROI
	--------------------------------------------------

	task.wait(FADE_TIME)

	if corpse.Parent then
		corpse:Destroy()
	end

end

--------------------------------------------------
-- PLAYER ADDED
--------------------------------------------------

Players.PlayerAdded:Connect(function(player)

	player.CharacterAdded:Connect(function(character)

		local humanoid =
			character:WaitForChild("Humanoid")

		humanoid.BreakJointsOnDeath = false

		humanoid.Died:Connect(function()

			print(
				"[Ragdoll] Died disparou pra",
				character.Name
			)

			task.spawn(
				Ragdoll,
				character
			)

		end)

	end)

end)
