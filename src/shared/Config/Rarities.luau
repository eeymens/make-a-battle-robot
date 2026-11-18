-- Nadirlik seviyeleri. Weight = kasadan çıkma ağırlığı (toplam 100 = yüzde).

export type Rarity = {
	Id: string,
	Index: number,
	Weight: number,
	Multiplier: number, -- HP ve hasar çarpanı
	Color: Color3,
}

local ById: { [string]: Rarity } = {
	Common = { Id = "Common", Index = 1, Weight = 60, Multiplier = 1.0, Color = Color3.fromRGB(170, 170, 170) },
	Rare = { Id = "Rare", Index = 2, Weight = 25, Multiplier = 1.4, Color = Color3.fromRGB(52, 152, 219) },
	Epic = { Id = "Epic", Index = 3, Weight = 11, Multiplier = 2.0, Color = Color3.fromRGB(155, 89, 182) },
	Legendary = { Id = "Legendary", Index = 4, Weight = 3.5, Multiplier = 3.0, Color = Color3.fromRGB(230, 126, 34) },
	Mythic = { Id = "Mythic", Index = 5, Weight = 0.5, Multiplier = 4.5, Color = Color3.fromRGB(231, 76, 60) },
}

local Ordered = { "Common", "Rare", "Epic", "Legendary", "Mythic" }

local Rarities = {
	ById = ById,
	Ordered = Ordered,
	HighTierIndex = 4, -- Legendary ve üstü: pity ve Şanslı Kasa bunları etkiler
}

-- Bir üst nadirlik (Mythic için nil)
function Rarities.Next(rarityId: string): string?
	local rarity = ById[rarityId]
	return rarity and Ordered[rarity.Index + 1]
end

return Rarities
