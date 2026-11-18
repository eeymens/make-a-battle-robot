-- Robux satın alımları (Developer Product) ve doğal anlarda gösterilen teklifler.
--
-- ProcessReceipt kuralları (Roblox'un önerdiği gibi):
--   * Aynı PurchaseId iki kez verilmez (PurchaseHistory'de tutulur)
--   * Ürün verildikten sonra veri HEMEN kaydedilir; kayıt başarılı olmadan "Granted" dönülmez
--   * Oyuncu/veri hazır değilse NotYetProcessed: Roblox sonra tekrar dener
-- Game Pass satın alımları TycoonService.onPassPurchased'da işlenir.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProductsConfig = require(ReplicatedStorage.Shared.Config.Products)
local GamePasses = require(ReplicatedStorage.Shared.Config.GamePasses)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local Events = require(script.Parent.Events)

local Products = ProductsConfig.Products

local MonetizationService = {}

local DataService
local TycoonService
local PartService
local ArenaService
local offerEvent: RemoteEvent

local MAX_HISTORY = 100
local OFFER_COOLDOWN = 180 -- aynı oyuncuya 3 dakikada en fazla 1 teklif
local lastOfferAt: { [Player]: number } = {}

---------------------------------------------------------------- ürünleri verme

local function scrapPackAmount(player: Player, product): number
	local rate = TycoonService.GetRate(player)
	return math.floor(math.max(product.Minimum, rate * product.ProductionSeconds))
end

local GRANTERS = {
	SmallScrap = function(player: Player, _data)
		local amount = scrapPackAmount(player, Products.SmallScrap)
		TycoonService.GiveScrap(player, amount)
		TycoonService.Notify(player, `+{Util.FormatNumber(amount)} hurda!`, "success")
	end,
	BigScrap = function(player: Player, _data)
		local amount = scrapPackAmount(player, Products.BigScrap)
		TycoonService.GiveScrap(player, amount)
		TycoonService.Notify(player, `+{Util.FormatNumber(amount)} hurda!`, "success")
	end,
	MegaCrate = function(player: Player, _data)
		PartService.GiveCrate(player, "Mega")
	end,
	Boost = function(player: Player, data)
		-- Üst üste alınırsa süre eklenir
		data.BoostUntil = math.max(os.time(), data.BoostUntil or 0) + Products.Boost.Duration
		TycoonService.Refresh(player)
		TycoonService.Notify(player, "3x Boost aktif!", "success")
	end,
	Repair = function(player: Player, _data)
		if not ArenaService.Repair(player) then
			-- Maç yoksa Robux boşa gitmesin: karşılığında hurda
			local amount = scrapPackAmount(player, Products.SmallScrap)
			TycoonService.GiveScrap(player, amount)
			TycoonService.Notify(player, `Aktif maç yoktu, karşılığında +{Util.FormatNumber(amount)} hurda verildi.`, "info")
		end
	end,
}

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and DataService.Get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotYetProcessed
	end

	local history = data.PurchaseHistory
	if table.find(history, receipt.PurchaseId) then
		-- Daha önce verildi (kayıt sonrası tekrar çağrı)
		return if DataService.SaveNow(player) or DataService.IsMemoryOnly()
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotYetProcessed
	end

	local key = ProductsConfig.FindByProductId(receipt.ProductId)
	local granter = key and GRANTERS[key]
	if not granter then
		warn(`[Monetization] Bilinmeyen ürün ID: {receipt.ProductId}`)
		return Enum.ProductPurchaseDecision.NotYetProcessed
	end

	local ok, err = pcall(granter, player, data)
	if not ok then
		warn(`[Monetization] {key} verilemedi: {err}`)
		return Enum.ProductPurchaseDecision.NotYetProcessed
	end

	table.insert(history, receipt.PurchaseId)
	while #history > MAX_HISTORY do
		table.remove(history, 1)
	end
	Events.Fire("Purchase", player, receipt.CurrencySpent or 0)

	if DataService.SaveNow(player) or DataService.IsMemoryOnly() then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	-- Kayıt başarısız: Roblox tekrar dener, PurchaseHistory sayesinde ikinci kez verilmez
	return Enum.ProductPurchaseDecision.NotYetProcessed
end

---------------------------------------------------------------- teklifler

-- kind: "product" | "pass", key: Products / GamePasses anahtarı
local function offer(player: Player, kind: string, key: string, text: string)
	local id = if kind == "product" then Products[key] and Products[key].Id else GamePasses[key]
	if not id or id == 0 then
		return -- ID girilmemiş ürün teklif edilmez
	end
	if kind == "pass" and TycoonService.HasPass(player, key) then
		return
	end
	local now = os.clock()
	if now - (lastOfferAt[player] or -math.huge) < OFFER_COOLDOWN then
		return
	end
	lastOfferAt[player] = now
	offerEvent:FireClient(player, { Kind = kind, Key = key, Text = text })
end

local function connectOffers()
	Events.Connect("LoseMatch", function(player)
		offer(player, "product", "Boost", "Biraz güç lazım mı? 15 dk 3x hurdayla robotunu hızlıca geliştir.")
	end)
	Events.Connect("CrateBlocked", function(player)
		offer(player, "product", "SmallScrap", "Kasaya az kaldı! Küçük Hurda Paketi ile hemen aç.")
	end)
	Events.Connect("BoxFull", function(player)
		offer(player, "pass", "AutoCollect", "Kutun doldu! Otomatik Toplama ile hurda direkt cebine gelsin.")
	end)
	Events.Connect("Rebirth", function(player)
		offer(player, "pass", "DoubleScrap", "Yeni başlangıç! 2x Hurda ile fabrikanı iki kat hızlı büyüt.")
	end)
end

---------------------------------------------------------------- başlatma

function MonetizationService.Init(dataService, tycoonService, partService, arenaService)
	DataService = dataService
	TycoonService = tycoonService
	PartService = partService
	ArenaService = arenaService
	offerEvent = Remotes.Event("Offer")

	MarketplaceService.ProcessReceipt = processReceipt
	connectOffers()

	Players.PlayerRemoving:Connect(function(player)
		lastOfferAt[player] = nil
	end)
end

return MonetizationService
