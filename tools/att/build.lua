-- Источники вещей с обликами из базы AllTheThings (лицензия MIT) — в компактный файл
-- для аддона TransmogHub_Sources (загружается по требованию).
--   lua5.1 tools/att/build.lua <папка AllTheThings> <выходной файл>
-- Берём только s(источник, предмет) — вещи с обликом. Для каждой — до 4 источников:
--   «раздел|место|источник|карта:x:y|цена»
--   раздел: буква категории ATT (Z — зоны, I — подземелья, P — PvP, …)
--   место: I<подземелье> или m<карта>; источник: n<существо>, e<босс>, q<задание>,
--   o<объект>, a<достижение>, p<профессия>, h<заголовок ATT>
--   цена: g<медь>, c<валюта>x<сколько>, i<предмет>x<сколько> через запятую
-- Названия заголовков и объектов ATT — на ruRU/enUS/esES/deDE/frFR (остальное игра назовёт сама).
-- третий аргумент — папка базы ATT: Standard (основная игра, по умолчанию) или Camelot (WoW Forever)
local attDir, out, flavor = arg[1], arg[2], arg[3] or "Standard"
assert(attDir and out, "usage: build.lua <AllTheThings dir> <out.lua> [Standard|Camelot]")
local db = attDir .. "/db/" .. flavor .. "/"

-- Файлы ATT начинаются с BOM — без него
local function LoadFile(path)
	local fh = assert(io.open(path, "rb"))
	local text = fh:read("*a"):gsub("^\239\187\191", "")
	fh:close()
	return assert(loadstring(text, "@" .. path))
end

-- Заглушка: любое поле — вызываемая заглушка (ATT в файлах базы зовёт свои функции)
local function Stub()
	local s = {}
	return setmetatable(s, { __index = function() return Stub() end, __call = function() return 0 end,
		__concat = function(a, b) return (type(a) == "string" and a or "") .. (type(b) == "string" and b or "") end })
end

---------------------------------------------------------------------------
-- Названия заголовков и объектов на трёх языках
---------------------------------------------------------------------------
local LOCALES = { "enUS", "ruRU", "esES", "deDE", "frFR" }
local headerNames, objectNames = {}, {}
for _, loc in ipairs(LOCALES) do
	-- таблицы L (HEADER_NAMES и т.п.) создаём по обращению, недостающие строки — пустые
	local L = setmetatable({}, { __index = function(t, k)
		if type(k) == "string" and k:find("^[A-Z_]+$") and (k:find("NAMES") or k:find("^HEADER_") or k:find("TYPES")
			or k:find("REMAPPING") or k:find("SEASONS") or k:find("EVENTS")) then
			local v = {}; rawset(t, k, v); return v
		end
		return ""
	end })
	-- вызовы игры в названиях — метками, в игре подставим настоящие названия:
	-- {s:заклинание}, {a:достижение}, {c:класс:подкласс}
	local wowapi = setmetatable({
		GetSpellName = function(id) return "{s:" .. tostring(id) .. "}" end,
		GetItemSubClassInfo = function(a, b) return "{c:" .. tostring(a) .. ":" .. tostring(b) .. "}" end,
	}, { __index = function() return function() return "" end end })
	local app = setmetatable({ L = L, WOWAPI = wowapi, DefaultColors = setmetatable({}, { __index = function() return "ffffffff" end }) },
		{ __index = function() return Stub() end })
	local env = setmetatable({ GetLocale = function() return loc end,
		GetAchievementInfo = function(id) return id, "{a:" .. tostring(id) .. "}" end,
		GetSpellInfo = function(id) return "{s:" .. tostring(id) .. "}" end,
	}, { __index = function(_, k)
		local v = _G[k]
		if v ~= nil then return v end
		-- глобальная строка игры (ENCOUNTER_JOURNAL…): помечаем, в игре возьмём её саму
		if type(k) == "string" and k:find("^[A-Z][A-Z0-9_]+$") then return "@" .. k end
		return Stub()
	end })
	local chunk = LoadFile(db .. "LocalizationDB.lua")
	setfenv(chunk, env)
	chunk("AllTheThings", app, {})
	for id, name in pairs(rawget(L, "HEADER_NAMES") or {}) do
		if type(name) == "string" then headerNames[id] = headerNames[id] or {}; headerNames[id][loc] = name end
	end
	for id, name in pairs(rawget(app, "ObjectNames") or {}) do
		if type(name) == "string" then objectNames[id] = objectNames[id] or {}; objectNames[id][loc] = name end
	end
