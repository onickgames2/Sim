-- Lua 5.1
local TweenService = game:GetService("TweenService")

local button = script.Parent
local frame = script.Parent.Parent.Frame2

local original = frame.Size
local hiden = false
local originalC = button.BackgroundColor3

button.MouseButton1Click:Connect(function()
	local value = not hiden
	hiden = value

	frame.BorderSizePixel = value and 2 or 0

	button.BackgroundColor3 = value and Color3.fromRGB(255,255,255) or originalC

	local tween = TweenService:Create(
		frame,
		TweenInfo.new(0.1, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut),
		{Size = value and original or UDim2.new(0,0,0,0)}
	)
	tween:Play()
	tween.Completed:Wait()
end)

frame.Size = UDim2.new(0,0,0,0)
