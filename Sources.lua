local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Где взять вещь — подробнее, чем «Торговец» или «Случайная добыча» (игра аддонам
-- больше ничего не сообщает).
-- 1) AllTheThings, если он установлен: его путь к источнику (зона > торговец, задание…).
-- 2) Встроенная выжимка базы AllTheThings (лицензия MIT) — отдельный аддон
--    TransmogHub_Sources, загружается при первой подсказке. Ставить ATT не нужно.
-- 3) Наблюдения игроков. Аддон замечает вещи с обликом у торговцев, в добыче и в
--    наградах за задания и раз в день отправляет новые находки разработчику:
--    предмет, торговец/существо/задание, зона, координаты и цена — без имени игрока.
--    Сводка приходит всем с обновлением аддона (Data/Sources.lua).
--    Отключить: /thub sources off.
---------------------------------------------------------------------------
local DAY = 86400
local MAX_SEEN, MAX_QUEUE = 5000, 400
local MAX_MESSAGES, MESSAGE_BYTES = 6, 230
local MOD_SOURCES_MAX = 20000
local MAX_LINES = 3

local function Secret(v)
	return issecretvalue and issecretvalue(v)
end

-- Текст в записи: без разделителей записи и полей
local function Field(text)
	if type(text) ~= "string" or Secret(text) then return "" end
	return (text:gsub("[:;|,\t\n]", " "):sub(1, 60))
end

local function NpcID(guid)
	if type(guid) ~= "string" or Secret(guid) then return nil end
	local kind, _, _, _, _, id = strsplit("-", guid)
	if kind == "Creature" or kind == "Vehicle" then return tonumber(id), "d" end
	if kind == "GameObject" then return tonumber(id), "o" end
end

-- Зона и координаты игрока (в тысячных долях карты); в подземельях координат нет
local function Position()
	local map = C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")
	if not map then return "", "", "" end
	local pos = C_Map.GetPlayerMapPosition and C_Map.GetPlayerMapPosition(map, "player")
	local x, y
	if pos then x, y = pos:GetXY() end
	if not x or Secret(x) or x == 0 then return map, "", "" end
	return map, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

-- Вещь с обликом? (для остального источник не нужен)
local function ItemWithLook(link)
	if type(link) ~= "string" or Secret(link) then return nil end
	local itemID = tonumber(link:match("item:(%d+)"))
	if not itemID then return nil end
	local ok, appearanceID = pcall(C_TransmogCollection.GetItemInfo, link)
	if not ok or not appearanceID then return nil end
	return itemID
end

