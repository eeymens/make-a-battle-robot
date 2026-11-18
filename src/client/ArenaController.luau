-- Arena tarafı client: kuyruk çubuğu, maç kamerası, yön girişi (klavye / joystick),
-- yetenek butonu, can barları, hasar sayıları, sonuç ekranı.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local MarketplaceService = game:GetService("MarketplaceService")

local Arena = require(ReplicatedStorage.Shared.Config.Arena)
local ProductsConfig = require(ReplicatedStorage.Shared.Config.Products)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local C = UIKit.Colors

local ArenaController = {}

local remotes = {} :: { [string]: RemoteEvent }
local controls = nil -- PlayerModule kontrolleri (klavye, joystick, gamepad)

-- Maç durumu
local current = nil -- { Info, Folder, Mine, Enemy, StartedAt, AbilityReadyAt }

-- UI
local screen: ScreenGui
local queueBar: Frame
local matchHud: Frame
local myBar: Frame
local enemyBar: Frame
local myName: TextLabel
local enemyName: TextLabel
local timerLabel: TextLabel
local bigText: TextLabel
local abilityButton: TextButton
local repairButton: TextButton
local resultPanel: Frame
local resultTitle: TextLabel
local resultBody: TextLabel

local REASONS = {
	ringout = "Robot arenadan düştü!",
	destroyed = "Robot hurdaya döndü!",
	time = "Süre doldu, canı fazla olan kazandı.",
	left = "Rakip oyundan çıktı.",
}

---------------------------------------------------------------- UI kurulumu

local function healthBar(parent: Instance, anchorRight: boolean, color: Color3): (Frame, TextLabel)
	local holder = UIKit.Frame({
		AnchorPoint = Vector2.new(if anchorRight then 1 else 0, 0),
		Position = if anchorRight then UDim2.new(1, -16, 0, 0) else UDim2.fromOffset(16, 0),
		Size = UDim2.new(0.4, -24, 0, 56),
		BackgroundTransparency = 1,
		Parent = parent,
	})
	local name = UIKit.Label({
		Text = "",
		TextXAlignment = if anchorRight then Enum.TextXAlignment.Right else Enum.TextXAlignment.Left,
		Size = UDim2.new(1, 0, 0, 22),
		Parent = holder,
	})
	local back = UIKit.Frame({
		Position = UDim2.fromOffset(0, 26),
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = C.Panel,
		Parent = holder,
	})
	UIKit.Corner(back, 6)
	local fill = UIKit.Frame({
		AnchorPoint = Vector2.new(if anchorRight then 1 else 0, 0),
		Position = if anchorRight then UDim2.fromScale(1, 0) else UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		Parent = back,
	})
	UIKit.Corner(fill, 6)
	return fill, name
end

