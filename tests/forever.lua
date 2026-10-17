-- Режим WoW Forever: имена «Имя Фамилия» без сервера, свои расы, друзья Battle.net только из Forever.
--   lua5.1 tests/forever.lua .
local dir = arg[1] or "."
package.path = dir .. "/tools/charts/?.lua;" .. package.path
local env = require("env")
env.install(1800000000)
WOW_PROJECT_ID, WOW_PROJECT_CAMELOT, WOW_PROJECT_MAINLINE = 18, 18, 1
UnitName = function() return "Кагор" end
GetUnitName = function(_, full) return full and "Кагор Палович" or "Кагор" end
local races = {}
C_CreatureInfo.GetRaceInfo = function(id) races[#races + 1] = id return { raceName = "Раса" .. id } end
local TH = env.load(dir)
local Net = TH.Net

assert(TH.FOREVER, "Forever распознан")
-- имя: свой персонаж — с фамилией, отправитель — как есть, без сервера
assert(Net.Me() == "Кагор Палович", Net.Me())
assert(Net.FullName("Андрей  Целофанов ") == "Андрей Целофанов")
assert(TH:IsCharName("Шамыч Кагор"))
assert(not TH:IsCharName("Шамыч-Гордунни"))
assert(not TH:IsCharName("Шамыч"))
assert(not TH:IsCharName("Шамыч Кагор,Андрей Целофанов"))

-- поиск игрока по вводу: полное имя, только имя (если одно) и неизвестный — как ввели, без сервера
TH.db = TH.db or {}
TH.db.net = { sets = { a = { author = "Кагор Палович" }, b = { author = "Андрей Целофанов" }, c = { author = "Андрей Петров" } },
	scores = {}, follows = {}, votes = {}, modBlocks = {} }
assert(TH:ResolvePlayerName("  кагор   палович ") == "Кагор Палович")
local name, found = TH:ResolvePlayerName("Кагор")
assert(name == "Кагор Палович" and found)
name, found = TH:ResolvePlayerName("Андрей")
assert(not found, "два Андрея — нужно уточнить")
name, found = TH:ResolvePlayerName("Новый Игрок")
assert(name == "Новый Игрок" and not found)

-- примерка: только расы Forever
assert(loadfile(dir .. "/Preview.lua"))("TransmogHub", { TH = TH, L = setmetatable({}, { __index = function(_, k) return k end }) })
races = {}
TH.races = nil
local list = TH:GetPlayableRaces()
assert(#list == 9, #list)
local ids = {}
for _, r in ipairs(list) do ids[r.id] = true end
assert(ids[95] and not ids[96] and not ids[11] and not ids[52], "небеснорождённые один раз, дренеев и драктиров нет")
assert(TH:GetRaceName(95) == "Небеснорождённый")
-- знаки, которых нет в шрифтах Forever, заменены
local lns = {}
assert(loadfile(dir .. "/Locales/Locale.lua"))("TransmogHub", lns)
assert(lns.L["  ·  |cff69ccf0подписок: "] == "  —  |cff69ccf0подписок: ")
assert(lns.L["Ждём…"] == "Ждём...")
print("FOREVER OK")
