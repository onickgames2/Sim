-- Lua 5.1
local TS = game:GetService("TweenService")
local runservice = game:GetService("RunService")

local DEBUG = false

local tStyle, tDirection = {
	[Enum.PoseEasingStyle.Linear]   = Enum.EasingStyle.Linear;
	[Enum.PoseEasingStyle.Bounce]   = Enum.EasingStyle.Bounce;
	[Enum.PoseEasingStyle.Cubic]    = Enum.EasingStyle.Cubic;
	[Enum.PoseEasingStyle.CubicV2]  = Enum.EasingStyle.Cubic;
	[Enum.PoseEasingStyle.Elastic]  = Enum.EasingStyle.Elastic;
	[Enum.PoseEasingStyle.Constant] = Enum.EasingStyle.Linear;
},{
	[Enum.PoseEasingDirection.In]    = Enum.EasingDirection.In;
	[Enum.PoseEasingDirection.Out]   = Enum.EasingDirection.Out;
	[Enum.PoseEasingDirection.InOut] = Enum.EasingDirection.InOut;
}

local activeAnimations = {}
local pendingAnimations = {}

local function debugPrint(...)
	if DEBUG then
		print("[AnimationLite]", ...)
	end
end

-- Remove AnimLiteActive de todos os motors de uma tabela
local function ClearMotorAttributes(motors)
	for _, motor in pairs(motors) do
		motor:SetAttribute("AnimLiteActive", nil)
	end
end

-- Marca todos os motors que serão usados na animação
local function SetMotorAttributes(motors)
	for _, motor in pairs(motors) do
		motor:SetAttribute("AnimLiteActive", true)
	end
end

local function StopCurrentAnimation(Model)
	if not Model then return end
	local activeData = activeAnimations[Model]
	if not activeData then return end

	debugPrint("Parando animação ativa em", Model.Name)
	activeData.shouldStop = true

	if activeData.tweens then
		for i = 1, #activeData.tweens do
			local tweenGroup = activeData.tweens[i]
			if tweenGroup and tweenGroup.Tweens then
				for _, tween in pairs(tweenGroup.Tweens) do
					tween:Cancel()
					tween:Destroy()
				end
			end
		end
	end

	if activeData.runConnection then
		activeData.runConnection:Disconnect()
		activeData.runConnection = nil
	end

	if activeData.motors then
		for name, v in pairs(activeData.motors) do
			local initC0 = v:FindFirstChild("InitC0")
			if initC0 then
				v.C0 = initC0.Value
				local mv = activeData.motorValues and activeData.motorValues[name]
				if mv then mv.Value = initC0.Value end
			end
		end
		ClearMotorAttributes(activeData.motors)
	end

	activeAnimations[Model] = nil
	Model:SetAttribute("AnimationLitePlaying", nil)
	debugPrint("Animação parada e resetada")
end

