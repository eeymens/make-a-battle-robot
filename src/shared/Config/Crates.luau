-- Kasalar. Olasılıklar Rarities.Weight'ten gelir ve oyunda kasanın üstünde gösterilir.

export type Crate = {
	Id: string,
	Name: string,
	Cost: number, -- Hurda (0 = hurdayla açılamaz, sadece hediye/Robux)
	PityThreshold: number, -- bu kadar kasa boyunca Legendary+ çıkmazsa sonraki garanti
	MinRarityIndex: number?, -- bu nadirlikten aşağısı çıkmaz
}

local Crates: { [string]: Crate } = {
	Basic = {
		Id = "Basic",
		Name = "Hurda Kasası",
		Cost = 500,
		PityThreshold = 150,
	},
	-- Robux (MegaCrate ürünü) ya da 7. gün ödülüyle gelir
	Mega = {
		Id = "Mega",
		Name = "Mega Kasa",
		Cost = 0,
		PityThreshold = 150,
		MinRarityIndex = 3, -- Epic+
	},
}

return Crates
