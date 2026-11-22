-- FormatNumber.luau
-- 1234 -> "1.23K", 5600000 -> "5.6M". Keeps the UI short on phone screens.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local function trim(s: string): string
	if string.find(s, "%.") then
		s = string.gsub(s, "0+$", "")
		s = string.gsub(s, "%.$", "")
	end
	return s
end

local function FormatNumber(n: number): string
	if n ~= n then
		return "0"
	end
	local negative = n < 0
	n = math.abs(n)

	local text
	if n < 1000 then
		text = if n == math.floor(n) then tostring(n) else trim(string.format("%.1f", n))
	else
		local tier = math.min(math.floor(math.log10(n) / 3), #SUFFIXES - 1)
		local scaled = n / 10 ^ (tier * 3)
		local decimals = if scaled < 10 then 2 elseif scaled < 100 then 1 else 0
		text = trim(string.format("%." .. decimals .. "f", scaled)) .. SUFFIXES[tier + 1]
	end

	return if negative then "-" .. text else text
end

return FormatNumber