local function build()
	screen = Instance.new("ScreenGui")
	screen.Name = "Arena"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5

	-- Kuyruk çubuğu
	queueBar = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Size = UDim2.fromOffset(340, 56),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screen,
	})
	UIKit.Corner(queueBar, 10)
	UIKit.Stroke(queueBar, Color3.fromRGB(231, 76, 60), 2)
	UIKit.Label({
		Text = "Rakip aranıyor...",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.fromOffset(200, 32),
		Parent = queueBar,
	})
	local cancel = UIKit.Button({
		Text = "İptal",
		BackgroundColor3 = C.Bad,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(90, 38),
		Parent = queueBar,
	})
	cancel.MouseButton1Click:Connect(function()
		remotes.ArenaLeaveQueue:FireServer()
		queueBar.Visible = false
	end)

	-- Maç HUD'u
	matchHud = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = screen,
	})
	local top = UIKit.Frame({
		Position = UDim2.fromOffset(0, 12),
		Size = UDim2.new(1, 0, 0, 60),
		BackgroundTransparency = 1,
		Parent = matchHud,
	})
	myBar, myName = healthBar(top, false, C.Good)
	enemyBar, enemyName = healthBar(top, true, C.Bad)
	timerLabel = UIKit.Label({
		Text = "90",
		Font = Enum.Font.GothamBlack,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(100, 50),
		Parent = top,
	})
	bigText = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Accent,
		TextStrokeTransparency = 0.3,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.fromOffset(500, 110),
		Parent = matchHud,
	})
	abilityButton = UIKit.Button({
		Text = "Yetenek (F)",
		BackgroundColor3 = Color3.fromRGB(142, 68, 173),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -110),
		Size = UDim2.fromOffset(170, 70),
		Parent = matchHud,
	})
	-- Tamir Kiti (Robux, ürün ID'si girilmişse görünür)
	repairButton = UIKit.Button({
		Text = "Tamir Kiti +%50",
		BackgroundColor3 = C.Good,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -24, 1, -190),
		Size = UDim2.fromOffset(170, 44),
		Visible = false,
		Parent = matchHud,
	})
	repairButton.MouseButton1Click:Connect(function()
		local id = ProductsConfig.Products.Repair.Id
		if id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, id)
		end
	end)

	UIKit.Label({
		Text = "WASD / joystick ile yönlendir · bırakırsan robot kendi saldırır",
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.Muted,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		Size = UDim2.fromOffset(520, 20),
		Parent = matchHud,
	})

	-- Sonuç ekranı
	resultPanel = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Size = UDim2.fromOffset(420, 230),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screen,
	})
	UIKit.Corner(resultPanel, 14)
	UIKit.AutoScale(resultPanel, 500)
	resultTitle = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamBlack,
		Position = UDim2.fromOffset(16, 14),
		Size = UDim2.new(1, -32, 0, 60),
		Parent = resultPanel,
	})
	resultBody = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		TextSize = 22,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 84),
		Size = UDim2.new(1, -32, 1, -100),
		Parent = resultPanel,
	})

	screen.Parent = player:WaitForChild("PlayerGui")
end

---------------------------------------------------------------- efektler

