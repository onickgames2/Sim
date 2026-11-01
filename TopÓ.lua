local button = script.Parent.Template
local emotes = game.ReplicatedStorage.Animations.Emotes:GetChildren()
local event = game.ReplicatedStorage.RemoteEvents.Emote
 
script.Parent.Parent.Enabled = true

for _,child in pairs(emotes) do
    local cl = button:clone()
    cl.Name = child.Name
    cl.Text = child.Name
    cl.Parent = script.Parent
    cl.Visible = true
    cl.MouseButton1Click:Connect(function()
        event:FireServer(cl.Name)
    end)
end

 
 

