-- Закрытая статистика Transmog Hub: интерактивная страница с графиками.
--   lua5.1 tools/stats/dashboard.lua <папка аддона> <папка закрытого репозитория> <выход .html>
--
-- Берёт данные закрытого репозитория (снимки stats, статистику тегов, жалобы, решения,
-- обращения, письма, разбор, предложения тегов, нажатия) и собирает одну HTML-страницу
-- (шаблон tools/stats/dashboard.html, графики — Chart.js). Страница лежит только
-- в закрытом репозитории: открыть — скачать и открыть в браузере.
-- Имён пожаловавшихся, авторов писем и обращений и их текстов на странице НЕТ — только
-- количества по дням и причинам. Условия и тексты скрытых достижений не берутся.
local dir, reportsDir, outPath = arg[1], arg[2], arg[3]
assert(dir and reportsDir and outPath, "usage: dashboard.lua <addon dir> <reports repo dir> <out.html>")

local env = dofile(dir .. "/tools/charts/env.lua")
env.install(os.time())
local TH = env.load(dir)

---------------------------------------------------------------------------
-- Чтение
---------------------------------------------------------------------------
local function Lines(path)
	local f = io.open(path)
	if not f then return {} end
	local out = {}
	for line in f:lines() do
		line = line:gsub("\r$", "")
		if line ~= "" then out[#out + 1] = line end
	end
	f:close()
	return out
end

local function Split(line)
	local out = {}
	for field in (line .. "|"):gmatch("([^|]*)|") do out[#out + 1] = field end
	return out
end

local function Day(t)
	t = tonumber(t)
	return t and os.date("!%Y-%m-%d", t) or nil
end

local function StatFiles()
	local p = io.popen('ls "' .. reportsDir .. '/reports/stats" 2>/dev/null')
	local out = {}
	for name in p:lines() do
		if name:match("^%d%d%d%d%-%d%d%.tsv$") then out[#out + 1] = reportsDir .. "/reports/stats/" .. name end
	end
	p:close()
	table.sort(out)
	return out
end

---------------------------------------------------------------------------
-- Снимки сети: S (сводка дня), A (достижения), T (погасшие теги), V (образы)
---------------------------------------------------------------------------
local days, achByDay, disputedByDay, topByDay = {}, {}, {}, {}
for _, path in ipairs(StatFiles()) do
	for _, line in ipairs(Lines(path)) do
		local f = Split(line)
		local kind, d = f[2], f[3]
		if kind == "S" then
			local dist = {}
			for n in (f[13] or ""):gmatch("%d+") do dist[#dist + 1] = tonumber(n) end
			days[d] = { d = d, sets = tonumber(f[4]), rated = tonumber(f[5]), charted = tonumber(f[6]),
				sus = tonumber(f[7]), votes = tonumber(f[8]), voters = tonumber(f[9]), players = tonumber(f[10]),
				avg = tonumber(f[11]), dist = dist, known = tonumber(f[14]), authors = tonumber(f[15]),
				active = tonumber(f[16]), minVotes = tonumber(f[17]) }
		elseif kind == "A" then
			achByDay[d] = achByDay[d] or {}
			achByDay[d][f[4]] = { tonumber(f[5]) or 0, tonumber(f[6]) or 0 }
		elseif kind == "T" then
			disputedByDay[d] = disputedByDay[d] or {}
			disputedByDay[d][f[6]] = (disputedByDay[d][f[6]] or 0) + 1
		elseif kind == "V" then
			topByDay[d] = topByDay[d] or {}
			local list = topByDay[d]
			list[#list + 1] = { id = f[4], author = f[5], n = tonumber(f[6]), avg = tonumber(f[7]),
				score = tonumber(f[8]), trend = tonumber(f[9]), flag = f[11] }
		end
	end
end
local dayList = {}
for _, v in pairs(days) do dayList[#dayList + 1] = v end
table.sort(dayList, function(a, b) return a.d < b.d end)
local lastDay = dayList[#dayList] and dayList[#dayList].d

-- достижения: последний снимок
local achievements = {}
local function LatestKey(t)
	local best
	for k in pairs(t) do if not best or k > best then best = k end end
	return best
end
local achDay = LatestKey(achByDay)
if achDay then
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		local v = achByDay[achDay][a.id]
		-- скрытые — без названия: тексты тайн на страницу не попадают
		local name = a.stat == "secret" and ("Скрытое (" .. a.id .. ")") or a.name
		achievements[#achievements + 1] = { id = a.id, name = name, rarity = a.rarity,
			count = v and v[1] or 0, players = v and v[2] or 0, shame = a.shame or false }
	end
end

-- самые оцениваемые образы последнего дня (авторы и так видны всем в аддоне)
local top = {}
if lastDay and topByDay[lastDay] then
	local list = topByDay[lastDay]
	table.sort(list, function(a, b) return (a.score or 0) > (b.score or 0) end)
	for i = 1, math.min(#list, 15) do top[i] = list[i] end
end

---------------------------------------------------------------------------
-- Теги
---------------------------------------------------------------------------
local tagSeries = {}
for _, line in ipairs(Lines(reportsDir .. "/reports/tag-usage.tsv")) do
	local f = Split(line)
	local counts = {}
	for key, n in (f[4] or ""):gmatch("([%w_]+)=(%d+)") do counts[key] = tonumber(n) end
	tagSeries[#tagSeries + 1] = { d = f[2], total = tonumber(f[3]), counts = counts }
end
table.sort(tagSeries, function(a, b) return a.d < b.d end)
local tagGroups = {}
for _, g in ipairs(TH.TAG_GROUPS) do
	local keys = {}
	for _, t in ipairs(g.tags) do keys[#keys + 1] = t[1] end
	tagGroups[#tagGroups + 1] = { name = g.name, keys = keys }
end
local disputed = {}
for d, list in pairs(disputedByDay) do
	for tag, n in pairs(list) do disputed[#disputed + 1] = { d = d, tag = tag, n = n } end
end

-- предложенные теги: текст, сколько разных персонажей, последняя дата (без имён)
local suggested = {}
do
	local byText = {}
	for _, line in ipairs(Lines(reportsDir .. "/reports/tags.tsv")) do
		local f = Split(line)
		local e = byText[f[2]]
		if not e then
			e = { text = f[2], who = {}, people = 0, last = 0 }
			byText[f[2]] = e
			suggested[#suggested + 1] = e
		end
		if not e.who[f[3]] then e.who[f[3]] = true; e.people = e.people + 1 end
		e.last = math.max(e.last, tonumber(f[4]) or 0)
	end
	for _, e in ipairs(suggested) do e.who = nil; e.last = Day(e.last) end
	table.sort(suggested, function(a, b) if a.people ~= b.people then return a.people > b.people end return a.text < b.text end)
end

---------------------------------------------------------------------------
-- Модерация: только количества по дням
---------------------------------------------------------------------------
local mod = { reports = {}, decisions = {}, appeals = {}, ideas = {}, review = {} }
local function Bump(t, d, key)
	if not d then return end
	t[d] = t[d] or {}
	t[d][key] = (t[d][key] or 0) + 1
end
local reportIds = {}
for _, line in ipairs(Lines(reportsDir .. "/reports/reports.tsv")) do
	local f = Split(line)
	Bump(mod.reports, Day(f[5]), f[4] or "?")
	reportIds[f[2]] = true
end
for _, line in ipairs(Lines(reportsDir .. "/reports/decisions.tsv")) do
	local f = Split(line)
	Bump(mod.decisions, Day(f[4]), f[2] or "?")
end
for _, line in ipairs(Lines(reportsDir .. "/reports/appeals.tsv")) do
	local f = Split(line)
	Bump(mod.appeals, Day(f[3]), "appeal")
end
for _, line in ipairs(Lines(reportsDir .. "/reports/ideas.tsv")) do
	local f = Split(line)
	Bump(mod.ideas, Day(f[3]), f[4] or "?")
end
-- разбор: review/log.tsv — цель|решение|дата|пояснение
local reviewed = {}
for _, line in ipairs(Lines(reportsDir .. "/review/log.tsv")) do
	local f = Split(line)
	if f[3] and f[3]:match("^%d%d%d%d%-%d%d%-%d%d") then Bump(mod.review, f[3]:sub(1, 10), f[2] or "?") end
	reviewed[f[1]] = true
end
-- жалобы, по которым ещё нет записи в разборе
local waiting = 0
for id in pairs(reportIds) do if not reviewed[id] then waiting = waiting + 1 end end

---------------------------------------------------------------------------
-- Нажатия на кнопки
---------------------------------------------------------------------------
local usage = {}
do
	local names, total = {}, {}
	for _, line in ipairs(Lines(reportsDir .. "/reports/usage-names.tsv")) do
		local f = Split(line)
		names[f[2]] = f[3]
	end
	local reportsN = 0
	for _, line in ipairs(Lines(reportsDir .. "/reports/usage.tsv")) do
		reportsN = reportsN + 1
		local text = line:match("^1|%d+|(.*)$") or ""
		for code, n in text:gmatch("(%w+)=(%d+)") do total[code] = (total[code] or 0) + tonumber(n) end
	end
	for code, n in pairs(total) do usage[#usage + 1] = { name = names[code] or ("код " .. code), n = n } end
	table.sort(usage, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.name < b.name end)
	usage.reports = reportsN
end

---------------------------------------------------------------------------
-- JSON и запись
---------------------------------------------------------------------------
local function Json(v)
	local t = type(v)
	if t == "nil" then return "null" end
	if t == "boolean" or t == "number" then
		if t == "number" and (v ~= v or v == math.huge or v == -math.huge) then return "null" end
		return tostring(v)
	end
	if t == "string" then
		return '"' .. v:gsub('[%c"\\]', function(c)
			local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
			return map[c] or string.format("\\u%04x", c:byte())
		end):gsub("</", "<\\/") .. '"'
	end
	-- массив: ключи 1..n
	local n = #v
	local isArray = n > 0 or next(v) == nil
	for k in pairs(v) do
		if type(k) ~= "number" or k < 1 or k > n or k % 1 ~= 0 then isArray = false break end
	end
	local out = {}
	if isArray then
		for i = 1, n do out[i] = Json(v[i]) end
		return "[" .. table.concat(out, ",") .. "]"
	end
	local keys = {}
	for k in pairs(v) do keys[#keys + 1] = tostring(k) end
	table.sort(keys)
	for _, k in ipairs(keys) do
		local val = v[k]
		if val == nil then val = v[tonumber(k)] end
		out[#out + 1] = Json(k) .. ":" .. Json(val)
	end
	return "{" .. table.concat(out, ",") .. "}"
end

local data = {
	generated = os.date("!%Y-%m-%d %H:%M UTC"),
	days = dayList,
	tagSeries = tagSeries,
	tagLabels = TH.TAG_LABEL,
	tagGroups = tagGroups,
	disputed = disputed,
	suggested = suggested,
	achievements = achievements,
	achDay = achDay,
	rarity = (function()
		local r = {}
		for q, v in pairs(TH.RARITY) do r[tostring(q)] = v.name end
		return r
	end)(),
	top = top,
	mod = mod,
	waiting = waiting,
	usage = usage,
	usageReports = usage.reports,
}
usage.reports = nil

local tf = assert(io.open(dir .. "/tools/stats/dashboard.html"))
local html = tf:read("*a")
tf:close()
local s, e = html:find("/*DATA*/null", 1, true)
assert(s, "в шаблоне нет /*DATA*/null")
html = html:sub(1, s - 1) .. Json(data) .. html:sub(e + 1)
local f = assert(io.open(outPath, "w"))
f:write(html)
f:close()
print(string.format("Статистика: дней %d, снимков тегов %d, жалоб %d дн., кнопок %d -> %s",
	#dayList, #tagSeries, (function() local n = 0 for _ in pairs(mod.reports) do n = n + 1 end return n end)(), #usage, outPath))
