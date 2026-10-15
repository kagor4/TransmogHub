local _, ns = ...
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
--   * снять набор с публикации может только его автор;
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
local SYNC_LIMIT = 100           -- сколько наборов отдаём на один запрос
local MAX_SETS = 3000            -- сколько наборов храним
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

-- Набор -> строка. Поля через табуляцию.
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
	}, "\t")
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
		if TH.TAG_LABEL[tag] then tags[#tags + 1] = tag end
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
	}
end

---------------------------------------------------------------------------
-- Имена
---------------------------------------------------------------------------
local myRealm

-- Отправитель приходит как «Имя» (свой сервер) или «Имя-Сервер»
function Net.FullName(name)
	if not name or name == "" then return name end
	if name:find("-", 1, true) then return name end
	myRealm = myRealm or GetNormalizedRealmName() or ""
	return name .. "-" .. myRealm
end

function Net.Me()
	return Net.FullName(UnitName("player"))
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

function Net:IsLocked()
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return true end
	if C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted() then return true end
	return false
end

---------------------------------------------------------------------------
-- Очередь отправки с ограничением скорости
---------------------------------------------------------------------------
local queue = {}
local tokens = TOKENS_MAX
local lastTick = 0
local msgCounter = 0

local THROTTLED = {}
if Enum.SendAddonMessageResult then
	THROTTLED[Enum.SendAddonMessageResult.AddonMessageThrottle] = true
	THROTTLED[Enum.SendAddonMessageResult.ChannelThrottle] = true
	THROTTLED[Enum.SendAddonMessageResult.AddOnMessageLockdown] = true
end

local function Pump()
	local now = GetTime()
	tokens = math.min(TOKENS_MAX, tokens + (now - lastTick) * TOKEN_RATE)
	lastTick = now
	if #queue == 0 or tokens < 1 or not Net:IsConnected() or Net:IsLocked() then return end

	local msg = queue[1]
	local result = C_ChatInfo.SendAddonMessage(PREFIX, msg, "CHANNEL", tostring(Net.channelId))
	if THROTTLED[result] then
		tokens = 0
		return
	end
	tremove(queue, 1)
	tokens = tokens - 1
end

