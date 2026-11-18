-- Oyuncu verisini yükler ve kaydeder.
--
-- Session lock: aynı oyuncu iki sunucuya aynı anda girerse (örn. hızlı server değiştirme)
-- veri çakışmasın diye kayıtta hangi sunucunun veriyi "tuttuğu" yazılır. Başka sunucu
-- kilitliyse birkaç kez beklenir, en son denemede kilit devralınır.
--
-- Studio'da API erişimi kapalıysa DataStore çalışmaz; o zaman veri sadece bellekte tutulur
-- (oyun çalışır ama kayıt olmaz). Açmak için: Game Settings > Security >
-- "Enable Studio Access to API Services".

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Economy = require(ReplicatedStorage.Shared.Config.Economy)
local Util = require(ReplicatedStorage.Shared.Util)

local STORE_NAME = "PlayerData_v1"
local LOCK_TIMEOUT = 30 * 60 -- 30 dk güncellenmeyen kilit ölü sayılır
local MAX_LOAD_ATTEMPTS = 5
local MAX_SAVE_ATTEMPTS = 3

local TEMPLATE = {
	Version = 1,
	Scrap = 0,
	Stored = 0, -- toplama kutusunda bekleyen hurda
	Rebirths = 0,
	RebirthTokens = 0,
	Upgrades = {}, -- upgradeId -> seviye
	Inventory = {}, -- "PartId|Rarity" -> adet (takılı olanlar burada sayılmaz)
	Equipped = {}, -- slot -> { PartId, Rarity }
	CrateStats = {
		Opened = 0,
		SincePity = 0, -- son Legendary+'tan beri açılan kasa
	},
	Trophies = 0, -- Aşama 3
	TokenUpgrades = {}, -- rebirth token ağacı: nodeId -> seviye
	SecondLoadout = {}, -- Ekstra Garaj pass'i: 2. robotun parçaları (slot -> item)
	ActiveGarage = 1,
	BoostUntil = 0, -- 3x boost bitiş zamanı (os.time)
	Daily = {
		LastClaimDay = 0,
		Streak = 0,
		LastVipCrateDay = 0,
		QuestDay = 0,
		Quests = {}, -- { Type, Target, Progress, Claimed }
	},
	LastOnline = 0,
	PurchaseHistory = {}, -- işlenmiş receipt PurchaseId'leri (son 100)
	Stats = {
		TotalScrap = 0,
		PlayTime = 0,
		Wins = 0,
		Losses = 0,
	},
}

local DataService = {}

-- Not: BindableEvent tabloları kopyaladığı için burada düz callback listesi kullanıyoruz;
-- dinleyiciler oyuncunun GERÇEK veri tablosunu alır ve değişiklikler kayda girer.
local loadedCallbacks: { (Player, any) -> () } = {}
local releasingCallbacks: { (Player, any) -> () } = {}

-- callback(player, data): veri yüklenince
function DataService.OnLoaded(callback: (Player, any) -> ())
	table.insert(loadedCallbacks, callback)
end

-- callback(player, data): oyuncu çıkarken, son kayıttan hemen önce
function DataService.OnReleasing(callback: (Player, any) -> ())
	table.insert(releasingCallbacks, callback)
end

local function fire(callbacks, player: Player, data)
	for _, callback in callbacks do
		local ok, err = pcall(callback, player, data)
		if not ok then
			warn("[DataService] callback hatası: " .. tostring(err))
		end
	end
end

local store: DataStore? = nil
local memoryOnly = false
local profiles: { [Player]: any } = {}

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function loadData(player: Player)
	if memoryOnly then
		return Util.DeepCopy(TEMPLATE)
	end

	local key = keyFor(player)
	for attempt = 1, MAX_LOAD_ATTEMPTS do
		local lockedByOther = false
		local loaded = nil

		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				old = old or {}
				local lock = old.Lock
				local lockAlive = lock ~= nil
					and lock.JobId ~= game.JobId
					and os.time() - (lock.Time or 0) < LOCK_TIMEOUT

				-- Son denemede kilidi devral, öncekilerde bekle
				if lockAlive and attempt < MAX_LOAD_ATTEMPTS then
					lockedByOther = true
					return nil -- güncellemeyi iptal et
				end

				loaded = old.Data
				old.Lock = { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)

		if ok and not lockedByOther then
			local data = loaded or Util.DeepCopy(TEMPLATE)
			return Util.Reconcile(data, TEMPLATE)
		end

		if not ok then
			warn(`[DataService] {player.Name} yüklenemedi (deneme {attempt}): {err}`)
		end

		if not player.Parent then
			return nil
		end
		task.wait(if lockedByOther then 6 else attempt * 2)
	end

	return nil
end

local function saveData(player: Player, data, release: boolean): boolean
	if memoryOnly then
		return true
	end

	local key = keyFor(player)
	for attempt = 1, MAX_SAVE_ATTEMPTS do
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				old = old or {}
				-- Başka bir sunucu kilidi aldıysa onun verisinin üstüne yazma
				if old.Lock and old.Lock.JobId ~= game.JobId then
					return nil
				end
				old.Data = data
				old.Lock = if release then nil else { JobId = game.JobId, Time = os.time() }
				return old
			end)
		end)
		if ok then
			return true
		end
		warn(`[DataService] {player.Name} kaydedilemedi (deneme {attempt}): {err}`)
		task.wait(attempt)
	end
	return false
end

local function onPlayerAdded(player: Player)
	local data = loadData(player)
	if not player.Parent then
		-- Yükleme sırasında çıktı: kilidi bırak ki bir sonraki girişte beklemesin
		if data then
			saveData(player, data, true)
		end
		return
	end
	if not data then
		player:Kick("Verin yüklenemedi, lütfen birkaç saniye sonra tekrar gir.")
		return
	end

	profiles[player] = data
	fire(loadedCallbacks, player, data)
end

local function onPlayerRemoving(player: Player)
	local data = profiles[player]
	if not data then
		return
	end
	profiles[player] = nil

	data.LastOnline = os.time()
	fire(releasingCallbacks, player, data)
	saveData(player, data, true)
end

function DataService.Get(player: Player)
	return profiles[player]
end

-- Hemen kaydet (Robux satın alımından sonra). Başarılıysa true.
function DataService.SaveNow(player: Player): boolean
	local data = profiles[player]
	if not data then
		return false
	end
	return saveData(player, data, false)
end

function DataService.IsMemoryOnly(): boolean
	return memoryOnly
end

function DataService.Init()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		-- Studio'da API erişimi kapalıysa çağrılar hata verir: o zaman belleğe düş
		if RunService:IsStudio() then
			local probeOk, probeErr = pcall(function()
				return (store :: DataStore):GetAsync("__probe")
			end)
			if not probeOk then
				memoryOnly = true
				warn("[DataService] Studio'da DataStore'a erişilemiyor, veri SADECE BELLEKTE: " .. tostring(probeErr))
			end
		end
	else
		memoryOnly = true
		warn("[DataService] DataStore kullanılamıyor, veri SADECE BELLEKTE tutulacak: " .. tostring(result))
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Otomatik kayıt
	task.spawn(function()
		while true do
			task.wait(Economy.AutosaveInterval)
			for player, data in profiles do
				data.LastOnline = os.time()
				task.spawn(saveData, player, data, false)
			end
		end
	end)

	-- Sunucu kapanırken herkesi kaydet
	game:BindToClose(function()
		local pending = 0
		for player, data in profiles do
			pending += 1
			task.spawn(function()
				data.LastOnline = os.time()
				saveData(player, data, true)
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
