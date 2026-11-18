-- Garaj ekranı: takılı parçalar, robot statları, envanter, kasa açma, takma ve birleştirme.
-- "GARAJ" butonu ya da G tuşu ile açılır.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Crates = require(ReplicatedStorage.Shared.Config.Crates)
local Items = require(ReplicatedStorage.Shared.Items)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local C = UIKit.Colors

local GarageUI = {}

local snapshot = nil -- sunucudan gelen son envanter
local selectedKey: string? = nil
local busy = false

local panel: Frame
local slotLabels: { [string]: TextLabel } = {}
local statsLabels: { [string]: TextLabel } = {}
local pityLabel: TextLabel
local grid: ScrollingFrame
local selectedLabel: TextLabel
local equipButton: TextButton
local fuseButton: TextButton
local swapButton: TextButton

---------------------------------------------------------------- çizim

local function renderSlots()
	for _, slot in Parts.Slots do
		local item = snapshot and snapshot.Equipped[slot]
		local label = slotLabels[slot]
		if item then
			label.Text = Items.DisplayName(item.PartId, item.Rarity)
			label.TextColor3 = Rarities.ById[item.Rarity].Color
		else
			label.Text = "Boş"
			label.TextColor3 = C.Muted
		end
	end
end

local function renderStats()
	local stats = snapshot and snapshot.Stats
	if not stats then
		return
	end
	statsLabels.Power.Text = `Güç: {stats.Power}`
	statsLabels.HP.Text = `Can: {stats.HP}`
	statsLabels.Damage.Text = `Hasar: {stats.Damage}`
	statsLabels.Speed.Text = `Hız: {stats.Speed}`
	statsLabels.Weight.Text = `Ağırlık: {stats.Weight} / {stats.Capacity}` .. (if stats.Overweight then "  (AĞIR!)" else "")
	statsLabels.Weight.TextColor3 = if stats.Overweight then C.Bad else C.Text

	local crate = Crates.Basic
	local left = crate.PityThreshold - (snapshot.SincePity or 0)
	pityLabel.Text = `Garanti Legendary+: {left} kasa sonra`
end

local function sortedItems()
	local list = {}
	if not snapshot then
		return list
	end
	local slotOrder = {}
	for i, slot in Parts.Slots do
		slotOrder[slot] = i
	end
	for key, count in snapshot.Inventory do
		local partId, rarityId = Items.Parse(key)
		if partId and rarityId then
			table.insert(list, { Key = key, PartId = partId, Rarity = rarityId, Count = count })
		end
	end
	table.sort(list, function(a, b)
		local ra, rb = Rarities.ById[a.Rarity].Index, Rarities.ById[b.Rarity].Index
		if ra ~= rb then
			return ra > rb -- en nadir önce
		end
		local sa, sb = slotOrder[Parts.ById[a.PartId].Slot], slotOrder[Parts.ById[b.PartId].Slot]
		if sa ~= sb then
			return sa < sb
		end
		return a.PartId < b.PartId
	end)
	return list
end

local renderActions -- ileri bildirim

local function renderGrid()
	for _, child in grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end

	local items = sortedItems()
	if selectedKey and not (snapshot and snapshot.Inventory[selectedKey]) then
		selectedKey = nil
	end

	for i, item in items do
		local rarity = Rarities.ById[item.Rarity]
		local part = Parts.ById[item.PartId]

		local card = Instance.new("TextButton")
		card.Name = item.Key
		card.LayoutOrder = i
		card.Text = ""
		card.AutoButtonColor = true
		card.BackgroundColor3 = if item.Key == selectedKey then C.CardHover else C.Card
		UIKit.Corner(card, 8)
		UIKit.Stroke(card, rarity.Color, if item.Key == selectedKey then 3 else 1.5)

		UIKit.Label({
			Text = part.Name,
			Position = UDim2.fromOffset(6, 6),
			Size = UDim2.new(1, -12, 0, 22),
			Parent = card,
		})
		UIKit.Label({
			Text = `{Parts.SlotNames[part.Slot]} · {item.Rarity}`,
			TextColor3 = rarity.Color,
			Font = Enum.Font.GothamMedium,
			Position = UDim2.fromOffset(6, 32),
			Size = UDim2.new(1, -12, 0, 16),
			Parent = card,
		})
		UIKit.Label({
			Text = `x{item.Count}`,
			TextColor3 = if item.Count >= 3 then C.Good else C.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
			Position = UDim2.new(0, 6, 1, -26),
			Size = UDim2.new(1, -12, 0, 20),
			Parent = card,
		})

		card.MouseButton1Click:Connect(function()
			selectedKey = item.Key
			renderGrid()
			renderActions()
		end)
		card.Parent = grid
	end
