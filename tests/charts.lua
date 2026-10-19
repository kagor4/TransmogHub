-- Тест официального чарта: синтетическая сеть -> tools/charts/build.lua -> Data/Charts.lua
--   lua5.1 tests/charts.lua .
local dir = arg[1] or "."
local tmp = os.tmpname()
local svPath, outPath = tmp .. "_sv.lua", tmp .. "_charts.lua"
local NOW = 1792000000
local DAY = 86400

-- Синтетическая сеть
local sets, votes, scores = {}, {}, {}
local function SetEntry(id, author, tags)
	sets[id] = { id = id, author = author, name = "Образ", desc = "", race = 1, sex = 0, class = "ROGUE",
		created = NOW - 20 * DAY, tags = tags or {}, items = { [5] = { 111 } } }
end
-- 40 авторов, у каждого образ; 60 постоянных голосующих (давно в сети, оценили много образов)
for i = 1, 40 do SetEntry("nset" .. i, "Автор" .. i .. "-Гордунни", i <= 12 and { "raid_midnight", "c_red" } or { "c_red" }) end
for i = 1, 40 do
	votes["nset" .. i] = {}
	for v = 1, 60 do
		-- чем меньше номер образа, тем выше оценки
		local stars = math.max(1, math.min(5, 5 - math.floor((i - 1) / 9) - (v % 7 == 0 and 1 or 0)))
		votes["nset" .. i]["Голос" .. v .. "-Гордунни"] = { stars, NOW - 30 * DAY + v * 60 }
	end
end
-- у nset1 тег рейда оспорен: отметили 20 из 60 оценивших
local tagFlags = { nset1 = { raid_midnight = {} } }
for v = 1, 20 do tagFlags.nset1.raid_midnight["Голос" .. v .. "-Гордунни"] = { 1, NOW - DAY } end
-- накрутка: 12 свежих твинков с сервера автора, все пятёрки за час
SetEntry("nboost", "Накрутчик-Свежеватель Душ", { "c_red" })
votes.nboost = {}
for v = 1, 12 do votes.nboost["Твинк" .. v .. "-Свежеватель Душ"] = { 5, NOW - 3600 + v } end

-- рейтинг очков: 25 игроков; «Хвастун» приписал себе «Легенду подиума» (top_1) в маске
local B32 = "0123456789abcdefghijklmnopqrstuv"
local function Mask(nums)
	local chars = {}
	for _, num in ipairs(nums) do
		local idx = math.floor((num - 1) / 5) + 1
		chars[idx] = (chars[idx] or 0) + 2 ^ ((num - 1) % 5)
	end
	local out = {}
	for i = 1, #chars > 0 and math.max(unpack((function() local k = {} for i in pairs(chars) do k[#k + 1] = i end return k end)())) or 0 do
		local v = chars[i] or 0
		out[i] = B32:sub(v + 1, v + 1)
	end
	return table.concat(out)
end
for i = 1, 25 do
	scores["Игрок" .. i .. "-Гордунни"] = { points = 0, earned = 1, mask = Mask({ 1 }), t = NOW - DAY }
end
scores["Хвастун-Гордунни"] = { points = 0, earned = 2, mask = Mask({ 1, 39 }), t = NOW - DAY } -- 39 = top_1
-- первооткрыватель: hid_neighbours (num 59, его проверяет аддон) найден раньше у Игрок1, позже у Игрок2
local function Pad36(n, w)
	local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", ""
	for _ = 1, w do o = d:sub(n % 36 + 1, n % 36 + 1) .. o; n = math.floor(n / 36) end
	return o
end
local EPOCH = 1767225600
local hourEarly, hourLate = math.floor((NOW - 10 * DAY - EPOCH) / 3600), math.floor((NOW - 5 * DAY - EPOCH) / 3600)
scores["Игрок1-Гордунни"] = { points = 0, earned = 2, mask = Mask({ 1, 59 }), t = NOW - DAY, found = Pad36(59, 2) .. Pad36(hourEarly, 3) }
scores["Игрок2-Гордунни"] = { points = 0, earned = 2, mask = Mask({ 1, 59 }), t = NOW - DAY, found = Pad36(59, 2) .. Pad36(hourLate, 3) }

