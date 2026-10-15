local ADDON_NAME, ns = ...

local TH = CreateFrame("Frame")
ns.TH = TH
TransmogHub = TH

TH.SCHEMA = 1
TH.LOCAL_PREFIX = "local:"
TH.TEST_PREFIX = "test:"

---------------------------------------------------------------------------
-- Теги: фиксированный список, чтобы не плодить «пират/пираты/pirate»
---------------------------------------------------------------------------
TH.TAG_GROUPS = {
	{ name = "Тема", tags = {
		{ "pirate", "Пират" }, { "knight", "Рыцарь" }, { "warrior", "Воитель" },
		{ "mage", "Маг" }, { "necro", "Некромант" }, { "nature", "Природа" },
		{ "elegant", "Элегантный" }, { "casual", "Повседневный" }, { "holiday", "Праздник" },
		{ "dark", "Тёмный" }, { "holy", "Светлый" }, { "rp", "Для RP" },
	} },
	{ name = "Цвет", tags = {
		{ "c_black", "Чёрный" }, { "c_white", "Белый" }, { "c_red", "Красный" },
		{ "c_blue", "Синий" }, { "c_green", "Зелёный" }, { "c_purple", "Фиолетовый" },
		{ "c_gold", "Золотой" }, { "c_brown", "Коричневый" }, { "c_pink", "Розовый" },
		{ "c_orange", "Оранжевый" }, { "c_yellow", "Жёлтый" }, { "c_gray", "Серый" },
		{ "c_teal", "Бирюзовый" },
	} },
}

