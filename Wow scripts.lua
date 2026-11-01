-- Lua 5.1
local f = script.Parent.Parent.Notification
local e = game.ReplicatedStorage.RemoteEvents.Notification
local t = f.Template
local e2 = game.ReplicatedStorage.RemoteEvents.NotificationClient

local TweenService = game:GetService("TweenService")
local SHOW_TIME = 7

local function show(title, subtitle, photoId)
	local clone = t:Clone()
	clone.Title.Text = title
	clone.Photo.Image = "rbxthumb://type=Asset&id=" .. tostring(photoId) .. "&w=420&h=420"
	clone.SubTitle.Text = subtitle
	clone.Visible = true
	clone.Parent = f

	local originalSize = clone.Size
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweenOut = TweenService:Create(clone, tweenInfo, {Size = UDim2.new(0, 0, 0, 0)})
	local tweenIn = TweenService:Create(clone, tweenInfo, {Size = originalSize})

	clone.Size = UDim2.new(0, 0, 0, 0)
	tweenIn:Play()

	delay(SHOW_TIME, function()
		tweenOut:Play()
		tweenOut.Completed:Wait()
		clone:Destroy()
	end)
end

e2.Event:Connect(function(title, subtitle, id)
	show(title, subtitle, id)
end)

e.OnClientEvent:Connect(function(title, subtitle, photoId)
	show(title, subtitle, photoId)
end)
