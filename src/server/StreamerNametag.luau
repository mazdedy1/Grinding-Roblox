-- StreamerNametag.luau
-- Free overhead nametag for the Streamer / Content Creator tier.
local StreamerNametag = {}

local TAG_NAME = "FreeStreamerNametag"

function StreamerNametag.apply(player: Player, role: string?)
	local character = player.Character
	if not character then return end

	local existing = character:FindFirstChild(TAG_NAME)
	if existing then existing:Destroy() end
	if role ~= "Streamer" then return end

	local adornee = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
	if not adornee or not adornee:IsA("BasePart") then return end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(150, 34)
	billboard.StudsOffset = Vector3.new(0, 2.6, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 100
	billboard.Parent = character

	local label = Instance.new("TextLabel")
	label.Name = "Title"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "STREAMER"
	label.TextColor3 = Color3.fromRGB(255, 220, 100)
	label.TextStrokeColor3 = Color3.fromRGB(25, 25, 30)
	label.TextStrokeTransparency = 0.15
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
end

return StreamerNametag
