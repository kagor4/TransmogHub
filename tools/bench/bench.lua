-- Нагрузочный замер логики аддона на синтетической базе (без игры).
--   lua5.1 tools/bench/bench.lua <папка аддона> [образов=3000] [голосов=100000] [игроков в рейтинге=5000] [--check]
--
-- Время — в обычном Lua 5.1; в игре порядок тот же. Главное — «повторный пересчёт»
-- и «проверка достижений»: они идут после каждой пачки сообщений из сети, и если
-- они долгие, игра подвисает во время синхронизации.
-- --check: выйти с ошибкой, если что-то медленнее порогов LIMITS (для автопроверки;
-- пороги с запасом в несколько раз — сервер проверки медленнее и нестабилен).
local dir = arg[1] or "."
local NSETS, NVOTES, NSCORES = tonumber(arg[2]) or 3000, tonumber(arg[3]) or 100000, tonumber(arg[4]) or 5000
local check = false
for i = 1, #arg do if arg[i] == "--check" then check = true end end

local LIMITS = { -- мс; при базе 3000 / 100 000 / 5000 сейчас примерно 6, 45, 20, 55
	reload = 60,
	query = 250,
	recommended = 250,
	board = 150,
	achievements = 350,
}

local env = dofile(dir .. "/tools/charts/env.lua")
local NOW = 1792000000
env.install(NOW)
math.randomseed(1)
local TH = env.load(dir)

-- синтетическая сеть
local TAGS = { "c_red", "c_blue", "pirate", "mage", "plate", "cloth", "elegant", "dark", "c_pink", "warrior" }
local NAMES = { "Пиратский капитан", "Ледяная королева", "Тёмный рыцарь", "Лесная жрица", "Розовый тролль", "Песчаный странник" }
local sets, votes, scores = {}, {}, {}
for i = 1, NSETS do
	local items = {}
	for _, s in ipairs({ 1, 3, 4, 5, 6, 7, 8, 9, 10, 15, 16, 17, 19 }) do items[s] = { 100000 + math.random(1, 90000), 0, 0 } end
	sets["n" .. i] = { id = "n" .. i, author = "Автор" .. (i % 1500) .. "-Сервер" .. (i % 20), name = NAMES[i % #NAMES + 1] .. " " .. i,
		desc = "Описание образа номер " .. i .. ", немного текста про вещи и настроение.", race = i % 30 + 1, sex = i % 2,
		class = "MAGE", created = NOW - math.random(1, 200) * 86400,
		tags = { TAGS[i % 10 + 1], TAGS[(i * 3) % 10 + 1], TAGS[(i * 7) % 10 + 1] }, items = items }
	votes["n" .. i] = {}
end
for v = 1, NVOTES do
	local id = "n" .. math.random(1, NSETS)
	votes[id]["Голос" .. math.random(1, 20000) .. "-Сервер" .. (v % 20)] = { math.random(1, 5), NOW - math.random(1, 100 * 86400) }
end
for i = 1, NSCORES do
	scores["Игрок" .. i .. "-Сервер" .. (i % 20)] = { points = math.random(0, 3000), earned = math.random(1, 60),
		mask = "vvvvvvvvvvvvvvvvvvv", t = NOW - math.random(1, 20) * 86400 }
end
TransmogHubDB = { net = { sets = sets, votes = votes, scores = scores } }
TH:ADDON_LOADED("TransmogHub")
-- без интерфейса: всплывающие окна и чат не нужны
TH.GetPlayableRaces = function() return {} end
TH.ShowAchievementToast = function() end
TH.UI = false
TH.SchedulePublishScore = function() end
TH.Print = function() end

-- выравнивание по буквам, а не байтам (кириллица — 2 байта)
local function Pad(s, w)
	local n = #s:gsub("[\128-\191]", "")
	return s .. string.rep(" ", math.max(1, w - n))
end

local results, failed = {}, {}
local function Measure(key, label, f, n)
	n = n or 5
	local t0 = os.clock()
	for _ = 1, n do f() end
	local ms = (os.clock() - t0) / n * 1000
	print(Pad(label, 36) .. string.format("%8.1f мс", ms))
	results[key] = ms
	if check and LIMITS[key] and ms > LIMITS[key] then
		failed[#failed + 1] = string.format("%s: %.1f мс > %d мс", label, ms, LIMITS[key])
	end
end

print(string.format("База: образов %d, голосов %d, игроков в рейтинге %d", NSETS, NVOTES, NSCORES))
Measure("first", "первый пересчёт ленты (один раз)", function() TH.Net.dirty = true; TH:LoadFeed() end, 1)
Measure("reload", "повторный пересчёт (после сети)", function() TH.Net.dirty = true; TH:LoadFeed() end)
Measure("query", "список «Лучшие»", function() TH:QuerySets("top", { tags = {} }) end)
Measure("trending", "список «В тренде»", function() TH:QuerySets("trending", { tags = {} }) end)
Measure("recommended", "список «Рекомендуемые»", function() TH:QuerySets("top", { tags = {}, sort = "recommended" }) end)
Measure("threshold", "порог чарта (раз в 10 минут)", function() TH:ComputeChartThreshold() end)
Measure("board", "таблица лидеров", function() TH:GetLeaderboard(false, "") end)
Measure("achievements", "проверка достижений", function() TH:CheckAchievements() end, 3)

collectgarbage("collect")
print(Pad("память (вся база в Lua)", 36) .. string.format("%8.1f МБ", collectgarbage("count") / 1024))

-- размер SavedVariables (примерно как пишет игра)
local function Ser(v, out)
	local t = type(v)
	if t == "table" then
		out[#out + 1] = "{"
		for k, x in pairs(v) do
			out[#out + 1] = type(k) == "number" and ("[" .. k .. "]=") or ("[" .. string.format("%q", k) .. "]=")
			Ser(x, out); out[#out + 1] = ",\n"
		end
		out[#out + 1] = "}"
	elseif t == "string" then out[#out + 1] = string.format("%q", v)
	else out[#out + 1] = tostring(v) end
end
local out = {}; Ser(TH.db.net, out)
print(Pad("файл сохранения (примерно)", 36) .. string.format("%8.1f МБ", #table.concat(out) / 1048576))

-- «следующий вход в игру»: заново загруженный аддон с той же базой
local TH2 = env.load(dir)
TH2:ADDON_LOADED("TransmogHub")
local t0 = os.clock(); TH2.Net.dirty = true; TH2:LoadFeed()
print(Pad("пересчёт при следующем входе", 36) .. string.format("%8.1f мс", (os.clock() - t0) * 1000))

if #failed > 0 then
	print("МЕДЛЕННО:\n  " .. table.concat(failed, "\n  "))
	os.exit(1)
end
if check then print("BENCH OK") end
