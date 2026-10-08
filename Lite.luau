-- AnimationLite (versão com troca suave)
local TS = game:GetService("TweenService")
local runservice = game:GetService("RunService")

local DEBUG = false
local LERP_SPEED = 15      -- quanto maior, mais rápido o C0 acompanha o alvo
local RELEASE_TIME = 0.25  -- tempo para voltar à pose original

local tStyle, tDirection = {
    [Enum.PoseEasingStyle.Linear]    = Enum.EasingStyle.Linear;
    [Enum.PoseEasingStyle.Bounce]    = Enum.EasingStyle.Bounce;
    [Enum.PoseEasingStyle.Cubic]     = Enum.EasingStyle.Cubic;
    [Enum.PoseEasingStyle.CubicV2]   = Enum.EasingStyle.Cubic;
    [Enum.PoseEasingStyle.Elastic]   = Enum.EasingStyle.Elastic;
    [Enum.PoseEasingStyle.Constant]  = Enum.EasingStyle.Linear;
},{
    [Enum.PoseEasingDirection.In]    = Enum.EasingDirection.In;
    [Enum.PoseEasingDirection.Out]   = Enum.EasingDirection.Out;
    [Enum.PoseEasingDirection.InOut] = Enum.EasingDirection.InOut;
}

local activeAnimations = {}
local releasing = {}

local function debugPrint(...)
    if DEBUG then
        print("[AnimationLite]", ...)
    end
end

local function SetMotorAttributes(motors, value)
    for _, motor in pairs(motors) do
        motor:SetAttribute("AnimLiteActive", value)
    end
end

local function CancelTweens(tweens)
    for _, group in pairs(tweens) do
        for _, tween in pairs(group.Tweens) do
            tween:Cancel()
            tween:Destroy()
        end
    end
end

-- Para a animação ativa SEM resetar a pose (quem chamou decide o que fazer)
local function StopCurrentAnimation(Model)
    if not Model then return nil end
    local data = activeAnimations[Model]
    if not data then return nil end

    debugPrint("Parando animação em", Model.Name)
    data.shouldStop = true
    CancelTweens(data.tweens)

    if data.runConnection then
        data.runConnection:Disconnect()
        data.runConnection = nil
    end

    activeAnimations[Model] = nil
    return data
end

local function CancelRelease(Model)
    local rel = releasing[Model]
    if not rel then return nil end
    if rel.connection then
        rel.connection:Disconnect()
    end
    releasing[Model] = nil
    return rel
end

-- Leva os motores de volta ao InitC0 de forma suave
local function StartRelease(Model, motors)
    local merged = {}
    for name, motor in pairs(motors) do
        merged[name] = motor
    end

    local prev = CancelRelease(Model)
    if prev then
        for name, motor in pairs(prev.motors) do
            if not merged[name] then
                merged[name] = motor
            end
        end
    end

    if next(merged) == nil then return end

    local rel = { motors = merged, elapsed = 0 }
    releasing[Model] = rel

    rel.connection = runservice.Heartbeat:Connect(function(dt)
        rel.elapsed += dt
        local done = rel.elapsed >= RELEASE_TIME
        local alpha = math.min(dt * LERP_SPEED, 1)

        for _, motor in pairs(merged) do
            local initC0 = motor.Parent and motor:FindFirstChild("InitC0")
            if initC0 then
                if done then
                    motor.C0 = initC0.Value
                else
                    motor.C0 = motor.C0:Lerp(initC0.Value, alpha)
                end
            end
        end

        if done then
            rel.connection:Disconnect()
            SetMotorAttributes(merged, nil)
            if releasing[Model] == rel then
                releasing[Model] = nil
            end
        end
    end)
end

