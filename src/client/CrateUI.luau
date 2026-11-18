-- Kasa açılış animasyonu: isimler hızla döner, yavaşlar, sonuçta durur.
-- Sonuç önceden sunucuda belirlenir; bu ekran sadece gösterir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Parts = require(ReplicatedStorage.Shared.Config.Parts)
local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)

local player = Players.LocalPlayer
local C = UIKit.Colors

local CrateUI = {}

local overlay: Frame
local card: Frame
local nameLabel: TextLabel
local rarityLabel: TextLabel
local stroke: UIStroke
local queue = {}
local playing = false

local function randomRarity(): string
	-- Animasyonda gerçek olasılıklara yakın görünsün diye ağırlıklı seç
	local roll = math.random() * 100
	for _, rarityId in Rarities.Ordered do
		roll -= Rarities.ById[rarityId].Weight
		if roll <= 0 then
			return rarityId
		end
	end
	return "Common"
end

local function show(partId: string, rarityId: string)
	local steps = 22
	overlay.Visible = true
	card.Size = UDim2.fromOffset(380, 200)

	for i = 1, steps do
		local fakePart = Parts.List[math.random(#Parts.List)]
		local fakeRarity = randomRarity()
		nameLabel.Text = fakePart.Name
		rarityLabel.Text = fakeRarity
		rarityLabel.TextColor3 = Rarities.ById[fakeRarity].Color
		stroke.Color = Rarities.ById[fakeRarity].Color
		task.wait(0.03 + (i / steps) ^ 3 * 0.25) -- giderek yavaşla
	end

	local rarity = Rarities.ById[rarityId]
	nameLabel.Text = Parts.ById[partId].Name
	rarityLabel.Text = rarityId .. (if rarity.Index >= Rarities.HighTierIndex then " !!!" else "")
	rarityLabel.TextColor3 = rarity.Color
	stroke.Color = rarity.Color

	-- Küçük "pop" efekti
	card.Size = UDim2.fromOffset(340, 180)
	TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Size = UDim2.fromOffset(380, 200) }):Play()

	task.wait(if rarity.Index >= Rarities.HighTierIndex then 2.5 else 1.4)
	overlay.Visible = false
end

local function processQueue()
	if playing then
		return
	end
	playing = true
	while #queue > 0 do
		local result = table.remove(queue, 1)
		show(result.PartId, result.Rarity)
	end
	playing = false
end

local function build()
	local screen = Instance.new("ScreenGui")
	screen.Name = "CrateOpening"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 10

	overlay = UIKit.Frame({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Visible = false,
		Parent = screen,
	})

	card = UIKit.Frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 200),
		BackgroundColor3 = C.Panel,
		Parent = overlay,
	})
	UIKit.Corner(card, 14)
	stroke = UIKit.Stroke(card, C.Muted, 4)
	UIKit.AutoScale(card, 500)

	UIKit.Label({
		Text = "KASA AÇILIYOR",
		TextColor3 = C.Muted,
		Font = Enum.Font.GothamMedium,
		Position = UDim2.new(0, 16, 0, 14),
		Size = UDim2.new(1, -32, 0, 22),
		Parent = card,
	})
	nameLabel = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(0, 16, 0, 50),
		Size = UDim2.new(1, -32, 0, 60),
		Parent = card,
	})
	rarityLabel = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamBlack,
		Position = UDim2.new(0, 16, 0, 120),
		Size = UDim2.new(1, -32, 0, 44),
		Parent = card,
	})

	screen.Parent = player:WaitForChild("PlayerGui")
end

function CrateUI.Init()
	build()
	Remotes.Event("CrateOpened").OnClientEvent:Connect(function(result)
		table.insert(queue, result)
		task.spawn(processQueue)
	end)
end

return CrateUI
