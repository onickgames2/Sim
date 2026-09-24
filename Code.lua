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

-- Cadáveres continuam colidindo com o mapa e entre si.
PhysicsService:CollisionGroupSetCollidable(
	CORPSE_GROUP,
	CORPSE_GROUP,
	true
)

-- Mantém colisão com o grupo padrão.
PhysicsService:CollisionGroupSetCollidable(
	CORPSE_GROUP,
	"Default",
	true
)

--------------------------------------------------
-- RETORNA A PARTE CENTRAL DO CORPO
--------------------------------------------------

local function GetRootLimb(corpse)
	return corpse:FindFirstChild("UpperTorso")
		or corpse:FindFirstChild("Torso")
end

--------------------------------------------------
-- CONFIGURA FÍSICA DO CADÁVER
--------------------------------------------------

local function SetupCorpsePhysics(corpse)

	for _, part in ipairs(corpse:GetDescendants()) do

		if part:IsA("BasePart") then

			part.Anchored = false

			--------------------------------------------------
			-- COLISÃO
			--------------------------------------------------

			part.CanCollide = true
			part.CanTouch = true
			part.CanQuery = true

			part.CollisionGroup = CORPSE_GROUP

			--------------------------------------------------
			-- FÍSICA
			--------------------------------------------------

			part.Massless = false

			part.CustomPhysicalProperties =
				PhysicalProperties.new(
					0.7, -- Density
					0.6, -- Friction
					0,   -- Elasticity
					100, -- FrictionWeight
					100  -- ElasticityWeight
				)

			--------------------------------------------------
			-- TENTA ATIVAR CCD
			--
			-- Algumas versões/API do Roblox podem não possuir
			-- esta propriedade. Por isso usamos pcall.
			--------------------------------------------------

			pcall(function()
				part.CollisionFidelity =
					Enum.CollisionFidelity.PreciseConvexDecomposition
			end)

		end

	end

end

--------------------------------------------------
-- RAGDOLL
--------------------------------------------------

local function Ragdoll(character)

	print("[Ragdoll] Iniciando pra", character.Name)

	--------------------------------------------------
	-- PLAYER
	--------------------------------------------------

	local player =
		Players:GetPlayerFromCharacter(character)

	--------------------------------------------------
	-- CLONE
	--------------------------------------------------

	character.Archivable = true

	local corpse = character:Clone()

	if not corpse then

		warn(
			"[Ragdoll] Clone falhou pra",
			character.Name
		)

		return
	end

	corpse.Name =
		character.Name .. "_Corpse"

	corpse.Parent = workspace

	--------------------------------------------------
	-- REMOVE PERSONAGEM ORIGINAL
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
	-- REMOVE SCRIPTS
	--------------------------------------------------

	for _, v in ipairs(corpse:GetDescendants()) do

		if v:IsA("Script")
			or v:IsA("LocalScript")
			or v:IsA("ModuleScript") then

			v:Destroy()

		end

	end

	--------------------------------------------------
	-- HUMANOID
	--------------------------------------------------

	local hum =
		corpse:FindFirstChildOfClass("Humanoid")

	if hum then

		hum.DisplayDistanceType =
			Enum.HumanoidDisplayDistanceType.None

		hum.BreakJointsOnDeath = false

		hum.PlatformStand = true

		hum.AutoRotate = false

		hum.Health = 0

	end

	--------------------------------------------------
	-- REMOVE ROOT
	--------------------------------------------------

	local root =
		corpse:FindFirstChild("HumanoidRootPart")

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

			local part0 = joint.Part0
			local part1 = joint.Part1

			--------------------------------------------------
			-- ATTACHMENT 0
			--------------------------------------------------

			local att0 =
				Instance.new("Attachment")

			att0.Name =
				"RagdollAttachment0"

			att0.CFrame =
				joint.C0

			att0.Parent =
				part0

			--------------------------------------------------
			-- ATTACHMENT 1
			--------------------------------------------------

			local att1 =
				Instance.new("Attachment")

			att1.Name =
				"RagdollAttachment1"

			att1.CFrame =
				joint.C1

			att1.Parent =
				part1

			--------------------------------------------------
			-- BALL SOCKET
			--------------------------------------------------

			local socket =
				Instance.new("BallSocketConstraint")

			socket.Name =
				"RagdollConstraint"

			socket.Attachment0 =
				att0

			socket.Attachment1 =
				att1

			--------------------------------------------------
			-- LIMITES
			--------------------------------------------------

			socket.LimitsEnabled = true
			socket.UpperAngle = 60

			socket.TwistLimitsEnabled = true
			socket.TwistUpperAngle = 30
			socket.TwistLowerAngle = -30

			--------------------------------------------------
			-- ESTABILIDADE
			--------------------------------------------------

			socket.MaxFrictionTorque = 100
			socket.Restitution = 0

			socket.Parent =
				joint.Parent

			--------------------------------------------------
			-- REMOVE MOTOR
			--------------------------------------------------

			joint:Destroy()

		end

	end

	--------------------------------------------------
	-- CONFIGURA TODAS AS PARTES
	--------------------------------------------------

	SetupCorpsePhysics(corpse)

	--------------------------------------------------
	-- NETWORK OWNERSHIP
	--
	-- Servidor controla a física do cadáver.
	--------------------------------------------------

	pcall(function()

		local rootLimb =
			GetRootLimb(corpse)

		if rootLimb then

			corpse.PrimaryPart =
				rootLimb

			rootLimb:SetNetworkOwner(nil)

		end

	end)

	--------------------------------------------------
	-- GARANTE NOVAMENTE A COLISÃO
	--------------------------------------------------

	for _, part in ipairs(corpse:GetDescendants()) do

		if part:IsA("BasePart") then

			part.CanCollide = true
			part.CanTouch = true
			part.CanQuery = true

			part.CollisionGroup =
				CORPSE_GROUP

			part.Anchored = false

		end

	end

	print(
		"[Ragdoll] Física configurada para",
		character.Name
	)

	--------------------------------------------------
	-- IMPACTO INICIAL
	--------------------------------------------------

	local rootLimb =
		GetRootLimb(corpse)

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

	if not corpse
		or not corpse.Parent then

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
				{
					Transparency = 1
				}
			):Play()

		end

	end

	--------------------------------------------------
	-- DESTROI
	--------------------------------------------------

	task.wait(FADE_TIME)

	if corpse
		and corpse.Parent then

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

