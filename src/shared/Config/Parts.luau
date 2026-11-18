-- Robot parçaları. Statlar Common seviyesi içindir; nadirlik çarpanı Rarities'ten gelir.
-- Ağırlık nadirlikle değişmez: güçlü ama ağır parça seçmek bir takas.

export type Part = {
	Id: string,
	Name: string,
	Slot: string,
	Weight: number,
	HP: number?,
	Damage: number?,
	Speed: number?,
	Capacity: number?, -- sadece gövde: taşıyabileceği toplam ağırlık
	Description: string,
}

local ById: { [string]: Part } = {
	-- Gövde
	TinCan = { Id = "TinCan", Name = "Teneke Kutu", Slot = "Body", HP = 100, Weight = 6, Capacity = 20, Description = "Hafif ve ucuz. Fazla yük kaldırmaz." },
	SteelChassis = { Id = "SteelChassis", Name = "Çelik Şasi", Slot = "Body", HP = 160, Weight = 10, Capacity = 30, Description = "Dengeli gövde." },
	TitanCore = { Id = "TitanCore", Name = "Titan Çekirdek", Slot = "Body", HP = 240, Weight = 16, Capacity = 45, Description = "Ağır ama her şeyi taşır." },

	-- Silah
	Saw = { Id = "Saw", Name = "Testere", Slot = "Weapon", Damage = 12, Weight = 4, Description = "Hızlı, sürekli hasar." },
	HammerArm = { Id = "HammerArm", Name = "Çekiç Kol", Slot = "Weapon", Damage = 20, Weight = 8, Description = "Yavaş ama sert vurur." },
	Flamethrower = { Id = "Flamethrower", Name = "Alev Makinesi", Slot = "Weapon", Damage = 9, Weight = 5, Description = "Düşük hasar, yakar." },

	-- Hareket
	Wheels = { Id = "Wheels", Name = "Tekerlek", Slot = "Movement", Speed = 16, Weight = 3, Description = "En hızlısı." },
	Treads = { Id = "Treads", Name = "Palet", Slot = "Movement", Speed = 11, HP = 40, Weight = 6, Description = "Yavaş ama sağlam." },
	SpiderLegs = { Id = "SpiderLegs", Name = "Örümcek Bacak", Slot = "Movement", Speed = 14, HP = 20, Weight = 5, Description = "Dengeli, yüksek duruş." },

	-- Zırh
	ScrapPlate = { Id = "ScrapPlate", Name = "Hurda Plaka", Slot = "Armor", HP = 40, Weight = 4, Description = "Az koruma, hafif." },
	CompositeShield = { Id = "CompositeShield", Name = "Kompozit Kalkan", Slot = "Armor", HP = 70, Weight = 7, Description = "Orta koruma." },
	ReactiveArmor = { Id = "ReactiveArmor", Name = "Reaktif Zırh", Slot = "Armor", HP = 110, Weight = 11, Description = "En çok koruma, çok ağır." },
}

local list = {}
for _, part in ById do
	table.insert(list, part)
end
table.sort(list, function(a, b)
	return a.Id < b.Id
end)

return {
	ById = ById,
	List = list, -- kasadan rastgele seçim için
	Slots = { "Body", "Weapon", "Movement", "Armor" },
	SlotNames = {
		Body = "Gövde",
		Weapon = "Silah",
		Movement = "Hareket",
		Armor = "Zırh",
	},
	-- Yeni oyuncuya verilen başlangıç robotu (Common)
	Starter = {
		Body = "TinCan",
		Weapon = "Saw",
		Movement = "Wheels",
		Armor = "ScrapPlate",
	},
}