local function PlayKeyframeSequence(Model, KeyframeSequence, SpeedMult, StartAtFrameNum, StopAtFrameNum)
    if not Model or not Model.Parent or not KeyframeSequence or not KeyframeSequence.Parent then
        debugPrint("Parâmetros inválidos para PlayKeyframeSequence")
        if Model then
            pcall(function() Model:SetAttribute("AnimationLitePlaying", nil) end)
        end
        return
    end

    -- Troca imediata: assume o lugar da animação anterior (sem fila e sem espera)
    local oldData = StopCurrentAnimation(Model)
    local oldRelease = CancelRelease(Model)

    local inheritedMotors = {}
    if oldData then
        for name, motor in pairs(oldData.motors) do
            inheritedMotors[name] = motor
        end
    end
    if oldRelease then
        for name, motor in pairs(oldRelease.motors) do
            inheritedMotors[name] = motor
        end
    end

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

    local tweens = {}
    local motors = {}
    local motorValues = {}
    local KeyframePoses = {}
    local rigMismatch = false

    -- Não reseta mais o C0 aqui: a animação nova parte da pose atual
    local function GetOrCacheMotor(poseName)
        if motors[poseName] then return motors[poseName] end
        local motor = motorCache[poseName]
        if not motor then
            rigMismatch = true
            return nil
        end
        if not motor:FindFirstChild("InitC0") then
            local initC0 = Instance.new("CFrameValue")
            initC0.Name = "InitC0"
            initC0.Value = motor.C0
            initC0.Parent = motor
        end
        motors[poseName] = motor
        return motor
    end

    local function GetOrCacheMotorValue(poseName)
        if motorValues[poseName] then return motorValues[poseName] end
        local motor = motors[poseName]
        if not motor then return nil end
        local mv = motor:FindFirstChild("MotorValue")
        if not mv then
            mv = Instance.new("CFrameValue")
            mv.Name = "MotorValue"
            mv.Parent = motor
        end
        mv.Value = motor.C0 -- começa da pose atual (sem pulo)
        motorValues[poseName] = mv
        return mv
    end

    local excessTimeAfterLastPose = 0
    if kfCount > 1 and #AllKeyframes[kfCount]:GetDescendants() == 0 then
        excessTimeAfterLastPose = (AllKeyframes[kfCount].Time - AllKeyframes[kfCount - 1].Time) * SpeedMult
    end

    for _, Keyframe in ipairs(AllKeyframes) do
        local entry
        for _, Pose in ipairs(Keyframe:GetDescendants()) do
            if Pose:IsA("Pose") and Pose.Weight > 0 then
                local poseName = Pose.Name
                local motor = GetOrCacheMotor(poseName)
                if motor then
                    GetOrCacheMotorValue(poseName)
                    if not entry then
                        entry = { Time = Keyframe.Time * SpeedMult, Poses = {} }
                        table.insert(KeyframePoses, entry)
                    end
                    entry.Poses[poseName] = { Motor6D = motor, Pose = Pose }
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

    local lastIndex = 0
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

            tweens[i] = { Time = Kf2.Time - Kf1.Time, Tweens = {} }
            lastIndex = i

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
                -- Usa o InitC0 como base (e não o C0 atual), senão a pose acumularia
                tweens[lp.StartIndex].Tweens[name] = TS:Create(
                    motorValues[name],
                    tweeninfo,
                    { Value = motors[name].InitC0.Value * data.Pose.CFrame }
                )
            end
        end
    end

    SetMotorAttributes(motors, true)

    -- Motores da animação anterior que a nova não usa voltam suavemente ao normal
    local orphans = {}
    local hasOrphans = false
    for name, motor in pairs(inheritedMotors) do
        if not motors[name] then
            orphans[name] = motor
            hasOrphans = true
        end
    end
    if hasOrphans then
        StartRelease(Model, orphans)
    end

    local animData = {
        shouldStop    = false,
        tweens        = tweens,
        motors        = motors,
        motorValues   = motorValues,
        runConnection = nil,
    }
    activeAnimations[Model] = animData

    local heartbeatPairs = {}
    for name, motor in pairs(motors) do
        local mv = motorValues[name]
        if mv then
            heartbeatPairs[#heartbeatPairs + 1] = { Motor = motor, Value = mv }
        end
    end

    animData.runConnection = runservice.Heartbeat:Connect(function(dt)
        local alpha = math.min(dt * LERP_SPEED, 1)
        for i = 1, #heartbeatPairs do
            local p = heartbeatPairs[i]
            p.Motor.C0 = p.Motor.C0:Lerp(p.Value.Value, alpha)
        end
    end)

    local function alive()
        return not animData.shouldStop
            and Model.Parent ~= nil
            and KeyframeSequence.Parent ~= nil
            and Model:GetAttribute("AnimationLitePlaying") == true
    end

    local function play()
        for i = 1, lastIndex do
            local v = tweens[i]
            if v then
                if not alive() then return end
                for _, tween in pairs(v.Tweens) do
                    tween:Play()
                end
                task.wait(v.Time)
            end
        end
        if alive() then
            task.wait(excessTimeAfterLastPose)
        end
    end

    while alive() do
        play()
        if not KeyframeSequence.Loop then
            debugPrint("Animação não é loop - finalizando")
            break
        end
    end

    -- Se foi interrompida por outra animação/Stop, quem interrompeu já cuidou de tudo
    if animData.shouldStop then
        return
    end

    -- Fim natural
    if activeAnimations[Model] == animData then
        activeAnimations[Model] = nil
    end
    CancelTweens(tweens)
    if animData.runConnection then
        animData.runConnection:Disconnect()
        animData.runConnection = nil
    end

    if Model.Parent then
        Model:SetAttribute("AnimationLitePlaying", nil)

        if StopAtFrameNum == 9999 then
            StartRelease(Model, motors) -- volta suave para a pose original
        else
            -- Modo estátua: mantém a pose final
            for name, motor in pairs(motors) do
                local mv = motorValues[name]
                if mv then
                    motor.C0 = mv.Value
                end
            end
            SetMotorAttributes(motors, nil)
        end
    end

    debugPrint("Animação finalizada:", KeyframeSequence.Name)
end

local function StopAnimation(Model)
    local data = StopCurrentAnimation(Model)
    if data then
        StartRelease(Model, data.motors)
        Model:SetAttribute("AnimationLitePlaying", nil)
    end
end

local AnimationLitePlayEvent = script:WaitForChild("AnimationLitePlayEvent")
AnimationLitePlayEvent.Event:Connect(PlayKeyframeSequence)

_G.AnimationLite = {
    Play = function(char, anim) PlayKeyframeSequence(char, anim) end,
    Stop = function(char) StopAnimation(char) end,
}
