-- Rebirth: fabrika sıfırlanır (hurda + fabrika upgrade'leri), karşılığında kalıcı +%50 hurda
-- çarpanı ve 1 Rebirth Token gelir. Parçalar, robot, kupalar SIFIRLANMAZ.

local Rebirth = {}

Rebirth.BaseCost = 100000 -- ilk rebirth için gereken hurda
Rebirth.CostGrowth = 2.5 -- her rebirth'te eşik bu kadar katlanır
Rebirth.TokensPerRebirth = 1

function Rebirth.Cost(rebirths: number): number
	return math.floor(Rebirth.BaseCost * Rebirth.CostGrowth ^ rebirths)
end

-- Token ağacı. Cost = seviye başına token, Value = seviye başına etki
Rebirth.Tree = {
	{
		Id = "StartBoost",
		Name = "Başlangıç Sermayesi",
		Description = "Rebirth sonrası hurdayla başla",
		Cost = 1,
		MaxLevel = 3,
		Values = { 1000, 5000, 25000 }, -- seviyeye göre başlangıç hurdası
	},
	{
		Id = "OfflineTime",
		Name = "Gece Vardiyası",
		Description = "Çevrimdışı kazanç süresi +1 saat",
		Cost = 1,
		MaxLevel = 3,
		Value = 60 * 60,
	},
	{
		Id = "ArenaBonus",
		Name = "Arena Ustası",
		Description = "Arena hurda ödülü +%20",
		Cost = 1,
		MaxLevel = 3,
		Value = 0.2,
	},
	{
		Id = "CrateLuck",
		Name = "Şanslı El",
		Description = "Legendary+ şansı +%10",
		Cost = 2,
		MaxLevel = 3,
		Value = 0.1,
	},
	{
		Id = "BoxCapacity",
		Name = "Dev Kutu",
		Description = "Toplama kutusu kapasitesi +%25",
		Cost = 2,
		MaxLevel = 2,
		Value = 0.25,
	},
}

Rebirth.ById = {}
for _, node in Rebirth.Tree do
	Rebirth.ById[node.Id] = node
end

-- Oyuncunun bir token upgrade'indeki seviyesi
function Rebirth.Level(data, nodeId: string): number
	return (data.TokenUpgrades and data.TokenUpgrades[nodeId]) or 0
end

return Rebirth