local function Note(record, key)
	local db = TH.db
	if not (db and db.sendSources) then return end
	local today = math.floor(TH.Net.Now() / DAY)
	if db.srcSeen[key] then return end
	db.srcSeen[key] = today
	local queue = db.srcQueue
	queue[#queue + 1] = record
	while #queue > MAX_QUEUE do tremove(queue, 1) end
end

-- Торговец: v:предмет:торговец:зона:x:y:медь:цена в валюте:имя
local function MerchantCost(index)
	local cost = ""
	local n = GetMerchantItemCostInfo and GetMerchantItemCostInfo(index) or 0
	if n > 0 and GetMerchantItemCostItem then
		local _, value, link = GetMerchantItemCostItem(index, 1)
		local cid = type(link) == "string" and link:match("currency:(%d+)")
		local iid = type(link) == "string" and link:match("item:(%d+)")
		if value and (cid or iid) then cost = (cid and "c" .. cid or "i" .. iid) .. "x" .. value end
	end
	return cost
end

local function OnMerchant()
	local npc, kind = NpcID(UnitGUID("npc"))
	if not npc or kind ~= "d" then return end
	local name = Field(UnitName("npc"))
	local map, x, y = Position()
	for i = 1, (GetMerchantNumItems and GetMerchantNumItems() or 0) do
		local itemID = ItemWithLook(GetMerchantItemLink(i))
		if itemID then
			local price = 0
			if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
				local info = C_MerchantFrame.GetItemInfo(i)
				price = info and info.price or 0
			elseif GetMerchantItemInfo then
				price = select(3, GetMerchantItemInfo(i)) or 0
			end
			Note(table.concat({ "v", itemID, npc, map, x, y, price, MerchantCost(i), name }, ":"), "v:" .. itemID .. ":" .. npc)
		end
	end
end

-- Добыча: d:предмет:существо:зона:x:y:имя (o — из сундука или другого объекта)
local function OnLoot()
	local target = UnitGUID("target")
	local map, x, y = Position()
	for slot = 1, (GetNumLootItems and GetNumLootItems() or 0) do
		local itemID = ItemWithLook(GetLootSlotLink(slot))
		local guid = itemID and GetLootSourceInfo and GetLootSourceInfo(slot)
		local id, kind = NpcID(guid)
		if id then
			local name = (guid == target) and Field(UnitName("target")) or ""
			Note(table.concat({ kind, itemID, id, map, x, y, name }, ":"), kind .. ":" .. itemID .. ":" .. id)
		end
	end
end

-- Награда за задание: q:предмет:задание:зона:x:y:название
local function OnQuest()
	local questID = GetQuestID and GetQuestID()
	if not questID or questID == 0 then return end
	local title = Field(GetTitleText and GetTitleText())
	local map, x, y = Position()
	for _, kind in ipairs({ "reward", "choice" }) do
		local n = kind == "reward" and (GetNumQuestRewards and GetNumQuestRewards() or 0)
			or (GetNumQuestChoices and GetNumQuestChoices() or 0)
		for i = 1, n do
			local itemID = ItemWithLook(GetQuestItemLink(kind, i))
			if itemID then
				Note(table.concat({ "q", itemID, questID, map, x, y, title }, ":"), "q:" .. itemID .. ":" .. questID)
			end
		end
	end
end

local handlers = {
	MERCHANT_SHOW = OnMerchant,
	LOOT_OPENED = OnLoot,
	QUEST_DETAIL = OnQuest,
	QUEST_COMPLETE = OnQuest,
}
TH.SourcesTest = handlers

-- Раз в день: новые находки — «ruRU;запись;запись», до шести сообщений
function TH:SendSources(force)
	local db = self.db
	if not (db and db.sendSources and self.Net and self.Net.SendIdea) then return end
	local now = self.Net.Now()
	if not force and now - (db.srcSent or 0) < DAY then return end
	local queue = db.srcQueue
	if #queue == 0 then return end
	local prefix = (GetLocale and GetLocale() or "enUS") .. ";"
	local messages, cur, len, used = {}, {}, #prefix, 0
	for i, record in ipairs(queue) do
		if len + #record + 1 > MESSAGE_BYTES and #cur > 0 then
			messages[#messages + 1] = prefix .. table.concat(cur, ";")
			cur, len = {}, #prefix
			if #messages >= MAX_MESSAGES then break end
		end
		if #record + #prefix <= MESSAGE_BYTES then
			cur[#cur + 1] = record
			len = len + #record + 1
		end
		used = i
	end
	if #cur > 0 and #messages < MAX_MESSAGES then messages[#messages + 1] = prefix .. table.concat(cur, ";") end
	for i, text in ipairs(messages) do
		C_Timer.After(i - 1, function() self.Net:SendIdea("s", text) end)
	end
	for _ = 1, used do tremove(queue, 1) end
	db.srcSent = now
	-- старые отметки «уже видели» не копим
	local count, oldest = 0, nil
	for _, day in pairs(db.srcSeen) do
		count = count + 1
		if not oldest or day < oldest then oldest = day end
	end
	if count > MAX_SEEN then
		for key, day in pairs(db.srcSeen) do
			if day == oldest then db.srcSeen[key] = nil end
		end
	end
end

-- Модератор: находки в журнал, без имени игрока (сводку собирает выпуск каталога)
function TH:LogSources(t, text)
	if not self:IsModeratorClient() then return end
	local log = self.db.modSources
	log[#log + 1] = table.concat({ "1", t, text }, "|")
	while #log > MOD_SOURCES_MAX do tremove(log, 1) end
end

function TH:StartSources()
	if (self.db.srcSent or 0) == 0 then self.db.srcSent = self.Net.Now() end
	if not self.db.sourcesNoticed then
		self.db.sourcesNoticed = true
		self:Print(L["Аддон запоминает, где встречаются вещи с обликами (торговцы, добыча, награды за задания), и раз в день отправляет разработчику — чтобы показывать всем, где их найти. Только предмет, место и цена, без вашего имени. Отключить: /thub sources off"])
	end
	local f = CreateFrame("Frame")
	for event in pairs(handlers) do f:RegisterEvent(event) end
	f:SetScript("OnEvent", function(_, event)
		if not self.db.sendSources then return end
		local ok, err = pcall(handlers[event])
		if not ok and self.ReportError then self:ReportError(err) end
	end)
	C_Timer.After(100, function() self:SendSources() end)
	-- встроенная база источников: подгружаем заранее, не в бою — первая подсказка не подвиснет
	C_Timer.After(20, function()
		if not (InCombatLockdown and InCombatLockdown()) then TH.LoadEmbeddedSources() end
	end)
end

---------------------------------------------------------------------------
-- Показ: строки «где найти» для подсказки вещи
---------------------------------------------------------------------------
local function ZoneName(map)
	local info = map and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(map)
	return info and info.name
end

local function Coords(x, y)
	if not x or not y then return "" end
	return string.format(" (%.1f, %.1f)", x / 10, y / 10)
end

local function CostText(price, cost)
	local parts = {}
	if price and price > 0 and GetCoinTextureString then parts[#parts + 1] = GetCoinTextureString(price) end
	local kind, id, n = (cost or ""):match("^([ci])(%d+)x(%d+)$")
	if kind == "c" and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo then
		local info = C_CurrencyInfo.GetCurrencyInfo(tonumber(id))
		if info then parts[#parts + 1] = n .. " |T" .. info.iconFileID .. ":0|t " .. info.name end
	elseif kind == "i" then
		local name = C_Item.GetItemNameByID(tonumber(id))
		local icon = C_Item.GetItemIconByID(tonumber(id))
		parts[#parts + 1] = n .. " " .. (icon and ("|T" .. icon .. ":0|t ") or "") .. (name or (L["Предмет #"] .. id))
	end
	return table.concat(parts, " + ")
end

-- Имя на языке клиента, иначе любое
local function LocalName(names)
	if type(names) ~= "table" then return names end
	return names[GetLocale and GetLocale() or "enUS"] or names.enUS or select(2, next(names))
end

-- Запись каталога: { вид, id, зона, x, y, имя(на языках), медь, цена в валюте }
local function CatalogLine(e)
	local kind, id, map, x, y, names = e[1], e[2], e[3], e[4], e[5], e[6]
	local zone = ZoneName(map)
	local where = zone and (" — " .. zone .. Coords(x, y)) or ""
	local name = LocalName(names)
	if kind == "v" then
		local cost = CostText(e[7], e[8])
		return L["Торговец: "] .. (name and name ~= "" and name or (L["НИП #"] .. id)) .. where
			.. (cost ~= "" and (", " .. cost) or "")
	elseif kind == "q" then
		local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
		title = title or name
		return L["Задание: "] .. (title and title ~= "" and ("«" .. title .. "»") or ("#" .. id)) .. where
	elseif kind == "o" then
		return L["Сундук или предмет в мире"] .. where
	end
	return L["Добыча: "] .. (name and name ~= "" and name or (L["существо #"] .. id)) .. where
end

-- Из своих находок (ещё не попавших в каталог)
local function OwnLines(itemID)
	local out = {}
	for _, record in ipairs(TH.db.srcQueue or {}) do
		local kind, item, id, map, x, y, a, b, c = strsplit(":", record)
		if tonumber(item) == itemID then
			local e = { kind, tonumber(id), tonumber(map), tonumber(x), tonumber(y) }
			if kind == "v" then e[6], e[7], e[8] = c, tonumber(a), b else e[6] = a end
			out[#out + 1] = CatalogLine(e)
			if #out >= MAX_LINES then break end
		end
	end
	return out
end

-- AllTheThings: путь от его корня до источника («Зона > Торговцы > Имя»)
local function ATT()
	local app = rawget(_G, "AllTheThings")
	if type(app) == "table" and type(app.SearchForObject) == "function" then return app end
end

-- Группа-фильтр по типу вещи («Тканевые») или заголовок только из таких групп
-- («Броня»): к месту отношения не имеют
local function Generic(g)
	if g.key == "filterID" then return true end
	if type(g.g) ~= "table" or #g.g == 0 then return false end
	for _, child in ipairs(g.g) do
		if child.key ~= "filterID" then return false end
	end
	return true
end

-- Координаты ATT: { [карта] = { { x, y }, … } } (в процентах); бывает и { { x, y, карта } }
-- Возвращает { x, y } и номер карты
local function FirstCoord(coords)
	if type(coords) ~= "table" then return nil end
	if type(coords[1]) == "table" then return coords[1], tonumber(coords[1][3]) end
	for map, list in pairs(coords) do
		if type(list) == "table" and type(list[1]) == "table" then return list[1], tonumber(map) end
	end
end

local function ATTPath(obj)
	local chain, coords = {}, nil
	local g, guard = obj, 0
	while g and guard < 15 do
		if g ~= obj then chain[#chain + 1] = g end
		if not coords then coords = (FirstCoord(g.coords)) end
		g = g.sourceParent or g.parent
		guard = guard + 1
	end
	chain[#chain] = nil -- корень ATT
	local first = 1
	while chain[first] and Generic(chain[first]) do first = first + 1 end
	-- раздел верхнего уровня («Игровые зоны», «Подземелья и рейды») — если есть что-то точнее
	if #chain > first then chain[#chain] = nil end
	-- названия от вещи вверх; имена, которые ATT ещё загружает, пропускаем
	-- (подсказка обновится, когда они придут)
	local named, pending, npc = {}, false, false
	for i = first, #chain do
		local g = chain[i]
		local text = g.sourceText or g.text
		if type(text) ~= "string" or text == "" or Secret(text)
			or (RETRIEVING_DATA and text:find(RETRIEVING_DATA, 1, true)) then
			pending = true
		else
			named[#named + 1] = { text = text, g = g }
			if g.npcID or g.creatureID then npc = true end
		end
	end
	-- до трёх ближайших; при торговце или существе заголовки («Торговцы») не нужны;
	-- зона — всегда первой
	local parts, zone = {}, nil
	for _, n in ipairs(named) do
		if #parts < 3 and not (npc and n.g.key == "headerID") then table.insert(parts, 1, n) end
		if n.g.mapID then zone = n break end -- выше зоны — материк и раздел, не нужны
	end
	if zone then
		local has = false
		for _, n in ipairs(parts) do if n == zone then has = true end end
		if not has then
			if #parts >= 3 then table.remove(parts, 1) end
			table.insert(parts, 1, zone)
		end
	end
	for i, n in ipairs(parts) do parts[i] = n.text end
	if #parts == 0 then return nil, pending end
	local text = table.concat(parts, " > ")
	if coords and tonumber(coords[1]) and tonumber(coords[2]) then
		text = text .. string.format(" (%.1f, %.1f)", coords[1], coords[2])
	end
	return text, pending
end

local attObject = {} -- [sourceID] = запись ATT (для метки на карте)
local function ATTLines(itemID, sourceID)
	local app = ATT()
	if not app then return nil end
	local ok, list = pcall(app.SearchForObject, "sourceID", sourceID, "field", true)
	if not ok or type(list) ~= "table" or #list == 0 then
		ok, list = pcall(app.SearchForObject, "itemID", itemID, "field", true)
	end
	if not ok or type(list) ~= "table" then return {} end
	local out, seen, pending = {}, {}, false
	attObject[sourceID] = list[1]
	for _, obj in ipairs(list) do
		local ok2, text, wait = pcall(ATTPath, obj)
		if ok2 and wait then pending = true end
		if ok2 and text and not seen[text] then
			seen[text] = true
			out[#out + 1] = text
			if #out >= MAX_LINES then break end
		end
	end
	return out, pending
end

---------------------------------------------------------------------------
-- Встроенная база (TransmogHub_ATT из аддона TransmogHub_Sources). Запись вещи —
-- до 4 источников через «;»: «раздел|место|источник|карта:x:y|цена» (см. tools/att/build.lua)
---------------------------------------------------------------------------
local embeddedTried = false
local function Embedded()
	if TransmogHub_ATT then return TransmogHub_ATT end
	-- база собрана для основной игры; в Forever другие вещи и карты — не грузим
	if TH.FOREVER or embeddedTried then return nil end
	embeddedTried = true
	local load = C_AddOns and C_AddOns.LoadAddOn or LoadAddOn
	if load then pcall(load, "TransmogHub_Sources") end
	return TransmogHub_ATT
end
TH.LoadEmbeddedSources = Embedded

-- Названия из таблиц базы ({ enUS=…, ruRU=… }) с метками: @ГЛОБАЛЬНАЯ_СТРОКА,
-- {s:заклинание}, {a:достижение}, {c:класс:подкласс}
local function Resolve(text)
	if type(text) ~= "string" then return nil end
	-- глобальные строки игры, в том числе внутри составных названий («@ZONE @BATTLE_PET_SOURCE_1»)
	text = text:gsub("@([A-Z][A-Z0-9_]*[A-Z0-9])", function(g)
		return type(_G[g]) == "string" and _G[g] or ""
	end)
	text = text:gsub("{s:(%d+)}", function(id)
		local name = C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(tonumber(id))
		return name or ""
	end)
	text = text:gsub("{a:(%d+)}", function(id)
		return GetAchievementInfo and select(2, GetAchievementInfo(tonumber(id))) or ""
	end)
	text = text:gsub("{c:(%d+):(%d+)}", function(a, b)
		local info = C_Item and C_Item.GetItemSubClassInfo and C_Item.GetItemSubClassInfo(tonumber(a), tonumber(b))
		return info or ""
	end)
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return text ~= "" and text or nil
end

-- Свои пояснения для заголовков ATT, которые в переводе звучат одинаково
local HEADER_TEXT = {
	[-63] = L["Добыча с существ в локации"],
	[-64] = L["Награды локации: редкие, сундуки, локальные задания"],
}

local function TableName(t, id)
	if t and t == (TransmogHub_ATT or {}).headers and HEADER_TEXT[id] then return HEADER_TEXT[id] end
	local names = t and t[id]
	if not names then return nil end
	return Resolve(LocalName(names))
end

-- Имя существа: игра знает его, только если оно было в кэше; иначе спросит сервер
-- (подсказку перерисуем, когда имя придёт)
local npcNames = {}
local function NpcName(id)
	if npcNames[id] then return npcNames[id] end
	local data = C_TooltipInfo and C_TooltipInfo.GetHyperlink
		and C_TooltipInfo.GetHyperlink("unit:Creature-0-0-0-0-" .. id .. "-0000000000")
	local line = data and data.lines and data.lines[1]
	local name = line and line.leftText
	if type(name) == "string" and name ~= "" and not Secret(name) and name ~= RETRIEVING_DATA then
		npcNames[id] = name
		return name
	end
end

local function PlaceName(token)
	local kind, id = (token or ""):match("^(%a)(%-?%d+)$")
	id = tonumber(id)
	if not id then return nil end
	if kind == "I" then
		return EJ_GetInstanceInfo and (EJ_GetInstanceInfo(id)) or nil
	end
	return ZoneName(id)
end

-- Источник: текст и ждём ли ещё имя от игры
local function SourceText(token, cost, db, cat)
	local kind, id = (token or ""):match("^(%a)(%-?%d+)$")
	id = tonumber(id)
	if not id then return nil end
	if kind == "e" then
		local name = EJ_GetEncounterInfo and (EJ_GetEncounterInfo(id))
		return L["Босс: "] .. (name or ("#" .. id))
	elseif kind == "n" then
		local name = NpcName(id)
		-- с ценой или в Торговой лавке — торговец, иначе добыча с существа
		local label = (cost ~= "" or cat == "T") and L["Торговец: "] or L["Добыча: "]
		return label .. (name or (L["существо #"] .. id)), not name
	elseif kind == "q" then
		local title = C_QuestLog and C_QuestLog.GetTitleForQuestID and C_QuestLog.GetTitleForQuestID(id)
		return L["Задание: "] .. (title and ("«" .. title .. "»") or ("#" .. id)), not title
	elseif kind == "o" then
		return TableName(db.objects, id) or L["Сундук или предмет в мире"]
	elseif kind == "a" then
		local name = GetAchievementInfo and select(2, GetAchievementInfo(id))
		return L["Достижение: "] .. (name or ("#" .. id))
	elseif kind == "p" then
		local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName and C_TradeSkillUI.GetTradeSkillDisplayName(id)
		return L["Профессия: "] .. (name or ("#" .. id))
	elseif kind == "h" then
		return TableName(db.headers, id)
	end
end

-- Цена: «g<медь>,c<валюта>x<n>,i<предмет>x<n>»
local function EmbeddedCost(cost)
	local parts = {}
	for part in (cost or ""):gmatch("[^,]+") do
		local copper = part:match("^g(%d+)$")
		if copper then
			local text = CostText(tonumber(copper))
			if text ~= "" then parts[#parts + 1] = text end
		else
			local text = CostText(nil, part)
			if text ~= "" then parts[#parts + 1] = text end
		end
	end
	return table.concat(parts, " + ")
end

local CATEGORY_LABEL = {
	P = L["PvP"], T = L["Торговая лавка"], S = L["Магазин игры"], B = L["Черный рынок"],
	H = L["Праздник"], W = L["Мировое событие"], D = L["Случайная добыча в мире"], R = L["Акция"],
}

local function EmbeddedEntries(itemID)
	local db = Embedded()
	local raw = db and db.items and db.items[itemID]
	if not raw then return nil, db end
	local out = {}
	for entry in raw:gmatch("[^;]+") do
		local cat, place, source, coord, cost = strsplit("|", entry)
		out[#out + 1] = { cat = cat, place = place, source = source, coord = coord or "", cost = cost or "" }
	end
	return out, db
end

local function EmbeddedLines(itemID)
	local entries, db = EmbeddedEntries(itemID)
	if not entries then return nil end
	local out, seen, pending = {}, {}, false
	for _, e in ipairs(entries) do
		local parts = {}
		local place = PlaceName(e.place)
		if place then parts[#parts + 1] = place end
		local src, wait = SourceText(e.source, e.cost, db, e.cat)
		if wait then pending = true end
		if src and src ~= place then parts[#parts + 1] = src end
		if #parts == 0 then parts[1] = CATEGORY_LABEL[e.cat] end
		if #parts > 0 then
			local text = table.concat(parts, " > ")
			local m, x, y = e.coord:match("^(%d+):([%d%.]+):([%d%.]+)$")
			if x then text = text .. string.format(" (%.1f, %.1f)", tonumber(x), tonumber(y)) end
			local cost = EmbeddedCost(e.cost)
			if cost ~= "" then text = text .. ", " .. cost end
			if CATEGORY_LABEL[e.cat] and parts[1] ~= CATEGORY_LABEL[e.cat] then
				text = CATEGORY_LABEL[e.cat] .. ": " .. text
			end
			if not seen[text] then
				seen[text] = true
				out[#out + 1] = text
				if #out >= MAX_LINES then break end
			end
		end
	end
	return out, pending
end

local function EmbeddedPoint(itemID)
	local entries = EmbeddedEntries(itemID)
	for _, e in ipairs(entries or {}) do
		local m, x, y = e.coord:match("^(%d+):([%d%.]+):([%d%.]+)$")
		if m then
			local src = SourceText(e.source, e.cost, TransmogHub_ATT or {}, e.cat)
			return tonumber(m), tonumber(x) / 100, tonumber(y) / 100, src
		end
	end
end

-- Возвращает заголовок и строки «где найти» (или nil), не установлен ли ATT
-- и ждём ли ещё имена от ATT (тогда подсказку стоит перерисовать)
function TH:GetWhereToFind(itemID, sourceID)
	if not itemID then return nil end
	local att, pending = ATTLines(itemID, sourceID)
	if att and #att > 0 then return L["Где найти (AllTheThings):"], att, false, pending end
	local embedded, wait = EmbeddedLines(itemID)
	if embedded and #embedded > 0 then return L["Где найти:"], embedded, false, pending or wait end
	local lines = {}
	local catalog = TransmogHub_Sources and TransmogHub_Sources.items and TransmogHub_Sources.items[itemID]
	for _, e in ipairs(catalog or {}) do
		lines[#lines + 1] = CatalogLine(e)
		if #lines >= MAX_LINES then break end
	end
	if #lines == 0 then lines = OwnLines(itemID) end
	if #lines > 0 then return L["Где найти (по данным игроков):"], lines, false, pending end
	-- совет поставить ATT — только если встроенной базы нет
	return nil, nil, att == nil and not TransmogHub_ATT, pending
end

---------------------------------------------------------------------------
-- Метка на карте: через AllTheThings (он сам находит координаты торговца или
-- существа и ставит метку TomTom или игры), иначе по находкам игроков
---------------------------------------------------------------------------
local function CatalogPoint(itemID)
	local list = TransmogHub_Sources and TransmogHub_Sources.items and TransmogHub_Sources.items[itemID]
	for _, e in ipairs(list or {}) do
		if e[3] and e[4] and e[5] then return e[3], e[4] / 1000, e[5] / 1000, LocalName(e[6]) end
	end
	for _, record in ipairs(TH.db.srcQueue or {}) do
		local kind, item, _, map, x, y, a, _, c = strsplit(":", record)
		if tonumber(item) == itemID and tonumber(x) and tonumber(y) and tonumber(map) then
			return tonumber(map), tonumber(x) / 1000, tonumber(y) / 1000, kind == "v" and c or a
		end
	end
end

-- Координаты из ATT: у записи или у торговца, существа, зоны над ней
local function ATTPoint(obj)
	local g, guard = obj, 0
	while g and guard < 15 do
		local c, map = FirstCoord(g.coords)
		if c and map and tonumber(c[1]) and tonumber(c[2]) then
			local text = g.sourceText or g.text
			return map, c[1] / 100, c[2] / 100, type(text) == "string" and not Secret(text) and text or nil
		end
		g = g.sourceParent or g.parent
		guard = guard + 1
	end
end

local function MapPoint(itemID, sourceID)
	if ATT() then
		if attObject[sourceID] == nil then ATTLines(itemID, sourceID) end
		local obj = attObject[sourceID]
		if obj then
			local ok, map, x, y, title = pcall(ATTPoint, obj)
			if ok and map then return map, x, y, title end
		end
	end
	local map, x, y, title = EmbeddedPoint(itemID)
	if map then return map, x, y, title end
	return CatalogPoint(itemID)
end

-- Метку можно поставить, только если координаты правда есть
function TH:CanShowOnMap(itemID, sourceID)
	if not itemID then return false end
	return MapPoint(itemID, sourceID) ~= nil
end

-- Метка игры (или TomTom, если он стоит)
function TH:ShowOnMap(itemID, sourceID, name)
	local map, x, y, title = MapPoint(itemID, sourceID)
	if not map then
		self:Print(L["Где находится, пока неизвестно: координат нет ни в AllTheThings, ни в находках игроков."])
		return
	end
	title = (title and title ~= "") and title or name
	if TomTom and TomTom.AddWaypoint then
		TomTom:AddWaypoint(map, x, y, { title = title, persistent = false })
	elseif C_Map and C_Map.SetUserWaypoint and UiMapPoint and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(map)) then
		C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(map, x, y))
		if C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then C_SuperTrack.SetSuperTrackedUserWaypoint(true) end
	else
		self:Print(L["На этой карте метку поставить нельзя."])
		return
	end
	-- ссылка игры на точку карты: нажатие открывает карту с этим местом
	local place = (title or "") .. " — " .. (ZoneName(map) or "?") .. Coords(x * 1000, y * 1000)
	local link = string.format("|cffffff00|Hworldmap:%d:%d:%d|h[%s]|h|r", map, math.floor(x * 10000 + 0.5),
		math.floor(y * 10000 + 0.5), place)
	self:Print(L["Метка на карте: "] .. link)
end
