-- Официальный чарт Transmog Hub.
--
--   lua5.1 tools/charts/build.lua <папка аддона> <TransmogHub.lua модератора> <выход Data/Charts.lua> [время] [папка secrets] [выход Data/Bundled.lua] [выход Data/Sources.lua] [снимки других регионов]
--
-- Снимки других регионов — «us=путь,…»: базы персонажей модератора в других регионах
-- (сеть у регионов своя). Их образы, оценки и отметки «в сети» добавляются к основному
-- снимку (Европа) с пометкой региона: каталог общий, а стучаться аддон будет только
-- к игрокам своего региона.
--
-- Папка secrets — из закрытого репозитория (hidden.lua и master.txt): по ней чарт
-- выдаёт скрытые достижения за теги и слово в названии. Условия в чарт не попадают.
--
-- Берёт снимок сети из SavedVariables модератора (его выгружает коннектор),
-- загружает логику аддона без игры и считает тем же кодом, что и клиент:
--   * вес голоса: свой образ — 0; голосовавший недавно или оценил меньше
--     3 образов — 0.5; остальные — 1. Твинк ради одной пятёрки почти ничего не весит;
--     систематически занижающий без своих образов — ещё меньше (TH.HarshVoterWeights);
--   * в чарте — образы с весом оценок не меньше порога дня (5% игроков с оценками
--     в день, медиана за неделю, минимум TH.MIN_CHART_VOTES) без подозрения на накрутку;
--   * списки «Лучшие», «В тренде», по тегам; награды за места и долю лучших;
--   * первооткрыватели (закрепляются навсегда при первом расчёте);
--   * рейтинг очков стиля: достижения за места — только по наградам чарта.
-- Награды копятся: из прошлого Data/Charts.lua берётся лучшее.
-- С выходом Data/Bundled.lua ещё и каталог: образы из снимка, которые придут всем
-- с обновлением аддона (видны и там, где рядом никого с аддоном).
-- С выходом Data/Sources.lua — сводка «где найти вещь» из находок игроков (modSources).
local dir, svPath, outPath, nowArg, secretsDir, bundledPath, sourcesPath, extraArg = arg[1], arg[2], arg[3], arg[4], arg[5], arg[6], arg[7], arg[8]
assert(dir and svPath and outPath, "usage: build.lua <addon dir> <SavedVariables> <out> [unix time] [secrets dir]")
if nowArg == "" then nowArg = nil end
if secretsDir == "" then secretsDir = nil end

local env = dofile(dir .. "/tools/charts/env.lua")
local now = tonumber(nowArg) or os.time()
env.install(now)
-- TH_FOREVER=1 — чарт и каталог WoW Forever (ветка forever, снимок клиента _forever_):
-- аддон грузится в режиме Forever (имена «Имя Фамилия», свои тайны и ключи)
local FOREVER = os.getenv("TH_FOREVER") == "1"
if FOREVER then WOW_PROJECT_ID, WOW_PROJECT_CAMELOT = 18, 18 end

-- прошлая сводка источников: находки копятся, журнал модератора ограничен
TransmogHub_Sources = nil
local prevSources = sourcesPath and sourcesPath ~= "" and loadfile(sourcesPath)
if prevSources then prevSources() end
local prevSrc = type(TransmogHub_Sources) == "table" and TransmogHub_Sources.items or {}

-- прошлый чарт (для накопленных наград и закреплённых первооткрывателей)
local prevChunk = loadfile(outPath)
if prevChunk then prevChunk() end
local prev = type(TransmogHub_Charts) == "table" and TransmogHub_Charts or { awards = {}, firsts = {} }

local TH = env.load(dir)
TransmogHub_Charts = nil -- считаем по живым данным, а не по прошлому чарту

