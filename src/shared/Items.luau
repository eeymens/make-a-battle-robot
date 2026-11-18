-- Envanter anahtarı: "PartId|Rarity" (örn. "Saw|Epic").
-- Envanter, anahtar -> adet sözlüğü olarak tutulur; aynı parçadan 3 tane birleştirmeyi kolaylaştırır.

local Parts = require(script.Parent.Config.Parts)
local Rarities = require(script.Parent.Config.Rarities)

local Items = {}

function Items.Key(partId: string, rarity: string): string
	return partId .. "|" .. rarity
end

-- Geçersiz anahtar için nil döner (client'tan gelen veriyi doğrulamak için)
function Items.Parse(key: any): (string?, string?)
	if typeof(key) ~= "string" then
		return nil, nil
	end
	local partId, rarity = string.match(key, "^(%w+)|(%w+)$")
	if not partId or not Parts.ById[partId] or not Rarities.ById[rarity] then
		return nil, nil
	end
	return partId, rarity
end

function Items.DisplayName(partId: string, rarity: string): string
	return `{Parts.ById[partId].Name} ({rarity})`
end

return Items
