-- Günlük giriş ödülü (7 günlük seri), günlük 3 görev ve VIP'in günlük bedava kasası.
-- Görev ilerlemesi Events üzerinden diğer servislerden gelir.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Daily = require(ReplicatedStorage.Shared.Config.Daily)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local Events = require(script.Parent.Events)

local DailyService = {}

local DataService
local TycoonService
local PartService
local updatedEvent: RemoteEvent

---------------------------------------------------------------- yardımcılar

-- 12345 -> 12000 gibi "yuvarlak" hedef sayılar
local function niceNumber(n: number): number
	if n < 100 then
		return math.max(1, math.floor(n))
	end
	local magnitude = 10 ^ (math.floor(math.log10(n)) - 1)
	return math.floor(n / magnitude) * magnitude
end

local function scaled(player: Player, seconds: number, minimum: number): number
	return math.floor(math.max(minimum, TycoonService.GetRate(player) * seconds))
end

-- Sıradaki giriş ödülü günü (1-7) ve bugün alınabilir mi
local function loginState(data): (number, boolean)
	local today = Daily.Today()
	local daily = data.Daily
	if daily.LastClaimDay == today then
		return daily.Streak, false
	end
	local continuing = daily.LastClaimDay == today - 1
	local nextDay = if continuing then daily.Streak % #Daily.LoginRewards + 1 else 1
	return nextDay, true
end

-- Bugünün görevleri yoksa oluştur (herkese aynı 3 görev, gün numarasıyla seçilir)
local function ensureQuests(player: Player, data)
	local today = Daily.Today()
	if data.Daily.QuestDay == today and #data.Daily.Quests > 0 then
		return
	end
	local pool = table.clone(Daily.QuestPool)
	local rng = Random.new(today)
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end

	local quests = {}
	for i = 1, Daily.QuestsPerDay do
		local def = pool[i]
		local target = def.Target or niceNumber(scaled(player, def.RateSeconds, def.Minimum))
		table.insert(quests, { Type = def.Type, Text = def.Text, Target = target, Progress = 0, Claimed = false })
	end
	data.Daily.QuestDay = today
	data.Daily.Quests = quests
end

local function snapshot(player: Player, data)
	ensureQuests(player, data)
	local nextDay, canClaim = loginState(data)
	local quests = {}
	for _, quest in data.Daily.Quests do
		table.insert(quests, {
			Text = string.format(quest.Text, Util.FormatNumber(quest.Target)),
			Progress = quest.Progress,
			Target = quest.Target,
			Claimed = quest.Claimed,
		})
	end
	return {
		LoginDay = nextDay,
		CanClaimLogin = canClaim,
		QuestReward = scaled(player, Daily.QuestRewardProductionSeconds, Daily.QuestRewardMinimum),
		LoginBase = scaled(player, Daily.LoginProductionSeconds, Daily.LoginMinimum),
		Quests = quests,
	}
end

local function push(player: Player, data)
	local snap = snapshot(player, data)
	local questReady = false
	for _, quest in snap.Quests do
		if not quest.Claimed and quest.Progress >= quest.Target then
			questReady = true
		end
	end
	player:SetAttribute("DailyReady", snap.CanClaimLogin or questReady)
	updatedEvent:FireClient(player, snap)
end

local function giveVipCrate(player: Player, data)
	local today = Daily.Today()
	if TycoonService.HasPass(player, "VIP") and data.Daily.LastVipCrateDay < today then
		data.Daily.LastVipCrateDay = today
		PartService.GiveCrate(player, "Basic")
		TycoonService.Notify(player, "VIP günlük kasan açıldı!", "success")
	end
end

---------------------------------------------------------------- aksiyonlar

function DailyService.ClaimLogin(player: Player): boolean
	local data = DataService.Get(player)
	if not data or not TycoonService.CanAct(player) then
		return false
	end
	local day, canClaim = loginState(data)
	if not canClaim then
		return false
	end

	local reward = Daily.LoginRewards[day]
	local scrap = math.floor(scaled(player, Daily.LoginProductionSeconds, Daily.LoginMinimum) * reward.Mult)
	data.Daily.LastClaimDay = Daily.Today()
	data.Daily.Streak = day
	TycoonService.GiveScrap(player, scrap)
	if reward.Crate then
		PartService.GiveCrate(player, reward.Crate)
	end
	TycoonService.Notify(player, `{day}. gün ödülü: +{Util.FormatNumber(scrap)} hurda!`, "success")
	push(player, data)
	return true
end

function DailyService.ClaimQuest(player: Player, index: any): boolean
	local data = DataService.Get(player)
	if not data or typeof(index) ~= "number" or not TycoonService.CanAct(player) then
		return false
	end
	ensureQuests(player, data)
	local quest = data.Daily.Quests[index]
	if not quest or quest.Claimed or quest.Progress < quest.Target then
		return false
	end
	quest.Claimed = true
	local scrap = scaled(player, Daily.QuestRewardProductionSeconds, Daily.QuestRewardMinimum)
	TycoonService.GiveScrap(player, scrap)
	TycoonService.Notify(player, `Görev tamam: +{Util.FormatNumber(scrap)} hurda!`, "success")
	push(player, data)
	return true
end

local function onProgress(questType: string)
	return function(player: Player, amount: number)
		local data = DataService.Get(player)
		if not data then
			return
		end
		ensureQuests(player, data)
		local changed = false
		for _, quest in data.Daily.Quests do
			if quest.Type == questType and not quest.Claimed and quest.Progress < quest.Target then
				quest.Progress = math.min(quest.Target, quest.Progress + amount)
				changed = true
				if quest.Progress >= quest.Target then
					TycoonService.Notify(player, "Günlük görev tamamlandı! Ödülünü al.", "success")
				end
			end
		end
		if changed then
			push(player, data)
		end
	end
end

---------------------------------------------------------------- başlatma

local function onLoaded(player: Player, data)
	ensureQuests(player, data)
	giveVipCrate(player, data)
	push(player, data)
	local _, canClaim = loginState(data)
	if canClaim then
		TycoonService.Notify(player, "Günlük ödülün hazır! (Günlük butonu)", "info")
	end
end

function DailyService.Init(dataService, tycoonService, partService)
	DataService = dataService
	TycoonService = tycoonService
	PartService = partService
	updatedEvent = Remotes.Event("DailyUpdated")

	Remotes.Function("GetDaily").OnServerInvoke = function(player)
		local data = DataService.Get(player)
		return if data then snapshot(player, data) else nil
	end
	Remotes.Function("ClaimLogin").OnServerInvoke = DailyService.ClaimLogin
	Remotes.Function("ClaimQuest").OnServerInvoke = DailyService.ClaimQuest

	for _, questType in { "CollectScrap", "BuyUpgrade", "OpenCrate", "PlayMatch", "WinMatch", "FusePart" } do
		Events.Connect(questType, onProgress(questType))
	end
	Events.Connect("PassPurchased", function(player)
		local data = DataService.Get(player)
		if data then
			giveVipCrate(player, data)
		end
	end)

	DataService.OnLoaded(onLoaded)

	-- Gece yarısı (UTC) geçince çevrimiçi oyuncular için yeni gün
	local lastDay = Daily.Today()
	task.spawn(function()
		while true do
			task.wait(60)
			local today = Daily.Today()
			if today ~= lastDay then
				lastDay = today
				for _, player in Players:GetPlayers() do
					local data = DataService.Get(player)
					if data then
						giveVipCrate(player, data)
						push(player, data)
					end
				end
			end
		end
	end)
end

return DailyService
