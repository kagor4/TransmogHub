local _, ns = ...
local L = ns.L
local TH = ns.TH

-- Сеть между игроками без сервера.
--
-- Все копии аддона сидят в скрытом канале CHANNEL_NAME и обмениваются
-- сообщениями аддонов (C_ChatInfo.SendAddonMessage). Каждый клиент хранит
-- свою копию базы (TransmogHubDB.net) и дополняет её тем, что слышит.
-- Новичок при входе спрашивает «что нового с момента X», и ОДИН из игроков
-- (выбирается случайной задержкой) присылает недостающее всему каналу.
--
-- Игра гарантирует имя отправителя, поэтому:
--   * снять образ с публикации может только его автор;
--   * прямой голос — «один персонаж — один голос». Голоса, пересланные
--     при синхронизации, проверить нельзя; это осознанное допущение.

local Net = {}
TH.Net = Net

local PREFIX = "TMHUB"
local CHANNEL_NAME = "TransmogHubNet"
local PROTOCOL = 1

local MAX_MESSAGE = 250          -- лимит игры 255 байт
local CHUNK = MAX_MESSAGE - 3    -- тип + номер сообщения
local TOKENS_MAX, TOKEN_RATE = 4, 1.0 -- не чаще ~1 сообщения в секунду
local SYNC_LIMIT = 100           -- сколько образов отдаём на один запрос
local MAX_SETS = 3000            -- сколько образов храним
local PEER_TIMEOUT = 15 * 60     -- игрок «в сети», если писал за 15 минут
local JOIN_DELAY = 8             -- общие каналы игры должны занять номера первыми

---------------------------------------------------------------------------
-- Кодирование
---------------------------------------------------------------------------
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"

local function Enc(n)
	n = math.floor(tonumber(n) or 0)
	if n == 0 then return "0" end
	local neg = n < 0
	if neg then n = -n end
	local out = ""
	while n > 0 do
		local d = n % 36
		out = B36:sub(d + 1, d + 1) .. out
		n = math.floor(n / 36)
	end
	return neg and ("-" .. out) or out
end

Net.Enc = Enc -- для тестов

local function Dec(s)
	if not s or s == "" then return nil end
	return tonumber(s, 36)
end

-- В текстах игроков не должно быть разделителей и управляющих символов
local function Clean(s, maxLen)
	s = tostring(s or ""):gsub("[%c|\t]", " ")
	if maxLen and #s > maxLen then
		-- не режем посреди буквы UTF-8
		s = s:sub(1, maxLen):gsub("[\192-\255][\128-\191]*$", "")
	end
	return s
end