-- снимок базы модератора
TransmogHubDB = nil
assert(loadfile(svPath))()
assert(type(TransmogHubDB) == "table", "в файле нет TransmogHubDB")
-- в одном файле — базы сети всех регионов (аддон хранит их по регионам): основная — Европа,
-- остальные добавляются ниже, как снимки других регионов
local REGION_TAG = { [1] = "us", [2] = "kr", [3] = "eu", [4] = "tw", [5] = "cn" }
local otherNets = {} -- { { регион, net } }
local ownRegion -- [имя своего персонажа] = регион, кроме Европы
do
	local raw = TransmogHubDB
	local cur = raw.regions and raw.region or 3
	if cur ~= 3 then
		otherNets[#otherNets + 1] = { REGION_TAG[cur] or tostring(cur), raw.net }
		raw.net = raw.regions[3] and raw.regions[3].net or nil
	end
	for r, saved in pairs(raw.regions or {}) do
		if r ~= 3 and r ~= cur and type(saved) == "table" and saved.net then
			otherNets[#otherNets + 1] = { REGION_TAG[r] or tostring(r), saved.net }
		end
	end
	raw.regions = nil
	-- свои персонажи модератора в других регионах: их отметки «в сети», попавшие в
	-- европейскую базу (до разделения регионов), — с пометкой их региона
	ownRegion = {}
	for name, r in pairs(raw.charRegion or {}) do
		if r ~= 3 and REGION_TAG[r] then ownRegion[name] = REGION_TAG[r] end
	end
end
TH:ADDON_LOADED("TransmogHub")
local db = TH.db
db.hidden = {} -- личные «скрыть» модератора на чарт не влияют

-- снимки других регионов: образы, оценки, очки и отметки «в сети» — к основной базе
local regionOf = {} -- [имя игрока] = регион (для отметок «в сети» и знакомых из каталога)
for tag, path in (extraArg or ""):gmatch("(%a+)=([^,]+)") do
	TransmogHubDB = nil
	local chunk = loadfile(path)
	if chunk then chunk() end
	local other = type(TransmogHubDB) == "table" and TransmogHubDB.net
	TransmogHubDB = db
	if other then otherNets[#otherNets + 1] = { tag, other } end
end
for _, entry in ipairs(otherNets) do
	local tag, other = entry[1], entry[2]
	do
		for id, set in pairs(other.sets or {}) do
			if not db.net.sets[id] and not db.net.tombstones[id] then
				set.region = tag
				db.net.sets[id] = set
			end
		end
		for setId, list in pairs(other.votes or {}) do
			db.net.votes[setId] = db.net.votes[setId] or {}
			for voter, v in pairs(list) do
				local mine = db.net.votes[setId][voter]
				if not mine or (v[2] or 0) > (mine[2] or 0) then db.net.votes[setId][voter] = v end
			end
		end
		for name, sc in pairs(other.scores or {}) do
			local mine = db.net.scores[name]
			if not mine or (sc.t or 0) > (mine.t or 0) then db.net.scores[name] = sc end
			regionOf[name] = tag
		end
		db.net.presence = db.net.presence or {}
		for name, p in pairs(other.presence or {}) do
			db.net.presence[name] = p
			regionOf[name] = tag
		end
	end
end
TH:LoadFeed()
for _, set in ipairs(TH.feed.sets) do
	if set.region and set.author then regionOf[set.author] = set.region end
end
for name, tag in pairs(ownRegion or {}) do regionOf[name] = tag end

local DAY, WEEK = 86400, 7 * 86400

---------------------------------------------------------------------------
-- Вес голосов
---------------------------------------------------------------------------
local voterSets, voterFirst = {}, {}
for _, votes in pairs(db.net.votes) do
	for name, v in pairs(votes) do
		voterSets[name] = (voterSets[name] or 0) + 1
		voterFirst[name] = math.min(voterFirst[name] or math.huge, v[2] or now)
	end
end

-- систематически занижающие без своих образов — тише (тот же расчёт, что в аддоне)
local harsh = TH.HarshVoterWeights(db.net.votes, db.net.sets, db.net.tombstones, now)
local harshCount = 0
for _ in pairs(harsh) do harshCount = harshCount + 1 end

local function Weight(voter, author)
	if voter == author then return 0 end
	local k = harsh[voter] or 1
	if (voterSets[voter] or 0) >= 3 and now - (voterFirst[voter] or now) >= WEEK then return k end
	return 0.5 * k
end

for _, set in ipairs(TH.feed.sets) do
	local votes = db.net.votes[set.id]
	if votes and next(votes) then
		local w, sum, trend, dist = 0, 0, 0, { 0, 0, 0, 0, 0 }
		for name, v in pairs(votes) do
			local k = Weight(name, set.author)
			w, sum = w + k, sum + k * v[1]
			dist[v[1]] = (dist[v[1]] or 0) + 1
			if now - (v[2] or 0) < TH.TREND_DAYS * DAY then trend = trend + k * v[1] end
		end
		set.rating = w > 0 and { avg = sum / w, n = w, dist = dist } or nil
		set.trend = trend
	end
end
TH:ResetSuspicion()

---------------------------------------------------------------------------
-- Списки
---------------------------------------------------------------------------
-- порог чарта на сегодня (клиенты со свежим чартом берут его отсюда)
local minVotes, activeVoters = TH:ComputeChartThreshold(now)
TH.chartThreshold = { day = math.floor(now / 86400), at = now, value = minVotes, median = activeVoters }
local charted = {}
for _, set in ipairs(TH.feed.sets) do
	if TH:IsCharted(set) then charted[#charted + 1] = set end
end
local function ByScore(a, b)
	local sa, sb = TH:GetScore(a), TH:GetScore(b)
	if sa ~= sb then return sa > sb end
	return a.id < b.id
end
local top, trending = {}, {}
for i, set in ipairs(charted) do top[i], trending[i] = set, set end
table.sort(top, ByScore)
table.sort(trending, function(a, b)
	if (a.trend or 0) ~= (b.trend or 0) then return (a.trend or 0) > (b.trend or 0) end
	return ByScore(a, b)
end)

---------------------------------------------------------------------------
-- Зал славы. Неделя — со среды (как еженедельный сброс). Раз в неделю образу
-- засчитывается первое место в «Лучших» и место в топ-10. Трижды первый или
-- 8 недель в топ-10 — образ уходит в Зал славы: его видно и можно оценивать,
-- но в местах, наградах за места и тегах он больше не участвует, а автор
-- получает достижение «Зал славы». Счётчики копятся с прошлых расчётов.
---------------------------------------------------------------------------
local HALL_FIRSTS, HALL_WEEKS = 3, 8
local week = math.floor((now - 6 * DAY) / WEEK) -- 7.01.1970 — среда
local hof = {}
for id, h in pairs(prev.hof or {}) do hof[id] = { h[1], h[2], h[3], h[4] } end
for i = 1, math.min(#top, 10) do
	local set = top[i]
	local h = hof[set.id] or { 0, 0, 0, false }
	hof[set.id] = h
	if not h[4] and h[3] ~= week then
		h[3] = week
		h[2] = h[2] + 1
		if i == 1 then h[1] = h[1] + 1 end
		if h[1] >= HALL_FIRSTS or h[2] >= HALL_WEEKS then h[4] = os.date("!%Y-%m-%d", now) end
	end
end
local inHall = {}
for id, h in pairs(hof) do if h[4] then inHall[id] = h[4] end end
local hallList = {}
local function WithoutHall(list)
	local out = {}
	for _, set in ipairs(list) do
		if inHall[set.id] then
			if list == top then hallList[#hallList + 1] = set end
		else
			out[#out + 1] = set
		end
	end
	return out
end
top, trending = WithoutHall(top), WithoutHall(trending)
-- в зал попадают и образы, которые уже не в чарте: они всё равно в зале
for id in pairs(inHall) do
	local set = TH.byId and TH.byId[id]
	local listed = false
	for _, s in ipairs(hallList) do if s.id == id then listed = true end end
	if set and not listed then hallList[#hallList + 1] = set end
end
local byTag = {}
for _, set in ipairs(top) do -- уже по баллу
	for _, tag in ipairs(TH:GetActiveTags(set)) do -- оспоренные теги не в счёт
		byTag[tag] = byTag[tag] or {}
		table.insert(byTag[tag], set)
	end
end
for tag, list in pairs(byTag) do
	if #list < TH.MIN_TAG_SETS then byTag[tag] = nil end
end

---------------------------------------------------------------------------
-- Награды (копятся с прошлых расчётов)
---------------------------------------------------------------------------
local awards = {}
for name, list in pairs(prev.awards or {}) do
	awards[name] = {}
	for id, v in pairs(list) do awards[name][id] = v end
end
local function Award(name, a, value)
	if not name or value < 1 then return end
	awards[name] = awards[name] or {}
	if value > (awards[name][a.id] or 0) then awards[name][a.id] = value end
end

local function RankAwards(list, stat)
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		if a.stat == stat then
			local pools = TH:GetTierPools(a)
			for i = 1, math.min(#list, a.goal) do Award(list[i].author, a, TH.TierFor(pools, #list)) end
		end
	end
end
RankAwards(top, "topRank")
-- автор образа из Зала славы
for _, set in ipairs(hallList) do
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		if a.stat == "hallOfFame" then Award(set.author, a, 1) end
	end
end
RankAwards(trending, "trendRank")

-- доля лучших в «Лучших»
for _, a in ipairs(TH.ACHIEVEMENTS) do
	if a.stat == "topPct" and #top >= a.minPool then
		local places = math.max(1, math.floor(#top * a.goal / 100))
		for i = 1, math.min(places, #top) do Award(top[i].author, a, 1) end
	end
end

-- места в тегах, в рейдовых тегах и «первый в 5 тегах»
local firstsByAuthor = {}
for tag, list in pairs(byTag) do
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		if a.stat == "tagRank" or (a.stat == "raidTagRank" and TH.RAID_TAGS[tag]) then
			local pools = TH:GetTierPools(a)
			for i = 1, math.min(#list, a.goal) do Award(list[i].author, a, TH.TierFor(pools, #list)) end
		end
	end
	local author = list[1].author
	if author then
		firstsByAuthor[author] = firstsByAuthor[author] or {}
		table.insert(firstsByAuthor[author], #list)
	end
end
for _, a in ipairs(TH.ACHIEVEMENTS) do
	if a.stat == "tagFirsts" then
		for author, sizes in pairs(firstsByAuthor) do
			if #sizes >= a.goal then
				table.sort(sizes, function(x, y) return x > y end)
				Award(author, a, TH.TierFor(TH:GetTierPools(a), sizes[a.goal]))
			end
		end
	end
end

---------------------------------------------------------------------------
-- Скрытые достижения за теги и слово в названии: проверяет только чарт.
-- Засчитывается опубликованный образ с весом оценок 5+, средней от 3.5 и без
-- подозрения на накрутку. Первым считается автор самого раннего такого образа.
---------------------------------------------------------------------------
local secretKeys, awardSets, serverFirsts = {}, {}, {}
for id, k in pairs(prev.secretKeys or {}) do secretKeys[id] = k end
for name, list in pairs(prev.awardSets or {}) do
	awardSets[name] = {}
	for id, setId in pairs(list) do awardSets[name][id] = setId end
end
if secretsDir then
	local hidden = assert(loadfile(secretsDir .. "/hidden.lua"))()
	local mf = assert(io.open(secretsDir .. "/master.txt"))
	local master = mf:read("*l"):gsub("%s", "")
	mf:close()
	local approved = {}
	for _, set in ipairs(TH.feed.sets) do
		local r = set.rating
		if set.author and r and (r.n or 0) >= TH.HIDDEN_MIN_VOTES and (r.avg or 0) >= TH.HIDDEN_MIN_AVG
			and not TH:GetSuspicion(set) then
			approved[#approved + 1] = set
		end
	end
	table.sort(approved, function(a, b)
		if (a.created or 0) ~= (b.created or 0) then return (a.created or 0) < (b.created or 0) end
		return a.id < b.id
	end)
	local function Matches(e, set)
		if e.probe == "tags" then
			local active = {}
			for _, tag in ipairs(TH:GetActiveTags(set)) do active[tag] = true end
			for _, cond in ipairs(e.conds) do
				local all = true
				for tag in cond:gmatch("[^,]+") do
					if not active[tag] then all = false end
				end
				if all then return true end
			end
		elseif e.probe == "word" then
			local name = TH.Lower(set.name or "")
			for _, w in ipairs(e.conds) do
				if name:find(w, 1, true) then return true end
			end
		end
		return false
	end
	for id, e in pairs(hidden) do
		local a = TH.ACHIEVEMENT_BY_ID[id]
		if a and (e.probe == "tags" or e.probe == "word") then
			for _, set in ipairs(approved) do
				if Matches(e, set) then
					Award(set.author, a, 1)
					awardSets[set.author] = awardSets[set.author] or {}
					awardSets[set.author][id] = awardSets[set.author][id] or set.id
					secretKeys[id] = TH.Secret.DeriveKey(master, id)
					serverFirsts[id] = serverFirsts[id] or { set.author, set.created or now }
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Рейтинг очков стиля и первооткрыватели
---------------------------------------------------------------------------
local entries = {}
for name, s in pairs(db.net.scores) do
	if not s.removed and s.mask and not TH:IsPlayerBlocked(name) and not TH:IsBanned(name) then
		entries[#entries + 1] = { name = name, s = s }
	end
end
table.sort(entries, function(a, b) return a.name < b.name end)

-- первооткрыватели: закреплённые не меняются, новые — самое раннее заявленное время
local firsts = {}
for id, f in pairs(prev.firsts or {}) do firsts[id] = { f[1], f[2] } end
for id, f in pairs(serverFirsts) do firsts[id] = firsts[id] or f end
local claims = {}
for _, e in ipairs(entries) do
	for num, t in pairs(TH.DecodeFound(e.s.found)) do
		local a = TH.ACHIEVEMENT_BY_NUM[num]
		-- за серверные тайны времени со слов клиента не верим
		if a and a.hidden and not TH.Secret.IsServer(a.id) and t <= (e.s.t or 0) and TH.MaskHas(e.s.mask, num) and not firsts[a.id] then
			local cur = claims[a.id]
			if not cur or t < cur[2] or (t == cur[2] and e.name < cur[1]) then claims[a.id] = { e.name, t } end
		end
	end
end
for id, c in pairs(claims) do firsts[id] = c end
local firstCount = {}
for _, f in pairs(firsts) do firstCount[f[1]] = (firstCount[f[1]] or 0) + 1 end
for name, n in pairs(firstCount) do
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		if a.stat == "firstFinds" and n >= a.goal then Award(name, a, 1) end
	end
end

-- очки: обычные достижения — по маске, за места — только по наградам чарта
local function Points(e, skipBoard)
	local points = 0
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		if TH:IsChartAchievement(a) then
			local skip = skipBoard and (a.stat == "boardRank" or a.stat == "boardPct")
			local v = not skip and awards[e.name] and awards[e.name][a.id]
			if v then points = points + TH:GetAchievementPoints(a, a.seasonal and v or nil) end
		elseif TH.MaskHas(e.s.mask, a.num) then
			points = points + a.points
		end
	end
	return points
end
local function SortBoard()
	table.sort(entries, function(a, b)
		if a.points ~= b.points then return a.points > b.points end
		return a.name < b.name
	end)
end
for _, e in ipairs(entries) do e.points = Points(e, true) end
SortBoard()
for _, a in ipairs(TH.ACHIEVEMENTS) do
	if a.stat == "boardRank" then
		local pools = TH:GetTierPools(a)
		for i = 1, math.min(#entries, a.goal) do Award(entries[i].name, a, TH.TierFor(pools, #entries)) end
	elseif a.stat == "boardPct" and #entries >= a.minPool then
		local places = math.max(1, math.floor(#entries * a.goal / 100))
		for i = 1, math.min(places, #entries) do Award(entries[i].name, a, 1) end
	end
end
for _, e in ipairs(entries) do e.points = Points(e, false) end
SortBoard()

---------------------------------------------------------------------------
-- Запись
---------------------------------------------------------------------------
local function Q(s) return string.format("%q", s) end
local function SortedKeys(t)
	local keys = {}
	for k in pairs(t) do keys[#keys + 1] = k end
	table.sort(keys)
	return keys
end
local function IdList(list)
	local out = {}
	for i, set in ipairs(list) do out[i] = Q(set.id) end
	return "{ " .. table.concat(out, ", ") .. " }"
end

local lines = {
	"-- Официальный чарт Transmog Hub. Файл создаётся автоматически (tools/charts/build.lua), не правьте руками.",
	"TransmogHub_Charts = {",
	string.format("\tdate = %s,", Q(os.date("!%Y-%m-%d", now))),
	string.format("\tt = %d,", now),
	"\tversion = 1,",
	string.format("\tminVotes = %d,", minVotes),
	string.format("\tactiveVoters = %d,", activeVoters),
	"\ttop = " .. IdList(top) .. ",",
	"\ttrending = " .. IdList(trending) .. ",",
	"\ttags = {",
}
for _, tag in ipairs(SortedKeys(byTag)) do
	lines[#lines + 1] = string.format("\t\t[%s] = %s,", Q(tag), IdList(byTag[tag]))
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\thof = {"
for _, id in ipairs(SortedKeys(hof)) do
	local h = hof[id]
	lines[#lines + 1] = string.format("\t\t[%s] = { %d, %d, %d, %s },", Q(id), h[1], h[2], h[3], h[4] and Q(h[4]) or "false")
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\tboard = {"
for _, e in ipairs(entries) do
	lines[#lines + 1] = string.format("\t\t{ %s, %d },", Q(e.name), e.points)
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\tfirsts = {"
for _, id in ipairs(SortedKeys(firsts)) do
	lines[#lines + 1] = string.format("\t\t[%s] = { %s, %d },", Q(id), Q(firsts[id][1]), firsts[id][2])
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\tsecretKeys = {"
for _, id in ipairs(SortedKeys(secretKeys)) do
	lines[#lines + 1] = string.format("\t\t[%s] = %s,", Q(id), Q(secretKeys[id]))
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\tawardSets = {"
for _, name in ipairs(SortedKeys(awardSets)) do
	local parts = {}
	for _, id in ipairs(SortedKeys(awardSets[name])) do parts[#parts + 1] = string.format("%s = %s", id, Q(awardSets[name][id])) end
	if #parts > 0 then lines[#lines + 1] = string.format("\t\t[%s] = { %s },", Q(name), table.concat(parts, ", ")) end
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "\tawards = {"
for _, name in ipairs(SortedKeys(awards)) do
	local parts = {}
	for _, id in ipairs(SortedKeys(awards[name])) do
		parts[#parts + 1] = string.format("%s = %d", id, awards[name][id])
	end
	if #parts > 0 then
		lines[#lines + 1] = string.format("\t\t[%s] = { %s },", Q(name), table.concat(parts, ", "))
	end
end
lines[#lines + 1] = "\t},"
lines[#lines + 1] = "}"

local f = assert(io.open(outPath, "w"))
f:write(table.concat(lines, "\n"), "\n")
f:close()

---------------------------------------------------------------------------
-- Каталог образов (Data/Bundled.lua): чарт, Зал славы и свежие образы из снимка.
-- Только опубликованные, без блокировок, жалоб, подозрений на накрутку и изгнанных
-- авторов (лента их уже отсеяла). Голоса по именам не переносятся: только итог оценки.
---------------------------------------------------------------------------
local BUNDLE_MAX, BUNDLE_FRESH = 2000, 90 * DAY
-- «Телефонная книга»: игроки с аддоном, бывшие в сети за 2 недели, — новичок стучится к ним.
-- Отметки «я в сети» (их можно отключить), авторы образов и игроки рейтинга; голосовавшие — нет.
local PEERS_MAX, PEERS_FRESH = 300, 14 * DAY
local bundledCount, bundledPeers = 0, 0
if bundledPath and bundledPath ~= "" then
	local pick, picked = {}, {}
	local function Want(set)
		if not set or picked[set.id] or not set.id:match("^n") or not set.author or not set.items then return end
		if TH:GetSuspicion(set) or TH:IsBanned(set.author) then return end
		picked[set.id] = true
		pick[#pick + 1] = set
	end
	for _, id in ipairs(top) do Want(TH.byId[id]) end
	for _, id in ipairs(SortedKeys(hof)) do Want(TH.byId[id]) end
	local fresh = {}
	for _, set in ipairs(TH.feed.sets) do
		if (set.created or 0) >= now - BUNDLE_FRESH then fresh[#fresh + 1] = set end
	end
	table.sort(fresh, function(a, b)
		if (a.created or 0) ~= (b.created or 0) then return (a.created or 0) > (b.created or 0) end
		return a.id < b.id
	end)
	for _, set in ipairs(fresh) do Want(set) end
	while #pick > BUNDLE_MAX do table.remove(pick) end
	table.sort(pick, function(a, b) return a.id < b.id end)

	local function Str(v) return string.format("%q", v) end
	local function Items(items)
		local parts = {}
		for slot = 1, 19 do
			local it = items[slot]
			if it then
				local vals = {}
				for i = 1, 3 do vals[i] = it[i] and tostring(it[i]) or "nil" end
				while vals[#vals] == "nil" do vals[#vals] = nil end
				parts[#parts + 1] = string.format("[%d] = { %s }", slot, table.concat(vals, ", "))
			end
		end
		return "{ " .. table.concat(parts, ", ") .. " }"
	end
	local out = {
		"-- Каталог образов, который приходит вместе с обновлением аддона.",
		"-- Файл собирает tools/charts/build.lua из снимка базы модератора, не правьте руками.",
		"TransmogHub_Bundled = {",
		"\tschema = 1,",
		string.format("\tgenerated = %d,", now),
		"\tsets = {",
	}
	for _, set in ipairs(pick) do
		local tags = {}
		for _, t in ipairs(set.tags or {}) do tags[#tags + 1] = Str(t) end
		local fields = {
			"id = " .. Str(set.id), "name = " .. Str(set.name or ""), "author = " .. Str(set.author),
			"created = " .. tostring(math.floor(set.created or 0)), "tags = { " .. table.concat(tags, ", ") .. " }",
			"items = " .. Items(set.items),
		}
		if set.desc and set.desc ~= "" then fields[#fields + 1] = "desc = " .. Str(set.desc) end
		if set.race then fields[#fields + 1] = "race = " .. tostring(set.race) end
		if set.sex then fields[#fields + 1] = "sex = " .. tostring(set.sex) end
		if set.class then fields[#fields + 1] = "class = " .. Str(set.class) end
		if set.region then fields[#fields + 1] = "region = " .. Str(set.region) end
		local r = set.rating
		if r and (r.n or 0) > 0 then
			local d = r.dist or {}
			fields[#fields + 1] = string.format("rating = { avg = %.3f, n = %d, dist = { %d, %d, %d, %d, %d } }",
				r.avg or 0, r.n, d[1] or 0, d[2] or 0, d[3] or 0, d[4] or 0, d[5] or 0)
		end
		out[#out + 1] = "\t\t{ " .. table.concat(fields, ", ") .. " },"
	end
	out[#out + 1] = "\t},"
	local seen = {}
	for _, set in ipairs(TH.feed.sets) do
		if set.author and set.id:match("^n") then
			local s = seen[set.author] or { t = 0 }
			if (set.created or 0) >= s.t then s.t, s.race = set.created or 0, set.race end
			seen[set.author] = s
		end
	end
	-- отметки «я в сети»: фракция из них надёжнее, чем по расе
	for name, p in pairs(db.net.presence or {}) do
		if type(p) == "table" and p[2] then
			local s = seen[name] or { t = 0 }
			if p[2] > s.t then s.t = p[2] end
			if p[1] == "A" or p[1] == "H" then s.faction = p[1] end
			seen[name] = s
		end
	end
	for name, sc in pairs(db.net.scores or {}) do
		if type(sc) == "table" and not sc.removed and sc.t then
			local s = seen[name] or { t = 0 }
			if sc.t > s.t then s.t = sc.t end
			seen[name] = s
		end
	end
	local peers = {}
	for name, s in pairs(seen) do
		-- имя персонажа: «Имя-Сервер», в Forever — «Имя Фамилия»
		local isChar
		if FOREVER then isChar = name:find("^[^%s%-]+ [^%s%-]+$") else isChar = name:find("-", 1, true) end
		if now - s.t <= PEERS_FRESH and s.t <= now and isChar and not TH:IsBanned(name) then
			peers[#peers + 1] = { name, s.faction or TH.Net.RaceFaction(s.race), s.t }
		end
	end
	table.sort(peers, function(a, b) if a[3] ~= b[3] then return a[3] > b[3] end return a[1] < b[1] end)
	while #peers > PEERS_MAX do table.remove(peers) end
	out[#out + 1] = "\tpeers = {"
	for _, p in ipairs(peers) do
		local region = regionOf[p[1]]
		out[#out + 1] = string.format("\t\t{ %s, %s, %d%s },", Str(p[1]), p[2] and Str(p[2]) or "nil", math.floor(p[3] / DAY) * DAY,
			region and (", " .. Str(region)) or "")
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	bundledPeers = #peers
	local bf = assert(io.open(bundledPath, "w"))
	bf:write(table.concat(out, "\n"), "\n")
	bf:close()
	bundledCount = #pick
end

---------------------------------------------------------------------------
-- Где найти вещь (Data/Sources.lua): находки игроков у торговцев, в добыче и в
-- наградах за задания. Записи «язык;вид:предмет:откуда:зона:x:y:…» из журнала
-- модератора (без имён игроков) складываются с прошлой сводкой; на предмет —
-- до трёх самых частых источников. Имена проверяются тем же фильтром, что и названия.
---------------------------------------------------------------------------
local SRC_PER_ITEM, SRC_MAX_ITEMS = 3, 40000
local sourcesCount = 0
if sourcesPath and sourcesPath ~= "" then
	local items = {} -- [itemID] = { [вид:id] = запись }
	local function Entry(itemID, kind, id)
		items[itemID] = items[itemID] or {}
		local key = kind .. ":" .. id
		local e = items[itemID][key]
		if not e then
			e = { kind = kind, id = id, n = 0, names = {} }
			items[itemID][key] = e
		end
		return e
	end
	local function Num(v) return tonumber(v) end
	local function Add(text)
		local lang, rest = text:match("^(%a%a%a%a);(.*)$")
		if not lang then return end
		for record in rest:gmatch("[^;]+") do
			local kind, item, id, map, x, y, a, b, c = record:match("^(%a):(%d+):(%d+):(%d*):(%d*):(%d*):?([^:]*):?([^:]*):?([^:]*)$")
			if kind and (kind == "v" or kind == "d" or kind == "o" or kind == "q") then
				local e = Entry(tonumber(item), kind, tonumber(id))
				e.n = e.n + 1
				e.map, e.x, e.y = Num(map) or e.map, Num(x) or e.x, Num(y) or e.y
				local name
				if kind == "v" then
					e.price = Num(a) or e.price
					if b:match("^[ci]%d+x%d+$") then e.cost = b end
					name = c
				else
					name = a
				end
				if name and name ~= "" and #name <= 60 and TH:IsTextAllowed(name) then e.names[lang] = name end
			end
		end
	end
	for _, line in ipairs(db.modSources or {}) do
		local text = line:match("^1|%d+|(.*)$")
		if text then Add(text) end
	end
	-- из прошлой сводки — то, чего в журнале уже нет (журнал ограничен); остальное
	-- пересчитано по журналу, иначе находки считались бы каждый день заново
	for itemID, list in pairs(prevSrc) do
		for _, p in ipairs(list) do
			if not (items[itemID] and items[itemID][p[1] .. ":" .. p[2]]) then
				local e = Entry(itemID, p[1], p[2])
				e.map, e.x, e.y, e.price, e.cost = p[3], p[4], p[5], p[7], p[8]
				for lang, name in pairs(type(p[6]) == "table" and p[6] or {}) do e.names[lang] = name end
				e.n = p.n or 1
			end
		end
	end
	local ids = {}
	for itemID in pairs(items) do ids[#ids + 1] = itemID end
	table.sort(ids)
	while #ids > SRC_MAX_ITEMS do table.remove(ids) end
	local out = {
		"-- Где взять вещи с обликами: сводка находок игроков. Собирает tools/charts/build.lua, не правьте руками.",
		"-- items[itemID] = { { вид, id, зона, x, y, имя, медь, цена, n = находок }, … }",
		"-- вид: v — торговец, d — добыча с существа, o — сундук или объект, q — награда за задание.",
		"-- x, y — в тысячных долях карты; имя — { [язык] = текст }.",
		"TransmogHub_Sources = {",
		"\tschema = 1,",
		string.format("\tgenerated = %d,", now),
		"\titems = {",
	}
	local function V(v) return v and tostring(v) or "nil" end
	for _, itemID in ipairs(ids) do
		local list = {}
		for _, e in pairs(items[itemID]) do list[#list + 1] = e end
		table.sort(list, function(a, b)
			if a.n ~= b.n then return a.n > b.n end
			if a.kind ~= b.kind then return a.kind < b.kind end
			return a.id < b.id
		end)
		local parts = {}
		for i = 1, math.min(#list, SRC_PER_ITEM) do
			local e = list[i]
			local names = {}
			for _, lang in ipairs(SortedKeys(e.names)) do names[#names + 1] = lang .. " = " .. Q(e.names[lang]) end
			parts[#parts + 1] = string.format("{ %q, %d, %s, %s, %s, { %s }, %s, %s, n = %d }", e.kind, e.id, V(e.map), V(e.x), V(e.y),
				table.concat(names, ", "), V(e.price), e.cost and Q(e.cost) or "nil", e.n)
		end
		out[#out + 1] = string.format("\t\t[%d] = { %s },", itemID, table.concat(parts, ", "))
	end
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	local sf = assert(io.open(sourcesPath, "w"))
	sf:write(table.concat(out, "\n"), "\n")
	sf:close()
	sourcesCount = #ids
end

print(string.format("Порог чарта: %d оценок (игроков с оценками в день: %d)", minVotes, activeVoters))
print(string.format("Чарт %s: в чарте %d образов, тегов %d, игроков %d, первооткрывателей %d, награждённых %d",
	os.date("!%Y-%m-%d", now), #top, #SortedKeys(byTag), #entries, #SortedKeys(firsts), #SortedKeys(awards)))
if harshCount > 0 then print(string.format("Тише весят голоса %d игроков (систематическое занижение)", harshCount)) end
if bundledPath and bundledPath ~= "" then print(string.format("Каталог: %d образов, телефонная книга: %d игроков", bundledCount, bundledPeers)) end
if sourcesPath and sourcesPath ~= "" then print(string.format("Где найти: %d предметов", sourcesCount)) end
