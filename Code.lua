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
--
-- IMPORTANTE: ragdolla o character ORIGINAL, sem
-- clonar/destruir. Cloná-lo criava um modelo que não
-- pertence a nenhum Player, e o Roblox não conseguia
-- atribuir a "posse" (network owner) de cada parte de
-- forma confiável — por isso braços e pernas atravessavam
-- o chão mesmo com CanCollide = true e SetNetworkOwner(nil)
-- setados manualmente.
--------------------------------------------------

local function Ragdoll(character)

	print("[Ragdoll] Iniciando pra", character.Name)

	local player =
		Players:GetPlayerFromCharacter(character)

	--------------------------------------------------
	-- MARCA COMO CADÁVER
	-- (pra não rodar isso 2x se Died disparar de novo)
	--------------------------------------------------

	if character:GetAttribute("IsRagdolled") then
		return
	end

	character:SetAttribute("IsRagdolled", true)

	character.Name =
		character.Name .. "_Corpse"

	--------------------------------------------------
	-- RESPAWN
	--
	-- O personagem antigo continua existindo no
	-- Workspace (como cadáver); o Player só recebe
	-- um character NOVO depois do delay.
	--------------------------------------------------

	if player then

		task.delay(RESPAWN_TIME, function()

			if player.Parent then
				player:LoadCharacter()
			end

		end)

	end

	--------------------------------------------------
	-- REMOVE SCRIPTS
	-- (ex: Animate, pra não brigar com a física do ragdoll)
	--------------------------------------------------

	for _, v in ipairs(character:GetDescendants()) do

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

	local hum =
		character:FindFirstChildOfClass("Humanoid")

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

	for _, joint in ipairs(character:GetDescendants()) do

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

	for _, part in ipairs(character:GetDescendants()) do

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
	-- Trava no servidor pra garantir física consistente
	-- (o character ainda pertence ao Player aqui, então
	-- isso agora "gruda" de verdade).
	--------------------------------------------------

	local rootLimb = GetRootLimb(character)

	if rootLimb then
		character.PrimaryPart = rootLimb
	end

	for _, part in ipairs(character:GetDescendants()) do

		if part:IsA("BasePart") then

			pcall(function()
				part:SetNetworkOwner(nil)
			end)

		end

	end

	print(
		"[Ragdoll] Física configurada para",
		character.Name
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

	if not character.Parent then
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

	for _, obj in ipairs(character:GetDescendants()) do

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

	if character.Parent then
		character:Destroy()
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