TH.TAG_LABEL = {}
TH.TAG_ORDER = {}
for _, group in ipairs(TH.TAG_GROUPS) do
	for _, tag in ipairs(group.tags) do
		TH.TAG_LABEL[tag[1]] = tag[2]
		TH.TAG_ORDER[#TH.TAG_ORDER + 1] = tag[1]
	end
end

function TH:FormatTags(tags)
	if not tags or #tags == 0 then return "" end
	local out = {}
	for _, key in ipairs(tags) do
		out[#out + 1] = self.TAG_LABEL[key] or key
	end
	return table.concat(out, ", ")
end

---------------------------------------------------------------------------
-- Утилиты
---------------------------------------------------------------------------

-- string.lower не трогает кириллицу в UTF-8, поэтому дополняем вручную.
local CYR_LOWER = {}
do
	local upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
	local lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
	local ups, lows = {}, {}
	for ch in upper:gmatch("[\192-\255][\128-\191]*") do ups[#ups + 1] = ch end
	for ch in lower:gmatch("[\192-\255][\128-\191]*") do lows[#lows + 1] = ch end
	for i = 1, #ups do CYR_LOWER[ups[i]] = lows[i] end
end

function TH.Lower(s)
	return (s:lower():gsub("[\208\209][\128-\191]", CYR_LOWER))
end

local uidCounter = 0
function TH:NewUid()
	uidCounter = uidCounter + 1
	return string.format("%08x%04x%04x%03x", time(), math.random(0, 0xffff), math.random(0, 0xffff), uidCounter % 0x1000)
end

function TH:Print(...)
	print("|cffd4a017Transmog Hub:|r", ...)
end

function TH:SexLabel(sex)
	return sex == 1 and "жен." or "муж."
end

function TH:PlayerSex()
	return (UnitSex("player") or 2) - 2
end

function TH:IsLocalId(id)
	return type(id) == "string" and id:sub(1, #self.LOCAL_PREFIX) == self.LOCAL_PREFIX
end

function TH:IsTestId(id)
	return type(id) == "string" and id:sub(1, #self.TEST_PREFIX) == self.TEST_PREFIX
end

---------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------
local DEFAULTS = {
	schema = 1,
	mySets = {},     -- [localId] = set
	outbox = {       -- то, что компаньон должен отправить на сервер
		publish = {},   -- { uid, localId, t, set }
		unpublish = {}, -- { uid, serverId, t }
		votes = {},     -- [setId] = { uid, stars, t }
		reports = {},   -- { uid, setId, t }
	},
	myVotes = {},    -- [setId] = 1..5 (локальная копия для интерфейса)
	favorites = {},  -- [setId] = true
	testSets = {},   -- тестовая лента (/thub test)
	minimap = { angle = 200, hide = false },
	achievements = {}, -- [id] = время получения
	stats = { saved = 0, published = 0, races = {}, colors = {}, maxHidden = 0 },
}

local function ApplyDefaults(t, d)
	for k, v in pairs(d) do
		if t[k] == nil then
			t[k] = type(v) == "table" and CopyTable(v) or v
		elseif type(v) == "table" and type(t[k]) == "table" then
			ApplyDefaults(t[k], v)
		end
	end
end

---------------------------------------------------------------------------
-- Лента наборов
---------------------------------------------------------------------------
local PRIOR_MEAN, PRIOR_WEIGHT = 3.5, 10

-- Байесовское среднее: один голос 5★ не обгоняет сотню голосов 4.8★.
-- Сервер присылает готовый score, это запасной вариант.
function TH:GetScore(set)
	if set.score then return set.score end
	local r = set.rating
	if not r or not r.n or r.n == 0 then return 0 end
	return (r.avg * r.n + PRIOR_MEAN * PRIOR_WEIGHT) / (r.n + PRIOR_WEIGHT)
end

function TH:LoadFeed()
	local bundled, live = TransmogHub_Bundled, TransmogHub_Live
	local src = bundled
	if type(live) == "table" and (not bundled or (live.generated or 0) >= (bundled.generated or 0)) then
		src = live
	end
	self.feed = src or { generated = 0, sets = {} }
	self.feed.sets = self.feed.sets or {}
	self.feedSource = (src == live) and "live" or "bundled"
	self.user = type(live) == "table" and live.user or nil

	self.byId = {}
	for _, set in ipairs(self.feed.sets) do
		self.byId[set.id] = set
	end
	for _, set in ipairs(self.db.testSets) do
		self.byId[set.id] = set
	end
end

function TH:GetSet(id)
	if not id then return end
	return self.byId[id] or self.db.mySets[id]
end

function TH:IsMine(set)
	if not set then return false end
	if self.db.mySets[set.id] then return true end
	for _, mine in pairs(self.db.mySets) do
		if mine.serverId and mine.serverId == set.id then return true end
	end
	return false
end

local function MatchesFilter(set, filter)
	if filter.text and filter.text ~= "" then
		local hay = TH.Lower((set.name or "") .. " " .. (set.author or "") .. " " .. TH:FormatTags(set.tags))
		if not hay:find(filter.text, 1, true) then return false end
	end
	if filter.tags then
		for key in pairs(filter.tags) do
			if not tContains(set.tags or {}, key) then return false end
		end
	end
	return true
end

-- view: top | trending | new | favorites | mine
function TH:QuerySets(view, filter)
	local list = {}
	if view == "mine" then
		for _, set in pairs(self.db.mySets) do list[#list + 1] = set end
	elseif view == "favorites" then
		for id in pairs(self.db.favorites) do
			local set = self:GetSet(id)
			if set then list[#list + 1] = set end
		end
	else
		for _, set in ipairs(self.feed.sets) do list[#list + 1] = set end
		for _, set in ipairs(self.db.testSets) do list[#list + 1] = set end
	end

	filter = filter or {}
	if filter.text then filter.text = self.Lower(filter.text) end
	local out = {}
	for _, set in ipairs(list) do
		if MatchesFilter(set, filter) then out[#out + 1] = set end
	end

	if view == "top" or view == "favorites" then
		table.sort(out, function(a, b) return self:GetScore(a) > self:GetScore(b) end)
	elseif view == "trending" then
		table.sort(out, function(a, b)
			local ta, tb = a.trend or 0, b.trend or 0
			if ta ~= tb then return ta > tb end
			return self:GetScore(a) > self:GetScore(b)
		end)
	else
		table.sort(out, function(a, b) return (a.created or 0) > (b.created or 0) end)
	end
	return out
end

---------------------------------------------------------------------------
-- Свои наборы, публикация, голоса
---------------------------------------------------------------------------
function TH:CreateMySet(name, desc, tags, items)
	local _, classFile = UnitClass("player")
	local _, _, raceID = UnitRace("player")
	local id = self.LOCAL_PREFIX .. self:NewUid()
	local set = {
		id = id,
		name = name,
		desc = desc,
		tags = tags,
		items = items,
		author = UnitName("player") .. "-" .. (GetNormalizedRealmName() or ""),
		race = raceID,
		sex = (UnitSex("player") or 2) - 2, -- 0 муж., 1 жен.
		class = classFile,
		created = time(),
		status = "draft",
	}
	self.db.mySets[id] = set
	self:TrackSavedSet(set)
	self:NotifyChanged()
	self:CheckAchievements()
	return set
end

local EXPORT_FIELDS = { "name", "desc", "tags", "items", "author", "race", "sex", "class", "created" }

function TH:Publish(localId)
	local set = self.db.mySets[localId]
	if not set or set.status == "pending" then return end
	local payload = {}
	for _, k in ipairs(EXPORT_FIELDS) do
		payload[k] = type(set[k]) == "table" and CopyTable(set[k]) or set[k]
	end
	tinsert(self.db.outbox.publish, { uid = self:NewUid(), localId = localId, t = time(), set = payload })
	set.status = "pending"
	if not set.everPublished then
		set.everPublished = true
		self.db.stats.published = self.db.stats.published + 1
	end
	self:NotifyChanged()
	self:CheckAchievements()
	self:SuggestReload()
end

function TH:DeleteMySet(localId)
	local set = self.db.mySets[localId]
	if not set then return end
	for i = #self.db.outbox.publish, 1, -1 do
		if self.db.outbox.publish[i].localId == localId then
			tremove(self.db.outbox.publish, i)
		end
	end
	if set.serverId then
		tinsert(self.db.outbox.unpublish, { uid = self:NewUid(), serverId = set.serverId, t = time() })
		self:SuggestReload()
	end
	self.db.mySets[localId] = nil
	self.db.favorites[localId] = nil
	self:NotifyChanged()
end

function TH:CanVote(set)
	if not set or self:IsLocalId(set.id) then return false, "Набор ещё не опубликован" end
	if self:IsMine(set) then return false, "Нельзя голосовать за свой набор" end
	return true
end

function TH:Vote(setId, stars)
	local set = self:GetSet(setId)
	local ok, err = self:CanVote(set)
	if not ok then
		self:Print(err)
		return
	end
	self.db.myVotes[setId] = stars
	if not self:IsTestId(setId) then
		self.db.outbox.votes[setId] = { uid = self:NewUid(), stars = stars, t = time() }
	end
	self:NotifyChanged()
	self:CheckAchievements()
end

function TH:ToggleFavorite(setId)
	self.db.favorites[setId] = not self.db.favorites[setId] or nil
	self:NotifyChanged()
	self:CheckAchievements()
end

function TH:Report(setId)
	if self:IsTestId(setId) or self:IsLocalId(setId) then return end
	tinsert(self.db.outbox.reports, { uid = self:NewUid(), setId = setId, t = time() })
	self:Print("Жалоба отправится вместе с остальными изменениями. Спасибо!")
	self:NotifyChanged()
end

function TH:GetPendingCounts()
	local ob = self.db.outbox
	local votes = 0
	for _ in pairs(ob.votes) do votes = votes + 1 end
	return #ob.publish + #ob.unpublish + #ob.reports, votes
end

-- Компаньон кладёт в Live.lua список обработанных uid; убираем их из очереди.
function TH:ApplyServerAcks()
	local user = self.user
	if not user then return end
	local acked = user.acked or {}
	local ob = self.db.outbox

	for _, queue in ipairs({ ob.publish, ob.unpublish, ob.reports }) do
		for i = #queue, 1, -1 do
			if acked[queue[i].uid] then tremove(queue, i) end
		end
	end
	for setId, v in pairs(ob.votes) do
		if acked[v.uid] then ob.votes[setId] = nil end
	end

	for localId, info in pairs(user.published or {}) do
		local set = self.db.mySets[localId]
		if set then
			set.serverId = info.id
			set.status = info.status or "published"
			set.rejectReason = info.reason
		end
	end

	-- Серверные голоса считаем истиной, если локально нет неотправленного
	for setId, stars in pairs(user.votes or {}) do
		if not ob.votes[setId] then self.db.myVotes[setId] = stars end
	end
end

StaticPopupDialogs["TRANSMOGHUB_RELOAD"] = {
	text = "Transmog Hub: изменения отправятся на сервер после перезагрузки интерфейса (или при выходе из игры).\n\nПерезагрузить сейчас?",
	button1 = "Перезагрузить",
	button2 = "Позже",
	OnAccept = function() ReloadUI() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function TH:SuggestReload()
	StaticPopup_Show("TRANSMOGHUB_RELOAD")
end

---------------------------------------------------------------------------
-- Уведомления интерфейса
---------------------------------------------------------------------------
function TH:NotifyChanged()
	if self.UI and self.UI.Refresh then self.UI:Refresh() end
end

local refreshPending = false
function TH:RequestRefresh()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0.25, function()
		refreshPending = false
		TH:NotifyChanged()
	end)
end

---------------------------------------------------------------------------
-- Тестовая лента: копии своих наборов со случайным рейтингом
---------------------------------------------------------------------------
local FAKE_AUTHORS = { "Ксарн-Гордунни", "Лиара-Свежеватель Душ", "Thrall-Draenor", "Мирабель-Ревущий фьорд", "Огрим-Галакронд" }

function TH:MakeTestFeed()
	local sources = {}
	for _, set in pairs(self.db.mySets) do sources[#sources + 1] = set end
	if #sources > 0 then
		self:FillTestFeed(sources)
		return
	end
	self:CaptureCurrent(function(items)
		if not items then
			self:Print("Не удалось снять текущий облик.")
			return
		end
		self:FillTestFeed({ { items = items, race = select(3, UnitRace("player")), sex = UnitSex("player") - 2 } })
	end)
end

function TH:FillTestFeed(sources)
	wipe(self.db.testSets)
	for i = 1, 25 do
		local src = sources[(i - 1) % #sources + 1]
		local n = math.random(0, 300)
		local tags = {}
		for _ = 1, math.random(1, 3) do
			local key = self.TAG_ORDER[math.random(1, #self.TAG_ORDER)]
			if not tContains(tags, key) then tags[#tags + 1] = key end
		end
		tinsert(self.db.testSets, {
			id = self.TEST_PREFIX .. i,
			name = "Тестовый набор " .. i,
			desc = "Сгенерировано командой /thub test",
			author = FAKE_AUTHORS[math.random(1, #FAKE_AUTHORS)],
			tags = tags,
			items = CopyTable(src.items),
			race = src.race,
			sex = src.sex,
			created = time() - math.random(0, 30 * 86400),
			rating = { avg = n > 0 and (math.random(250, 500) / 100) or 0, n = n },
			trend = math.random(0, 100),
		})
	end
	self:LoadFeed()
	self:NotifyChanged()
	self:Print("Создано 25 тестовых наборов.")
end

---------------------------------------------------------------------------
-- События и команды
---------------------------------------------------------------------------
TH:SetScript("OnEvent", function(self, event, ...)
	if self[event] then self[event](self, ...) end
end)
TH:RegisterEvent("ADDON_LOADED")
TH:RegisterEvent("PLAYER_LOGIN")

function TH:ADDON_LOADED(name)
	if name ~= ADDON_NAME then return end
	TransmogHubDB = TransmogHubDB or {}
	ApplyDefaults(TransmogHubDB, DEFAULTS)
	self.db = TransmogHubDB
	self:UnregisterEvent("ADDON_LOADED")
end

function TH:PLAYER_LOGIN()
	self:LoadFeed()
	self:ApplyServerAcks()
	self:UpdateMinimapButton()
	C_Timer.After(5, function()
		self:RebuildStatsFromSets()
		self:CheckAchievements()
	end)
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
end

function TH:GET_ITEM_INFO_RECEIVED()
	if self.UI and self.UI:IsShown() then self:RequestRefresh() end
end

function TH:TRANSMOG_COLLECTION_UPDATED()
	if self.WipeSourceCache then self:WipeSourceCache() end
	if self.UI and self.UI:IsShown() then self:RequestRefresh() end
end

function TH:Toggle()
	if self.UI then self.UI:Toggle() end
end

function TransmogHub_OnAddonCompartmentClick()
	TH:Toggle()
end

SLASH_TRANSMOGHUB1 = "/thub"
SLASH_TRANSMOGHUB2 = "/transmoghub"
SlashCmdList.TRANSMOGHUB = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "minimap" then
		TH:ToggleMinimapButton()
	elseif msg == "test" then
		TH:MakeTestFeed()
	elseif msg == "test clear" then
		wipe(TH.db.testSets)
		TH:LoadFeed()
		TH:NotifyChanged()
		TH:Print("Тестовые наборы удалены.")
	elseif msg == "capture" then
		TH:CaptureCurrent(function(items, method)
			if not items then
				TH:Print("Не удалось снять облик.")
				return
			end
			TH:Print("Облик снят способом:", method)
			for slotID, it in pairs(items) do
				print(slotID, it[1], it[2] or "-", it[3] or "-")
			end
		end)
	else
		TH:Toggle()
	end
end