end

renderActions = function()
	if not selectedKey or not snapshot then
		selectedLabel.Text = "Bir parça seç"
		selectedLabel.TextColor3 = C.Muted
		equipButton.Visible = false
		fuseButton.Visible = false
		return
	end
	local partId, rarityId = Items.Parse(selectedKey)
	if not partId or not rarityId then
		return
	end
	local count = snapshot.Inventory[selectedKey] or 0
	selectedLabel.Text = Items.DisplayName(partId, rarityId)
	selectedLabel.TextColor3 = Rarities.ById[rarityId].Color

	equipButton.Visible = true
	local nextRarity = Rarities.Next(rarityId)
	fuseButton.Visible = nextRarity ~= nil
	fuseButton.Text = if nextRarity then `Birleştir 3→1 ({count}/3)` else ""
	fuseButton.BackgroundColor3 = if count >= 3 then C.Good else C.Card
end

local function renderAll()
	if snapshot then
		swapButton.Visible = snapshot.HasExtraGarage == true
		swapButton.Text = `Garaj {snapshot.ActiveGarage or 1} ⇄ {if snapshot.ActiveGarage == 2 then 1 else 2}`
	end
	renderSlots()
	renderStats()
	renderGrid()
	renderActions()
end

---------------------------------------------------------------- sunucu çağrıları

local function invoke(remoteName: string, arg)
	if busy then
		return
	end
	busy = true
	local ok, err = pcall(function()
		Remotes.Function(remoteName):InvokeServer(arg)
	end)
	if not ok then
		warn(`[GarageUI] {remoteName} hatası: {err}`)
	end
	busy = false
end

---------------------------------------------------------------- kurulum

