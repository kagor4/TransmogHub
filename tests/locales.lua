-- Проверка переводов: у каждого L["…"] в коде есть английский перевод; коды цвета и
-- подстановки (%s, %d…) совпадают по числу и порядку; в переводах нет знаков, которых
-- нет в шрифтах игры. Испанский и немецкий тоже должны быть полными; другие языки (если появятся)
-- проверяются так же, но пропуски допустимы.
--   lua5.1 tests/locales.lua .
local dir = arg[1] or "."

local files = {}
for name in io.popen('ls "' .. dir .. '"/*.lua'):lines() do files[#files + 1] = name end

-- ключи из кода: тела строк L["…"] так, как Lua их прочитает
local keys, order = {}, {}
for _, path in ipairs(files) do
	local src = assert(io.open(path)):read("*a")
	for body in src:gmatch('L%["(.-[^\\])"%]') do
		local ok, value = pcall(loadstring, 'return "' .. body .. '"')
		value = ok and value and value()
		if value and not keys[value] then keys[value] = path; order[#order + 1] = value end
	end
end

local ns = {}
GetLocale = function() return "enUS" end
for _, f in ipairs({ "Locale.lua", "enUS.lua", "deDE.lua", "frFR.lua", "esES.lua" }) do
	local chunk = loadfile(dir .. "/Locales/" .. f)
	if chunk then chunk("TransmogHub", ns) end
end

local function Codes(s)
	local out = {}
	for c in s:gmatch("|c%x%x%x%x%x%x%x%x") do out[#out + 1] = "c" end
	for c in s:gmatch("|r") do out[#out + 1] = "r" end
	for p in s:gmatch("%%[%-%d%.]*[sdif%%]") do out[#out + 1] = p end
	return table.concat(out, " ")
end
local BAD = { "\226\128\166", "\226\128\156", "\226\128\157", "\226\128\152", "\226\128\153" } -- … “ ” ‘ ’

local fails, missing = 0, 0
for lang, t in pairs(ns.LOCALES) do
	for _, key in ipairs(order) do
		local v = t[key]
		if v == nil then
			if lang == "enUS" or lang == "esES" or lang == "deDE" then -- эти языки — полностью
				missing = missing + 1
				if missing <= 20 then print("NO " .. lang .. ": " .. key:sub(1, 80) .. "  (" .. keys[key]:match("[^/]+$") .. ")") end
			end
		else
			if Codes(v) ~= Codes(key) then
				fails = fails + 1
				print(lang .. " CODES/PLACEHOLDERS differ: " .. key:sub(1, 70) .. " => " .. v:sub(1, 70))
			end
			for _, b in ipairs(BAD) do
				if v:find(b, 1, true) then fails = fails + 1; print(lang .. " BAD GLYPH: " .. v:sub(1, 70)) end
			end
			if v:find("[\208\209][\128-\191]") then fails = fails + 1; print(lang .. " CYRILLIC LEFT: " .. v:sub(1, 70)) end
		end
	end
	local extra = 0
	for k in pairs(t) do if not keys[k] then extra = extra + 1 end end
	print(string.format("%s: %d keys, %d unused", lang, (function() local n = 0 for _ in pairs(t) do n = n + 1 end return n end)(), extra))
end
print(string.format("%d strings in code, %d without translation", #order, missing))
assert(fails == 0 and missing == 0, "locale check failed")
print("LOCALES OK")
