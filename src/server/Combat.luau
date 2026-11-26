-- Combat.luau
-- Server-authoritative Training Dummy combat used by the Daily 2x Damage boost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local Combat = {}
local lastAttack = {}
local Data

local function createDummy()
	local model = Instance.new("Model")
	model.Name = "Training Dummy"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(0, 3, 25)
	root.Anchored = true
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model

	local torso = Instance.new("Part")
	torso.Name = "Torso"
	torso.Size = Vector3.new(2.5, 3, 1.3)
	torso.CFrame = root.CFrame
	torso.Anchored = true
	torso.Color = Color3.fromRGB(120, 135, 150)
	torso.Material = Enum.Material.Metal
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.6, 1.6, 1.6)
	head.CFrame = root.CFrame * CFrame.new(0, 2.2, 0)
	head.Anchored = true
	head.Color = Color3.fromRGB(220, 190, 150)
	head.Parent = model

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = Config.Combat.DummyMaxHealth
	humanoid.Health = humanoid.MaxHealth
	humanoid.DisplayName = "Training Dummy"
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOn
	humanoid.Parent = model
	model.PrimaryPart = root

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AttackPrompt"
	prompt.ActionText = "Punch"
	prompt.ObjectText = "Training Dummy"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Config.Combat.AttackDistance
	prompt.RequiresLineOfSight = false
	prompt.Parent = torso

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "DummyLabel"
	billboard.Adornee = head
	billboard.Size = UDim2.fromOffset(180, 42)
	billboard.StudsOffset = Vector3.new(0, 1.6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = model

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = "TRAINING DUMMY"
	label.TextColor3 = Color3.fromRGB(255, 220, 110)
	label.TextStrokeTransparency = 0.25
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Parent = billboard

	model.Parent = workspace
	return model, humanoid, prompt
end

function Combat.start(dataService)
	Data = dataService
	local model, humanoid, prompt = createDummy()

	prompt.Triggered:Connect(function(player)
		local profile = Data.get(player)
		local character = player.Character
		local playerRoot = character and character:FindFirstChild("HumanoidRootPart")
		if not profile or not playerRoot or humanoid.Health <= 0 then
			return
		end
		if (playerRoot.Position - model.PrimaryPart.Position).Magnitude > Config.Combat.AttackDistance + 3 then
			return
		end

		local now = os.clock()
		if now - (lastAttack[player] or 0) < Config.Combat.AttackCooldown then
			return
		end
		lastAttack[player] = now

		local damage = Formulas.damagePerHit({
			gearLevel = profile.gearLevel,
			rebirths = profile.rebirths,
			hasDoubleDamage = Data.hasActiveBoost(player, "DoubleDamage"),
		})
		humanoid:TakeDamage(damage)
		local notify = ReplicatedStorage.Remotes:FindFirstChild("Notify")
		if notify then
			notify:FireClient(player, "success", ("Dealt %s damage!"):format(Formulas.abbreviate(damage)))
		end
	end)

	humanoid.Died:Connect(function()
		task.delay(Config.Combat.DummyRespawnSeconds, function()
			if model.Parent then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return Combat
