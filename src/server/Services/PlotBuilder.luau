-- Fabrika arsalarını kodla oluşturur. Studio'da elle harita yapılana kadar test için yeterli.
-- Sonra Eymen Workspace'e "Plots" klasörü içinde kendi modellerini koyarsa, TycoonService
-- onları kullanır (isimler aynı kaldığı sürece: Base, Collector, Conveyor, Box,
-- SpawnPoint, Sign, Pads/<UpgradeId>).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local PlotBuilder = {}

PlotBuilder.PlotCount = 6
PlotBuilder.PlotSize = 70

local COLORS = {
	Base = Color3.fromRGB(58, 62, 70),
	Collector = Color3.fromRGB(230, 126, 34),
	Conveyor = Color3.fromRGB(35, 37, 42),
	Box = Color3.fromRGB(241, 196, 15),
	Pad = Color3.fromRGB(46, 204, 113),
	Sign = Color3.fromRGB(44, 62, 80),
}

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

-- Parçanın üstünde yazı gösteren BillboardGui, TextLabel'ı döner
function PlotBuilder.MakeBillboard(parent: Instance, name: string, size: Vector2, offsetY: number): TextLabel
	local gui = Instance.new("BillboardGui")
	gui.Name = name
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = label

	gui.Parent = parent
	return label
end

local function makePrompt(parent: Instance, action: string, object: string): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = action
	prompt.ObjectText = object
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = parent
	return prompt
end

-- Arsa merkezlerinin dünya konumları: 2 sıra x 3, ön yüzleri ortadaki yola bakar
function PlotBuilder.GetPlotCFrame(index: number): CFrame
	local column = (index - 1) % 3 -- 0,1,2
	local row = if index <= 3 then -1 else 1
	local spacing = PlotBuilder.PlotSize + 10
	local position = Vector3.new((column - 1) * spacing, 0, row * (PlotBuilder.PlotSize / 2 + 20))
	-- LookVector (yerel -Z) z=0 çizgisine baksın
	return CFrame.lookAt(position, Vector3.new(position.X, 0, 0))
end

function PlotBuilder.Build(index: number, parent: Instance): Model
	local cf = PlotBuilder.GetPlotCFrame(index)
	local function at(x: number, y: number, z: number): CFrame
		return cf * CFrame.new(x, y, z)
	end

	local model = Instance.new("Model")
	model.Name = "Plot" .. index

	local size = PlotBuilder.PlotSize
	local base = makePart({
		Name = "Base",
		Size = Vector3.new(size, 1, size),
		CFrame = at(0, 0.5, 0),
		Color = COLORS.Base,
		Material = Enum.Material.DiamondPlate,
	})
	base.Parent = model

	-- Arka kenardaki tabela: sahibinin adı
	local sign = makePart({
		Name = "Sign",
		Size = Vector3.new(24, 6, 1),
		CFrame = at(0, 4, size / 2 - 2),
		Color = COLORS.Sign,
		Material = Enum.Material.Metal,
	})
	sign.Parent = model
	PlotBuilder.MakeBillboard(sign, "OwnerGui", Vector2.new(260, 60), 5).Text = "Boş Arsa"

	-- Hurda toplayıcı (arkada) -> konveyör -> toplama kutusu (önde)
	local collector = makePart({
		Name = "Collector",
		Size = Vector3.new(10, 8, 8),
		CFrame = at(0, 5, 22),
		Color = COLORS.Collector,
		Material = Enum.Material.Metal,
	})
	collector.Parent = model

	local conveyor = makePart({
		Name = "Conveyor",
		Size = Vector3.new(6, 1, 30),
		CFrame = at(0, 1.5, 2),
		Color = COLORS.Conveyor,
		Material = Enum.Material.Fabric,
	})
	conveyor.Parent = model

	local box = makePart({
		Name = "Box",
		Size = Vector3.new(10, 5, 8),
		CFrame = at(0, 3.5, -17),
		Color = COLORS.Box,
		Material = Enum.Material.Metal,
	})
	box.Parent = model
	makePrompt(box, "Topla", "Toplama Kutusu").Name = "CollectPrompt"
	PlotBuilder.MakeBillboard(box, "BoxGui", Vector2.new(220, 50), 5)

	local spawnPoint = makePart({
		Name = "SpawnPoint",
		Size = Vector3.new(4, 1, 4),
		CFrame = at(0, 1.5, -28),
		Transparency = 1,
		CanCollide = false,
	})
	spawnPoint.Parent = model

	-- Robotun sergilendiği kaide (sol arka)
	local stand = makePart({
		Name = "RobotStand",
		Size = Vector3.new(12, 1, 12),
		CFrame = at(-20, 1.5, 10),
		Color = Color3.fromRGB(40, 44, 52),
		Material = Enum.Material.Metal,
	})
	stand.Parent = model

	-- Kasa makinesi (sol ön): olasılıklar üstünde yazar
	local crate = Crates.Basic
	local machine = makePart({
		Name = "CrateMachine",
		Size = Vector3.new(7, 7, 7),
		CFrame = at(-22, 4.5, -17),
		Color = Color3.fromRGB(142, 68, 173),
		Material = Enum.Material.Metal,
	})
	machine.Parent = model
	makePrompt(machine, `Kasa Aç ({crate.Cost})`, crate.Name).Name = "CratePrompt"

	local odds = {}
	for _, rarityId in Rarities.Ordered do
		table.insert(odds, `{rarityId} %{Rarities.ById[rarityId].Weight}`)
	end
	PlotBuilder.MakeBillboard(machine, "CrateGui", Vector2.new(240, 90), 6).Text =
		`{crate.Name} - {crate.Cost} Hurda\n{table.concat(odds, " · ")}`

	-- Upgrade pedleri sağ kenarda sıralı
	local pads = Instance.new("Folder")
	pads.Name = "Pads"
	pads.Parent = model
	for i, upgrade in Upgrades.Ordered do
		local pad = makePart({
			Name = upgrade.Id,
			Size = Vector3.new(8, 0.6, 8),
			CFrame = at(24, 1.3, 22 - (i - 1) * 13),
			Color = COLORS.Pad,
			Material = Enum.Material.Neon,
		})
		pad.Parent = pads
		makePrompt(pad, "Satın Al", upgrade.Name).Name = "BuyPrompt"
		PlotBuilder.MakeBillboard(pad, "PadGui", Vector2.new(200, 70), 4)
	end

	model.PrimaryPart = base
	model.Parent = parent
	return model
end

return PlotBuilder
