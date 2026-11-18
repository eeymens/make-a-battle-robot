-- Ekonomi sabitleri. Denge ayarları tek yerden buradan yapılır.

local Economy = {
	-- Fabrika
	BaseRate = 2, -- upgrade'siz başlangıç üretimi (hurda/sn)
	CostGrowth = 1.15, -- her upgrade seviyesinde fiyat artışı
	BoxCapacitySeconds = 10 * 60, -- toplama kutusu en fazla kaç saniyelik üretim tutar

	-- Çevrimdışı kazanç
	OfflineRatio = 0.25, -- çevrimdışıyken üretimin yüzde kaçı gelir
	OfflineMaxSeconds = 2 * 60 * 60, -- en fazla 2 saat

	-- Rebirth (Aşama 4'te kullanılacak)
	RebirthMultiplierPerRebirth = 0.5,

	-- Sistem
	AutosaveInterval = 60, -- saniye
	ActionCooldown = 0.25, -- oyuncu başına iki işlem arası minimum süre
	TickInterval = 1, -- üretim döngüsü (saniye)
}

return Economy