local function buildSlotCard(parent: Instance, slot: string, index: number)
	local card = UIKit.Frame({
		Position = UDim2.fromOffset(0, (index - 1) * 62),
		Size = UDim2.new(1, 0, 0, 54),
		Parent = parent,
	})
	UIKit.Corner(card, 8)
	UIKit.Label({
		Text = Parts.SlotNames[slot],
		TextColor3 = C.Muted,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 4),
		Size = UDim2.new(1, -20, 0, 16),
		Parent = card,
	})
	slotLabels[slot] = UIKit.Label({
		Text = "-",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -20, 0, 26),
		Parent = card,
	})
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "Garage"
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Ana panel
	panel = UIKit.Frame({
		Name = "Panel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(740, 470),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screen,
	})
	UIKit.Corner(panel, 14)
	UIKit.Stroke(panel, C.Accent, 2)
	UIKit.AutoScale(panel, 800)

	UIKit.Label({
		Text = "GARAJ",
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(16, 10),
		Size = UDim2.fromOffset(200, 34),
		Parent = panel,
	})
	local close = UIKit.Button({
		Text = "X",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.fromOffset(36, 36),
		BackgroundColor3 = C.Bad,
		Parent = panel,
	})

	-- Sol sütun: slotlar + statlar
	local left = UIKit.Frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.fromOffset(300, 400),
		Parent = panel,
	})
	for i, slot in Parts.Slots do
		buildSlotCard(left, slot, i)
	end

	local statsCard = UIKit.Frame({
		Position = UDim2.fromOffset(0, 4 * 62),
		Size = UDim2.new(1, 0, 0, 150),
		Parent = left,
	})
	UIKit.Corner(statsCard, 8)
	statsLabels.Power = UIKit.Label({
		Text = "Güç: -",
		Font = Enum.Font.GothamBlack,
		TextColor3 = C.Accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -20, 0, 30),
		Parent = statsCard,
	})
	for i, name in { "HP", "Damage", "Speed", "Weight" } do
		statsLabels[name] = UIKit.Label({
			Text = "-",
			Font = Enum.Font.GothamMedium,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(10, 40 + (i - 1) * 26),
			Size = UDim2.new(1, -20, 0, 22),
			Parent = statsCard,
		})
	end

	-- Sağ sütun: kasa + envanter + aksiyonlar
	local right = UIKit.Frame({
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(332, 56),
		Size = UDim2.fromOffset(392, 400),
		Parent = panel,
	})

	local crate = Crates.Basic
	local crateButton = UIKit.Button({
		Text = `{crate.Name} Aç · {crate.Cost} Hurda`,
		BackgroundColor3 = Color3.fromRGB(142, 68, 173),
		Size = UDim2.new(1, 0, 0, 44),
		Parent = right,
	})
	pityLabel = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.Muted,
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = right,
	})

	grid = Instance.new("ScrollingFrame")
	grid.Name = "Inventory"
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Position = UDim2.fromOffset(0, 74)
	grid.Size = UDim2.new(1, 0, 0, 252)
	grid.ScrollBarThickness = 6
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = right
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(122, 84)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid

	local actionBar = UIKit.Frame({
		Position = UDim2.fromOffset(0, 336),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = right,
	})
	UIKit.Corner(actionBar, 8)
	selectedLabel = UIKit.Label({
		Text = "Bir parça seç",
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.fromOffset(150, 40),
		Parent = actionBar,
	})
	equipButton = UIKit.Button({
		Text = "Tak",
		BackgroundColor3 = C.Blue,
		Position = UDim2.fromOffset(166, 8),
		Size = UDim2.fromOffset(70, 40),
		Visible = false,
		Parent = actionBar,
	})
	fuseButton = UIKit.Button({
		Text = "Birleştir",
		Position = UDim2.fromOffset(244, 8),
		Size = UDim2.fromOffset(140, 40),
		Visible = false,
		Parent = actionBar,
	})

	-- Ekstra Garaj: iki robot arasında geçiş (pass varsa görünür)
	swapButton = UIKit.Button({
		Text = "Garaj 1 ⇄ 2",
		BackgroundColor3 = C.Blue,
		Position = UDim2.fromOffset(150, 12),
		Size = UDim2.fromOffset(150, 32),
		Visible = false,
		Parent = panel,
	})
	swapButton.MouseButton1Click:Connect(function()
		invoke("SwapLoadout", nil)
	end)

	-- Bağlantılar
	SideMenu.Register(panel)
	local function toggleOpen()
		if SideMenu.Toggle(panel) then
			renderAll()
		end
	end
	SideMenu.AddButton("GARAJ (G)", C.Accent, 1, toggleOpen)
	close.MouseButton1Click:Connect(function()
		SideMenu.Toggle(panel, false)
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.G then
			toggleOpen()
		end
	end)

	crateButton.MouseButton1Click:Connect(function()
		invoke("OpenCrate", crate.Id)
	end)
	equipButton.MouseButton1Click:Connect(function()
		if selectedKey then
			invoke("EquipPart", selectedKey)
		end
	end)
	fuseButton.MouseButton1Click:Connect(function()
		if selectedKey then
			invoke("FusePart", selectedKey)
		end
	end)

	screen.Parent = player:WaitForChild("PlayerGui")
end

function GarageUI.Init()
	build()

	Remotes.Event("InventoryUpdated").OnClientEvent:Connect(function(newSnapshot)
		snapshot = newSnapshot
		if panel.Visible then
			renderAll()
		end
	end)

	-- İlk yükleme: sunucu veriyi henüz yüklemediyse birkaç kez dene
	task.spawn(function()
		for _ = 1, 30 do
			if snapshot then
				break
			end
			local ok, result = pcall(function()
				return Remotes.Function("GetInventory"):InvokeServer()
			end)
			if ok and result and not snapshot then
				snapshot = result
				break
			end
			task.wait(1)
		end
	end)
end

return GarageUI
