-- Mağaza (Robux): Game Pass'ler ve Developer Product'lar. Bir de sunucunun doğal anlarda
-- gönderdiği küçük teklif kartı (kutu doldu, maç kaybedildi, ...).
-- ID'si 0 olan ürünler "Yakında" görünür ve satın alınamaz.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductsConfig = require(ReplicatedStorage.Shared.Config.Products)
local GamePasses = require(ReplicatedStorage.Shared.Config.GamePasses)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UIKit = require(script.Parent.UIKit)
local SideMenu = require(script.Parent.SideMenu)

local player = Players.LocalPlayer
local C = UIKit.Colors
local Products = ProductsConfig.Products

local ShopUI = {}

local panel: Frame
local passCards: { [string]: { Button: TextButton, Price: TextLabel } } = {}
local offerCard: Frame
local offerText: TextLabel
local offerBuy: TextButton
local currentOffer = nil

---------------------------------------------------------------- satın alma

local function passId(key: string): number
	return GamePasses[key] or 0
end

local function productId(key: string): number
	return Products[key] and Products[key].Id or 0
end

local function prompt(kind: string, key: string)
	local id = if kind == "pass" then passId(key) else productId(key)
	if id == 0 then
		return
	end
	if kind == "pass" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
end

-- Gerçek Robux fiyatını Roblox'tan çek (ID yoksa config'teki tahmin)
local function fetchPrice(kind: string, key: string, fallback: number, label: TextLabel)
	local id = if kind == "pass" then passId(key) else productId(key)
	if id == 0 then
		label.Text = "Yakında"
		return
	end
	label.Text = `R$ {fallback}`
	task.spawn(function()
		local infoType = if kind == "pass" then Enum.InfoType.GamePass else Enum.InfoType.Product
		local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, id, infoType)
		if ok and info and info.PriceInRobux then
			label.Text = `R$ {info.PriceInRobux}`
		end
	end)
end

local function refreshOwnedPasses()
	for key, card in passCards do
		local id = passId(key)
		if id ~= 0 then
			task.spawn(function()
				local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
				if ok and owns then
					card.Button.Text = "Sende var"
					card.Button.BackgroundColor3 = C.Card
					card.Button.Active = false
					card.Button.AutoButtonColor = false
				end
			end)
		end
	end
end

---------------------------------------------------------------- arayüz

local function itemCard(parent: Instance, order: number, name: string, description: string, accent: Color3)
	local card = UIKit.Frame({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 64),
		Parent = parent,
	})
	UIKit.Corner(card, 8)
	UIKit.Label({
		Text = name,
		TextColor3 = accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 6),
		Size = UDim2.new(1, -140, 0, 24),
		Parent = card,
	})
	UIKit.Label({
		Text = description,
		Font = Enum.Font.GothamMedium,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(10, 34),
		Size = UDim2.new(1, -140, 0, 20),
		Parent = card,
	})
	local button = UIKit.Button({
		Text = "Satın Al",
		BackgroundColor3 = C.Good,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.fromOffset(110, 30),
		Parent = card,
	})
	local price = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamMedium,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 40),
		Size = UDim2.fromOffset(110, 18),
		Parent = card,
	})
	return button, price
end

local function column(parent: Instance, title: string, x: number): ScrollingFrame
	UIKit.Label({
		Text = title,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.new(x, 0, 0, 0),
		Size = UDim2.new(0.5, -8, 0, 26),
		Parent = parent,
	})
	local list = Instance.new("ScrollingFrame")
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Position = UDim2.new(x, 0, 0, 32)
	list.Size = UDim2.new(0.5, -8, 1, -32)
	list.ScrollBarThickness = 5
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 8)
	layout.Parent = list
	return list
end

local function build()
	local content
	panel, content = SideMenu.CreatePanel("MAĞAZA", Vector2.new(760, 460), C.Good)

	local passList = column(content, "Kalıcı (Game Pass)", 0)
	for i, key in ProductsConfig.PassOrder do
		local info = ProductsConfig.PassInfo[key]
		local button, price = itemCard(passList, i, info.Name, info.Description, C.Accent)
		passCards[key] = { Button = button, Price = price }
		fetchPrice("pass", key, info.Price, price)
		button.MouseButton1Click:Connect(function()
			prompt("pass", key)
		end)
	end

	local productList = column(content, "Tek seferlik", 0.5)
	for i, key in ProductsConfig.ProductOrder do
		local product = Products[key]
		local button, price = itemCard(productList, i, product.Name, product.Description, C.Blue)
		fetchPrice("product", key, product.Price, price)
		button.MouseButton1Click:Connect(function()
			prompt("product", key)
		end)
	end

	-- Teklif kartı (sağ üst)
	local screen = SideMenu.GetScreen()
	offerCard = UIKit.Frame({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 96),
		Size = UDim2.fromOffset(300, 130),
		BackgroundColor3 = C.Panel,
		Visible = false,
		Parent = screen,
	})
	UIKit.Corner(offerCard, 12)
	UIKit.Stroke(offerCard, C.Good, 2)
	offerText = UIKit.Label({
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextScaled = false,
		TextSize = 17,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(1, -24, 0, 64),
		Parent = offerCard,
	})
	offerBuy = UIKit.Button({
		Text = "Göz at",
		BackgroundColor3 = C.Good,
		Position = UDim2.new(0, 12, 1, -46),
		Size = UDim2.new(0.6, -18, 0, 36),
		Parent = offerCard,
	})
	local dismiss = UIKit.Button({
		Text = "Sonra",
		BackgroundColor3 = C.Card,
		Position = UDim2.new(0.6, 0, 1, -46),
		Size = UDim2.new(0.4, -12, 0, 36),
		Parent = offerCard,
	})
	offerBuy.MouseButton1Click:Connect(function()
		if currentOffer then
			prompt(currentOffer.Kind, currentOffer.Key)
		end
		offerCard.Visible = false
	end)
	dismiss.MouseButton1Click:Connect(function()
		offerCard.Visible = false
	end)
end

local function showOffer(payload)
	currentOffer = payload
	offerText.Text = payload.Text
	offerCard.Visible = true
	task.delay(12, function()
		if currentOffer == payload then
			offerCard.Visible = false
		end
	end)
end

function ShopUI.Init()
	build()
	SideMenu.AddButton("MAĞAZA", C.Good, 2, function()
		if SideMenu.Toggle(panel) then
			refreshOwnedPasses()
		end
	end)
	Remotes.Event("Offer").OnClientEvent:Connect(showOffer)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, _, purchased)
		if who == player and purchased then
			refreshOwnedPasses()
		end
	end)
end

return ShopUI
