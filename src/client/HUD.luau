-- Ekrandaki hurda sayacı, üretim hızı ve bildirimler.
-- Değerleri sunucunun oyuncuya yazdığı attribute'lardan okur (Scrap, Rate, Stored, Capacity).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Util = require(ReplicatedStorage.Shared.Util)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

local player = Players.LocalPlayer

local HUD = {}

local KIND_COLORS = {
	info = Color3.fromRGB(52, 152, 219),
	success = Color3.fromRGB(46, 204, 113),
	error = Color3.fromRGB(231, 76, 60),
}

local screen: ScreenGui
local scrapLabel: TextLabel
local rateLabel: TextLabel
local toastHolder: Frame
local boostLabel: TextLabel

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function build()
	screen = Instance.new("ScreenGui")
	screen.Name = "HUD"
	screen.ResetOnSpawn = false
	screen.IgnoreGuiInset = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	-- Üst ortada hurda paneli
	local panel = Instance.new("Frame")
	panel.Name = "ScrapPanel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 10)
	panel.Size = UDim2.fromOffset(260, 70)
	panel.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	panel.BackgroundTransparency = 0.15
	panel.Parent = screen
	corner(panel, 12)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(241, 196, 15)
	stroke.Thickness = 2
	stroke.Parent = panel

	scrapLabel = Instance.new("TextLabel")
	scrapLabel.Name = "Scrap"
	scrapLabel.BackgroundTransparency = 1
	scrapLabel.Position = UDim2.fromOffset(12, 6)
	scrapLabel.Size = UDim2.new(1, -24, 0, 36)
	scrapLabel.Font = Enum.Font.GothamBlack
	scrapLabel.TextScaled = true
	scrapLabel.TextColor3 = Color3.fromRGB(241, 196, 15)
	scrapLabel.Text = "Hurda: 0"
	scrapLabel.Parent = panel

	rateLabel = Instance.new("TextLabel")
	rateLabel.Name = "Rate"
	rateLabel.BackgroundTransparency = 1
	rateLabel.Position = UDim2.fromOffset(12, 44)
	rateLabel.Size = UDim2.new(1, -24, 0, 20)
	rateLabel.Font = Enum.Font.GothamMedium
	rateLabel.TextScaled = true
	rateLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	rateLabel.Text = "+0/sn"
	rateLabel.Parent = panel

	-- 3x Boost göstergesi (panelin altında)
	boostLabel = Instance.new("TextLabel")
	boostLabel.Name = "Boost"
	boostLabel.AnchorPoint = Vector2.new(0.5, 0)
	boostLabel.Position = UDim2.new(0.5, 0, 0, 86)
	boostLabel.Size = UDim2.fromOffset(200, 26)
	boostLabel.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
	boostLabel.TextColor3 = Color3.new(1, 1, 1)
	boostLabel.Font = Enum.Font.GothamBlack
	boostLabel.TextScaled = true
	boostLabel.Visible = false
	boostLabel.Parent = screen
	corner(boostLabel, 8)

	-- Bildirimler: sağ alt köşede üst üste
	toastHolder = Instance.new("Frame")
	toastHolder.Name = "Toasts"
	toastHolder.AnchorPoint = Vector2.new(1, 1)
	toastHolder.Position = UDim2.new(1, -16, 1, -16)
	toastHolder.Size = UDim2.fromOffset(320, 300)
	toastHolder.BackgroundTransparency = 1
	toastHolder.Parent = screen

	local layout = Instance.new("UIListLayout")
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = toastHolder

	screen.Parent = player:WaitForChild("PlayerGui")
end

local toastCount = 0
function HUD.Toast(text: string, kind: string?)
	toastCount += 1
	local toast = Instance.new("TextLabel")
	toast.LayoutOrder = toastCount
	toast.Size = UDim2.fromOffset(320, 44)
	toast.BackgroundColor3 = KIND_COLORS[kind or "info"] or KIND_COLORS.info
	toast.BackgroundTransparency = 0.1
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Font = Enum.Font.GothamBold
	toast.TextScaled = true
	toast.Text = text
	toast.Parent = toastHolder
	corner(toast, 10)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 6)
	padding.Parent = toast

	task.delay(3, function()
		local tween = TweenService:Create(toast, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		toast:Destroy()
	end)
end

local displayedScrap = 0
local function refresh()
	local scrap = player:GetAttribute("Scrap") or 0
	local rate = player:GetAttribute("Rate") or 0

	-- Sayı yukarı doğru "sayarak" artsın
	local from = displayedScrap
	displayedScrap = scrap
	if scrap > from and scrap - from < 1e12 then
		local steps = 10
		task.spawn(function()
			for i = 1, steps do
				if displayedScrap ~= scrap then
					return -- daha yeni bir değer geldi
				end
				scrapLabel.Text = "Hurda: " .. Util.FormatNumber(from + (scrap - from) * i / steps)
				task.wait(0.02)
			end
		end)
	else
		scrapLabel.Text = "Hurda: " .. Util.FormatNumber(scrap)
	end

	rateLabel.Text = string.format("+%s/sn", Util.FormatNumber(rate))
end

function HUD.Init()
	build()

	player:GetAttributeChangedSignal("Scrap"):Connect(refresh)
	player:GetAttributeChangedSignal("Rate"):Connect(refresh)
	refresh()

	Remotes.Event("Notify").OnClientEvent:Connect(function(payload)
		HUD.Toast(payload.Text, payload.Kind)
	end)

	-- Boost geri sayımı
	task.spawn(function()
		while true do
			local left = (player:GetAttribute("BoostUntil") or 0) - os.time()
			boostLabel.Visible = left > 0
			if left > 0 then
				boostLabel.Text = string.format("3x BOOST %d:%02d", left // 60, left % 60)
			end
			task.wait(1)
		end
	end)

	-- Notify, client hazır olmadan gönderilmiş olabilir: çevrimdışı kazancı attribute'tan da göster
	local offline = player:GetAttribute("OfflineEarned")
	if offline and offline > 0 then
		HUD.Toast(`Sen yokken fabrikan {Util.FormatNumber(offline)} hurda üretti!`, "success")
	end
end

return HUD