-- Ставит в очередь сообщение любой длины, разрезая его на части
function Net:Send(body)
	if #body <= MAX_MESSAGE - 1 then
		queue[#queue + 1] = "S" .. body
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
		queue[#queue + 1] = kind .. id .. piece
		first = false
	end
end

function Net:QueueLength()
	return #queue
end

---------------------------------------------------------------------------
-- Приём и сборка частей
---------------------------------------------------------------------------
local partial = {} -- [sender..id] = { parts, t }

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
	if db.tombstones[set.id] then return false end
	if db.sets[set.id] then return false end
	set.via = sender
	set.verified = (sender == set.author) or nil
	set.received = Now()
	db.sets[set.id] = set
	self.dirty = true
	return true
end

function Net:StoreVote(setId, voter, stars, t)
	stars = tonumber(stars)
	if not stars or stars < 1 or stars > 5 then return false end
	local db = DB()
	local votes = db.votes[setId]
	if not votes then
		votes = {}
		db.votes[setId] = votes
	end
	local old = votes[voter]
	if old and old[2] >= t then return false end
	votes[voter] = { stars, t }
	self.dirty = true
	return true
end

function Net:RemoveSet(setId)
	local db = DB()
	db.sets[setId] = nil
	db.votes[setId] = nil
	db.tombstones[setId] = Now()
	self.dirty = true
end

-- Ограничиваем базу: выкидываем самые старые наборы
function Net:Prune()
	local db = DB()
	local list = {}
	for _, set in pairs(db.sets) do list[#list + 1] = set end
	if #list <= MAX_SETS then return end
	table.sort(list, function(a, b) return (a.created or 0) > (b.created or 0) end)
	for i = MAX_SETS + 1, #list do
		db.sets[list[i].id] = nil
		db.votes[list[i].id] = nil
	end
end

---------------------------------------------------------------------------
-- Протокол
--   P<набор>                       — публикация или пересылка набора
--   V<id>\t<звёзды>\t<время>       — голос отправителя
--   W<id>\t<голосующий>,<зв>,<вр>;… — пересланные голоса (при синхронизации)
--   D<id>                          — снять с публикации (только автор)
--   H<версия>                      — «я в сети»
--   Q<запрос>\t<с какого времени>  — пришлите новое
--   A<запрос>                      — «я отвечаю на запрос», остальные молчат
---------------------------------------------------------------------------
function Net:PublishSet(set)
	self:StoreSet(CopyTable(set), Net.Me())
	self:Send("P" .. Net.EncodeSet(set))
end

function Net:SendVote(setId, stars)
	local t = Now()
	self:StoreVote(setId, Net.Me(), stars, t)
	self:Send("V" .. setId .. "\t" .. stars .. "\t" .. Enc(t))
end

function Net:Unpublish(setId)
	self:RemoveSet(setId)
	self:Send("D" .. setId)
end

local pendingAnswers = {} -- [reqId] = true, пока ждём своей очереди ответить

-- Время синхронизации запоминаем, только когда кто-то ответил: иначе,
-- войдя в пустой канал, мы бы потом не скачали старые наборы.
function Net:RequestSync()
	local since = math.max(0, (DB().lastSync or 0) - 3600) -- час запаса
	self.myReqId = Enc(math.random(0, 60000000))
	self.myReqTime = Now()
	self:Send("Q" .. self.myReqId .. "\t" .. Enc(since))
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

	local votes = {}
	for setId, list in pairs(db.votes) do
		local fresh = {}
		for voter, v in pairs(list) do
			if v[2] > since then fresh[#fresh + 1] = voter .. "," .. v[1] .. "," .. Enc(v[2]) end
		end
		if #fresh > 0 then votes[setId] = fresh end
	end
	return sets, votes
end

function Net:Answer(reqId, since)
	pendingAnswers[reqId] = nil
	local sets, votes = CollectSince(since)
	if #sets == 0 and not next(votes) then return end
	self:Send("A" .. reqId)
	for _, set in ipairs(sets) do
		self:Send("P" .. Net.EncodeSet(set))
	end
	for setId, list in pairs(votes) do
		-- голоса пачками, чтобы не упереться в размер сообщения
		local batch = {}
		for _, v in ipairs(list) do
			batch[#batch + 1] = v
			if #batch == 8 then
				self:Send("W" .. setId .. "\t" .. table.concat(batch, ";"))
				batch = {}
			end
		end
		if #batch > 0 then self:Send("W" .. setId .. "\t" .. table.concat(batch, ";")) end
	end
end

local handlers = {}

handlers.P = function(self, body, sender)
	local set = Net.DecodeSet(body)
	if set then self:StoreSet(set, sender) end
end

handlers.V = function(self, body, sender)
	local setId, stars, t = body:match("^([^\t]+)\t(%d)\t(%w+)$")
	if setId then self:StoreVote(setId, sender, tonumber(stars), Dec(t) or 0) end
end

handlers.W = function(self, body)
	local setId, list = body:match("^([^\t]+)\t(.+)$")
	if not setId then return end
	for entry in list:gmatch("[^;]+") do
		local voter, stars, t = entry:match("^([^,]+),(%d),(%w+)$")
		if voter then self:StoreVote(setId, voter, tonumber(stars), Dec(t) or 0) end
	end
end

handlers.D = function(self, body, sender)
	local set = DB().sets[body]
	-- снять набор может только автор
	if set and set.author == sender then self:RemoveSet(body) end
end

-- Появился новый игрок: если мы ещё ни с кем не синхронизировались, спросим
handlers.H = function(self)
	self:ScheduleSync(5 + math.random() * 10)
end

handlers.Q = function(self, body, sender)
	local reqId, since = body:match("^(%w+)\t(%w+)$")
	if not reqId or pendingAnswers[reqId] then return end
	since = Dec(since) or 0
	local sets, votes = CollectSince(since)
	if #sets == 0 and not next(votes) then return end
	-- Отвечает тот, чья случайная задержка кончится первой
	pendingAnswers[reqId] = true
	C_Timer.After(1 + math.random() * 5, function()
		if pendingAnswers[reqId] then self:Answer(reqId, since) end
	end)
end

handlers.A = function(self, body)
	pendingAnswers[body] = nil -- кто-то уже отвечает
	if body == self.myReqId then
		self.synced = true
		DB().lastSync = self.myReqTime
	end
end

function Net:OnMessage(prefix, text, channel, sender)
	if prefix ~= PREFIX then return end
	sender = Net.FullName(sender)
	if sender == Net.Me() then return end
	self.peers[sender] = Now()
	local body = Assemble(sender, text)
	if not body or body == "" then return end
	local handler = handlers[body:sub(1, 1)]
	if handler then
		local ok, err = pcall(handler, self, body:sub(2), sender)
		if not ok and TH.debug then TH:Print("Ошибка сети:", err) end
	end
	if self.dirty then TH:RequestRefresh() end
end

function Net:PeerCount()
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
	self:Send("H" .. PROTOCOL)
	C_Timer.After(3, function() self:RequestSync() end)
	TH:RequestRefresh()
end

function Net:Start()
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	local frame = CreateFrame("Frame")
	frame:RegisterEvent("CHAT_MSG_ADDON")
	frame:SetScript("OnEvent", function(_, _, ...) Net:OnMessage(...) end)

	lastTick = GetTime()
	C_Timer.NewTicker(0.25, Pump)

	C_Timer.After(JOIN_DELAY, function()
		if self:Join() then self:OnConnected() end
	end)
	-- Следим, что канал на месте (его могли покинуть командой /leave)
	C_Timer.NewTicker(60, function()
		CleanupPartial()
		if self.connectedOnce and not self:UpdateChannel() then self:Join() end
	end)
end