function PlayKeyframeSequence(Model, KeyframeSequence, SpeedMult, StartAtFrameNum, StopAtFrameNum)
	if not Model or not Model.Parent or not KeyframeSequence or not KeyframeSequence.Parent then
		debugPrint("Parâmetros inválidos para PlayKeyframeSequence")
		pcall(function() Model:SetAttribute("AnimationLitePlaying", nil) end)
		return
	end

	if activeAnimations[Model] or pendingAnimations[Model] then
		debugPrint("Animação em andamento/agendada - PARANDO e AGENDANDO nova:", KeyframeSequence.Name)
		StopCurrentAnimation(Model)
		pendingAnimations[Model] = nil
		pendingAnimations[Model] = {
			KeyframeSequence = KeyframeSequence,
			SpeedMult        = SpeedMult,
			StartAtFrameNum  = StartAtFrameNum,
			StopAtFrameNum   = StopAtFrameNum
		}
		return
	end

	debugPrint("===================================")
	debugPrint("Iniciando animação:", KeyframeSequence.Name, "em", Model.Name)

	Model:SetAttribute("AnimationLitePlaying", true)

	SpeedMult      = SpeedMult or 1
	StopAtFrameNum = StopAtFrameNum or 9999
	if (not StartAtFrameNum) or StartAtFrameNum > StopAtFrameNum or StartAtFrameNum < 1 then
		StartAtFrameNum = 1
	end

	local AllKeyframes = KeyframeSequence:GetKeyframes()
	table.sort(AllKeyframes, function(a, b) return a.Time < b.Time end)
	local kfCount = #AllKeyframes

	local motorCache = {}
	for _, v in ipairs(Model:GetDescendants()) do
		if v:IsA("Motor6D") and v.Part1 then
			motorCache[v.Part1.Name] = v
		end
	end

	local tweens        = {}
	local motors        = {}
	local motorValues   = {}
	local KeyframePoses = {}
	local rigMismatch   = false

	local function GetOrCacheMotor(poseName)
		if motors[poseName] then return motors[poseName] end
		local Motor6D = motorCache[poseName]
		if not Motor6D then
			rigMismatch = true
			return nil
		end
		local initC0 = Motor6D:FindFirstChild("InitC0")
		if not initC0 then
			initC0        = Instance.new("CFrameValue")
			initC0.Name   = "InitC0"
			initC0.Value  = Motor6D.C0
			initC0.Parent = Motor6D
		else
			Motor6D.C0 = initC0.Value
		end
		motors[poseName] = Motor6D
		return Motor6D
	end

	local function GetOrCacheMotorValue(poseName)
		if motorValues[poseName] then return motorValues[poseName] end
		local motor = motors[poseName]
		if not motor then return nil end
		local mv = motor:FindFirstChild("MotorValue")
		if mv then
			mv.Value = motor.C0
		else
			mv        = Instance.new("CFrameValue")
			mv.Name   = "MotorValue"
			mv.Value  = motor.C0
			mv.Parent = motor
		end
		motorValues[poseName] = mv
		return mv
	end

	local excessTimeAfterLastPose = 0
	if kfCount > 1 and #AllKeyframes[kfCount]:GetDescendants() == 0 then
		excessTimeAfterLastPose = (AllKeyframes[kfCount].Time - AllKeyframes[kfCount - 1].Time) * SpeedMult
	end

	for i, Keyframe in ipairs(AllKeyframes) do
		for _, Pose in ipairs(Keyframe:GetDescendants()) do
			if Pose:IsA("Pose") and Pose.Weight > 0 then
				local poseName = Pose.Name
				local Motor6D  = GetOrCacheMotor(poseName)
				if Motor6D then
					GetOrCacheMotorValue(poseName)
					if not KeyframePoses[i] then
						KeyframePoses[i] = { Time = Keyframe.Time * SpeedMult, Poses = {} }
					end
					KeyframePoses[i].Poses[poseName] = { Motor6D = Motor6D, Pose = Pose }
				end
			end
		end
	end

	if rigMismatch then
		local humanoid = Model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.RigType == Enum.HumanoidRigType.R6 then
				warn("Motor mismatch:", KeyframeSequence.Name, "is an R15 animation, but the rig is R6.")
			elseif humanoid.RigType == Enum.HumanoidRigType.R15 then
				warn("Motor mismatch:", KeyframeSequence.Name, "is an R6 animation, but the rig is R15.")
			end
		end
	end

	local kfPoseCount = #KeyframePoses
	if kfPoseCount > 0 then
		local lastPose = {}
		for i = StartAtFrameNum, math.min(kfPoseCount - 1, StopAtFrameNum) do
			local Kf1, Kf2
			if kfPoseCount == 1 then
				Kf1, Kf2 = KeyframePoses[i], KeyframePoses[i]
				Kf1.Time, Kf2.Time = 0.001, 0.002
			else
				Kf1, Kf2 = KeyframePoses[i], KeyframePoses[i + 1]
			end
			local t = Kf2.Time - Kf1.Time
			tweens[i] = { Time = t, Tweens = {} }

			for name, data in pairs(Kf1.Poses) do
				lastPose[name]            = data
				lastPose[name].StartIndex = i
				lastPose[name].Time       = Kf1.Time
			end

			for name, data in pairs(Kf2.Poses) do
				if not lastPose[name] then
					lastPose[name]                      = data
					lastPose[name].Pose.EasingStyle     = Enum.PoseEasingStyle.Linear
					lastPose[name].Pose.EasingDirection = Enum.PoseEasingDirection.In
					lastPose[name].Pose.CFrame          = CFrame.new()
					lastPose[name].Time                 = 0
					lastPose[name].StartIndex           = StartAtFrameNum
				end
				local lp = lastPose[name]
				local tweeninfo = TweenInfo.new(
					math.abs(lp.Time - Kf2.Time),
					tStyle[lp.Pose.EasingStyle],
					tDirection[lp.Pose.EasingDirection]
				)
				tweens[lp.StartIndex].Tweens[name] = TS:Create(
					motorValues[name],
					tweeninfo,
					{ Value = motors[name].C0 * data.Pose.CFrame }
				)
			end
		end
	end

	-- Marca todos os motores que serão usados na animação
	SetMotorAttributes(motors)

	local animData = {
		shouldStop    = false,
		tweens        = tweens,
		motors        = motors,
		motorValues   = motorValues,
		runConnection = nil,
	}
	activeAnimations[Model] = animData

	local function play()
		for i = 1, #tweens do
			local v = tweens[i]
			if v then
				if not Model.Parent or not KeyframeSequence.Parent then
					debugPrint("Model ou KeyframeSequence removido durante playback")
					StopAtFrameNum = 0
					break
				end
				if animData.shouldStop or Model:GetAttribute("AnimationLitePlaying") ~= true then
					debugPrint("Animação foi interrompida")
					break
				end

				for _, tween in pairs(v.Tweens) do
					tween:Play()
				end
				wait(v.Time)
			end
		end

		if not animData.shouldStop and Model:GetAttribute("AnimationLitePlaying") == true then
			wait(excessTimeAfterLastPose)
		end
	end

	local myBreak = false

	local heartbeatPairs = {}
	for name, motor in pairs(motors) do
		local mv = motorValues[name]
		if mv then
			heartbeatPairs[#heartbeatPairs + 1] = { Motor = motor, Value = mv }
		end
	end

	animData.runConnection = runservice.Heartbeat:Connect(function(dt)
		if myBreak or animData.shouldStop then
			if animData.runConnection then
				animData.runConnection:Disconnect()
				animData.runConnection = nil
			end
			return
		end
		local alpha = math.min(dt * 15, 1)
		for i = 1, #heartbeatPairs do
			local p = heartbeatPairs[i]
			p.Motor.C0 = p.Motor.C0:Lerp(p.Value.Value, alpha)
		end
	end)

	while not animData.shouldStop and Model:GetAttribute("AnimationLitePlaying") == true do
		play()
		if not KeyframeSequence.Loop then
			debugPrint("Animação não é loop - finalizando")
			break
		end
	end

	myBreak = true
	wait(0.05)

	for i = 1, #tweens do
		local v = tweens[i]
		if v and v.Tweens then
			for _, tween in pairs(v.Tweens) do
				tween:Cancel()
				tween:Destroy()
			end
		end
	end

	if StopAtFrameNum == 9999 and not animData.shouldStop then
		for name, v in pairs(motors) do
			local initC0 = v:FindFirstChild("InitC0")
			if initC0 then
				v.C0 = initC0.Value
				if motorValues[name] then
					motorValues[name].Value = initC0.Value
				end
			end
		end
	end

	-- Desmarca todos os motores no final
	ClearMotorAttributes(motors)

	activeAnimations[Model] = nil
	Model:SetAttribute("AnimationLitePlaying", nil)

	debugPrint("Animação finalizada:", KeyframeSequence.Name)
	debugPrint("===================================")

	wait(0.03)
	if pendingAnimations[Model] then
		local pending = pendingAnimations[Model]
		pendingAnimations[Model] = nil
		debugPrint(">> Tocando animação AGENDADA:", pending.KeyframeSequence.Name)
		spawn(function()
			PlayKeyframeSequence(
				Model,
				pending.KeyframeSequence,
				pending.SpeedMult,
				pending.StartAtFrameNum,
				pending.StopAtFrameNum
			)
		end)
	else
		debugPrint("Nenhuma animação agendada")
	end
end

local AnimationLitePlayEvent = script:WaitForChild("AnimationLitePlayEvent")
AnimationLitePlayEvent.Event:Connect(PlayKeyframeSequence)

_G.AnimationLite = {
	Play = function(char, anim) PlayKeyframeSequence(char, anim) end,
	Stop = function(char) StopCurrentAnimation(char) end
}