end

---------------------------------------------------------------------------
-- База: узел — таблица полей ATT плюс _k (вид) и _id (номер); дети — в g
---------------------------------------------------------------------------
local KIND = {
	CreateItemSource = "s", CreateNPC = "n", CreateEncounter = "e", CreateInstance = "I", CreateMap = "m",
	CreateQuest = "q", CreateObject = "o", CreateAchievement = "a", CreateProfession = "p",
	CreateHeader = "h", CreateCustomHeader = "h", CreateDifficulty = "d", CreateFilter = "f",
	CreateCharacterClass = "c", CreateExpansion = "x",
}
local categories = {}
local handlers = {}
local app = setmetatable({
	AddEventHandler = function(event, fn) if event == "OnBuildDataCache" then handlers[#handlers + 1] = fn end end,
	L = setmetatable({}, { __index = function() return setmetatable({}, { __index = function() return "" end }) end }),
}, { __index = function(_, name)
	if type(name) == "string" and name:find("^Create") then
		local kind = KIND[name] or "?"
		return function(a, b, c)
			-- узел — сама таблица полей (встроенные функции базы правят её поля)
			local node
			if kind == "s" then
				node = type(c) == "table" and c or {}
				node._item = b
			else
				node = type(b) == "table" and b or (type(c) == "table" and c) or {}
			end
			node._k, node._id = kind, a
			return node
		end
	end
	return Stub()
end })

local CATEGORY = {
	Zones = "Z", Instances = "I", PVP = "P", WorldEvents = "W", ExpansionFeatures = "X", WorldDrops = "D",
	Holidays = "H", Craftables = "C", Character = "K", TradingPost = "T", Delves = "V", Promotions = "R",
	GroupFinder = "G", InGameShop = "S", BlackMarket = "B", Professions = "C", Secrets = "Q", Unsorted = "U",
}
local dbEnv = setmetatable({}, { __index = function(_, k)
	local v = _G[k]
	if v ~= nil then return v end
	return Stub() -- функции игры (GetCVar…): в базе они только для тонкой настройки
end })
for name in pairs(CATEGORY) do
	local path = db .. "Categories/" .. name .. ".lua"
	local exists = io.open(path, "rb")
	if exists then exists:close() end
	local chunk = exists and LoadFile(path) or function() end
	setfenv(chunk, dbEnv)
	chunk("AllTheThings", app)
end
for _, fn in ipairs(handlers) do fn(categories) end

---------------------------------------------------------------------------
-- Обход: для каждой вещи — место, источник, координаты, цена
---------------------------------------------------------------------------
local function FirstCoord(coords)
	if type(coords) ~= "table" then return nil end
	if type(coords[1]) == "table" then return coords[1][3], coords[1][1], coords[1][2] end
	local bestMap
	for map, list in pairs(coords) do
		if type(list) == "table" and type(list[1]) == "table" and (not bestMap or map < bestMap) then bestMap = map end
	end
	if bestMap then return bestMap, coords[bestMap][1][1], coords[bestMap][1][2] end
end

local function Cost(cost)
	if type(cost) ~= "table" then return "" end
	local parts = {}
	for _, c in ipairs(cost) do
		if type(c) == "table" then
			if c[1] == "g" and tonumber(c[2]) then parts[#parts + 1] = "g" .. math.floor(c[2])
			elseif (c[1] == "c" or c[1] == "i") and tonumber(c[2]) then parts[#parts + 1] = c[1] .. c[2] .. "x" .. (tonumber(c[3]) or 1) end
		end
	end
	return table.concat(parts, ",")
end

-- Заголовок по типу вещи («Броня», «Плащи»): внутри только фильтры — о месте ничего не говорит
local function Generic(node)
	local g = type(node.g) == "table" and node.g or node
	if g[1] == nil then return false end
	for _, child in ipairs(g) do
		if type(child) ~= "table" or child._k ~= "f" then return false end
	end
	return true
end

local SOURCE_KIND = { n = true, e = true, q = true, o = true, a = true, p = true }
local items, usedHeaders, usedObjects = {}, {}, {}
local count = 0

local function Record(node, chain, cat)
	local itemID = tonumber(node._item)
	if not itemID then return end
	local place, source, header
	local map, x, y = FirstCoord(node.coords)
	local cost = Cost(node.cost)
	for i = #chain, 1, -1 do
		local a = chain[i]
		local k, id = a._k, tonumber(a._id)
		-- цена набора или контейнера, в котором вещь (до торговца): её и показываем
		if not source and cost == "" and a.cost then cost = Cost(a.cost) end
		if not source and SOURCE_KIND[k] and id and id > 0 then
			source = k .. id
			if k == "o" then usedObjects[id] = true end
		elseif not source and not header and k == "h" and id and headerNames[id] and not Generic(a) then
			header = id
		end
		if not map then map, x, y = FirstCoord(a.coords) end
		if not place then
			if k == "I" and id then place = "I" .. id
			elseif k == "m" and id then place = "m" .. id
			elseif tonumber(a.mapID) then place = "m" .. a.mapID end
		end
	end
	if not source and header then
		source = "h" .. header
		usedHeaders[header] = true
	end
	local coord = ""
	if map and tonumber(x) and tonumber(y) then coord = string.format("%d:%g:%g", map, x, y) end
	local entry = table.concat({ cat, place or "", source or "", coord, cost }, "|")
	local list = items[itemID]
	if not list then list = {}; items[itemID] = list end
	for _, e in ipairs(list) do if e == entry then return end end
	if #list < 4 then list[#list + 1] = entry; count = count + 1 end
end

local function Walk(node, chain, cat)
	if type(node) ~= "table" then return end
	if node._k == "s" then Record(node, chain, cat) end
	-- дети — в g или прямо списком в таблице узла (когда других полей нет)
	local g = type(node.g) == "table" and node.g or (node[1] ~= nil and node) or nil
	if g then
		chain[#chain + 1] = node
		for _, child in ipairs(g) do Walk(child, chain, cat) end
		chain[#chain] = nil
	end
end

for name, letter in pairs(CATEGORY) do
	local root = categories[name]
	if type(root) == "table" then
		if root._k then Walk(root, {}, letter) else for _, n in ipairs(root) do Walk(n, {}, letter) end end
	end
end

---------------------------------------------------------------------------
-- Запись
---------------------------------------------------------------------------
local function Q(s) return string.format("%q", s) end
local ids = {}
for id in pairs(items) do ids[#ids + 1] = id end
table.sort(ids)
local f = assert(io.open(out, "w"))
f:write("-- Источники вещей с обликами: данные AllTheThings (лицензия MIT, см. LICENSE-AllTheThings.txt).\n")
f:write("-- Собирается tools/att/build.lua — руками не править.\n")
f:write("TransmogHub_ATT = { schema = 1, generated = ", tostring(os.time()), ",\n")
local function Names(t, used)
	local keys = {}
	for id in pairs(used) do if t[id] then keys[#keys + 1] = id end end
	table.sort(keys)
	for _, id in ipairs(keys) do
		local n = t[id]
		local parts = {}
		for _, loc in ipairs(LOCALES) do if n[loc] then parts[#parts + 1] = loc .. "=" .. Q(n[loc]) end end
		f:write("[", id, "]={", table.concat(parts, ","), "},\n")
	end
end
f:write("headers = {\n"); Names(headerNames, usedHeaders); f:write("},\n")
f:write("objects = {\n"); Names(objectNames, usedObjects); f:write("},\n")
f:write("items = {\n")
for _, id in ipairs(ids) do f:write("[", id, "]=", Q(table.concat(items[id], ";")), ",\n") end
f:write("} }\n")
f:close()
print(string.format("items: %d, sources: %d, headers: %d", #ids, count, (function() local n = 0 for _ in pairs(usedHeaders) do n = n + 1 end return n end)()))