local function floatingText(position: Vector3, text: string, color: Color3, size: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position + Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
	anchor.Parent = Workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(size * 4, size)
	gui.AlwaysOnTop = true
	gui.Parent = anchor
	local label = UIKit.Label({
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamBlack,
		TextStrokeTransparency = 0.2,
		Size = UDim2.fromScale(1, 1),
		Parent = gui,
	})

	TweenService:Create(anchor, TweenInfo.new(0.8), { Position = anchor.Position + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		anchor:Destroy()
	end)
end

local function sparks(position: Vector3, color: Color3)
	for _ = 1, 5 do
		local spark = Instance.new("Part")
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.Material = Enum.Material.Neon
		spark.Color = color
		spark.Size = Vector3.new(0.3, 0.3, 0.3)
		spark.Position = position
		spark.Parent = Workspace
		local target = position + Vector3.new(math.random() * 6 - 3, math.random() * 3, math.random() * 6 - 3)
		TweenService:Create(spark, TweenInfo.new(0.35), { Position = target, Transparency = 1 }):Play()
		task.delay(0.4, function()
			spark:Destroy()
		end)
	end
end

local function shockwave(position: Vector3)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(241, 196, 15)
	ring.Transparency = 0.3
	ring.Size = Vector3.new(0.4, 2, 2)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = Workspace
	local radius = Arena.Weapons.HammerArm.Ability.Radius
	TweenService:Create(ring, TweenInfo.new(0.35), { Size = Vector3.new(0.4, radius * 2, radius * 2), Transparency = 1 }):Play()
	task.delay(0.4, function()
		ring:Destroy()
	end)
end

local ABILITY_TEXT = {
	Turbo = "TURBO!",
	Shockwave = "ŞOK DALGASI!",
	Inferno = "ALEV PATLAMASI!",
	Repair = "TAMİR!",
}

local function onFx(payload)
	if not current then
		return
	end
	if payload.Type == "hit" then
		local mine = payload.Side == current.Info.Side
		local color = if mine then C.Bad else Color3.new(1, 1, 1)
		floatingText(payload.Position, tostring(payload.Amount), color, 28)
		sparks(payload.Position - Vector3.new(0, 2, 0), Color3.fromRGB(255, 200, 80))
	elseif payload.Type == "ability" then
		floatingText(payload.Position + Vector3.new(0, 7, 0), ABILITY_TEXT[payload.Ability] or "!", C.Accent, 40)
		if payload.Ability == "Shockwave" then
			shockwave(payload.Position)
		end
		if payload.Ability == "Repair" then
			if payload.Side == current.Info.Side then
				repairButton.Visible = false -- maç başına 1 kez
			end
		elseif payload.Side == current.Info.Side then
			current.AbilityReadyAt = os.clock() + current.Info.AbilityCooldown
		end
	end
end

---------------------------------------------------------------- maç döngüsü

local function robotPosition(model: Model?): Vector3?
	local root = model and model.PrimaryPart
	return root and root.Position
end

local function updateBars()
	if not current then
		return
	end
	local function apply(model: Model?, fill: Frame, label: TextLabel)
		if not model then
			return
		end
		local hp = model:GetAttribute("HP") or 0
		local maxHp = math.max(1, model:GetAttribute("MaxHP") or 1)
		fill.Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1)
		label.Text = `{model:GetAttribute("DisplayName") or "?"}  ·  {math.ceil(hp)}/{maxHp}`
	end
	apply(current.Mine, myBar, myName)
	apply(current.Enemy, enemyBar, enemyName)
end

local function renderStep()
	if not current then
		return
	end
	local info = current.Info
	local center = Arena.GetCenter(info.ArenaIndex)

	-- Kamera: kendi robotun yakın tarafta, iki robotun ortasına bakar
	local a = robotPosition(current.Mine) or center
	local b = robotPosition(current.Enemy) or center
	local focus = center:Lerp((a + b) / 2, 0.6)
	local back = if info.Side == 1 then 1 else -1
	local eye = focus + Vector3.new(0, 42, 46 * back)
	camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(eye, focus), 0.15)

	updateBars()

	local elapsed = os.clock() - current.StartedAt
	if elapsed < info.Countdown then
		bigText.Text = tostring(math.ceil(info.Countdown - elapsed))
	elseif elapsed < info.Countdown + 0.8 then
		bigText.Text = "SAVAŞ!"
	else
		bigText.Text = ""
	end
	timerLabel.Text = tostring(current.Folder:GetAttribute("TimeLeft") or info.Duration)

	local cooldown = (current.AbilityReadyAt or 0) - os.clock()
	if cooldown > 0 then
		abilityButton.Text = `{info.AbilityName} ({math.ceil(cooldown)})`
		abilityButton.BackgroundColor3 = C.Card
	else
		abilityButton.Text = `{info.AbilityName} (F)`
		abilityButton.BackgroundColor3 = Color3.fromRGB(142, 68, 173)
	end
end

local function inputLoop(token)
	while current and current.Token == token do
		local move = Vector3.zero
		if not controls then
			-- Yedek: karakterin hareket yönü (zaten dünya koordinatında)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
				move = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z)
				if move.Magnitude > 0.01 then
					move = move.Unit
				end
			end
		end
		if controls then
			local ok, vector = pcall(function()
				return controls:GetMoveVector()
			end)
			if ok and vector and vector.Magnitude > 0.05 then
				-- Kamera yönüne göre dünyaya çevir (W = ekranda yukarı)
				local world = camera.CFrame:VectorToWorldSpace(vector)
				local flatWorld = Vector3.new(world.X, 0, world.Z)
				if flatWorld.Magnitude > 0.01 then
					move = flatWorld.Unit * math.min(vector.Magnitude, 1)
				end
			end
		end
		remotes.ArenaInput:FireServer(move)
		task.wait(0.1)
	end
