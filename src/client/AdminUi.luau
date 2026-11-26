-- AdminUi.luau
-- Compact command-driven admin window. Visibility is granted by server attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UI = require(script.Parent.UI)

local AdminUi = {}
local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminRequest")

local function makeLabel(parent, text, position, size, color)
	return UI.create("TextLabel", {
		Position = position, Size = size, BackgroundTransparency = 1,
		Text = text, TextColor3 = color or UI.Palette.text,
		Font = Enum.Font.Gotham, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true, Parent = parent,
	})
end

function AdminUi.build()
	local noticeGui = UI.create("ScreenGui", {
		Name = "AdminNotices", ResetOnSpawn = false, DisplayOrder = 30,
		Parent = player:WaitForChild("PlayerGui"),
	})
	local notice = UI.create("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(420, 48), BackgroundColor3 = UI.Palette.panel,
		TextColor3 = UI.Palette.text, Font = Enum.Font.FredokaOne, TextScaled = true,
		Visible = false, Parent = noticeGui,
	}, { UI.corner(10), UI.stroke(UI.Palette.accent, 2) })
	local function showNotice(value)
		notice.Text = tostring(value)
		notice.Visible = true
		task.delay(5, function()
			if notice.Parent and notice.Text == tostring(value) then notice.Visible = false end
		end)
	end
	player:GetAttributeChangedSignal("AdminAnnouncement"):Connect(function()
		local value = player:GetAttribute("AdminAnnouncement")
		if type(value) == "string" and value ~= "" then showNotice(value) end
	end)
	player:GetAttributeChangedSignal("AdminEventNotice"):Connect(function()
		local value = player:GetAttribute("AdminEventNotice")
		if type(value) == "string" and value ~= "" then showNotice(value) end
	end)

	local content = UI.window("Admin", "ADMIN CONTROL", UDim2.fromOffset(540, 440))
	makeLabel(content, "Server administration • Commands are checked by the server.", UDim2.fromOffset(4, 0), UDim2.new(1, -8, 0, 28), UI.Palette.subtext)

	local commandBox = UI.create("TextBox", {
		Position = UDim2.fromOffset(4, 38), Size = UDim2.new(1, -112, 0, 40),
		BackgroundColor3 = UI.Palette.bg, TextColor3 = UI.Palette.text,
		PlaceholderText = "event start megagrind 10  |  kick PlayerName reason",
		PlaceholderColor3 = UI.Palette.subtext, Text = "", ClearTextOnFocus = false,
		Font = Enum.Font.Code, TextSize = 14, Parent = content,
	}, { UI.corner(8), UI.padding(8) })

	local execute = UI.button({
		Text = "RUN", Size = UDim2.fromOffset(96, 40),
		Position = UDim2.new(1, -100, 0, 38), Parent = content,
	})
	local output = makeLabel(content, "Ready. Type 'help' for commands.", UDim2.fromOffset(4, 88), UDim2.new(1, -8, 0, 48), UI.Palette.good)
	local eventLabel = makeLabel(content, "Active event: none", UDim2.fromOffset(4, 142), UDim2.new(1, -8, 0, 28), UI.Palette.accent)
	local playersLabel = makeLabel(content, "Players: loading...", UDim2.fromOffset(4, 176), UDim2.new(1, -8, 0, 76), UI.Palette.text)
	local logsLabel = makeLabel(content, "Recent actions: none", UDim2.fromOffset(4, 258), UDim2.new(1, -8, 0, 120), UI.Palette.subtext)

	local function run()
		local command = commandBox.Text
		if command == "" then return end
		remote:FireServer("command", command)
		commandBox.Text = ""
	end
	execute.Activated:Connect(run)
	commandBox.FocusLost:Connect(function(enterPressed) if enterPressed then run() end end)

	remote.OnClientEvent:Connect(function(kind, payload, success)
		if kind == "result" then
			output.Text = tostring(payload)
			output.TextColor3 = success and UI.Palette.good or UI.Palette.bad
		elseif kind == "state" and type(payload) == "table" then
			eventLabel.Text = "Active event: " .. (payload.event and payload.event.name or "none")
			local names = {}
			for _, item in payload.players or {} do table.insert(names, item.name .. " (" .. item.userId .. ")") end
			playersLabel.Text = "Online players:\n" .. table.concat(names, ", ")
			local entries = {}
			for index, item in payload.logs or {} do
				if index > 5 then break end
				table.insert(entries, item.actor .. ": " .. item.command .. " → " .. item.result)
			end
			logsLabel.Text = "Recent actions:\n" .. (#entries > 0 and table.concat(entries, "\n") or "none")
		end
	end)

	task.spawn(function()
		while content.Parent do
			if player:GetAttribute("IsAdmin") then remote:FireServer("state") end
			task.wait(10)
		end
	end)
end

return AdminUi