end)--------------------------------------------------

local function SetupCorpsePhysics(corpse)

	for _, part in ipairs(corpse:GetDescendants()) do
		if part:IsA("BasePart") then

			part.Anchored = false

			-- Permite colisão com o mapa
			part.CanCollide = true

			-- Mantém Touch/Query funcionando
			part.CanTouch = true
			part.CanQuery = true

			-- Todas as partes do cadáver ficam nesse grupo
			part.CollisionGroup = CORPSE_COLLISION_GROUP

			-- Evita que a física fique exageradamente pesada
			part.CustomPhysicalProperties = PhysicalProperties.new(
				0.7, -- Density
				0.5, -- Friction
				0.1, -- Elasticity
				1,
				1
			)
		end
	end
end

--------------------------------------------------
-- RAGDOLL
--------------------------------------------------

local function Ragdoll(character)

	print("[Ragdoll] Iniciando pra", character.Name)

	local player = Players:GetPlayerFromCharacter(character)

	--------------------------------------------------
	-- CLONE
	--------------------------------------------------

	character.Archivable = true

	local corpse = character:Clone()

	if not corpse then
		warn(
			"[Ragdoll] Clone falhou pra",
			character.Name
		)
		return
	end

	corpse.Name = character.Name .. "_Corpse"
	corpse.Parent = workspace

	--------------------------------------------------
	-- DESTRÓI PERSONAGEM ORIGINAL
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
	-- REMOVE SCRIPTS
	--------------------------------------------------

	for _, obj in ipairs(corpse:GetDescendants()) do

		if obj:IsA("Script")
			or obj:IsA("LocalScript")
			or obj:IsA("ModuleScript") then

			obj:Destroy()

		end

	end

	--------------------------------------------------
	-- HUMANOID
	--------------------------------------------------

	local humanoid = corpse:FindFirstChildOfClass("Humanoid")

	if humanoid then

		humanoid.DisplayDistanceType =
			Enum.HumanoidDisplayDistanceType.None

		humanoid.BreakJointsOnDeath = false
		humanoid.PlatformStand = true

		humanoid.AutoRotate = false

		humanoid.Health = 0

	end

	--------------------------------------------------
	-- REMOVE HUMANOIDROOTPART
	--------------------------------------------------

	local root = corpse:FindFirstChild("HumanoidRootPart")

	if root then
		root:Destroy()
	end

	--------------------------------------------------
	-- CONVERTE MOTOR6D EM BALL SOCKET
	--------------------------------------------------

	for _, joint in ipairs(corpse:GetDescendants()) do

		if joint:IsA("Motor6D")
			and joint.Part0
			and joint.Part1 then

			local part0 = joint.Part0
			local part1 = joint.Part1

			--------------------------------------------------
			-- ATTACHMENT 0
			--------------------------------------------------

			local att0 = Instance.new("Attachment")
			att0.Name = "RagdollAttachment0"
			att0.CFrame = joint.C0
			att0.Parent = part0

			--------------------------------------------------
			-- ATTACHMENT 1
			--------------------------------------------------

			local att1 = Instance.new("Attachment")
			att1.Name = "RagdollAttachment1"
			att1.CFrame = joint.C1
			att1.Parent = part1

			--------------------------------------------------
			-- CONSTRAINT
			--------------------------------------------------

			local socket = Instance.new("BallSocketConstraint")

			socket.Name = "RagdollConstraint"

			socket.Attachment0 = att0
			socket.Attachment1 = att1

			-- Limites para impedir membros de girarem 360°
			socket.LimitsEnabled = true
			socket.UpperAngle = 60

			socket.TwistLimitsEnabled = true
			socket.TwistUpperAngle = 30
			socket.TwistLowerAngle = -30

			-- Ajuda a estabilidade da física
			socket.MaxFrictionTorque = 100

			socket.Restitution = 0

			socket.Parent = joint.Parent

			--------------------------------------------------
			-- REMOVE MOTOR
			--------------------------------------------------

			joint:Destroy()

		end

	end

	--------------------------------------------------
	-- CONFIGURA FÍSICA
	--------------------------------------------------

	SetupCorpsePhysics(corpse)

	--------------------------------------------------
	-- NETWORK OWNER
	--------------------------------------------------

	pcall(function()

		local rootLimb = GetRootLimb(corpse)

		corpse.PrimaryPart = rootLimb

		if rootLimb then
			rootLimb:SetNetworkOwner(nil)
		end

	end)

	print("[Ragdoll] Juntas convertidas")

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

	--------------------------------------------------
	-- ESPERA
	--------------------------------------------------

	task.wait(BODY_TIME)

	if not corpse or not corpse.Parent then
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

	--------------------------------------------------
	-- REMOVE
	--------------------------------------------------

	task.wait(FADE_TIME)

	if corpse and corpse.Parent then
		corpse:Destroy()
	end

end

--------------------------------------------------
-- PLAYER
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
