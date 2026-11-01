-- Lua 5.1
--AnimationLiteService - Adapted verious examples to create a Procedural KeyframeSequence player using C0 so it blends with regular animations.  ScottSpiritWalker, 08/21/2025.

local TS = game:GetService("TweenService")
local runservice = game:GetService("RunService")

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

function PlayKeyframeSequence(Model, KeyframeSequence, SpeedMult, StartAtFrameNum, StopAtFrameNum)
	if not Model or not Model.Parent or not KeyframeSequence or not KeyframeSequence.Parent then
		pcall(function()
			Model:SetAttribute("AnimationLitePlaying", nil)
		end)
		return
	end

	if Model:GetAttribute("AnimationLitePlaying") or Model:GetAttribute("AnimationLitePlaying") == false then
		Model:SetAttribute("AnimationLitePlaying", false)
		print("Can't play", Model, KeyframeSequence, " Previous animation is still playing.")
		print("Try stopping it or waiting for it to finish. See comments in the AnimationLitePlayScript.")
		return
	end

	Model:SetAttribute("AnimationLitePlaying", true)
	if not SpeedMult then
		SpeedMult = 1
	end
	if not StopAtFrameNum then
		StopAtFrameNum = 9999
	end
	if (not StartAtFrameNum) or StartAtFrameNum > StopAtFrameNum or StartAtFrameNum < 1 then
		StartAtFrameNum = 1
	end

	local AllKeyframes = {}

	for i, Keyframe in pairs(KeyframeSequence:GetKeyframes()) do
		table.insert(AllKeyframes, {
			Time = Keyframe.Time,
			Keyframe = Keyframe
		})
	end
	table.sort(AllKeyframes, function(a, b)
		return a.Time < b.Time
	end)

	local tweens = {}
	local motors = {}
	local motorValues = {}
	local KeyframePoses = {}

	local rigMismatch = false

	local function GetMotorFromPose(Pose, Keyframe)
		for i, v in pairs(Model:GetDescendants()) do
			if v:IsA("Motor6D") then
				if v.Part1 and v.Part1.Name == Pose.Name then
					local initC0 = v:FindFirstChild("InitC0")
					if initC0 then
						v.C0 = initC0.Value
					else
						initC0 = Instance.new("CFrameValue")
						initC0.Name = "InitC0"
						initC0.Value = v.C0
						initC0.Parent = v
					end
					return v
				end
			end
		end
		rigMismatch = true
		return nil
	end

	local excessTimeAfterLastPose = 0
	if #AllKeyframes > 1 and #AllKeyframes[#AllKeyframes].Keyframe:GetDescendants() == 0 then
		excessTimeAfterLastPose = (AllKeyframes[#AllKeyframes].Time - AllKeyframes[#AllKeyframes - 1].Time) * SpeedMult
		table.remove(AllKeyframes, #AllKeyframes)
	end

	for i, Keyframe in pairs(AllKeyframes) do
		for x, Pose in pairs(Keyframe.Keyframe:GetDescendants()) do
			if Pose:IsA("Pose") and Pose.Weight > 0 then
				local Motor6D = motors[Pose.Name] or GetMotorFromPose(Pose, Keyframe)
				if Motor6D then
					if not KeyframePoses[i] then
						KeyframePoses[i] = {
							Time = Keyframe.Time * SpeedMult,
							Poses = {}
						}
					end
					if not motors[Pose.Name] then
						motors[Pose.Name] = Motor6D
					end
					if not motorValues[Pose.Name] then
						local mv = motors[Pose.Name]:FindFirstChild("MotorValue")
						if mv and mv.Name == "MotorValue" then
							mv.Value = Motor6D.InitC0.Value
							motorValues[Pose.Name] = mv
						else
							local motorVal = Instance.new("CFrameValue")
							motorVal.Name = "MotorValue"
							motorVal.Parent = motors[Pose.Name]
							motorVal.Value = Motor6D.InitC0.Value
							motorValues[Pose.Name] = motorVal
						end
					end
					KeyframePoses[i].Poses[Pose.Name] = {Motor6D = Motor6D, Pose = Pose}
				end
			end
		end
	end

	if rigMismatch then
		if Model.Humanoid.RigType == Enum.HumanoidRigType.R6 then
			warn("Motor mismatch:", KeyframeSequence.Name, "is an R15 animation, but the rig is R6.")
		elseif Model.Humanoid.RigType == Enum.HumanoidRigType.R15 then
			warn("Motor mismatch:", KeyframeSequence.Name, "is an R6 animation, but the rig is R15.")
		end
	end

	if #KeyframePoses > 0 then
		local lastPose = {}
		for i = StartAtFrameNum, math.min(#KeyframePoses - 1, StopAtFrameNum) do
			local Kf1, Kf2
			if #KeyframePoses == 1 then
				Kf1, Kf2 = KeyframePoses[i], KeyframePoses[i]
				Kf1.Time, Kf2.Time = 0.001, 0.002
			else
				Kf1, Kf2 = KeyframePoses[i], KeyframePoses[i + 1]
			end

			local t = Kf2.Time - Kf1.Time
			tweens[i] = {
				Time = t,
				Tweens = {}
			}
			for name, data in pairs(Kf1.Poses) do
				lastPose[name] = data
				lastPose[name].StartIndex = i
				lastPose[name].Time = Kf1.Time
			end

			for name, data in pairs(Kf2.Poses) do
				if not lastPose[name] then
					lastPose[name] = data
					lastPose[name].Pose.EasingStyle = Enum.PoseEasingStyle.Linear
					lastPose[name].Pose.EasingDirection = Enum.PoseEasingDirection.In
					lastPose[name].Pose.CFrame = CFrame.new()
					lastPose[name].Time = 0
					lastPose[name].StartIndex = StartAtFrameNum
					print("SL_Make StartFrame", name, data)
				end
				local tweeninfo = TweenInfo.new(
					math.abs(lastPose[name].Time - Kf2.Time),
					tStyle[lastPose[name].Pose.EasingStyle],
					tDirection[lastPose[name].Pose.EasingDirection]
				)
				tweens[lastPose[name].StartIndex].Tweens[name] = TS:Create(motorValues[name], tweeninfo, {Value = motors[data.Pose.Name].C0 * data.Pose.CFrame})
			end
		end
	end

	local breakPlay = false

	local function play()
		for i, v in pairs(motors) do
			local initC0 = v:FindFirstChild("InitC0")
			if initC0 and v.C0 ~= initC0.Value then
				v.C0 = initC0.Value
				motorValues[i].Value = initC0.Value
			end
		end
		for i, v in pairs(tweens) do
			if not Model or not Model.Parent or not KeyframeSequence or not KeyframeSequence.Parent then
				breakPlay = true
				break
			end
			if (not Model:GetAttribute("AnimationLitePlaying")) then
				break
			end
			for _, tween in pairs(v.Tweens) do
				tween:Play()
			end
			wait(v.Time)
		end
		if Model:GetAttribute("AnimationLitePlaying") then
			wait(excessTimeAfterLastPose)
		end
	end

	local myBreak = false
	local myTicks = tick()
	local runConnection

	runConnection = runservice.Stepped:Connect(function()
		for i, v in pairs(motors) do
			if myBreak then
				runConnection:Disconnect()
				break
			end
			if v.C0 ~= motorValues[i].Value then
				v.C0 = motorValues[i].Value
			end
		end
	end)

	while Model:GetAttribute("AnimationLitePlaying") do
		play()
		if KeyframeSequence.Loop == false or breakPlay then
			break
		end
	end

	myBreak = true
	wait()

	for i, v in pairs(tweens) do
		for _, tween in pairs(v.Tweens) do
			tween:Cancel()
			tween:Destroy()
		end
	end

	if StopAtFrameNum == 9999 then
		for i, v in pairs(motors) do
			local initC0 = v:FindFirstChild("InitC0")
			if initC0 and v.C0 ~= initC0.Value then
				v.C0 = initC0.Value
				motorValues[i].Value = initC0.Value
			end
		end
	end

	pcall(function()
		Model:SetAttribute("AnimationLitePlaying", nil)
	end)
end

local AnimationLitePlayEvent = script:WaitForChild("AnimationLitePlayEvent")
AnimationLitePlayEvent.Event:Connect(PlayKeyframeSequence)
