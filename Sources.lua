local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Где взять вещь — подробнее, чем «Торговец» или «Случайная добыча» (игра аддонам
-- больше ничего не сообщает).
-- 1) AllTheThings, если он установлен: его путь к источнику (зона > торговец, задание…).
-- 2) Наблюдения игроков. Аддон замечает вещи с обликом у торговцев, в добыче и в
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

local function ATTPath(obj)
	local parts, coords = {}, nil
	local g, guard = obj, 0
	while g and guard < 15 do
		if g ~= obj then
			local text = g.sourceText or g.text
			if type(text) == "string" and text ~= "" and not Secret(text) then table.insert(parts, 1, text) end
		end
		if not coords and type(g.coords) == "table" and type(g.coords[1]) == "table" then coords = g.coords[1] end
		g = g.sourceParent or g.parent
		guard = guard + 1
	end
	if #parts > 1 then table.remove(parts, 1) end -- корень ATT
	while #parts > 4 do table.remove(parts, 1) end
	if #parts == 0 then return nil end
	local text = table.concat(parts, " > ")
	if coords and tonumber(coords[1]) and tonumber(coords[2]) then
		text = text .. string.format(" (%.1f, %.1f)", coords[1], coords[2])
	end
	return text
end

local function ATTLines(itemID, sourceID)
	local app = ATT()
	if not app then return nil end
	local ok, list = pcall(app.SearchForObject, "sourceID", sourceID, "field", true)
	if not ok or type(list) ~= "table" or #list == 0 then
		ok, list = pcall(app.SearchForObject, "itemID", itemID, "field", true)
	end
	if not ok or type(list) ~= "table" then return {} end
	local out, seen = {}, {}
	for _, obj in ipairs(list) do
		local ok2, text = pcall(ATTPath, obj)
		if ok2 and text and not seen[text] then
			seen[text] = true
			out[#out + 1] = text
			if #out >= MAX_LINES then break end
		end
	end
	return out
end

-- Возвращает заголовок и строки «где найти» или nil
function TH:GetWhereToFind(itemID, sourceID)
	if not itemID then return nil end
	local att = ATTLines(itemID, sourceID)
	if att and #att > 0 then return L["Где найти (AllTheThings):"], att end
	local lines = {}
	local catalog = TransmogHub_Sources and TransmogHub_Sources.items and TransmogHub_Sources.items[itemID]
	for _, e in ipairs(catalog or {}) do
		lines[#lines + 1] = CatalogLine(e)
		if #lines >= MAX_LINES then break end
	end
	if #lines == 0 then lines = OwnLines(itemID) end
	if #lines > 0 then return L["Где найти (по данным игроков):"], lines end
	return nil, nil, att == nil -- третье значение: AllTheThings не установлен
end
