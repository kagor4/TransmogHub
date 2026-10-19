local appName, _, a = ...
local L = _.L
local localize = function(t, data) for k,v in pairs(data) do t[k] = v end end
localize(L.HEADER_NAMES, {
	[-12] = "Achievements",
	[-7] = string.format(SPELLBOOK_AVAILABLE_AT, 48),
	[-247] = select(2,GetAchievementInfo(2091))..": Season 1",
})
local simplifiedLocale = GetLocale():sub(1,2)
if simplifiedLocale == "ru" then
localize(L.HEADER_NAMES, {
	[-12] = "Достижения",
})
end
