-- Lua 5.1 (Roblox 2016)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer

-- O RemoteEvent precisa ser criado pelo SERVIDOR (veja o script abaixo).
-- Um RemoteEvent criado no client nao chega no servidor.
local remoteEvent = ReplicatedStorage:WaitForChild("DetectDeviceType")

local function detectDeviceType()
	local lastInputType = UserInputService:GetLastInputType()

	if lastInputType == Enum.UserInputType.Touch then
		return "Mobile"
	elseif lastInputType == Enum.UserInputType.Gamepad1
		or lastInputType == Enum.UserInputType.Gamepad2
		or lastInputType == Enum.UserInputType.Gamepad3
		or lastInputType == Enum.UserInputType.Gamepad4 then
		return "Console"
	else
		return "PC"
	end
end

-- Detecta o dispositivo na primeira vez que entra
wait(1)
local lastDetectedDevice = detectDeviceType()
print("Dispositivo detectado: " .. lastDetectedDevice)
remoteEvent:FireServer(lastDetectedDevice)

-- Monitora mudancas continuas
while true do
	wait(1)

	local currentDevice = detectDeviceType()

	if currentDevice ~= lastDetectedDevice then
		lastDetectedDevice = currentDevice
		print("Dispositivo mudou para: " .. currentDevice)
		remoteEvent:FireServer(currentDevice)
	end
end
