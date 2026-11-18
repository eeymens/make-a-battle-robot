-- Developer Product'lar (tekrar alınabilir). Creator Hub'da oluşturup 0'ları gerçek ID'lerle değiştir.
-- Fiyat Creator Hub'da belirlenir; buradaki Price sadece ID girilmemişken UI'da gösterilen tahmin.
-- Game Pass ID'leri: Config/GamePasses.luau

local Products = {
	SmallScrap = {
		Id = 0,
		Name = "Küçük Hurda Paketi",
		Description = "10 dakikalık üretim kadar hurda",
		Price = 25,
		ProductionSeconds = 10 * 60,
		Minimum = 500,
	},
	BigScrap = {
		Id = 0,
		Name = "Büyük Hurda Paketi",
		Description = "1 saatlik üretim kadar hurda",
		Price = 99,
		ProductionSeconds = 60 * 60,
		Minimum = 5000,
	},
	MegaCrate = {
		Id = 0,
		Name = "Mega Kasa",
		Description = "Epic veya daha iyisi garanti",
		Price = 79,
	},
	Boost = {
		Id = 0,
		Name = "3x Boost (15 dk)",
		Description = "15 dakika boyunca 3 kat hurda",
		Price = 49,
		Duration = 15 * 60,
		Multiplier = 3,
	},
	Repair = {
		Id = 0,
		Name = "Tamir Kiti",
		Description = "Arenada robotun canını %50 doldurur (maç başına 1)",
		Price = 15,
		HealRatio = 0.5,
	},
}

-- Mağazada pass'lerin açıklamaları (ID'ler GamePasses.luau'da)
local PassInfo = {
	DoubleScrap = { Name = "2x Hurda", Description = "Bütün hurda kazancı kalıcı 2 kat", Price = 199 },
	AutoCollect = { Name = "Otomatik Toplama", Description = "Kutuya gitmeden hurda direkt cebe", Price = 99 },
	ExtraGarage = { Name = "Ekstra Garaj", Description = "2. robot, aralarında tek tıkla geçiş", Price = 149 },
	LuckyCrate = { Name = "Şanslı Kasa", Description = "Legendary+ şansı 1.5 kat", Price = 299 },
	VIP = { Name = "VIP", Description = "Her gün bedava kasa + VIP tabelası", Price = 349 },
}

local PassOrder = { "DoubleScrap", "AutoCollect", "ExtraGarage", "LuckyCrate", "VIP" }
local ProductOrder = { "SmallScrap", "BigScrap", "MegaCrate", "Boost", "Repair" }

-- ID -> ürün anahtarı
local function findByProductId(id: number): string?
	for key, product in Products do
		if product.Id ~= 0 and product.Id == id then
			return key
		end
	end
	return nil
end

return {
	Products = Products,
	PassInfo = PassInfo,
	PassOrder = PassOrder,
	ProductOrder = ProductOrder,
	FindByProductId = findByProductId,
}
