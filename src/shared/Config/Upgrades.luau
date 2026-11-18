-- Fabrika upgrade'leri. Fiyat formülü: BaseCost * CostGrowth ^ seviye (bkz. Formulas)

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	BaseCost: number,
	MaxLevel: number,
	Order: number,
	RatePerLevel: number?,
	MultPerLevel: number?,
	CapacityPerLevel: number?,
}

local Upgrades: { [string]: Upgrade } = {
	Collector = {
		Id = "Collector",
		Name = "Hurda Toplayıcı",
		Description = "+2 hurda/sn",
		BaseCost = 25,
		MaxLevel = 50,
		Order = 1,
		RatePerLevel = 2,
	},
	Conveyor = {
		Id = "Conveyor",
		Name = "Hızlı Konveyör",
		Description = "+%10 üretim",
		BaseCost = 150,
		MaxLevel = 20,
		Order = 2,
		MultPerLevel = 0.10,
	},
	Magnet = {
		Id = "Magnet",
		Name = "Mıknatıs",
		Description = "Kutu kapasitesi +5 dk",
		BaseCost = 800,
		MaxLevel = 6,
		Order = 3,
		CapacityPerLevel = 5 * 60,
	},
	Furnace = {
		Id = "Furnace",
		Name = "Isıtma Fırını",
		Description = "Hurda değeri +%50",
		BaseCost = 2500,
		MaxLevel = 5,
		Order = 4,
		MultPerLevel = 0.5,
	},
}

-- Sıralı liste (UI ve plot yerleşimi için)
local ordered = {}
for _, upgrade in Upgrades do
	table.insert(ordered, upgrade)
end
table.sort(ordered, function(a, b)
	return a.Order < b.Order
end)

return {
	ById = Upgrades,
	Ordered = ordered,
}