-- Запись SavedVariables
local function Ser(v, indent)
	indent = indent or ""
	if type(v) == "table" then
		local out = { "{" }
		for k, x in pairs(v) do
			local key = type(k) == "number" and ("[" .. k .. "]") or ("[" .. string.format("%q", k) .. "]")
			out[#out + 1] = indent .. "\t" .. key .. " = " .. Ser(x, indent .. "\t") .. ","
		end
		out[#out + 1] = indent .. "}"
		return table.concat(out, "\n")
	elseif type(v) == "string" then
		return string.format("%q", v)
	end
	return tostring(v)
end
local f = assert(io.open(svPath, "w"))
local modSources = {
	"1|" .. NOW .. "|ruRU;v:244267:4567:2248:452:601:748::Торговка Ала;d:5000:77:2248:100:200:Волк",
	"1|" .. NOW .. "|enUS;v:244267:4567:2248:452:601:748::Vendor Ala",
	"1|" .. NOW .. "|ruRU;v:244267:9999:2248:::0::Редкий",
}
local presence = { ["Тихоня-Гордунни"] = { "H", NOW - 2 * DAY }, ["Давний-Гордунни"] = { "A", NOW - 40 * DAY } }
f:write("TransmogHubDB = " .. Ser({ net = { sets = sets, votes = votes, scores = scores, tagFlags = tagFlags, presence = presence }, moderator = true, modSources = modSources }) .. "\n")
f:close()

-- Сборка (первый раз — без прошлого чарта)
os.remove(outPath)
-- выдуманная закрытая папка тайн: настоящие условия тесты не знают
local secretsDir = tmp .. "_secrets"
os.execute("mkdir -p '" .. secretsDir .. "'")
local sf = assert(io.open(secretsDir .. "/hidden.lua", "w"))
sf:write('return { hid_lichking = { probe = "tags", conds = { "c_red,raid_midnight" }, name = "Т", desc = "Т" },',
	' hid_murloc = { probe = "word", conds = { "несуществующееслово" }, name = "Т", desc = "Т" } }\n')
sf:close()
sf = assert(io.open(secretsDir .. "/master.txt", "w")); sf:write("0123456789abcdef0123\n"); sf:close()

local bundledPath = tmp .. "_bundled.lua"
local sourcesPath = tmp .. "_sources.lua"
os.remove(sourcesPath)
local function Build(t)
	arg = { dir, svPath, outPath, tostring(t), secretsDir, bundledPath, sourcesPath }
	dofile(dir .. "/tools/charts/build.lua")
end
Build(NOW)

TransmogHub_Charts = nil
dofile(outPath)
local c = assert(TransmogHub_Charts, "chart written")
-- каталог: образы чарта есть, накрученного нет, у образов итог оценки без имён голосовавших
TransmogHub_Bundled = nil
dofile(bundledPath)
local b = assert(TransmogHub_Bundled, "catalog written")
local inCatalog = {}
for _, set in ipairs(b.sets) do
	inCatalog[set.id] = set
	assert(set.items and set.author and set.created, "catalog set complete: " .. set.id)
	assert(not set.votes, "no per-voter votes in catalog")
end
for _, id in ipairs(c.top) do assert(inCatalog[id], "charted set in catalog: " .. id) end
assert(not inCatalog.nboost, "boosted set not in catalog")
assert(inCatalog[c.top[1]].rating and inCatalog[c.top[1]].rating.n > 0, "catalog keeps rating summary")
-- где найти: находки сложены, самый частый источник первым, имена на обоих языках
TransmogHub_Sources = nil
dofile(sourcesPath)
local srcItem = assert(TransmogHub_Sources.items[244267], "sources written")
assert(srcItem[1][1] == "v" and srcItem[1][2] == 4567 and srcItem[1].n == 2, "most reported vendor first")
assert(srcItem[1][6].ruRU == "Торговка Ала" and srcItem[1][6].enUS == "Vendor Ala" and srcItem[1][7] == 748, "names per language and price")
assert(TransmogHub_Sources.items[5000][1][1] == "d", "drop recorded")
assert(not io.open(sourcesPath):read("*a"):find("Гордунни", 1, true), "no player names in sources")
-- повторная сборка с тем же журналом находки не удваивает
Build(NOW)
TransmogHub_Sources = nil
dofile(sourcesPath)
assert(TransmogHub_Sources.items[244267][1].n == 2, "rebuild does not double counts")
-- телефонная книга: авторы и игроки рейтинга с фракцией, без голосовавших
assert(type(b.peers) == "table" and #b.peers > 0, "phonebook written")
local inBook = {}
for _, p in ipairs(b.peers) do inBook[p[1]] = p end
assert(inBook["Игрок1-Гордунни"], "ranking players seen this week")
assert(not inBook["Автор1-Гордунни"], "authors silent for over two weeks are left out")
assert(not inBook["Голос1-Гордунни"], "voters are not published")
assert(inBook["Тихоня-Гордунни"] and inBook["Тихоня-Гордунни"][2] == "H", "players who only checked in, with faction")
assert(not inBook["Давний-Гордунни"], "old check-ins left out")
local src = io.open(bundledPath):read("*a")
assert(not src:find("votes", 1, true), "no vote lists in catalog file")
assert(c.t == NOW and c.date)
assert(#c.top == 40, "40 honest sets charted, boosted one excluded: " .. #c.top)
for _, id in ipairs(c.top) do assert(id ~= "nboost", "boosted set not in chart") end
assert(c.top[1]:match("^nset%d$"), "best sets on top: " .. c.top[1])
assert(c.tags.raid_midnight and #c.tags.raid_midnight == 11, "raid tag list without the disputed one")
for _, id in ipairs(c.tags.raid_midnight) do assert(id ~= "nset1", "disputed tag excluded") end
-- награды
local first = c.top[1]:gsub("nset", "")
local author1 = "Автор" .. first .. "-Гордунни"
assert(c.awards[author1] and c.awards[author1].top_1 == 1, "top-1 award with tier 1 (40 sets)")
assert(c.awards[author1].pct_top_25 == 1, "top-25% award")
assert(not (c.awards["Хвастун-Гордунни"] or {}).top_1, "claimed but not awarded")
assert(c.firsts.hid_neighbours[1] == "Игрок1-Гордунни", "earliest finder is first")
assert(c.awards["Игрок1-Гордунни"].first_find_1 == 1, "first finder award")
-- скрытое за теги выдал чарт: условие в чарте не видно, только награда, образ и ключ
assert(c.firsts.hid_lichking[1] == "Автор10-Гордунни", "first: earliest approved set with the active tags (nset1 tag disputed)")
assert(c.awards["Автор10-Гордунни"].hid_lichking == 1 and c.awardSets["Автор10-Гордунни"].hid_lichking == "nset10", "server secret awarded")
assert(not (c.awards["Автор1-Гордунни"] or {}).hid_lichking, "disputed tag does not count")
assert(c.secretKeys.hid_lichking and not c.secretKeys.hid_murloc, "key published only after a find")
local chartText = io.open(outPath):read("*a")
assert(not chartText:find("raid_midnight\"? *,") and not chartText:find("c_red,raid"), "condition not in the chart")
-- очки: «Хвастун» не получил 100 за top_1
local pts = {}
for _, e in ipairs(c.board) do pts[e[1]] = e[2] end
assert(pts["Хвастун-Гордунни"] == pts["Игрок3-Гордунни"], "fake top_1 gives no points: " .. tostring(pts["Хвастун-Гордунни"]))
assert(pts["Игрок1-Гордунни"] > pts["Игрок2-Гордунни"], "first finder gets more")

-- Повторная сборка: первооткрыватель закреплён, даже если кто-то заявит время раньше
scores["Игрок2-Гордунни"].found = Pad36(59, 2) .. Pad36(hourEarly - 100, 3)
f = assert(io.open(svPath, "w"))
f:write("TransmogHubDB = " .. Ser({ net = { sets = sets, votes = votes, scores = scores, tagFlags = tagFlags }, moderator = true }) .. "\n")
f:close()
Build(NOW + DAY)
TransmogHub_Charts = nil
dofile(outPath)
assert(TransmogHub_Charts.firsts.hid_neighbours[1] == "Игрок1-Гордунни", "locked first finder")
assert(TransmogHub_Charts.awards[author1].top_1 == 1, "awards accumulate")

-- Зал славы: первый в «Лучших» три разные недели — уходит в зал и из мест
local leader = TransmogHub_Charts.top[1]
Build(NOW + 8 * DAY); Build(NOW + 15 * DAY)
TransmogHub_Charts = nil
dofile(outPath)
local h = TransmogHub_Charts.hof[leader]
assert(h and h[1] >= 3 and h[4], "three weekly firsts -> hall of fame")
for _, id in ipairs(TransmogHub_Charts.top) do assert(id ~= leader, "hall set is out of the top list") end
local hallAward = false
for _, list in pairs(TransmogHub_Charts.awards) do if list.hall_1 then hallAward = true end end
assert(hallAward, "hall achievement awarded")

-- снимок базы из другого региона (Америка): его образы и отметки «в сети» — в общем
-- каталоге с пометкой региона (стучаться аддон будет только к своему региону)
local usPath = tmp .. "_us.lua"
local uf = assert(io.open(usPath, "w"))
uf:write("TransmogHubDB = " .. Ser({ region = 1, net = {
	sets = { nus1 = { id = "nus1", author = "Янки-Area52", name = "Ковбой", desc = "", race = 1, sex = 0, class = "HUNTER",
		created = NOW + 15 * DAY - DAY, tags = {}, items = { [1] = { 111 } } } },
	votes = {}, scores = {}, presence = { ["Янки-Area52"] = { "A", NOW + 15 * DAY - DAY } } } }) .. "\n")
uf:close()
arg = { dir, svPath, outPath, tostring(NOW + 15 * DAY), secretsDir, bundledPath, sourcesPath, "us=" .. usPath }
dofile(dir .. "/tools/charts/build.lua")
TransmogHub_Bundled = nil
dofile(bundledPath)
local usSet, usPeer, euPeer
for _, set in ipairs(TransmogHub_Bundled.sets) do if set.id == "nus1" then usSet = set end end
for _, p in ipairs(TransmogHub_Bundled.peers) do
	if p[1] == "Янки-Area52" then usPeer = p elseif p[1] == "Тихоня-Гордунни" then euPeer = p end
end
assert(usSet and usSet.region == "us", "set from the other region in the catalog, tagged")
assert(usPeer and usPeer[4] == "us", "check-in from the other region tagged")
assert(not euPeer or euPeer[4] == nil, "own region untagged")
os.remove(usPath)

os.remove(svPath); os.remove(outPath); os.remove(tmp)
os.execute("rm -rf '" .. secretsDir .. "'")
print("CHARTS OK")
