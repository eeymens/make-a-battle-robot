-- Ekonomi formülleri. Hem sunucu hem client kullanır, böylece UI'daki sayılar
-- sunucudaki hesapla birebir aynı olur.

local Economy = require(script.Parent.Config.Economy)
local Upgrades = require(script.Parent.Config.Upgrades)
local Rebirth = require(script.Parent.Config.Rebirth)

local Formulas = {}

function Formulas.UpgradeCost(upgradeId: string, level: number): number
	local upgrade = Upgrades.ById[upgradeId]
	return math.floor(upgrade.BaseCost * Economy.CostGrowth ^ level)
end

-- Saniyelik hurda üretimi
function Formulas.Rate(data, passMultiplier: number?): number
	local levels = data.Upgrades
	local byId = Upgrades.ById

	local base = Economy.BaseRate + (levels.Collector or 0) * byId.Collector.RatePerLevel
	local conveyor = 1 + (levels.Conveyor or 0) * byId.Conveyor.MultPerLevel
	local furnace = 1 + (levels.Furnace or 0) * byId.Furnace.MultPerLevel
	local rebirth = 1 + (data.Rebirths or 0) * Economy.RebirthMultiplierPerRebirth

	return base * conveyor * furnace * rebirth * (passMultiplier or 1)
end

-- Toplama kutusunun alabileceği maksimum hurda
function Formulas.Capacity(data, rate: number): number
	local magnet = data.Upgrades.Magnet or 0
	local seconds = Economy.BoxCapacitySeconds + magnet * Upgrades.ById.Magnet.CapacityPerLevel
	local tokenBonus = 1 + Rebirth.Level(data, "BoxCapacity") * Rebirth.ById.BoxCapacity.Value
	return math.floor(rate * seconds * tokenBonus)
end

function Formulas.OfflineMaxSeconds(data): number
	return Economy.OfflineMaxSeconds + Rebirth.Level(data, "OfflineTime") * Rebirth.ById.OfflineTime.Value
end

return Formulas
