-- Rebirth ve token ağacı.
-- Rebirth: hurda + kutu + fabrika upgrade'leri sıfırlanır; Rebirths +1 (kalıcı +%50 üretim, bkz. Formulas)
-- ve Rebirth Token kazanılır. Parçalar, robot, kupa ve token upgrade'leri kalır.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Rebirth = require(ReplicatedStorage.Shared.Config.Rebirth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local Events = require(script.Parent.Events)

local RebirthService = {}

local DataService
local TycoonService
local updatedEvent: RemoteEvent

local function snapshot(data)
	return {
		Rebirths = data.Rebirths,
		Tokens = data.RebirthTokens,
		Cost = Rebirth.Cost(data.Rebirths),
		TokenUpgrades = data.TokenUpgrades,
	}
end

local function push(player: Player, data)
	updatedEvent:FireClient(player, snapshot(data))
end

function RebirthService.DoRebirth(player: Player): boolean
	local data = DataService.Get(player)
	if not data or not TycoonService.CanAct(player) then
		return false
	end
	local cost = Rebirth.Cost(data.Rebirths)
	if data.Scrap < cost then
		TycoonService.Notify(player, `Rebirth için {Util.FormatNumber(cost)} hurda lazım.`, "error")
		return false
	end

	-- Sıfırla
	local startLevel = Rebirth.Level(data, "StartBoost")
	data.Scrap = if startLevel > 0 then Rebirth.ById.StartBoost.Values[startLevel] else 0
	data.Stored = 0
	data.Upgrades = {}

	-- Ödül
	data.Rebirths += 1
	data.RebirthTokens += Rebirth.TokensPerRebirth

	TycoonService.Refresh(player)
	push(player, data)
	TycoonService.Notify(player, `REBIRTH {data.Rebirths}! Üretim kalıcı olarak arttı, +{Rebirth.TokensPerRebirth} token.`, "success")
	Events.Fire("Rebirth", player, data.Rebirths)
	return true
end

function RebirthService.BuyNode(player: Player, nodeId: any): boolean
	local data = DataService.Get(player)
	local node = typeof(nodeId) == "string" and Rebirth.ById[nodeId]
	if not data or not node or not TycoonService.CanAct(player) then
		return false
	end
	local level = Rebirth.Level(data, node.Id)
	if level >= node.MaxLevel then
		return false
	end
	if data.RebirthTokens < node.Cost then
		TycoonService.Notify(player, `{node.Cost} token lazım.`, "error")
		return false
	end

	data.RebirthTokens -= node.Cost
	data.TokenUpgrades[node.Id] = level + 1
	TycoonService.Refresh(player) -- Dev Kutu kapasiteyi etkiler
	push(player, data)
	TycoonService.Notify(player, `{node.Name} seviye {level + 1}!`, "success")
	return true
end

function RebirthService.Init(dataService, tycoonService)
	DataService = dataService
	TycoonService = tycoonService
	updatedEvent = Remotes.Event("RebirthUpdated")

	Remotes.Function("GetRebirth").OnServerInvoke = function(player)
		local data = DataService.Get(player)
		return if data then snapshot(data) else nil
	end
	Remotes.Function("Rebirth").OnServerInvoke = RebirthService.DoRebirth
	Remotes.Function("BuyTokenNode").OnServerInvoke = RebirthService.BuyNode
end

return RebirthService
