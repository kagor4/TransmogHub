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
-- каталог и чарт Forever (их собирает release-forever.sh) — вместо основных
TransmogHub_BundledForever = { generated = 1800000000, sets = {}, peers = { { "Тест Альянсов", "A", 1800000000 } } }
TransmogHub_ChartsForever = nil
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
-- теги: лишних из основной игры нет, свои рейды и подземелья есть
assert(TH.TAG_LABEL.raid_onyxia and TH.TAG_LABEL.dg_drowned and TH.TAG_LABEL.dg_strat and TH.TAG_LABEL.r_skyborne)
assert(not TH.TAG_LABEL.deathknight and not TH.TAG_LABEL.raid_midnight and not TH.TAG_LABEL.r_pandaren)
assert(TH.RAID_TAGS.raid_hyjal and not TH.RAID_TAGS.raid_midnight)
-- достижения на теги не требуют скрытых в Forever тегов
local src = io.open(dir .. "/Achievements.lua"):read("*a")
assert(TH.TAG_LABEL.midsummer and not TH.TAG_LABEL.brewfest)
assert(src:find('TH.FOREVER and { "hallows", "winterveil", "lovefest", "midsummer" }', 1, true))
for _, theme in ipairs(TH.TAG_THEMES) do
	for _, key in ipairs(theme.tags) do assert(TH.TAG_LABEL[key], "тема " .. theme.name .. ": нет тега " .. key) end
end

-- тексты достижений: без лора дополнений и ключей эпохального+; PvP-звания по фракции
local BANNED = { "Пандари", "Вальдраккен", "Сурамар", "Ульдуар", "наару", "Безлик", "Гаррош", "Ключ +", "эпохальн",
	"Рио", "Корен", "Серебряного союза", "Бесконечные", "Зул'Амана", "Вариан когда-то" }
for _, a in ipairs(TH.ACHIEVEMENTS) do
	for _, field in ipairs(a.hidden and {} or { "name", "desc", "flavor" }) do
		local text = a[field]
		if type(text) == "string" then
			for _, word in ipairs(BANNED) do assert(not text:find(word, 1, true), a.id .. "." .. field .. ": " .. word) end
		end
	end
end
assert(TH.ACHIEVEMENT_BY_ID.pct_top_25.name == "Скелетный ключ")
assert(TH.ACHIEVEMENT_BY_ID.raid_aotc.name == "Голова на воротах")
UnitFactionGroup = function() return "Horde" end
TH:ApplyFactionNames()
assert(TH.ACHIEVEMENT_BY_ID.pct_board_01.name == "Верховный вождь")
UnitFactionGroup = function() return "Alliance" end
TH:ApplyFactionNames()
assert(TH.ACHIEVEMENT_BY_ID.pct_board_01.name == "Главнокомандующий")

-- тайны: у тех, чьи условия в основной игре используют скрытые теги и расы, есть вариант Forever,
-- и он подменяет основной
assert(type(TransmogHub_SecretsForever) == "table")
for _, id in ipairs({ "hid_bloodtank", "hid_lunar", "hid_raidguide", "hid_rwf", "hid_illidan", "hid_chen", "hid_neighbours", "hid_translate" }) do
	assert(TransmogHub_SecretsForever[id], "нет тайны Forever: " .. id)
	assert(TransmogHub_Secrets[id] == TransmogHub_SecretsForever[id], "тайна Forever не подменила основную: " .. id)
end

-- каталог и чарт основной игры в Forever не показываются
assert(TransmogHub_Bundled == TransmogHub_BundledForever, "каталог Forever вместо основного")
assert(TransmogHub_Charts == nil and TH:GetCharts() == nil, "чарта Forever ещё нет — основной не подставляется")
for _, set in ipairs(TH.feed and TH.feed.sets or {}) do assert(not set.author or TH:IsCharName(set.author), "образ основной игры в ленте: " .. tostring(set.author)) end

-- образ автора из основной игры в Forever не принимается
assert(not Net:StoreSet({ id = "n1", author = "Шуншуня-Гордунни", name = "Мао", items = {} }, "Киса Мрр"))

-- телефонная книга Forever: к персонажу разработчика своей фракции, себя пропускаем
do
	UnitFactionGroup = function() return "Alliance" end
	local names = {}
	for _, c in ipairs(Net:KnockCandidates()) do names[c[1]] = true end
	assert(names["Первый Каг"], "альянс стучится к Первому Кагу")
	assert(names["Тест Альянсов"], "телефонная книга Forever из каталога")
	assert(not names["Кагор Палович"], "себя и другую фракцию пропускаем")
	for name in pairs(names) do assert(TH:IsCharName(name), "только имена Forever: " .. name) end
end

-- «где найти» в Forever — своя база ATT (Camelot), её и грузит TransmogHub_Sources
do
	local toc = assert(io.open(dir .. "/TransmogHub_Sources/TransmogHub_Sources.toc")):read("*a")
	assert(toc:find("\nATTForever%.lua") and not toc:find("\nATT%.lua") and toc:find("16001"), "toc Forever")
	local saved = TransmogHub_ATT
	dofile(dir .. "/TransmogHub_Sources/ATTForever.lua")
	local n = 0
	for _ in pairs(TransmogHub_ATT.items) do n = n + 1 end
	assert(n > 1000, "вещей в базе Forever: " .. n)
	assert(TransmogHub_ATT.items[22108], "вещь из Наксрамаса")
	TransmogHub_ATT = saved
	-- и аддон в Forever её загружает (раньше загрузка в Forever была запрещена)
	local src = assert(io.open(dir .. "/Sources.lua")):read("*a")
	assert(not src:find("TH.FOREVER or embeddedTried", 1, true), "Forever грузит встроенную базу")
	TransmogHub_ATT = saved
end

-- знаки, которых нет в шрифтах Forever, заменены
local lns = {}
assert(loadfile(dir .. "/Locales/Locale.lua"))("TransmogHub", lns)
assert(lns.L["  ·  |cff69ccf0подписок: "] == "  —  |cff69ccf0подписок: ")
assert(lns.L["Ждём…"] == "Ждём...")
print("FOREVER OK")