local function Split(s, sep)
	local out = {}
	for part in (s .. sep):gmatch("(.-)" .. sep) do out[#out + 1] = part end
	return out
end

-- Образ -> строка. Поля через табуляцию.
function Net.EncodeSet(set)
	local items = {}
	for slotID, it in pairs(set.items or {}) do
		items[#items + 1] = Enc(slotID) .. ":" .. Enc(it[1]) .. "." .. (it[2] and Enc(it[2]) or "") .. "." .. (it[3] and Enc(it[3]) or "")
	end
	table.sort(items)
	return table.concat({
		set.id,
		Clean(set.author, 60),
		Clean(set.name, 96),
		Clean(set.desc, 240),
		Enc(set.race or 0),
		Enc(set.sex or 0),
		Clean(set.class, 16),
		Enc(set.created or 0),
		table.concat(set.tags or {}, ","),
		table.concat(items, ";"),
		Enc(set.icon or 0), -- иконка (fileID); старые версии это поле не читают
	}, "\t")
end

-- Иконка образа — номер файла игры (fileID)
local function ValidIcon(n)
	n = tonumber(n)
	if n and n > 0 and n < 2 ^ 31 and n == math.floor(n) then return n end
end

function Net.DecodeSet(s)
	local f = Split(s, "\t")
	if #f < 10 or f[1] == "" then return nil end
	local items = {}
	for entry in f[10]:gmatch("[^;]+") do
		local slot, a, b, c = entry:match("^(%w+):(%-?%w+)%.(%-?%w*)%.(%-?%w*)$")
		local slotID = Dec(slot)
		if slotID and TH.SLOT_BY_ID[slotID] then
			items[slotID] = { Dec(a), Dec(b), Dec(c) }
		end
	end
	local tags = {}
	for tag in f[9]:gmatch("[^,]+") do
		-- неизвестные теги храним: они могут быть из более новой версии
		if #tags < 5 and #tag <= 24 and tag:match("^[%w_]+$") then tags[#tags + 1] = tag end
	end
	return {
		id = f[1],
		author = f[2],
		name = f[3] ~= "" and f[3] or "?",
		desc = f[4],
		race = Dec(f[5]),
		sex = Dec(f[6]),
		class = f[7],
		created = Dec(f[8]) or 0,
		tags = tags,
		items = items,
		icon = ValidIcon(Dec(f[11])),
	}
end

---------------------------------------------------------------------------
-- Имена
---------------------------------------------------------------------------
local myRealm

-- Отправитель приходит как «Имя» (свой сервер) или «Имя-Сервер».
-- В Forever серверов нет: имя — «Имя Фамилия», оно и есть полное.
function Net.FullName(name)
	if not name or name == "" then return name end
	if TH.FOREVER then return (strtrim(name):gsub("%s+", " ")) end
	if name:find("-", 1, true) then return name end
	myRealm = myRealm or GetNormalizedRealmName() or ""
	return name .. "-" .. myRealm
end

local myName
function Net.Me()
	if myName then return myName end
	local name = UnitName("player")
	-- Forever: нужна фамилия. Берём первый из вариантов, где она есть (с пробелом)
	if TH.FOREVER and name and not name:find(" ", 1, true) then
		for _, alt in ipairs({ GetUnitName and GetUnitName("player", true), UnitFullName and UnitFullName("player") }) do
			if type(alt) == "string" and alt:find(" ", 1, true) then name = alt break end
		end
	end
	if not name or name == UNKNOWNOBJECT then return Net.FullName(name) end
	myName = Net.FullName(name)
	return myName
end

local function Now()
	return GetServerTime and GetServerTime() or time()
end
Net.Now = Now

---------------------------------------------------------------------------
-- Канал
---------------------------------------------------------------------------
Net.channelId = 0
Net.peers = {}
Net.channelPeers = {} -- кого слышали в канале (чтобы понять, что гильдия — мост)
Net.guildPeers = {}   -- [имя] = когда слышали через гильдию
Net.whisperPeers = {} -- [имя] = когда слышали через скрытый шёпот (знакомство через каталог)
Net.voteStamp = {} -- [setId] = счётчик изменений голосов (для пересчёта только изменённых)

local function HideChannelFromChat()
	for i = 1, (NUM_CHAT_WINDOWS or 10) do
		local frame = _G["ChatFrame" .. i]
		if frame and frame.RemoveChannel then
			pcall(frame.RemoveChannel, frame, CHANNEL_NAME)
		end
	end
end

function Net:UpdateChannel()
	local id = GetChannelName(CHANNEL_NAME)
	self.channelId = (type(id) == "number" and id > 0) and id or 0
	return self.channelId > 0
end

function Net:Join()
	if self:UpdateChannel() then
		HideChannelFromChat()
		return true
	end
	local join = JoinTemporaryChannel or JoinPermanentChannel
	if join then pcall(join, CHANNEL_NAME) end
	C_Timer.After(2, function()
		if self:UpdateChannel() then
			HideChannelFromChat()
			self:OnConnected()
		end
	end)
	return false
end

function Net:IsConnected()
	return self.channelId > 0
end

-- Блокировка сообщений в бою и подземельях (Midnight). Не путать с
-- AreOutgoingAddonChatMessagesRestricted: та запрещает аддонам ОБЫЧНЫЙ чат
-- на всех обычных серверах и к сообщениям аддонов отношения не имеет.
function Net:IsLocked()
	return C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() or false
end

---------------------------------------------------------------------------
-- Адресаты
--   CHANNEL — скрытый канал своего сервера
--   GROUP   — группа/рейд, если в ней есть игроки с других серверов
--   GUILD   — гильдия: при входе — знакомство и синхронизация; рассылка — только если
--             через гильдию слышно тех, кого нет в канале (другая фракция, а в Forever
--             канал у каждого свой)
--   BNET    — друг Battle.net в WoW (любой сервер и фракция), target = gameAccountID
--   WHISPER — скрытый шёпот аддона игроку по имени (другой сервер своей фракции), target = имя:
--             одиночка без связей стучится к авторам из каталога (Net:KnockCatalog)
-- Пересылка между ними связывает серверы: игрок с друзьями на других
-- серверах работает «мостом». Повторы отсекаются по id образа.
---------------------------------------------------------------------------
local CHANNEL = { kind = "CHANNEL" }
local GROUP = { kind = "GROUP" }
local GUILD = { kind = "GUILD" }
local function BNET(id) return { kind = "BNET", target = id } end
local function WHISPER(name) return { kind = "WHISPER", target = name } end

local MAX_WHISPER_PEERS = 8 -- сколько знакомых через шёпот получают рассылку
local PRESENCE_TTL, MAX_PRESENCE = 14 * 86400, 2000 -- телефонная книга
local MAX_RELAY_QUEUE = 200 -- если очередь длиннее, пересылку пропускаем: догонит синхронизация

local function GroupChatType()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then return "INSTANCE_CHAT" end
	if IsInRaid() then return "RAID" end
	if IsInGroup() then return "PARTY" end
end

-- Есть ли в группе игроки с других серверов (свой сервер и так слышит канал)
function Net:GroupHasOtherRealm()
	if not IsInGroup() then return false end
	local raid = IsInRaid()
	for i = 1, GetNumGroupMembers() do
		local unit = raid and ("raid" .. i) or ("party" .. i)
		local ok, _, realm = pcall(UnitName, unit)
		if ok and type(realm) == "string" and realm ~= "" then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Друзья Battle.net с аддоном
---------------------------------------------------------------------------
Net.bnPeers = {}   -- [gameAccountID] = { name = "Имя-Сервер", t = время }
local bnGreeted = {} -- кому уже сказали «я в сети» в этой сессии
local bnSynced = {}  -- с кем уже синхронизировались в этой сессии

local function NormalizeRealm(realm)
	return (realm or ""):gsub("[%s%-']", "")
end

local function BNetName(gameAccountID)
	local info = C_BattleNet.GetGameAccountInfoByID(gameAccountID)
	if not info or not info.characterName or info.characterName == "" then return nil end
	if TH.FOREVER then return Net.FullName(info.characterName) end
	return info.characterName .. "-" .. NormalizeRealm(info.realmName)
end

-- Друзья, которые сейчас в той же игре (Retail или Forever) того же региона
local function OnlineWoWFriends()
	local list = {}
	if not (BNGetNumFriends and C_BattleNet.GetFriendNumGameAccounts) then return list end
	local wow = BNET_CLIENT_WOW or "WoW"
	for i = 1, BNGetNumFriends() do
		for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
			local info = C_BattleNet.GetFriendGameAccountInfo(i, j)
			if info and info.isOnline and info.clientProgram == wow
				and info.wowProjectID == (WOW_PROJECT_ID or WOW_PROJECT_MAINLINE or 1) and info.isInCurrentRegion then
				list[#list + 1] = info.gameAccountID
			end
		end
	end
	return list
end

-- Запоминаем персонажей друзей Battle.net (для вкладки «Друзья»): друг может
-- сейчас играть другим персонажем, а образы публиковать с прошлого.
function Net:RememberFriendChars()
	if not (BNGetNumFriends and C_BattleNet.GetFriendNumGameAccounts) then return end
	local chars, wow = TH.db.friendChars, BNET_CLIENT_WOW or "WoW"
	for i = 1, BNGetNumFriends() do
		for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) do
			local info = C_BattleNet.GetFriendGameAccountInfo(i, j)
			if info and info.clientProgram == wow and info.characterName and info.characterName ~= ""
				and info.realmName and info.realmName ~= "" then
				chars[info.characterName .. "-" .. NormalizeRealm(info.realmName)] = Now()
			end
		end
	end
end

function Net:GreetFriends()
	self:RememberFriendChars()
	for _, id in ipairs(OnlineWoWFriends()) do
		if not bnGreeted[id] then
			bnGreeted[id] = true
			self:Send("H" .. PROTOCOL, BNET(id))
			self:SendMyChars(BNET(id))
		end
	end
end

-- h<Имя-Сервер>,<Имя-Сервер>,… — все свои персонажи, только другу Battle.net: во вкладке
-- «Друзья» у него будут образы и тех твинков, которыми мы при нём не заходили
function Net:SendMyChars(dest)
	local list = {}
	for name in pairs(TH.db.myChars) do list[#list + 1] = name end
	table.sort(list)
	if #list > 0 then self:Send("h" .. table.concat(list, ","), dest) end
end

-- Согильдийцы с аддоном, которых слышали за последние 15 минут
function Net:GuildPeerCount()
	if not IsInGuild() then return 0 end
	local now, n = Now(), 0
	for _, t in pairs(self.guildPeers) do
		if now - t < PEER_TIMEOUT then n = n + 1 end
	end
	return n
end

function Net:BNetPeerCount()
	local now, n = Now(), 0
	for _, peer in pairs(self.bnPeers) do
		if now - peer.t < PEER_TIMEOUT then n = n + 1 end
	end
	return n
end

---------------------------------------------------------------------------
-- Очередь отправки с ограничением скорости
---------------------------------------------------------------------------
local queue = {}   -- { text, kind, target }
local tokens = TOKENS_MAX
local lastTick = 0
local msgCounter = 0

local RESULT = Enum.SendAddonMessageResult or {}
local THROTTLED = {}
for _, key in ipairs({ "AddonMessageThrottle", "ChannelThrottle", "AddOnMessageLockdown" }) do
	if RESULT[key] then THROTTLED[RESULT[key]] = true end
end

local RESULT_NAME = {}
for name, v in pairs(RESULT) do RESULT_NAME[v] = name end
local GIVE_UP = 40          -- столько раз подряд «занято» — сообщение бросаем, догонит синхронизация
local blockedUntil = {}     -- [вид адресата] = время: этот путь занят, шлём другим
Net.sendStats = { dropped = 0 } -- для строки состояния: почему очередь стоит

-- Отправить одно сообщение. true — убрать из очереди, false — подождать
local function Deliver(entry)
	local result
	if entry.kind == "CHANNEL" then
		if not Net:IsConnected() then return false end
		result = C_ChatInfo.SendAddonMessage(PREFIX, entry.text, "CHANNEL", tostring(Net.channelId))
	elseif entry.kind == "GROUP" then
		local chatType = GroupChatType()
		if not chatType then return true end -- группы уже нет
		result = C_ChatInfo.SendAddonMessage(PREFIX, entry.text, chatType)
	elseif entry.kind == "GUILD" then
		if not IsInGuild() then return true end -- из гильдии вышли
		result = C_ChatInfo.SendAddonMessage(PREFIX, entry.text, "GUILD")
	elseif entry.kind == "WHISPER" then
		result = C_ChatInfo.SendAddonMessage(PREFIX, entry.text, "WHISPER", entry.target)
	else
		result = C_BattleNet.SendGameData(entry.target, PREFIX, entry.text)
	end
	if THROTTLED[result] then
		entry.tries = (entry.tries or 0) + 1
		Net.sendStats.reason = RESULT_NAME[result] or tostring(result)
		Net.sendStats.since = Net.sendStats.since or GetTime()
		-- этот путь занят: пробуем позже (дольше с каждой попыткой), другие пути не ждут
		blockedUntil[entry.kind] = GetTime() + math.min(30, entry.tries)
		if entry.tries >= GIVE_UP then
			Net.sendStats.dropped = Net.sendStats.dropped + 1
			return true
		end
		return false
	end
	Net.sendStats.reason, Net.sendStats.since = nil, nil
	return true -- отправлено или адресат недоступен: в обоих случаях дальше
end

local function Pump()
	local now = GetTime()
	tokens = math.min(TOKENS_MAX, tokens + (now - lastTick) * TOKEN_RATE)
	lastTick = now
	if #queue == 0 or tokens < 1 or Net:IsLocked() then return end
	-- первое сообщение, которое можно отправить сейчас: канал может ещё не подключиться,
	-- а занятый путь (канал, группа, Battle.net) не держит остальные
	for i, entry in ipairs(queue) do
		if (entry.kind ~= "CHANNEL" or Net:IsConnected()) and (blockedUntil[entry.kind] or 0) <= now then
			if Deliver(entry) then
				tremove(queue, i)
				tokens = tokens - 1
			end
			return
		end
	end
end

-- Очередь стоит дольше 20 секунд: причина от игры (например, ChannelThrottle)
function Net:SendStallReason()
	local st = self.sendStats
	if st.reason and st.since and GetTime() - st.since > 20 then return st.reason end
end

local function Enqueue(text, dest)
	queue[#queue + 1] = { text = text, kind = dest.kind, target = dest.target }
end

-- Сообщение одному адресату, с нарезкой на части
local function SendTo(body, dest)
	if #body <= MAX_MESSAGE - 1 then
		Enqueue("S" .. body, dest)
		return
	end
	msgCounter = (msgCounter + 1) % 1296
	local id = Enc(msgCounter)
	if #id < 2 then id = "0" .. id end
	local pos, first = 1, true
	while pos <= #body do
		local piece = body:sub(pos, pos + CHUNK - 1)
		pos = pos + CHUNK
		local kind = first and "B" or (pos > #body and "E" or "C")
		Enqueue(kind .. id .. piece, dest)
		first = false
	end
end

-- Отправить адресату dest или всем (dest = nil). except — откуда пришло:
-- туда не пересылаем.
function Net:Send(body, dest, except)
	if dest then return SendTo(body, dest) end
	if not (except and except.kind == "CHANNEL") then SendTo(body, CHANNEL) end
	if not (except and except.kind == "GROUP") and self:GroupHasOtherRealm() then SendTo(body, GROUP) end
	if not (except and except.kind == "GUILD") and self.guildBridge and IsInGuild() then SendTo(body, GUILD) end
	-- знакомые через шёпот: им тоже всё новое, но не больше 8 самых недавних
	-- (остальное дойдёт по цепочке, а очередь отправки не забьётся)
	for _, name in ipairs(self:ActiveWhisperPeers(MAX_WHISPER_PEERS)) do
		if not (except and except.kind == "WHISPER" and except.target == name) then SendTo(body, WHISPER(name)) end
	end
	for id in pairs(self.bnPeers) do
		if not (except and except.kind == "BNET" and except.target == id) then SendTo(body, BNET(id)) end
	end
end

-- Активные знакомые через шёпот, самые недавние первыми
function Net:ActiveWhisperPeers(max)
	local now, list = Now(), {}
	for name, t in pairs(self.whisperPeers) do
		if now - t < PEER_TIMEOUT then list[#list + 1] = { name, t } end
	end
	table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
	local out = {}
	for i = 1, math.min(#list, max or #list) do out[i] = list[i][1] end
	return out
end

-- Переслать полученное дальше, если очередь не перегружена
function Net:Relay(body, origin)
	if #queue < MAX_RELAY_QUEUE then self:Send(body, nil, origin) end
end

function Net:QueueLength()
	return #queue
end

---------------------------------------------------------------------------
-- Приём и сборка частей
---------------------------------------------------------------------------
local partial = {} -- [отправитель..id] = { части, t }

local function Assemble(sender, text)
	local kind = text:sub(1, 1)
	if kind == "S" then return text:sub(2) end
	local key = sender .. text:sub(2, 3)
	local piece = text:sub(4)
	if kind == "B" then
		partial[key] = { piece, t = GetTime() }
	elseif partial[key] then
		local buf = partial[key]
		buf[#buf + 1] = piece
		if kind == "E" then
			partial[key] = nil
			return table.concat(buf)
		end
	end
end

local function CleanupPartial()
	local now = GetTime()
	for key, buf in pairs(partial) do
		if now - buf.t > 60 then partial[key] = nil end
	end
end

---------------------------------------------------------------------------
-- База сети
---------------------------------------------------------------------------
local function DB()
	return TH.db.net
end

function Net:StoreSet(set, sender)
	local db = DB()
	set.name = TH.FormatSetName(set.name)
	if db.tombstones[set.id] then return false end
	if db.sets[set.id] then return false end
	-- неприличное название и заблокированных авторов не храним и не пересылаем
	if not TH:IsSetTextAllowed(set) or TH:IsBlocked(set) or TH:IsBanned(set.author) then return false end
	set.via = sender
	set.verified = (sender == set.author) or nil
	set.received = Now()
	db.sets[set.id] = set
	self.dirty = true
	if TH.OnSetStored then TH:OnSetStored(set) end
	return true
end

-- Голос; звёзд 0 — голос снят (наказание за занижение): у всех удаляется, а отметка
-- о снятии не даёт старой копии голоса вернуться при синхронизации
function Net:StoreVote(setId, voter, stars, t)
	if TH:IsBanned(voter) then return false end -- изгнанные не голосуют
	stars = tonumber(stars)
	if not stars or stars < 0 or stars > 5 then return false end
	local db = DB()
	local retracted = db.voteRetracts[setId] and db.voteRetracts[setId][voter]
	if retracted and retracted >= t then return false end
	local votes = db.votes[setId]
	if not votes then
		votes = {}
		db.votes[setId] = votes
	end
	local old = votes[voter]
	if old and old[2] >= t then return false end
	if stars == 0 then
		db.voteRetracts[setId] = db.voteRetracts[setId] or {}
		db.voteRetracts[setId][voter] = t
		votes[voter] = nil
		self.voteStamp[setId] = (self.voteStamp[setId] or 0) + 1
		self.voteCount = (self.voteCount or 0) + 1
		self.dirty = true
		return true
	end
	votes[voter] = { stars, t }
	self.voteStamp[setId] = (self.voteStamp[setId] or 0) + 1 -- рейтинг этого образа пересчитать
	self.voteCount = (self.voteCount or 0) + 1 -- любые голоса изменились
	self.dirty = true
	if not old and TH.OnVoteStored then TH:OnVoteStored(setId, voter, stars, t) end
	return true
end

-- Жалоба: один персонаж — одна жалоба на образ, новее заменяет старую
function Net:StoreReport(setId, reporter, reason, t)
	if TH:IsBanned(reporter) then return false end
	-- «u» — жалоба отозвана (её автором): запись остаётся, чтобы старая копия не вернулась
	if not TH.REPORT_LABEL[reason] and reason ~= "u" then return false end
	local db = DB()
	local list = db.reports[setId]
	if not list then
		list = {}
		db.reports[setId] = list
	end
	local old = list[reporter]
	if old and old[2] >= t then return false end
	list[reporter] = { reason, t }
	TH:LogReport(setId, reporter, reason, t)
	self.dirty = true
	return true
end

-- Избранное: { 1 или 0, время } от каждого игрока; новее заменяет старое
function Net:StoreFav(setId, name, on, t)
	if TH:IsBanned(name) then return false end
	on = tonumber(on)
	if not (setId and name and t) or (on ~= 0 and on ~= 1) then return false end
	local favs = DB().favs
	local list = favs[setId]
	if not list then
		list = {}
		favs[setId] = list
	end
	local old = list[name]
	if old and (old[2] > t or (old[2] == t and old[1] >= on)) then return false end
	list[name] = { on, t }
	self.dirty = true
	if on == 1 and not (old and old[1] == 1) and TH.OnFavStored then TH:OnFavStored(setId, name, t) end
	return true
end

-- Подписки: [на кого][кто] = { 1 или 0, время }; новее заменяет старое
function Net:StoreFollow(target, name, on, t)
	if TH:IsBanned(name) then return false end
	on = tonumber(on)
	if not (target and name and t) or (on ~= 0 and on ~= 1) or target == name then return false end
	if #target > 64 or target:find("[,;\t]") then return false end
	local follows = DB().follows
	local list = follows[target]
	if not list then
		list = {}
		follows[target] = list
	end
	local old = list[name]
	if old and (old[2] > t or (old[2] == t and old[1] >= on)) then return false end
	list[name] = { on, t }
	self.followStamp = (self.followStamp or 0) + 1
	if TH.OnFollowStored then TH:OnFollowStored(target, name, on, t) end
	return true
end

function Net:SendFollow(target, on)
	local old = DB().follows[target] and DB().follows[target][Net.Me()]
	local t = math.max(Now(), old and old[2] + 1 or 0)
	self:StoreFollow(target, Net.Me(), on, t)
	self:Send("f" .. target .. "\t" .. on .. "\t" .. Enc(t))
end

-- Оспоренные теги образа: [образ][тег][игрок] = { 1 или 0, время }; новее заменяет старое
function Net:StoreTagFlag(setId, name, tag, on, t)
	if TH:IsBanned(name) then return false end
	on = tonumber(on)
	if not (setId and name and tag and t) or (on ~= 0 and on ~= 1) or not tag:match("^[%w_]+$") or #tag > 40 then
		return false
	end
	local all = DB().tagFlags
	all[setId] = all[setId] or {}
	local list = all[setId][tag]
	if not list then
		list = {}
		all[setId][tag] = list
	end
	local old = list[name]
	if old and (old[2] > t or (old[2] == t and old[1] >= on)) then return false end
	list[name] = { on, t }
	self.dirty = true
	return true
end

function Net:SendTagFlag(setId, tag, on)
	local mine = DB().tagFlags[setId] and DB().tagFlags[setId][tag] and DB().tagFlags[setId][tag][Net.Me()]
	local t = math.max(Now(), mine and mine[2] + 1 or 0)
	self:StoreTagFlag(setId, Net.Me(), tag, on, t)
	self:Send("T" .. setId .. "\t" .. tag .. "\t" .. on .. "\t" .. Enc(t))
end

function Net:SendFav(setId, on)
	-- время растёт, даже если отметку сняли в ту же секунду
	local old = DB().favs[setId] and DB().favs[setId][Net.Me()]
	local t = math.max(Now(), old and old[2] + 1 or 0)
	self:StoreFav(setId, Net.Me(), on, t)
	self:Send("F" .. setId .. "\t" .. on .. "\t" .. Enc(t))
end

-- Оспаривание решения: от игрока хранится последнее обращение. Принимаем и от
-- забаненных — иначе бан было бы не оспорить.
local APPEAL_MAX = 300 -- байт текста
function Net:StoreAppeal(name, t, text)
	if not (name and t and text) or text == "" then return false end
	text = Clean(text, APPEAL_MAX)
	local appeals = DB().appeals
	local old = appeals[name]
	if old and old[1] >= t then return false end
	appeals[name] = { t, text }
	TH:LogAppeal(name, t, text)
	return true
end

function Net:SendAppeal(text)
	local t = Now()
	text = Clean(text, APPEAL_MAX)
	self:StoreAppeal(Net.Me(), t, text)
	self:Send("J" .. Enc(t) .. "\t" .. text)
end

-- Предложения разработчику: идея, ошибка или другое; e — автоматический отчёт об ошибке Lua в аддоне
-- r — пояснение к жалобе «Другое»: «[id образа] текст»
-- u — статистика нажатий на кнопки (раз в неделю, хранится отдельно от писем)
-- s — места вещей с обликами (торговец, добыча, задание; раз в день, хранится как статистика)
local IDEA_KINDS = { i = true, b = true, o = true, e = true, r = true, u = true, s = true }
local USAGE_TTL, MAX_USAGE = 14 * 86400, 2000
local MAX_IDEAS = 500
function Net:StoreIdea(name, t, kind, text)
	if not (name and t and IDEA_KINDS[kind] and text) or text == "" or TH:IsBanned(name) then return false end
	local stat = kind == "u" or kind == "s"
	local ideas = stat and DB().usage or DB().ideas
	local key = name .. "#" .. t
	if ideas[key] then return false end
	text = Clean(text, APPEAL_MAX)
	if stat then
		if Now() - t > USAGE_TTL then return false end
		ideas[key] = { name, t, kind, text }
		if kind == "u" and TH.LogUsage then TH:LogUsage(t, text) end
		if kind == "s" and TH.LogSources then TH:LogSources(t, text) end
		return true
	end
	ideas[key] = { name, t, kind, text }
	TH:LogIdea(name, t, kind, text)
	return true
end

function Net:SendIdea(kind, text)
	local t = Now()
	text = Clean(text, APPEAL_MAX)
	self:StoreIdea(Net.Me(), t, kind, text)
	self:Send("N" .. Enc(t) .. "\t" .. kind .. "\t" .. text)
end

-- Предложенный тег: один персонаж — одно предложение на текст
function Net:StoreTagSuggestion(text, name, t)
	if TH:IsBanned(name) then return false end
	if TH.NormalizeTag(text) ~= text or not TH:IsTextAllowed(text) then return false end
	local db = DB()
	local list = db.tagSuggest[text]
	if not list then
		list = {}
		db.tagSuggest[text] = list
	end
	if list[name] then return false end
	list[name] = t
	TH:LogTagSuggestion(text, name, t)
	return true
end

-- Очки стиля игрока для рейтинга. Запись в сообщении (через запятую):
--   <очки>,<получено>,<лучшее>,<время>,<маска достижений>  или  x,<время> — вышел из рейтинга
-- Маска: по 5 достижений на символ (0-9a-v), по их постоянным номерам.
local MAX_POINTS, MAX_EARNED = 100000, 1000

local function ScoreKey(s)
	return s.removed and "" or string.format("%09d:%05d:%s:%s:%d:%d", s.points + 100000, s.earned, s.best or "", s.mask or "",
		s.avatar or 0, s.title or 0) .. ":" .. (s.tiers or "") .. ":" .. (s.found or "")
end

local function ParseScore(body)
	local t = body:match("^x,(%w+)$")
	if t then return { removed = true, t = Dec(t) } end
	-- в конце необязательные поля: аватар (номер файла иконки) и титул (номер достижения * 2 + пол)
	-- found — когда найдены скрытые достижения: по 5 знаков (номер, час) — для «первооткрывателя»
	local points, earned, best, ts, mask, avatar, title, tiers, found =
		body:match("^(%-?%d+),(%d+),([%w_]*),(%w+),([0-9a-v]*),(%w*),(%w*),([0-5]*),([0-9a-z]*)$")
	if not points then
		points, earned, best, ts, mask, avatar, title, tiers =
			body:match("^(%-?%d+),(%d+),([%w_]*),(%w+),([0-9a-v]*),(%w*),(%w*),([0-5]*)$")
	end
	if not points then
		points, earned, best, ts, mask, avatar, title =
			body:match("^(%-?%d+),(%d+),([%w_]*),(%w+),([0-9a-v]*),(%w*),(%w*)$")
	end
	if not points then
		points, earned, best, ts, mask, avatar = body:match("^(%-?%d+),(%d+),([%w_]*),(%w+),([0-9a-v]*),(%w*)$")
	end
	if not points then
		points, earned, best, ts, mask = body:match("^(%-?%d+),(%d+),([%w_]*),(%w+),([0-9a-v]*)$")
	end
	points, earned = tonumber(points), tonumber(earned)
	if not points or math.abs(points) > MAX_POINTS or earned > MAX_EARNED or #mask > 200 then return nil end
	if found and (#found % 5 ~= 0 or #found > 150) then found = nil end
	avatar = avatar and avatar ~= "" and Dec(avatar) or nil
	if avatar and (avatar <= 0 or avatar >= 2 ^ 31) then avatar = nil end
	title = title and title ~= "" and Dec(title) or nil
	if title and (title < 0 or title > 100000) then title = nil end
	return { points = points, earned = earned, best = best ~= "" and best or nil, t = Dec(ts), mask = mask,
		avatar = avatar, title = title, tiers = tiers ~= "" and tiers or nil, found = found ~= "" and found or nil }
end

local function ScoreBody(s)
	if s.removed then return "x," .. Enc(s.t) end
	return table.concat({ s.points, s.earned, s.best or "", Enc(s.t), s.mask or "", s.avatar and Enc(s.avatar) or "",
		s.title and Enc(s.title) or "", s.tiers or "", s.found or "" }, ",")
end

function Net:StoreScore(name, entry)
	if TH:IsBanned(name) and not (entry and entry.removed) then return false end
	if not (name and entry and entry.t) then return false end
	local scores = DB().scores
	local old = scores[name]
	if old then
		if old.t > entry.t then return false end
		-- одинаковое время: побеждает «большая» запись, чтобы все пришли к одному
		if old.t == entry.t and ScoreKey(entry) <= ScoreKey(old) then return false end
	end
	scores[name] = entry
	self.dirty = true
	return true
end

local function ScoreEntry(name, s)
	return name .. "," .. ScoreBody(s)
end

-- Решение модератора (уже проверено, что оно от модератора)
function Net:ApplyModDecision(action, target)
	local mod = DB().modBlocks
	if action == "s" then
		mod.sets[target] = Now()
	elseif action == "a" then
		mod.authors[target] = Now()
	elseif action == "u" then
		mod.sets[target] = nil
		if mod.names then mod.names[target] = nil end
	elseif action == "e" or action == "o" then
		-- запрещённое название: шуточное (просим переименовать) или оскорбление;
		-- образ скрыт, а автор узнаёт об этом в своём аддоне
		mod.sets[target] = Now()
		mod.names = mod.names or {}
		mod.names[target] = action
		-- автора, которого попросили переименовать, помечаем (первый такой образ):
		-- повторная шутка — уже наказание, даже если его аддон переустановлен
		local set = DB().sets[target]
		if action == "e" and set and set.author then
			mod.warned = mod.warned or {}
			mod.warned[set.author] = mod.warned[set.author] or target
		end
		if TH.CheckNameViolations then TH:CheckNameViolations() end
	elseif action == "b" then
		-- реклама: бан автора сразу
		mod.banned = mod.banned or {}
		mod.banned[target] = Now()
		if TH.db.myChars[target] and TH.OnAdBan then TH:OnAdBan() end
	elseif action == "r" then
		-- амнистия: с игрока снимается всё (бан, блокировки, пометка за шутку, наказания)
		for _, key in ipairs({ "banned", "authors", "players", "warned" }) do
			if mod[key] then mod[key][target] = nil end
		end
		for id, set in pairs(DB().sets) do
			if set.author == target then
				mod.sets[id] = nil
				if mod.names then mod.names[id] = nil end
			end
		end
		if TH.db.myChars[target] and TH.Amnesty then TH:Amnesty() end
	elseif action == "y" then
		-- бан снят (ошибка)
		if mod.banned then mod.banned[target] = nil end
	elseif action == "v" then
		mod.authors[target] = nil
	elseif action == "p" then
		mod.players[target] = Now()
	elseif action == "q" then
		mod.players[target] = nil
	elseif action == "d" then
		-- жалобы на образ ложные: если и вы жаловались — это ваша ложная жалоба
		if TH.db.myReports[target] then TH.db.falseReports[target] = Now() end
	elseif action == "m" or action == "x" then
		-- админ назначил или снял модератора
		DB().modRoles[target] = { action == "m" and 1 or 0, Now() }
		if TH.db.myChars[target] then
			TH.db.moderator = TH:IsModerator(target) or nil
			TH:Notify(action == "m" and L["Вас назначили модератором Transmog Hub: вкладка «Модерация» откроется после /reload."]
				or L["Вас сняли с модераторов Transmog Hub."])
		end
	elseif action == "w" then
		-- модератор снял наказание за занижение оценок
		if TH.db.myChars[target] and TH.LiftVotePenalty then TH:LiftVotePenalty() end
	elseif action == "k" then
		-- оценки образа проверены, накрутки нет: запоминаем, сколько их было
		local votes, n = DB().votes[target], 0
		for _ in pairs(votes or {}) do n = n + 1 end
		mod.verified = mod.verified or {}
		mod.verified[target] = n
		if TH.ResetSuspicion then TH:ResetSuspicion() end -- решение действует сразу
	end
	self.dirty = true
end

function Net:RemoveSet(setId)
	local db = DB()
	db.sets[setId] = nil
	db.votes[setId] = nil
	db.voteRetracts[setId] = nil
	db.favs[setId] = nil
	db.tagFlags[setId] = nil
	db.tombstones[setId] = Now()
	self.dirty = true
end

local REPORT_TTL = 60 * 86400 -- жалобы и предложения тегов старше 60 дней забываем
local MAX_TAG_SUGGESTIONS = 1000
local SCORE_TTL = 60 * 86400 -- кто 60 дней не заходил, пропадает из рейтинга

-- Ограничиваем базу: выкидываем самые старые образы и жалобы
function Net:Prune()
	local db = DB()
	local now = Now()
	-- телефонная книга: 14 дней, не больше 2000 самых свежих
	db.presence = db.presence or {}
	local present = {}
	for name, p in pairs(db.presence) do
		if now - p[2] > PRESENCE_TTL then db.presence[name] = nil else present[#present + 1] = { name, p[2] } end
	end
	if #present > MAX_PRESENCE then
		table.sort(present, function(a, b) return a[2] > b[2] end)
		for i = MAX_PRESENCE + 1, #present do db.presence[present[i][1]] = nil end
	end
	for setId, list in pairs(db.reports) do
		for name, r in pairs(list) do
			if now - r[2] > REPORT_TTL then list[name] = nil end
		end
		if not next(list) then db.reports[setId] = nil end
	end
	local texts = {}
	for text, list in pairs(db.tagSuggest) do
		local newest = 0
		for name, t in pairs(list) do
			if now - t > REPORT_TTL then list[name] = nil elseif t > newest then newest = t end
		end
		if next(list) then texts[#texts + 1] = { text, newest } else db.tagSuggest[text] = nil end
	end
	if #texts > MAX_TAG_SUGGESTIONS then
		table.sort(texts, function(a, b) return a[2] > b[2] end)
		for i = MAX_TAG_SUGGESTIONS + 1, #texts do db.tagSuggest[texts[i][1]] = nil end
	end
	for name, s in pairs(db.scores) do
		if now - s.t > SCORE_TTL then db.scores[name] = nil end
	end
	for name, a in pairs(db.appeals) do
		if now - a[1] > REPORT_TTL then db.appeals[name] = nil end
	end
	local ideaList = {}
	for key, idea in pairs(db.ideas) do
		if now - idea[2] > REPORT_TTL then db.ideas[key] = nil else ideaList[#ideaList + 1] = key end
	end
	if #ideaList > MAX_IDEAS then
		table.sort(ideaList, function(a, b) return db.ideas[a][2] > db.ideas[b][2] end)
		for i = MAX_IDEAS + 1, #ideaList do db.ideas[ideaList[i]] = nil end
	end
	local usage = {}
	for key, u in pairs(db.usage) do
		if now - u[2] > USAGE_TTL then db.usage[key] = nil else usage[#usage + 1] = key end
	end
	if #usage > MAX_USAGE then
		table.sort(usage, function(a, b) return db.usage[a][2] > db.usage[b][2] end)
		for i = MAX_USAGE + 1, #usage do db.usage[usage[i]] = nil end
	end
	-- отписки старше 30 дней забываем: они нужны, только пока расходятся по сети
	for target, list in pairs(db.follows) do
		for name, f in pairs(list) do
			if f[1] == 0 and now - f[2] > 30 * 86400 then list[name] = nil end
		end
		if not next(list) then db.follows[target] = nil end
	end
	for setId in pairs(db.favs) do
		if not db.sets[setId] then db.favs[setId] = nil end -- образ удалён или вытеснен
	end
	for setId in pairs(db.tagFlags) do
		if not db.sets[setId] then db.tagFlags[setId] = nil end
	end
	local all = 0
	for _ in pairs(db.sets) do all = all + 1 end
	if all <= MAX_SETS then return end
	-- Вытесняем только старые образы, которые никому не нужны: образы из чарта и Зала
	-- славы, свои, из избранного и от авторов из подписок остаются всегда
	local keep = {}
	local charts = TH.GetCharts and TH:GetCharts()
	if type(charts) == "table" then
		for _, key in ipairs({ "top", "trending" }) do
			for _, id in ipairs(type(charts[key]) == "table" and charts[key] or {}) do keep[id] = true end
		end
		for _, ids in pairs(type(charts.tags) == "table" and charts.tags or {}) do
			for _, id in ipairs(type(ids) == "table" and ids or {}) do keep[id] = true end
		end
		for id in pairs(type(charts.hof) == "table" and charts.hof or {}) do keep[id] = true end
	end
	for id in pairs(TH.db.favorites or {}) do keep[id] = true end
	local list = {}
	for id, set in pairs(db.sets) do
		local protected = keep[id] or (TH.IsMine and TH:IsMine(set))
			or (set.author and TH.IsFollowing and TH:IsFollowing(set.author))
		if not protected then list[#list + 1] = set end
	end
	table.sort(list, function(a, b) return (a.created or 0) > (b.created or 0) end)
	local excess = all - MAX_SETS
	for i = #list, math.max(1, #list - excess + 1), -1 do
		local id = list[i].id
		db.sets[id] = nil
		db.votes[id] = nil
		db.voteRetracts[id] = nil
	end
end

---------------------------------------------------------------------------
-- Протокол
--   P<образ>                       — публикация или пересылка образа
--   V<id>\t<звёзды>\t<время>       — голос отправителя
--   W<id>\t<голосующий>,<зв>,<вр>;… — пересланные голоса
--   D<id>                          — снять с публикации (только автор)
--   R<id>\t<причина>\t<время>      — жалоба отправителя (a — реклама, o — оскорбление, x — другое)
--   X<id>\t<кто>,<причина>,<вр>;…  — пересланные жалобы
--   F<id>\t<1|0>\t<время>          — отправитель добавил образ в избранное / убрал
--   U<id>\t<кто>,<1|0>,<вр>;…       — пересланные отметки избранного
--   f<на кого>\t<1|0>\t<время>       — отправитель подписался на автора / отписался
--   g<на кого>\t<кто>,<1|0>,<вр>;…    — пересланные подписки
--   G<тег>\t<время>                — предложение тега от отправителя
--   Y<тег>\t<кто>,<вр>;…            — пересланные предложения тегов
--   L<очки>,<получено>,<лучшее>,<вр>,<маска> — очки стиля отправителя (Lx,<вр> — вышел из рейтинга)
--   Zs\t<кто>,<запись как в L>;…    — пересланные очки
--   M<действие>\t<цель>            — решение модератора (только напрямую от модератора)
--   H<версия>                      — «я в сети»
--   I<версия>                      — ответ на H: «я тоже тут»
--   Q<запрос>\t<с какого времени>  — пришлите новое
--   A<запрос>                      — «я отвечаю на запрос», остальные молчат
---------------------------------------------------------------------------
function Net:PublishSet(set)
	self:StoreSet(CopyTable(set), Net.Me())
	self:Send("P" .. Net.EncodeSet(set))
end

function Net:SendVote(setId, stars)
	local old = DB().votes[setId] and DB().votes[setId][Net.Me()]
	local t = math.max(Now(), old and old[2] + 1 or 0)
	self:StoreVote(setId, Net.Me(), stars, t)
	self:Send("V" .. setId .. "\t" .. stars .. "\t" .. Enc(t))
end

function Net:SendReport(setId, reason)
	local old = DB().reports[setId] and DB().reports[setId][Net.Me()]
	local t = math.max(Now(), old and old[2] + 1 or 0) -- отзыв сразу после жалобы — всё равно новее
	self:StoreReport(setId, Net.Me(), reason, t)
	self:Send("R" .. setId .. "\t" .. reason .. "\t" .. Enc(t))
end

function Net:SendTagSuggestion(text)
	local t = Now()
	self:StoreTagSuggestion(text, Net.Me(), t)
	self:Send("G" .. text .. "\t" .. Enc(t))
end

-- entry: { points, earned, best, mask } или nil — выйти из рейтинга
function Net:SendScore(entry)
	-- время всегда растёт, даже при двух отправках в одну секунду
	local old = DB().scores[Net.Me()]
	local t = math.max(Now(), old and old.t + 1 or 0)
	entry = entry and { points = entry.points, earned = entry.earned, best = entry.best, mask = entry.mask,
		avatar = entry.avatar, title = entry.title, tiers = entry.tiers, found = entry.found, t = t }
		or { removed = true, t = t }
	self:StoreScore(Net.Me(), entry)
	self:Send("L" .. ScoreBody(entry))
end

function Net:Unpublish(setId)
	self:RemoveSet(setId)
	self:Send("D" .. setId)
end

local pendingAnswers = {} -- [reqId] = true, пока ждём своей очереди ответить
local myRequests = {}     -- [reqId] = { dest, time, peer }

-- Запрос «что нового». Время синхронизации запоминаем, только когда
-- кто-то ответил: иначе, войдя в пустой канал, мы бы потом не скачали
-- старые образы.
function Net:RequestSync(dest, peerName)
	dest = dest or CHANNEL
	local last = peerName and DB().peerSync[peerName] or DB().lastSync or 0
	local since = math.max(0, last - 3600) -- час запаса
	local reqId = Enc(math.random(0, 60000000))
	myRequests[reqId] = { dest = dest, time = Now(), peer = peerName }
	self:Send("Q" .. reqId .. "\t" .. Enc(since), dest)
end

local syncScheduled = false
function Net:ScheduleSync(delay)
	if self.synced or syncScheduled then return end
	syncScheduled = true
	C_Timer.After(delay, function()
		syncScheduled = false
		if not self.synced then self:RequestSync() end
	end)
end

-- Что отдать на запрос «новое с since»
local function CollectSince(since)
	local db = DB()
	local sets = {}
	for _, set in pairs(db.sets) do
		if (set.created or 0) > since or (set.received or 0) > since then
			sets[#sets + 1] = set
		end
	end
	table.sort(sets, function(a, b) return (a.created or 0) > (b.created or 0) end)
	while #sets > SYNC_LIMIT do tremove(sets) end

	local votes, reports = {}, {}
	for setId, list in pairs(db.votes) do
		local fresh = {}
		for voter, v in pairs(list) do
			if v[2] > since then fresh[#fresh + 1] = voter .. "," .. v[1] .. "," .. Enc(v[2]) end
		end
		if #fresh > 0 then votes[setId] = fresh end
	end
	-- снятые голоса расходятся так же, со звёздами 0
	for setId, list in pairs(db.voteRetracts) do
		for voter, t in pairs(list) do
			if t > since then
				votes[setId] = votes[setId] or {}
				table.insert(votes[setId], voter .. ",0," .. Enc(t))
			end
		end
	end
	for setId, list in pairs(db.reports) do
		local fresh = {}
		for name, r in pairs(list) do
			if r[2] > since then fresh[#fresh + 1] = name .. "," .. r[1] .. "," .. Enc(r[2]) end
		end
		if #fresh > 0 then reports[setId] = fresh end
	end
	-- прочее пачками: { вид сообщения, ключ, записи }
	local batches = {}
	for text, list in pairs(db.tagSuggest) do
		local fresh = {}
		for name, t in pairs(list) do
			if t > since then fresh[#fresh + 1] = name .. "," .. Enc(t) end
		end
		if #fresh > 0 then batches[#batches + 1] = { "Y", text, fresh } end
	end
	local scores = {}
	for name, s in pairs(db.scores) do
		if s.t > since then scores[#scores + 1] = ScoreEntry(name, s) end
	end
	if #scores > 0 then batches[#batches + 1] = { "Z", "s", scores } end
	local presence = {}
	for name, p in pairs(db.presence or {}) do
		if p[2] > since then presence[#presence + 1] = name .. "," .. p[1] .. "," .. Enc(p[2]) end
	end
	if #presence > 0 then batches[#batches + 1] = { "p", "s", presence } end
	for target, list in pairs(db.follows) do
		local fresh = {}
		for name, f in pairs(list) do
			if f[2] > since then fresh[#fresh + 1] = name .. "," .. f[1] .. "," .. Enc(f[2]) end
		end
		if #fresh > 0 then batches[#batches + 1] = { "g", target, fresh } end
	end
	for setId, list in pairs(db.favs) do
		local fresh = {}
		for name, f in pairs(list) do
			if f[2] > since then fresh[#fresh + 1] = name .. "," .. f[1] .. "," .. Enc(f[2]) end
		end
		if #fresh > 0 then batches[#batches + 1] = { "U", setId, fresh } end
	end
	for setId, tags in pairs(db.tagFlags) do
		local fresh = {}
		for tag, list in pairs(tags) do
			for name, f in pairs(list) do
				if f[2] > since then fresh[#fresh + 1] = name .. "," .. tag .. "," .. f[1] .. "," .. Enc(f[2]) end
			end
		end
		if #fresh > 0 then batches[#batches + 1] = { "C", setId, fresh } end
	end
	for name, a in pairs(db.appeals) do
		if a[1] > since then batches[#batches + 1] = { "K", name, { Enc(a[1]) .. "\t" .. a[2] } } end
	end
	for _, idea in pairs(db.usage) do
		if idea[2] > since then
			batches[#batches + 1] = { "O", idea[1], { Enc(idea[2]) .. "\t" .. idea[3] .. "\t" .. idea[4] } }
		end
	end
	for _, idea in pairs(db.ideas) do
		if idea[2] > since then
			batches[#batches + 1] = { "O", idea[1], { Enc(idea[2]) .. "\t" .. idea[3] .. "\t" .. idea[4] } }
		end
	end
	return sets, votes, reports, batches
end

-- Голоса (W) и жалобы (X) пачками, чтобы не упереться в размер сообщения
local function SendBatches(self, kind, setId, entries, dest, except)
	for i = 1, #entries, 8 do
		local batch = {}
		for k = i, math.min(i + 7, #entries) do batch[#batch + 1] = entries[k] end
		self:Send(kind .. setId .. "\t" .. table.concat(batch, ";"), dest, except)
	end
end
local function SendVotes(self, setId, entries, dest, except)
	SendBatches(self, "W", setId, entries, dest, except)
end

function Net:Answer(reqId, since, dest)
	pendingAnswers[reqId] = nil
	local sets, votes, reports, batches = CollectSince(since)
	self:Send("A" .. reqId, dest)
	for _, set in ipairs(sets) do
		self:Send("P" .. Net.EncodeSet(set), dest)
	end
	for setId, list in pairs(votes) do
		SendVotes(self, setId, list, dest)
	end
	for setId, list in pairs(reports) do
		SendBatches(self, "X", setId, list, dest)
	end
	for _, b in ipairs(batches) do
		SendBatches(self, b[1], b[2], b[3], dest)
	end
end

local handlers = {}

handlers.P = function(self, body, sender, origin)
	local set = Net.DecodeSet(body)
	if set and self:StoreSet(set, sender) then self:Relay("P" .. body, origin) end
end

handlers.V = function(self, body, sender, origin)
	local setId, stars, t = body:match("^([^\t]+)\t(%d)\t(%w+)$")
	if setId and self:StoreVote(setId, sender, tonumber(stars), Dec(t) or 0) then
		-- дальше голос идёт с именем проголосовавшего
		self:Relay("W" .. setId .. "\t" .. sender .. "," .. stars .. "," .. t, origin)
	end
end

handlers.W = function(self, body, _, origin)
	local setId, list = body:match("^([^\t]+)\t(.+)$")
	if not setId then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local voter, stars, t = entry:match("^([^,]+),(%d),(%w+)$")
		if voter and self:StoreVote(setId, voter, tonumber(stars), Dec(t) or 0) then
			fresh[#fresh + 1] = entry
		end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendVotes(self, setId, fresh, nil, origin) end
end

handlers.R = function(self, body, sender, origin)
	local setId, reason, t = body:match("^([^\t]+)\t(%a)\t(%w+)$")
	if setId and self:StoreReport(setId, sender, reason, Dec(t) or 0) then
		self:Relay("X" .. setId .. "\t" .. sender .. "," .. reason .. "," .. t, origin)
	end
end

handlers.X = function(self, body, _, origin)
	local setId, list = body:match("^([^\t]+)\t(.+)$")
	if not setId then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local name, reason, t = entry:match("^([^,]+),(%a),(%w+)$")
		if name and self:StoreReport(setId, name, reason, Dec(t) or 0) then fresh[#fresh + 1] = entry end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "X", setId, fresh, nil, origin) end
end

handlers.F = function(self, body, sender, origin)
	local setId, on, t = body:match("^([^\t]+)\t([01])\t(%w+)$")
	if setId and self:StoreFav(setId, sender, on, Dec(t) or 0) then
		self:Relay("U" .. setId .. "\t" .. sender .. "," .. on .. "," .. t, origin)
	end
end

-- f<на кого>\t<1|0>\t<время> — отправитель подписался / отписался; g<на кого>\t<кто>,<1|0>,<время>;… — пересланное
handlers.f = function(self, body, sender, origin)
	local target, on, t = body:match("^([^\t]+)\t([01])\t(%w+)$")
	if target and self:StoreFollow(target, sender, on, Dec(t) or 0) then
		self:Relay("g" .. target .. "\t" .. sender .. "," .. on .. "," .. t, origin)
	end
end

handlers.g = function(self, body, _, origin)
	local target, list = body:match("^([^\t]+)\t(.+)$")
	if not target then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local name, on, t = entry:match("^([^,]+),([01]),(%w+)$")
		if name and self:StoreFollow(target, name, on, Dec(t) or 0) then fresh[#fresh + 1] = entry end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "g", target, fresh, nil, origin) end
end

-- T<образ>\t<тег>\t<1|0>\t<время> — отправитель оспорил тег; C<образ>\t<кто>,<тег>,<1|0>,<время>;… — пересланное
handlers.T = function(self, body, sender, origin)
	local setId, tag, on, t = body:match("^([^\t]+)\t([%w_]+)\t([01])\t(%w+)$")
	if setId and self:StoreTagFlag(setId, sender, tag, on, Dec(t) or 0) then
		self:Relay("C" .. setId .. "\t" .. sender .. "," .. tag .. "," .. on .. "," .. t, origin)
	end
end

handlers.C = function(self, body, _, origin)
	local setId, list = body:match("^([^\t]+)\t(.+)$")
	if not setId then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local name, tag, on, t = entry:match("^([^,]+),([%w_]+),([01]),(%w+)$")
		if name and self:StoreTagFlag(setId, name, tag, on, Dec(t) or 0) then fresh[#fresh + 1] = entry end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "C", setId, fresh, nil, origin) end
end

handlers.U = function(self, body, _, origin)
	local setId, list = body:match("^([^\t]+)\t(.+)$")
	if not setId then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local name, on, t = entry:match("^([^,]+),([01]),(%w+)$")
		if name and self:StoreFav(setId, name, on, Dec(t) or 0) then fresh[#fresh + 1] = entry end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "U", setId, fresh, nil, origin) end
end

-- J<время>\t<текст> — обращение отправителя; K<кто>\t<время>\t<текст> — пересланное
-- N<время>\t<вид>\t<текст> — предложение отправителя; O<кто>\t<время>\t<вид>\t<текст> — пересланное
handlers.N = function(self, body, sender, origin)
	local t, kind, text = body:match("^(%w+)\t(%a)\t(.+)$")
	if t and self:StoreIdea(sender, Dec(t) or 0, kind, text) then
		self:Relay("O" .. sender .. "\t" .. t .. "\t" .. kind .. "\t" .. Clean(text, APPEAL_MAX), origin)
	end
end

handlers.O = function(self, body, _, origin)
	local name, t, kind, text = body:match("^([^\t]+)\t(%w+)\t(%a)\t(.+)$")
	if name and self:StoreIdea(name, Dec(t) or 0, kind, text) then self:Relay("O" .. body, origin) end
end

handlers.J = function(self, body, sender, origin)
	local t, text = body:match("^(%w+)\t(.+)$")
	if t and self:StoreAppeal(sender, Dec(t) or 0, text) then
		self:Relay("K" .. sender .. "\t" .. t .. "\t" .. Clean(text, APPEAL_MAX), origin)
	end
end

handlers.K = function(self, body, _, origin)
	local name, t, text = body:match("^([^\t]+)\t(%w+)\t(.+)$")
	if name and self:StoreAppeal(name, Dec(t) or 0, text) then self:Relay("K" .. body, origin) end
end

handlers.G = function(self, body, sender, origin)
	local text, t = body:match("^([^\t]+)\t(%w+)$")
	if text and self:StoreTagSuggestion(text, sender, Dec(t) or 0) then
		self:Relay("Y" .. text .. "\t" .. sender .. "," .. t, origin)
	end
end

handlers.Y = function(self, body, _, origin)
	local text, list = body:match("^([^\t]+)\t(.+)$")
	if not text then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local name, t = entry:match("^([^,]+),(%w+)$")
		if name and self:StoreTagSuggestion(text, name, Dec(t) or 0) then fresh[#fresh + 1] = entry end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "Y", text, fresh, nil, origin) end
end

handlers.L = function(self, body, sender, origin)
	local entry = ParseScore(body)
	if entry and self:StoreScore(sender, entry) then
		self:Relay("Zs\t" .. sender .. "," .. body, origin)
	end
end

handlers.Z = function(self, body, _, origin)
	local list = body:match("^s\t(.+)$")
	if not list then return end
	local fresh = {}
	for item in list:gmatch("[^;]+") do
		local name, rest = item:match("^([^,]+),(.+)$")
		local entry = rest and ParseScore(rest)
		if entry and self:StoreScore(name, entry) then fresh[#fresh + 1] = item end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "Z", "s", fresh, nil, origin) end
end

-- Решение модератора принимаем только напрямую от него и не пересылаем:
-- пересланное подделать проще простого
handlers.M = function(self, body, sender)
	if not TH:IsModerator(sender) then return end
	local action, target = body:match("^(%a)\t(.+)$")
	-- назначать и снимать модераторов может только админ
	if (action == "m" or action == "x") and not TH:IsAdmin(sender) then return end
	if action then self:ApplyModDecision(action, target) end
end

handlers.D = function(self, body, sender)
	local set = DB().sets[body]
	-- снять образ может только автор (пересланное удаление не принимаем)
	if set and set.author == sender then self:RemoveSet(body) end
end

local SMALL_NETWORK = 20 -- в маленькой сети отвечаем новичку «я тоже тут»

-- Появился игрок. Друг Battle.net или группа: отвечаем и синхронизируемся
-- с ним напрямую. Канал: если мы ещё ни с кем не синхронизировались —
-- спросим, а в маленькой сети ещё и отзовёмся.
-- персонажи друга Battle.net (принимаем только напрямую от него)
handlers.h = function(self, body, _, origin)
	if origin.kind ~= "BNET" then return end
	local chars, n = TH.db.friendChars, 0
	for name in body:gmatch("[^,]+") do
		n = n + 1
		if n > 60 then break end
		if TH:IsCharName(name) and not TH.db.myChars[name] then chars[name] = Now() end
	end
end

handlers.H = function(self, _, sender, origin)
	if origin.kind == "BNET" then
		self:Send("I" .. PROTOCOL, origin)
		self:SendMyChars(origin)
		self:SyncWithPeer(origin, sender)
		return
	end
	if origin.kind == "GROUP" or origin.kind == "GUILD" then
		self:Send("I" .. PROTOCOL, origin.kind == "GROUP" and GROUP or GUILD)
		return
	end
	if origin.kind == "WHISPER" then
		self:Send("I" .. PROTOCOL, origin)
		return
	end
	self:ScheduleSync(5 + math.random() * 10)
	local members = self:ChannelMemberCount()
	if (members or self:PeerCount() + 1) <= SMALL_NETWORK then
		C_Timer.After(1 + math.random() * 4, function() self:Send("I" .. PROTOCOL, CHANNEL) end)
	end
end

handlers.I = function(self, _, sender, origin)
	if origin.kind == "BNET" then self:SyncWithPeer(origin, sender) end
end

local whisperSynced = {}
function Net:SyncWithWhisper(dest, name)
	if whisperSynced[name] then return end
	whisperSynced[name] = true
	C_Timer.After(2 + math.random() * 3, function()
		self:RequestSync(dest, name)
		self:SharePeers(dest, name)
		-- когда поставлен аддон: новичок засчитывается тому, кто ему о нём рассказал
		if (TH.db.installed or 0) > 0 then self:Send("w" .. Enc(TH.db.installed), dest) end
	end)
end

---------------------------------------------------------------------------
-- Знакомство через каталог. Одиночка (ни канала с людьми, ни друзей Battle.net,
-- ни согильдийцев, ни группы) стучится скрытым шёпотом к авторам образов из
-- каталога и базы — тем, кто публиковал недавно. Кто в игре с аддоном, отвечает,
-- и аддоны синхронизируются: одиночка подключён ко всей сети. Стучимся понемногу,
-- к каждому не чаще раза в сутки; «такого игрока нет в игре» в чат не пишем.
---------------------------------------------------------------------------
local KNOCK_BATCH, KNOCK_EVERY, KNOCK_MAX, KNOCK_REPEAT = 3, 300, 8, 86400
local knockRounds, knocked = 0, {} -- knocked[имя] = время стука в этой сессии
-- расы Альянса и Орды: шёпот другой фракции игра не пропускает
local ALLIANCE = { [1] = true, [3] = true, [4] = true, [7] = true, [11] = true, [22] = true, [25] = true, [29] = true,
	[30] = true, [32] = true, [34] = true, [37] = true, [52] = true, [85] = true, [91] = true, [95] = true }
local HORDE = { [2] = true, [5] = true, [6] = true, [8] = true, [9] = true, [10] = true, [26] = true, [27] = true,
	[28] = true, [31] = true, [35] = true, [36] = true, [70] = true, [84] = true, [86] = true, [96] = true }

-- «Имя-Сервер» (в Forever своя проверка: «Имя Фамилия»)
local function IsCharName(name)
	if rawget(TH, "IsCharName") then return TH:IsCharName(name) end
	return type(name) == "string" and #name <= 64 and name:find("^[^%-,]+%-[^%-,]+$") ~= nil
end

function Net:IsIsolated()
	return self:PeerCount() == 0 and self:BNetPeerCount() == 0 and self:GuildPeerCount() == 0
		and not self:GroupHasOtherRealm() and not next(self.whisperPeers)
end

-- Фракция по расе: «A», «H» или nil (нейтральный пандарен, неизвестная раса)
function Net.RaceFaction(race)
	race = tonumber(race)
	return race and ((ALLIANCE[race] and "A") or (HORDE[race] and "H")) or nil
end

-- К кому стучаться: авторы из базы и каталога и «телефонная книга» каталога — игроки
-- с аддоном, недавно бывшие в сети (сначала самые недавние). Другую фракцию пропускаем.
function Net:KnockCandidates()
	local me, myChars = Net.Me(), TH.db.myChars or {}
	local f = UnitFactionGroup and UnitFactionGroup("player")
	local mine = (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
	local last = TH.db.knocks or {}
	local now, best = Now(), {}
	local function Consider(name, faction, t)
		if not IsCharName(name) or name == me or myChars[name] or knocked[name] then return end
		if now - (last[name] or 0) < KNOCK_REPEAT then return end
		if mine and faction and faction ~= mine then return end
		t = t or 0
		if not best[name] or t > best[name] then best[name] = t end
	end
	for _, set in pairs(DB().sets) do Consider(set.author, Net.RaceFaction(set.race), set.created) end
	local bundled = TransmogHub_Bundled or {}
	for _, set in ipairs(bundled.sets or {}) do Consider(set.author, Net.RaceFaction(set.race), set.created) end
	for _, p in ipairs(bundled.peers or {}) do Consider(p[1], p[2], p[3]) end
	for name, p in pairs(DB().presence or {}) do Consider(name, p[1] ~= "-" and p[1] or nil, p[2]) end
	local list = {}
	for name, t in pairs(best) do list[#list + 1] = { name, t } end
	table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
	return list
end

-- force — проверка вручную (/thub knock): без условия «одиночка» и лимита раундов;
-- target — постучаться к конкретному игроку
function Net:KnockCatalog(force, target)
	local names = {}
	if not force and (knockRounds >= KNOCK_MAX or not self:IsIsolated()) then return names end
	if not force then knockRounds = knockRounds + 1 end
	TH.db.knocks = TH.db.knocks or {}
	local now = Now()
	local list = self:KnockCandidates()
	if target and target ~= "" then list = { { Net.FullName(target) } } end
	for _, c in ipairs(list) do
		if #names >= KNOCK_BATCH then break end
		knocked[c[1]] = now
		TH.db.knocks[c[1]] = now
		self:Send("H" .. PROTOCOL, WHISPER(c[1]))
		names[#names + 1] = c[1]
	end
	-- старые отметки о стуке не копим
	for name, t in pairs(TH.db.knocks) do
		if now - t > KNOCK_REPEAT then TH.db.knocks[name] = nil end
	end
	return names
end

-- «Игрок не найден» после нашего стука — не показываем в чате
local function HideKnockMiss(_, _, msg)
	local fmt = ERR_CHAT_PLAYER_NOT_FOUND_S
	if type(msg) ~= "string" or type(fmt) ~= "string" then return false end
	local pre, post = fmt:match("^(.-)%%s(.*)$")
	if not pre or #msg <= #pre + #post or msg:sub(1, #pre) ~= pre or msg:sub(#msg - #post + 1) ~= post then return false end
	local name = msg:sub(#pre + 1, #msg - #post):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	name = Net.FullName(name)
	return knocked[name] ~= nil and Now() - knocked[name] < 60
end
Net.HideKnockMiss = HideKnockMiss

---------------------------------------------------------------------------
-- Знакомые. Кого слышали через шёпот, аддон помнит между сессиями (до 50, 30 дней) и
-- после входа стучится к ним — сеть связывается сразу. Знакомые передают друг другу
-- по 5 своих контактов («k»), так из одного знакомства вырастает сеть. Ещё аддон стучится
-- к тем, с кем вы переписывались или были в группе (14 дней): у кого нет аддона, ничего
-- не увидит. Не больше 3 стуков за раз и 20 за сессию, к каждому — раз в сутки.
---------------------------------------------------------------------------
local function Secret(v) return issecretvalue and issecretvalue(v) end
local KNOWN_MAX, KNOWN_TTL = 50, 30 * 86400
local CONTACT_MAX, CONTACT_TTL = 100, 14 * 86400
local NEW_USER, INVITE_WINDOW = 7 * 86400, 30 * 86400
local KNOCK_SESSION_MAX, SHARE_PEERS = 20, 5
local sessionKnocks = 0

-- Оставить в таблице [имя] = время не больше max самых свежих
local function KeepRecent(t, max)
	local list = {}
	for k, v in pairs(t) do list[#list + 1] = { k, v } end
	if #list <= max then return end
	table.sort(list, function(a, b) return a[2] > b[2] end)
	for i = max + 1, #list do t[list[i][1]] = nil end
end

local function CanKnock(self, name, now)
	if not IsCharName(name) or name == Net.Me() or (TH.db.myChars or {})[name] or knocked[name] then return false end
	local t = self.whisperPeers[name]
	if t and now - t < PEER_TIMEOUT then return false end
	local last = TH.db.knocks and TH.db.knocks[name]
	return not last or now - last >= KNOCK_REPEAT
end

function Net:Knock(name)
	local now = Now()
	knocked[name] = now
	TH.db.knocks = TH.db.knocks or {}
	TH.db.knocks[name] = now
	sessionKnocks = sessionKnocks + 1
	self:Send("H" .. PROTOCOL, WHISPER(name))
end

-- Собеседник: шёпот в обе стороны и группа (имя — полное)
function Net:NoteContact(name)
	if not IsCharName(name) or name == Net.Me() then return end
	TH.db.chatContacts = TH.db.chatContacts or {}
	TH.db.chatContacts[name] = Now()
	KeepRecent(TH.db.chatContacts, CONTACT_MAX)
end

-- Фракция одной буквой: A, H или nil (нейтральный пандарен)
local function FactionLetter(unit)
	local f = UnitFactionGroup and UnitFactionGroup(unit)
	if Secret(f) then return nil end
	return (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
end

function Net:NoteGroup()
	if not (IsInGroup and IsInGroup()) or not GetNumGroupMembers then return end
	local raid = IsInRaid and IsInRaid()
	local mine = FactionLetter("player")
	for i = 1, GetNumGroupMembers() do
		local unit = raid and ("raid" .. i) or ("party" .. i)
		-- из межфракционной группы — только своих: шёпот другой фракции не доходит
		local theirs = FactionLetter(unit)
		if mine and theirs and theirs ~= mine then unit = nil end
		local name, realm
		if unit then name, realm = UnitFullName(unit) end
		if type(name) == "string" and not Secret(name) and name ~= "" then
			self:NoteContact(Net.FullName((realm and realm ~= "" and not Secret(realm)) and (name .. "-" .. realm) or name))
		end
	end
end

-- Сначала знакомые прошлых сессий, потом собеседники; по 3 за раз
function Net:KnockAcquaintances()
	local now, sent = Now(), 0
	for _, source in ipairs({ { TH.db.knownPeers, KNOWN_TTL }, { TH.db.chatContacts, CONTACT_TTL } }) do
		local list = {}
		for name, t in pairs(source[1] or {}) do
			if now - t < source[2] then list[#list + 1] = { name, t } end
		end
		table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
		for _, c in ipairs(list) do
			if sent >= KNOCK_BATCH or sessionKnocks >= KNOCK_SESSION_MAX then return end
			if CanKnock(self, c[1], now) then
				self:Knock(c[1])
				sent = sent + 1
			end
		end
	end
end

-- Попросить у игрока его образы: незнакомому — стук (ответ запустит синхронизацию),
-- знакомому — сразу запрос синхронизации
function Net:AskFor(name)
	name = Net.FullName(name)
	if not IsCharName(name) or name == Net.Me() then return end
	local t = self.whisperPeers[name]
	if t and Now() - t < PEER_TIMEOUT then
		self:RequestSync(WHISPER(name), name)
	else
		knocked[name] = nil -- игрок сам прислал ссылку: стучимся, даже если сегодня уже стучались
		self:Knock(name)
	end
end

-- Передать знакомому до 5 своих контактов (кроме него самого). Все они — нашей фракции
-- (шёпот ходит только внутри фракции), поэтому первым идёт «=A» или «=H»: получатель
-- другой фракции их пропустит. Старые версии «=A» пропускают как не похожее на имя.
function Net:SharePeers(dest, except)
	local now, names, seen = Now(), {}, {}
	local function Add(name)
		if #names < SHARE_PEERS and name ~= except and not seen[name] and IsCharName(name) then
			seen[name] = true
			names[#names + 1] = name
		end
	end
	for _, name in ipairs(self:ActiveWhisperPeers()) do Add(name) end
	local known = {}
	for name, t in pairs(TH.db.knownPeers or {}) do
		if now - t < KNOWN_TTL then known[#known + 1] = { name, t } end
	end
	table.sort(known, function(a, b) return a[2] > b[2] end)
	for _, k in ipairs(known) do Add(k[1]) end
	if #names == 0 then return end
	local f = FactionLetter("player")
	self:Send("k" .. (f and ("=" .. f .. ",") or "") .. table.concat(names, ","), dest)
end

handlers.k = function(self, body, _, origin)
	if origin.kind ~= "WHISPER" then return end
	local theirs = body:match("^=([AH]),")
	local mine = FactionLetter("player")
	if theirs and mine and theirs ~= mine then return end -- контакты другой фракции
	local now, sent = Now(), 0
	for name in body:gsub("^=[AH],", ""):gmatch("[^,]+") do
		if sent >= KNOCK_BATCH or sessionKnocks >= KNOCK_SESSION_MAX then break end
		name = Net.FullName(name)
		if #name <= 64 and CanKnock(self, name, now) then
			self:Knock(name)
			sent = sent + 1
		end
	end
end

---------------------------------------------------------------------------
-- Телефонная книга. Раз в сутки аддон отмечается в сети: «p s\tимя,фракция,время». Отметки
-- расходятся, как голоса, и копятся у всех (14 дней, до 2000): к недавно бывшим в сети
-- одиночка стучится первым, а ежедневный выпуск раздаёт их новичкам в каталоге.
-- Отключить: /thub phonebook off или в настройках (тогда отметок нет, запись истечёт сама).
---------------------------------------------------------------------------
function Net:StorePresence(name, faction, t)
	if not IsCharName(name) or not t or TH:IsBanned(name) then return false end
	local now = Now()
	if t > now + 3600 or now - t > PRESENCE_TTL then return false end
	local db = DB()
	db.presence = db.presence or {}
	local old = db.presence[name]
	if old and old[2] >= t then return false end
	db.presence[name] = { faction, t }
	return true
end

handlers.p = function(self, body, _, origin)
	local key, list = body:match("^([^\t]+)\t(.+)$")
	if key ~= "s" then return end
	local fresh = {}
	for entry in list:gmatch("[^;]+") do
		local name, f, t = entry:match("^([^,]+),([AH%-]),(%w+)$")
		if name and self:StorePresence(name, f, Dec(t)) then fresh[#fresh + 1] = entry end
	end
	if #fresh > 0 and #queue < MAX_RELAY_QUEUE then SendBatches(self, "p", "s", fresh, nil, origin) end
end

-- Отметиться в сети (раз в сутки на персонажа)
function Net:SendPresence()
	if not TH.db.sendPresence then return end
	local me, now = Net.Me(), Now()
	local day = math.floor(now / 86400)
	TH.db.presenceSent = TH.db.presenceSent or {}
	if TH.db.presenceSent[me] == day then return end
	TH.db.presenceSent[me] = day
	local f = FactionLetter("player") or "-"
	if self:StorePresence(me, f, now) then
		SendBatches(self, "p", "s", { me .. "," .. f .. "," .. Enc(now) })
	end
end

-- Сколько игроков с аддоном было в сети за 2 недели (по отметкам)
function Net:PresenceCount()
	local n, now = 0, Now()
	for _, p in pairs(DB().presence or {}) do
		if now - p[2] <= PRESENCE_TTL then n = n + 1 end
	end
	return n
end

-- «Я поставил аддон тогда-то». Новичок (до 7 дней), с которым вы переписывались или были
-- в группе, засчитывается вам как приглашённый (достижения «Сарафанное радио»)
handlers.w = function(self, body, sender, origin)
	if origin.kind ~= "WHISPER" then return end
	local t, now = Dec(body), Now()
	if not t or t > now + 86400 or now - t > NEW_USER then return end
	local contact = TH.db.chatContacts and TH.db.chatContacts[sender]
	if not contact or now - contact > INVITE_WINDOW then return end
	TH.db.invited = TH.db.invited or {}
	if not TH.db.invited[sender] then TH.db.invited[sender] = now end
end

function Net:SyncWithPeer(dest, name)
	if bnSynced[dest.target] then return end
	bnSynced[dest.target] = true
	self:RequestSync(dest, name)
end

handlers.Q = function(self, body, _, origin)
	local reqId, since = body:match("^(%w+)\t(%w+)$")
	if not reqId or pendingAnswers[reqId] then return end
	since = Dec(since) or 0
	local sets, votes, reports, batches = CollectSince(since)
	if #sets == 0 and not next(votes) and not next(reports) and #batches == 0 then
		-- другу отвечаем всегда: пустой ответ тоже значит «синхронизировано»
		if origin.kind == "BNET" or origin.kind == "WHISPER" then self:Send("A" .. reqId, origin) end
		return
	end
	if origin.kind == "BNET" or origin.kind == "WHISPER" then
		self:Answer(reqId, since, origin)
		return
	end
	-- В канале и группе отвечает тот, чья случайная задержка кончится первой
	pendingAnswers[reqId] = true
	local dest = origin.kind == "GROUP" and GROUP or origin.kind == "GUILD" and GUILD or CHANNEL
	C_Timer.After(1 + math.random() * 5, function()
		if pendingAnswers[reqId] then self:Answer(reqId, since, dest) end
	end)
end

handlers.A = function(self, body)
	pendingAnswers[body] = nil -- кто-то уже отвечает
	local req = myRequests[body]
	if not req then return end
	myRequests[body] = nil
	if req.peer then
		DB().peerSync[req.peer] = req.time
	elseif req.dest.kind == "CHANNEL" then
		self.synced = true
		DB().lastSync = req.time
	end
end

local function Dispatch(self, body, sender, origin)
	if not body or body == "" then return end
	local handler = handlers[body:sub(1, 1)]
	if handler then
		local ok, err = pcall(handler, self, body:sub(2), sender, origin)
		if not ok and TH.debug then TH:Print(L["Ошибка сети:"], err) end
	end
	if self.dirty then TH:RequestRefresh() end
end

-- Сообщение из канала или группы
function Net:OnMessage(prefix, text, channel, sender)
	if prefix ~= PREFIX then return end
	local origin
	if channel == "CHANNEL" then
		origin = CHANNEL
	elseif channel == "PARTY" or channel == "RAID" or channel == "INSTANCE_CHAT" then
		origin = GROUP
	elseif channel == "GUILD" then
		origin = GUILD
	elseif channel == "WHISPER" then
		origin = WHISPER(Net.FullName(sender))
	else
		return
	end
	sender = Net.FullName(sender)
	if sender == Net.Me() then return end
	-- согильдиец, которого не слышно в канале: гильдия — мост, рассылаем и через неё
	if origin == GUILD and not self.guildBridge and not self.channelPeers[sender] then self.guildBridge = true end
	if origin == CHANNEL then self.channelPeers[sender] = true end
	if origin == GUILD then self.guildPeers[sender] = Now() end
	if origin.kind == "WHISPER" then
		local known = self.whisperPeers[origin.target]
		self.whisperPeers[origin.target] = Now()
		TH.db.knownPeers = TH.db.knownPeers or {}
		TH.db.knownPeers[origin.target] = Now()
		KeepRecent(TH.db.knownPeers, KNOWN_MAX)
		-- новый знакомый: забираем у него новое (один раз за сессию)
		if not known then self:SyncWithWhisper(origin, origin.target) end
	end
	self.peers[sender] = Now()
	Dispatch(self, Assemble(sender, text), sender, origin)
end

-- Сообщение от друга Battle.net
function Net:OnBNetMessage(prefix, text, _, senderID)
	if prefix ~= PREFIX then return end
	local name = BNetName(senderID)
	if not name or name == Net.Me() then return end
	local isNew = not self.bnPeers[senderID]
	self.bnPeers[senderID] = { name = name, t = Now() }
	if isNew then TH:CheckAchievements() end
	Dispatch(self, Assemble("bn" .. senderID, text), name, BNET(senderID))
end

-- Сколько человек в скрытом канале (по данным игры), включая нас; nil — если неизвестно
function Net:ChannelMemberCount()
	if not (GetNumDisplayChannels and GetChannelDisplayInfo) or not self:IsConnected() then return nil end
	for i = 1, GetNumDisplayChannels() do
		local name, _, _, number, count = GetChannelDisplayInfo(i)
		if (number == self.channelId or name == CHANNEL_NAME) and type(count) == "number" and count > 0 then
			return count
		end
	end
end

-- Игроков с аддоном на своём сервере, кроме нас: по списку канала, иначе — по сообщениям
function Net:PeerCount()
	local members = self:ChannelMemberCount()
	if members then return members - 1 end
	local now, n = Now(), 0
	for _, t in pairs(self.peers) do
		if now - t < PEER_TIMEOUT then n = n + 1 end
	end
	return n
end

function Net:SetCount()
	local n = 0
	for _ in pairs(DB().sets) do n = n + 1 end
	return n
end

---------------------------------------------------------------------------
-- Запуск
---------------------------------------------------------------------------
function Net:OnConnected()
	if self.connectedOnce then return end
	self.connectedOnce = true
	self:Send("H" .. PROTOCOL, CHANNEL)
	C_Timer.After(3, function() self:RequestSync() end)
	TH:RequestRefresh()
end

local groupGreeted = false
function Net:OnGroupChanged()
	if not self:GroupHasOtherRealm() then
		groupGreeted = false
		return
	end
	if groupGreeted then return end
	groupGreeted = true
	self:Send("H" .. PROTOCOL, GROUP)
	C_Timer.After(5, function() self:RequestSync(GROUP, "group") end)
end

-- Гильдия: один раз за сессию знакомимся и спрашиваем новое у согильдийцев
local guildGreeted = false
function Net:GreetGuild()
	if guildGreeted or not IsInGuild() then return end
	guildGreeted = true
	self:Send("H" .. PROTOCOL, GUILD)
	C_Timer.After(8, function() self:RequestSync(GUILD, "guild") end)
end

function Net:Start()
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:RegisterEvent("BN_CHAT_MSG_ADDON")
	frame:RegisterEvent("GROUP_ROSTER_UPDATE")
	frame:RegisterEvent("CHAT_MSG_WHISPER")
	frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
	frame:SetScript("OnEvent", function(_, event, ...)
		if event == "CHAT_MSG_ADDON" then
			Net:OnMessage(...)
		elseif event == "BN_CHAT_MSG_ADDON" then
			Net:OnBNetMessage(...)
		elseif event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_WHISPER_INFORM" then
			local who = select(2, ...)
			if type(who) == "string" and not Secret(who) then pcall(Net.NoteContact, Net, Net.FullName(who)) end
		else
			Net:OnGroupChanged()
			pcall(Net.NoteGroup, Net)
		end
	end)

	lastTick = GetTime()
	C_Timer.NewTicker(0.25, Pump)

	C_Timer.After(JOIN_DELAY, function()
		if self:Join() then self:OnConnected() end
		self:GreetFriends()
		self:OnGroupChanged()
		self:GreetGuild()
	end)
	-- одиночка: через пару минут после входа и дальше раз в 5 минут стучимся к авторам каталога
	if ChatFrame_AddMessageEventFilter then ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", HideKnockMiss) end
	C_Timer.After(120, function() self:KnockCatalog() end)
	C_Timer.NewTicker(KNOCK_EVERY, function()
		self:KnockCatalog()
		self:KnockAcquaintances()
	end)
	-- знакомые прошлых сессий и собеседники: вскоре после входа
	C_Timer.After(45, function() self:KnockAcquaintances() end)
	-- отметка «я в сети» для телефонной книги: через 3 минуты и при смене суток
	C_Timer.After(180, function() self:SendPresence() end)
	C_Timer.NewTicker(3600, function() self:SendPresence() end)
	-- Раз в минуту: канал на месте? новые друзья в игре?
	C_Timer.NewTicker(60, function()
		CleanupPartial()
		if self.connectedOnce and not self:UpdateChannel() then self:Join() end
		self:GreetFriends()
	end)
end
