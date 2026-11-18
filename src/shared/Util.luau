local Util = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc" }

-- 1234 -> "1.23K", 5600000 -> "5.60M"
function Util.FormatNumber(n: number): string
	n = math.floor(n)
	if n < 1000 then
		return tostring(n)
	end

	local value = n
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end

	local format
	if value < 10 then
		format = "%.2f%s"
	elseif value < 100 then
		format = "%.1f%s"
	else
		format = "%.0f%s"
	end
	return string.format(format, value, SUFFIXES[index])
end

function Util.DeepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = Util.DeepCopy(v)
	end
	return copy
end

-- template'te olup data'da olmayan alanları ekler (yeni alan eklediğimizde eski kayıtlar bozulmasın)
function Util.Reconcile(data, template)
	for key, value in template do
		if data[key] == nil then
			data[key] = Util.DeepCopy(value)
		elseif type(value) == "table" and type(data[key]) == "table" then
			Util.Reconcile(data[key], value)
		end
	end
	return data
end

return Util
