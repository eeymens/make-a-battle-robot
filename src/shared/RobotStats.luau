-- Takılı parçalardan robot statlarını hesaplar. Sunucu (eşleştirme, arena) ve client (garaj UI) aynı fonksiyonu kullanır.
-- equipped: { [slot]: { PartId: string, Rarity: string } }

local Parts = require(script.Parent.Config.Parts)
local Rarities = require(script.Parent.Config.Rarities)

export type Stats = {
	HP: number,
	Damage: number,
	Speed: number,
	Weight: number,
	Capacity: number,
	Overweight: boolean,
	Power: number,
}

local RobotStats = {}

function RobotStats.Compute(equipped): Stats
	local hp, damage, speed, weight, capacity = 0, 0, 0, 0, 0

	for _, item in equipped do
		local part = Parts.ById[item.PartId]
		local rarity = Rarities.ById[item.Rarity]
		if part and rarity then
			local mult = rarity.Multiplier
			hp += (part.HP or 0) * mult
			damage += (part.Damage or 0) * mult
			-- Hız ve kapasite nadirlikle daha az büyür, yoksa Mythic robotlar ışınlanır
			speed += (part.Speed or 0) * (1 + (mult - 1) * 0.2)
			capacity += (part.Capacity or 0) * (1 + (mult - 1) * 0.25)
			weight += part.Weight
		end
	end

	-- Fazla yük: hız, kapasite/ağırlık oranında düşer
	local overweight = capacity > 0 and weight > capacity
	if overweight then
		speed *= capacity / weight
	end

	local power = math.floor(hp * 0.5 + damage * 5 + speed * 3)

	return {
		HP = math.floor(hp),
		Damage = math.floor(damage * 10) / 10,
		Speed = math.floor(speed * 10) / 10,
		Weight = weight,
		Capacity = math.floor(capacity),
		Overweight = overweight,
		Power = power,
	}
end

return RobotStats
