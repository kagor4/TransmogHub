local _, ns = ...

---------------------------------------------------------------------------
-- Переводы. Исходный язык — русский: текст в коде, L["…"], он же ключ перевода.
-- Locales/<язык>.lua кладут свои таблицы в ns.LOCALES[язык] = { ["русский"] = "перевод" }.
-- Нет перевода на язык клиента — английский; нет и его — русский как есть.
-- Переводы проверяет tests/locales.lua: у каждого L["…"] в коде должен быть английский.
---------------------------------------------------------------------------
ns.LOCALES = ns.LOCALES or {}

-- Язык с похожим вариантом: испанский Мексики — как испанский, британский — как американский
local SAME = { esMX = "esES", enGB = "enUS", ptPT = "ptBR" }

function ns.ClientLocale()
	local loc = (GetLocale and GetLocale()) or "enUS"
	return SAME[loc] or loc
end

-- В шрифтах интерфейса WoW Forever нет некоторых знаков (квадратики): заменяем на похожие
local FOREVER_GLYPHS = { ["·"] = "—", ["…"] = "...", ["×"] = "x" }
local function IsForever()
	local toc = GetBuildInfo and select(4, GetBuildInfo())
	return (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
		or (type(toc) == "number" and toc >= 16000 and toc < 20000)
end
local glyphs = IsForever() and FOREVER_GLYPHS
local fixed = {}

local function Translate(key)
	local loc = ns.ClientLocale()
	if loc == "ruRU" then return key end
	local own = ns.LOCALES[loc]
	local v = own and own[key]
	if v == nil then
		local en = ns.LOCALES.enUS
		v = en and en[key]
	end
	return v or key
end

ns.L = setmetatable({}, { __index = function(_, key)
	if not glyphs then return Translate(key) end
	local v = fixed[key]
	if v == nil then
		v = Translate(key)
		if type(v) == "string" then
			for from, to in pairs(glyphs) do v = v:gsub(from, to) end
		end
		fixed[key] = v
	end
	return v
end })