end

local function useAbility()
	if current and os.clock() >= (current.AbilityReadyAt or 0) then
		remotes.ArenaAbility:FireServer()
	end
end

local function onMatchStarted(info)
	queueBar.Visible = false
	local arenaModel = Workspace:WaitForChild("Arenas"):WaitForChild("Arena" .. info.ArenaIndex)
	local folder = arenaModel:WaitForChild("Match", 10)
	if not folder then
		return
	end
	local mine = folder:WaitForChild("Robot" .. info.Side, 10) :: Model?
	local enemy = folder:WaitForChild("Robot" .. (3 - info.Side), 10) :: Model?

	local token = {}
	current = {
		Token = token,
		Info = info,
		Folder = folder,
		Mine = mine,
		Enemy = enemy,
		StartedAt = os.clock(),
		AbilityReadyAt = 0,
	}

	resultPanel.Visible = false
	matchHud.Visible = true
	repairButton.Visible = ProductsConfig.Products.Repair.Id ~= 0
	camera.CameraType = Enum.CameraType.Scriptable
	RunService:BindToRenderStep("ArenaCamera", Enum.RenderPriority.Camera.Value + 1, renderStep)
	task.spawn(inputLoop, token)
end

local function onMatchEnded(result)
	local wasCurrent = current
	current = nil
	RunService:UnbindFromRenderStep("ArenaCamera")
	matchHud.Visible = false
	bigText.Text = ""

	resultTitle.Text = if result.Won then "KAZANDIN!" else "KAYBETTİN"
	resultTitle.TextColor3 = if result.Won then C.Good else C.Bad
	local trophySign = if result.TrophyDelta >= 0 then "+" else ""
	local lines = {
		REASONS[result.Reason] or "",
		`+{Util.FormatNumber(result.Reward)} Hurda`,
		`{trophySign}{result.TrophyDelta} Kupa  (Toplam {result.Trophies} · {result.League})`,
	}
	if result.LeagueUp then
		table.insert(lines, `YENİ LİG: {result.League}!`)
	end
	resultBody.Text = table.concat(lines, "\n")
	resultPanel.Visible = true

	task.delay(Arena.ResultSeconds, function()
		resultPanel.Visible = false
		if current == nil and wasCurrent then
			camera.CameraType = Enum.CameraType.Custom
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
	end)
end

---------------------------------------------------------------- başlatma

function ArenaController.Init()
	for _, name in { "ArenaQueue", "ArenaMatchStarted", "ArenaMatchEnded", "ArenaFx", "ArenaInput", "ArenaAbility", "ArenaLeaveQueue" } do
		remotes[name] = Remotes.Event(name)
	end

	-- Kontrol modülünü arka planda ara; bulunamazsa Humanoid.MoveDirection kullanılır.
	-- (Burada beklersek diğer UI'lar hiç oluşmuyordu.)
	task.spawn(function()
		local playerScripts = player:WaitForChild("PlayerScripts", 10)
		local module = playerScripts and playerScripts:WaitForChild("PlayerModule", 10)
		if module then
			local ok, playerModule = pcall(require, module :: ModuleScript)
			if ok and playerModule then
				controls = playerModule:GetControls()
			end
		end
	end)

	build()

	remotes.ArenaQueue.OnClientEvent:Connect(function(payload)
		queueBar.Visible = payload.InQueue == true and current == nil
	end)
	remotes.ArenaMatchStarted.OnClientEvent:Connect(onMatchStarted)
	remotes.ArenaMatchEnded.OnClientEvent:Connect(onMatchEnded)
	remotes.ArenaFx.OnClientEvent:Connect(onFx)

	abilityButton.MouseButton1Click:Connect(useAbility)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonX then
			useAbility()
		end
	end)
end

return ArenaController
