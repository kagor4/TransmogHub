local _, ns = ...
local L = ns.L
local TH = ns.TH

-- Порядок слотов, как в окне трансмогрификации.
-- items[slotID] = { sourceID, secondarySourceID, illusionID }
TH.SLOTS = {
	{ id = 1, key = "HEADSLOT" },
	{ id = 3, key = "SHOULDERSLOT" },
	{ id = 15, key = "BACKSLOT" },
	{ id = 5, key = "CHESTSLOT" },
	{ id = 4, key = "SHIRTSLOT" },
	{ id = 19, key = "TABARDSLOT" },
	{ id = 9, key = "WRISTSLOT" },
	{ id = 10, key = "HANDSSLOT" },
	{ id = 6, key = "WAISTSLOT" },
	{ id = 7, key = "LEGSSLOT" },
	{ id = 8, key = "FEETSLOT" },
	{ id = 16, key = "MAINHANDSLOT", hand = "MAINHANDSLOT" },
	{ id = 17, key = "SECONDARYHANDSLOT", hand = "SECONDARYHANDSLOT" },
}

-- Строки карточки образа: слоты плюс левый наплечник (показывается, только если
-- наплечники разные)
TH.DETAIL_SLOTS = {}
for _, slot in ipairs(TH.SLOTS) do
	TH.DETAIL_SLOTS[#TH.DETAIL_SLOTS + 1] = { id = slot.id, index = 1, slot = slot }
	if slot.id == 3 then
		TH.DETAIL_SLOTS[#TH.DETAIL_SLOTS + 1] = { id = 3, index = 2, slot = slot, label = L["Лев. плечо"] }
	end
	-- чары (иллюзия) на оружии — отдельной строкой под ним, если есть
	if slot.id == 16 or slot.id == 17 then
		TH.DETAIL_SLOTS[#TH.DETAIL_SLOTS + 1] = { id = slot.id, index = 3, slot = slot, label = L["  Чары"], illusion = true }
	end
end

-- Короткие подписи для карточки образа (полные — из игры, для подсказок)
local SHORT_LABELS = {
	[4] = L["Рубашка"], [19] = L["Накидка"], [10] = L["Кисти"],
	[16] = L["Пр. рука"], [17] = L["Лев. рука"],
}
for _, slot in ipairs(TH.SLOTS) do
	slot.short = SHORT_LABELS[slot.id]
end
TH.SLOT_BY_ID = {}
for _, slot in ipairs(TH.SLOTS) do
	slot.label = _G[slot.key] or slot.key
	TH.SLOT_BY_ID[slot.id] = slot
end

---------------------------------------------------------------------------
-- Снимок текущего облика
---------------------------------------------------------------------------

-- Наложенный трансмог, иначе облик самой вещи. Второе значение — был ли трансмог.
local function ReadSlot(slotID, transmogType, isSecondary)
	local loc = TransmogUtil.CreateTransmogLocation(slotID, transmogType, isSecondary)
	local info = C_Transmog.GetSlotVisualInfo(loc:GetData())
	if not info then return end
	if info.appliedSourceID and info.appliedSourceID > 0 then return info.appliedSourceID, true end
	if info.baseSourceID and info.baseSourceID > 0 then return info.baseSourceID, false end
end

-- Способ 2 (запасной): API трансмогрификации. В Midnight он отдаёт
-- «просматриваемый» образ, который может не совпадать с надетым, поэтому
-- результат без единого наложенного трансмога не принимаем.
-- TransmogUtil живёт в загружаемом по требованию Blizzard_TransmogShared.
local function CaptureViaTransmogAPI()
	if not (TransmogUtil and TransmogUtil.CreateTransmogLocation) then
		C_AddOns.LoadAddOn("Blizzard_TransmogShared")
	end
	if not (TransmogUtil and TransmogUtil.CreateTransmogLocation and C_Transmog.GetSlotVisualInfo) then
		return
	end
	local items, any, anyApplied = {}, false, false
	for _, slot in ipairs(TH.SLOTS) do
		local ok, entry = pcall(function()
			local main, applied = ReadSlot(slot.id, Enum.TransmogType.Appearance, false)
			if not main then return end
			if applied then anyApplied = true end
			local e = { main }
			if slot.id == INVSLOT_SHOULDER then
				local secondary = ReadSlot(slot.id, Enum.TransmogType.Appearance, true)
				if secondary and secondary ~= main then e[2] = secondary end
			elseif slot.hand then
				e[3] = ReadSlot(slot.id, Enum.TransmogType.Illusion, false)
			end
			return e
		end)
		if ok and entry then
			items[slot.id] = entry
			any = true
		end
	end
	return (any and anyApplied) and items or nil
end

-- Способ 3 (последний): облик самих надетых вещей, без трансмога.
local function CaptureViaEquipment()
	local items, any = {}, false
	for _, slot in ipairs(TH.SLOTS) do
		local link = GetInventoryItemLink("player", slot.id)
		if link then
			local _, sourceID = C_TransmogCollection.GetItemInfo(link)
			if sourceID then
				items[slot.id] = { sourceID }
				any = true
			end
		end
	end
	return any and items or nil
end

-- Асинхронно: callback(items, method). items = nil, если ничего не вышло.
-- Сначала модель игрока (то, что реально видно, см. Preview.lua),
-- затем API трансмогрификации, затем надетые вещи.
function TH:CaptureCurrent(callback)
	self:CaptureViaModel(function(items)
		if items then return callback(items, "model") end
		items = CaptureViaTransmogAPI()
		if items then return callback(items, "transmog") end
		items = CaptureViaEquipment()
		callback(items, items and "equipment" or nil)
	end)
end

---------------------------------------------------------------------------
-- Откуда вещь и собрана ли она
---------------------------------------------------------------------------
local cache = {}
local dropTries = {}
local MAX_DROP_TRIES = 5

function TH:WipeSourceCache()
	wipe(cache)
	wipe(dropTries)
end

local function JoinDifficulties(list)
	if not list or #list == 0 then return nil end
	return table.concat(list, ", ")
end

-- Игра не сообщает источник (жетоны комплектов, акции, магазин, события).
-- Пробуем угадать: тот же облик у другой вещи с известным источником,
-- комплект из коллекции, дополнение вещи.
local function SetText(setID)
	local si = C_TransmogSets and C_TransmogSets.GetSetInfo and C_TransmogSets.GetSetInfo(setID)
	if not si or not si.name then return nil end
	local extra = {}
	if si.label and si.label ~= "" then extra[#extra + 1] = si.label end
	if si.description and si.description ~= "" then extra[#extra + 1] = si.description end
	return "«" .. si.name .. "»" .. (#extra > 0 and (" — " .. table.concat(extra, ", ")) or "")
end

function TH:GuessSource(d, info, sourceID)
	-- тот же облик у другой вещи
	local all = info.visualID and C_TransmogCollection.GetAllAppearanceSources
		and C_TransmogCollection.GetAllAppearanceSources(info.visualID)
	for _, other in ipairs(all or {}) do
		local oi = other ~= sourceID and C_TransmogCollection.GetSourceInfo(other)
		local text = oi and oi.sourceType and _G["TRANSMOG_SOURCE_" .. oi.sourceType]
		if text then
			d.typeText, d.sourceType = text, oi.sourceType
			local name = oi.name ~= "" and oi.name or (oi.itemID and C_Item.GetItemNameByID(oi.itemID))
			d.where = L["Такой же облик у вещи "] .. (name and ("«" .. name .. "»") or L["другой вещи"]) .. L[" — источник: "] .. text .. "."
			return
		end
	end
	-- комплект (классовые наборы рейдов выдаются за жетоны — источника у вещей нет)
	local sets = C_TransmogSets and C_TransmogSets.GetSetsContainingSourceID
		and C_TransmogSets.GetSetsContainingSourceID(sourceID)
	local text = sets and sets[1] and SetText(sets[1])
	if text then
		d.typeText, d.fromSet = L["Комплект"], true
		d.where = L["Вещь из комплекта "] .. text .. L[". Подробности — в коллекции, вкладка «Комплекты»."]
		return
	end
	d.typeText = L["Другое"]
	local exp = info.itemID and C_Item.GetItemInfo and select(15, C_Item.GetItemInfo(info.itemID))
	local expName = exp and _G["EXPANSION_NAME" .. exp]
	d.where = L["Игра не сообщает, откуда эта вещь (обычно акции, магазин или события)."]
		.. (expName and (L[" Дополнение: "] .. expName .. ".") or "")
end

-- Возвращает таблицу:
-- name, quality, itemID, icon, typeText, where, collected, hidden, pending
function TH:GetSourceDetails(sourceID)
	if not sourceID then return end
	local d = cache[sourceID]
	if d and not d.pending then return d end

	local info = C_TransmogCollection.GetSourceInfo(sourceID)
	if not info then
		return { pending = true, name = L["Облик #"] .. sourceID }
	end

	d = {
		itemID = info.itemID,
		quality = info.quality,
		hidden = info.isHideVisual,
		sourceType = info.sourceType,
	}
	d.name = info.name
	if (not d.name or d.name == "") and info.itemID then
		d.name = C_Item.GetItemNameByID(info.itemID)
		if not d.name then
			C_Item.RequestLoadItemDataByID(info.itemID)
			d.pending = true
		end
	end
	d.name = d.name or (L["Предмет #"] .. (info.itemID or sourceID))
	d.icon = info.itemID and C_Item.GetItemIconByID(info.itemID) or 134400

	if d.hidden then
		d.typeText = L["Скрыто"]
		d.collected = true
	else
		d.typeText = info.sourceType and _G["TRANSMOG_SOURCE_" .. info.sourceType]
		-- артефактное оружие (Легион): игра не даёт источника, но качество «Артефакт»
		if not d.typeText and info.quality == 6 then
			d.typeText = L["Артефакт"]
			d.artifact = true
			d.where = L["Артефактное оружие Легиона: облики открываются заданиями, достижениями и прокачкой артефакта."]
		end
		if not d.typeText then self:GuessSource(d, info, sourceID) end
		d.collected = info.isCollected
		-- Облик мог быть собран с другой вещи
		if not d.collected and C_TransmogCollection.GetAppearanceInfoBySource then
			local ai = C_TransmogCollection.GetAppearanceInfoBySource(sourceID)
			if ai and ai.appearanceIsCollected then d.collected = true end
		end
	end

	-- Для добычи с боссов уточняем подземелье, босса и сложности
	if info.sourceType == 1 and C_TransmogCollection.GetAppearanceSourceDrops then
		local drops = C_TransmogCollection.GetAppearanceSourceDrops(sourceID)
		local drop = drops and drops[1]
		if drop then
			local where = (drop.instance or "?") .. " — " .. (drop.encounter or "?")
			local diff = JoinDifficulties(drop.difficulties)
			if diff then where = where .. " (" .. diff .. ")" end
			if #drops > 1 then where = where .. string.format(L[" и ещё %d"], #drops - 1) end
			d.where = where
		else
			-- Данные о добыче могут прийти не сразу: спросим ещё несколько раз
			-- Попытки считаем не чаще раза в секунду: за одну перерисовку
			-- окна функцию вызывают много раз.
			local tries = dropTries[sourceID] or { n = 0, t = 0 }
			if GetTime() - tries.t >= 1 then
				tries.n, tries.t = tries.n + 1, GetTime()
			end
			dropTries[sourceID] = tries
			if tries.n < MAX_DROP_TRIES then
				d.pending = true
			else
				d.where = L["Место добычи неизвестно (нет в путеводителе по подземельям)."]
			end
		end
	end

	cache[sourceID] = d
	return d
end

-- Чары на оружии (иллюзия): название, иконка, собраны ли, откуда
local illusions = {}
function TH:GetIllusionDetails(illusionID)
	if not illusionID or illusionID == 0 then return nil end
	if illusions[illusionID] then return illusions[illusionID] end
	local C = C_TransmogCollection
	local info = C.GetIllusionInfo and C.GetIllusionInfo(illusionID)
	local name, _, sourceText
	if C.GetIllusionStrings then name, _, sourceText = C.GetIllusionStrings(illusionID) end
	if not info and not name then return { pending = true, name = L["Чары #"] .. illusionID } end
	local d = {
		illusion = true,
		name = (name and name ~= "") and name or (L["Чары #"] .. illusionID),
		icon = info and info.icon or 135913,
		collected = info and info.isCollected or false,
		hidden = info and info.isHideVisual or false,
		quality = 4,
		typeText = L["Чары для оружия (иллюзия)"],
		where = (sourceText and sourceText ~= "") and sourceText:gsub("|n", "\n") or L["Игра не сообщает, откуда эти чары."],
	}
	illusions[illusionID] = d
	return d
end

-- Сколько вещей образа уже есть у игрока.
function TH:GetCollectedStats(set)
	local have, total = 0, 0
	for _, it in pairs(set.items or {}) do
		for i = 1, 2 do
			if it[i] then
				local d = self:GetSourceDetails(it[i])
				if d and not d.hidden then
					total = total + 1
					if d.collected then have = have + 1 end
				end
			end
		end
	end
	return have, total
end

---------------------------------------------------------------------------
-- Предзагрузка: при открытии окна просим у игры данные о вещах своих образов и
-- верха чартов, порциями по кадрам. Это только сведения о предметах (кэш игры,
-- килобайты) — модели вещей игра грузит сама, когда рисует их.
---------------------------------------------------------------------------
local PREFETCH_TOP, PREFETCH_PER_TICK = 20, 15
local prefetched = {} -- [sourceID] = true — уже просили в этом сеансе

function TH:PrefetchSets(sets)
	local queue = {}
	for _, set in ipairs(sets) do
		for _, it in pairs(set.items or {}) do
			local id = it[1]
			if id and not prefetched[id] then
				prefetched[id] = true
				queue[#queue + 1] = id
			end
		end
	end
	local i = 1
	local function Tick()
		for _ = 1, PREFETCH_PER_TICK do
			local id = queue[i]
			if not id then return end
			i = i + 1
			local info = C_TransmogCollection.GetSourceInfo(id)
			if info and info.itemID and C_Item.RequestLoadItemDataByID then C_Item.RequestLoadItemDataByID(info.itemID) end
		end
		C_Timer.After(0, Tick)
	end
	if #queue > 0 then Tick() end
	return #queue
end

-- Свои образы и верх «Лучших» и «В тренде»
function TH:PrefetchLikelySets()
	local sets = {}
	for _, set in pairs(self.db.mySets) do sets[#sets + 1] = set end
	for _, view in ipairs({ "top", "trending" }) do
		local list = self:QuerySets(view, {})
		for n = 1, math.min(PREFETCH_TOP, #list) do sets[#sets + 1] = list[n] end
	end
	return self:PrefetchSets(sets)
end
