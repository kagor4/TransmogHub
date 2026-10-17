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

ns.L = setmetatable({}, { __index = function(_, key)
	local loc = ns.ClientLocale()
	if loc == "ruRU" then return key end
	local own = ns.LOCALES[loc]
	local v = own and own[key]
	if v == nil then
		local en = ns.LOCALES.enUS
		v = en and en[key]
	end
	return v or key
end })
