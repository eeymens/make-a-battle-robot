-- Arena platformlarını, arena kapısını ve kupa tablosunu kodla oluşturur.
-- Arenalar fabrikalardan uzakta (z=420), havada durur: kenardan düşen robot yere çakılır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Arena = require(ReplicatedStorage.Shared.Config.Arena)
local PlotBuilder = require(script.Parent.PlotBuilder)

local ArenaBuilder = {}

local function makePart(props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- Arena merkezinin (platform üst yüzeyi) dünya konumu
ArenaBuilder.GetCenter = Arena.GetCenter

local function buildArena(index: number, parent: Instance)
	local center = ArenaBuilder.GetCenter(index)
	local model = Instance.new("Model")
	model.Name = "Arena" .. index

	-- Silindirin ekseni X: Z'de 90° döndürünce dik durur. Size.X = kalınlık.
	local floor = makePart({
		Name = "Floor",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, Arena.Radius * 2, Arena.Radius * 2),
		CFrame = CFrame.new(center - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(70, 74, 82),
		Material = Enum.Material.DiamondPlate,
	})
	floor.Parent = model

	-- Kenarda tehlike şeridi
	local edge = makePart({
		Name = "Edge",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.8, Arena.Radius * 2 + 2, Arena.Radius * 2 + 2),
		CFrame = CFrame.new(center - Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		Color = Color3.fromRGB(231, 76, 60),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	edge.Parent = model

	-- Seyirci platformu (arenanın arkasında, yüksekte): oyuncunun karakteri burada bekler
	local stand = makePart({
		Name = "SpectatorStand",
		Size = Vector3.new(30, 1, 8),
		CFrame = CFrame.new(center + Vector3.new(0, 14, Arena.Radius + 14)),
		Color = Color3.fromRGB(44, 62, 80),
		Material = Enum.Material.Metal,
	})
	stand.Parent = model
	for i, x in { -6, 6 } do
		local spot = makePart({
			Name = "Spot" .. i,
			Size = Vector3.new(3, 0.2, 3),
			CFrame = stand.CFrame * CFrame.new(x, 0.6, 0),
			Transparency = 1,
			CanCollide = false,
		})
		spot.Parent = model
	end

	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 16, -Arena.Radius - 4)),
		Transparency = 1,
		CanCollide = false,
	})
	sign.Parent = model
	PlotBuilder.MakeBillboard(sign, "ArenaGui", Vector2.new(260, 50), 0).Text = `ARENA {index}`

	model.Parent = parent
	return model
end

local function buildGate(parent: Instance)
	local gate = Instance.new("Model")
	gate.Name = "ArenaGate"

	for _, x in { -7, 7 } do
		makePart({
			Name = "Pillar",
			Size = Vector3.new(2, 14, 2),
			CFrame = CFrame.new(x, 7, 0),
			Color = Color3.fromRGB(44, 62, 80),
			Material = Enum.Material.Metal,
		}).Parent = gate
	end
	makePart({
		Name = "Top",
		Size = Vector3.new(16, 2, 2),
		CFrame = CFrame.new(0, 15, 0),
		Color = Color3.fromRGB(231, 76, 60),
		Material = Enum.Material.Neon,
	}).Parent = gate

	local pad = makePart({
		Name = "Pad",
		Size = Vector3.new(12, 0.6, 6),
		CFrame = CFrame.new(0, 0.3, 0),
		Color = Color3.fromRGB(231, 76, 60),
		Material = Enum.Material.Neon,
	})
	pad.Parent = gate
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "JoinPrompt"
	prompt.ActionText = "Arenaya Gir"
	prompt.ObjectText = "Robot Arenası"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	PlotBuilder.MakeBillboard(pad, "GateGui", Vector2.new(280, 60), 18).Text = "ROBOT ARENASI\n1v1 · Kupa kazan!"

	gate.Parent = parent
	return gate
end

local function buildLeaderboard(parent: Instance)
	local board = makePart({
		Name = "Leaderboard",
		Size = Vector3.new(16, 22, 1),
		-- Ön yüzü (-Z) 90° döndürünce -X'e, yani arena kapısına bakar
		CFrame = CFrame.new(28, 11, 0) * CFrame.Angles(0, math.rad(90), 0),
		Color = Color3.fromRGB(20, 22, 26),
		Material = Enum.Material.SmoothPlastic,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(400, 550)
	gui.LightInfluence = 0
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(241, 196, 15)
	title.Text = "EN ÇOK KUPA"
	title.Parent = gui

	local list = Instance.new("TextLabel")
	list.Name = "List"
	list.Position = UDim2.fromOffset(16, 70)
	list.Size = UDim2.new(1, -32, 1, -86)
	list.BackgroundTransparency = 1
	list.Font = Enum.Font.GothamMedium
	list.TextSize = 30
	list.TextXAlignment = Enum.TextXAlignment.Left
	list.TextYAlignment = Enum.TextYAlignment.Top
	list.TextColor3 = Color3.new(1, 1, 1)
	list.Text = "Yükleniyor..."
	list.Parent = gui

	board.Parent = parent
	return board
end

function ArenaBuilder.Build(): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Arenas"
	for index = 1, Arena.Count do
		buildArena(index, folder)
	end
	buildGate(folder)
	buildLeaderboard(folder)
	folder.Parent = Workspace
	return folder
end

return ArenaBuilder
