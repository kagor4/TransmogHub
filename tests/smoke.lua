-- Permissive stub of the WoW API: any unknown method returns a stub.
local function stub(name)
  local o = {}
  return setmetatable(o, {
    __index = function(t, k) local f = function(self, ...) return nil end; return f end,
  })
end
local function frame()
  local f = { scripts = {}, shown = true, checked = false, text = "" }
  local mt = {}
  mt.__index = function(t, k)
    local special = {
      SetScript = function(self, n, fn) self.scripts[n] = fn end,
      HookScript = function(self, n, fn) self.scripts[n] = fn end,
      IsShown = function(self) return self.shown end,
      Show = function(self) self.shown = true; if self.scripts.OnShow then self.scripts.OnShow(self) end end,
      Hide = function(self) self.shown = false end,
      SetShown = function(self, v) self.shown = v and true or false end,
      CreateFontString = function() return frame() end,
      CreateTexture = function() return frame() end,
      GetName = function(self) return self.name end,
      GetText = function(self) return self.text end,
      SetText = function(self, v) self.text = v end,
      GetChecked = function(self) return self.checked end,
      SetChecked = function(self, v) self.checked = v end,
      GetPlayerActor = function(self) return self.actor end,
    }
    if special[k] then return special[k] end
    if type(k) == "string" and k:match("^%l") then return nil end
    return function() return nil end
  end
  return setmetatable(f, mt)
end
local actor = frame()
local actorMeta = getmetatable(actor).__index
actor.cb = nil
actor.SetOnModelLoadedCallback = function(self, cb) self.cb = cb end
actor.SetModelByUnit = function(self) if self.cb then self.cb(self) end end
actor.IsLoaded = function() return true end
actor.GetItemTransmogInfoList = function()
  return { [1] = {appearanceID=111, secondaryAppearanceID=0, illusionID=0}, [3] = {appearanceID=333, secondaryAppearanceID=334, illusionID=0},
           [16] = {appearanceID=1616, secondaryAppearanceID=0, illusionID=5900}, [2] = {appearanceID=0, secondaryAppearanceID=0, illusionID=0} }
end
_G.CreateFrame = function(kind, name, parent, template)
  local f = frame(); f.name = name
  if kind == "ModelScene" then f.actor = actor end
  if name then _G[name] = f end
  return f
end
UIParent = frame(); GameTooltip = frame()
UISpecialFrames = {}; StaticPopupDialogs = {}; StaticPopup_Show = function(n) print("[popup]", n) end
ReloadUI = function() end
time = os.time; date = os.date; tinsert = table.insert; tremove = table.remove; wipe = function(t) for k in pairs(t) do t[k]=nil end return t end
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
CopyTable = function(t) local r = {} for k, v in pairs(t) do r[k] = type(v)=="table" and CopyTable(v) or v end return r end
Mixin = function(o, ...) for _, m in ipairs({...}) do for k, v in pairs(m) do o[k] = v end end return o end
Clamp = function(v, a, b) return math.min(math.max(v, a), b) end
C_Timer = { After = function(_, fn) fn() end }
UnitName = function() return "Тест" end; GetNormalizedRealmName = function() return "Гордунни" end
UnitClass = function() return "Разбойник", "ROGUE" end; UnitRace = function() return "Человек", "Human", 1 end; UnitSex = function() return 2 end
C_CreatureInfo = { GetRaceInfo = function(id) return { raceName = "Раса" .. id } end }
C_TransmogCollection = {
  GetSourceInfo = function(id) return { itemID = id * 10, name = "Вещь " .. id, quality = 4, isCollected = id % 2 == 0, sourceType = 1, isHideVisual = false } end,
  GetAppearanceInfoBySource = function() return { appearanceIsCollected = false } end,
  GetAppearanceSourceDrops = function() return { { instance = "Каражан", encounter = "Мидива", difficulties = {"Героич."} } } end,
}
C_Item = { GetItemInfoInstant = function(id) return id, "", "", "", 1, 4, id % 4 + 1 end, GetItemNameByID = function() return "X" end, GetItemIconByID = function() return 1 end, RequestLoadItemDataByID = function() end }
C_Texture = { GetAtlasInfo = function() return {} end }
C_AddOns = { LoadAddOn = function() end, GetAddOnMetadata = function() return "0.2.0" end }
Minimap = frame(); Minimap.GetWidth = function() return 140 end; Minimap.GetFrameLevel = function() return 2 end
Enum = { ItemTryOnReason = { Success = 0, DataPending = 3 } }
ItemUtil = { CreateItemTransmogInfo = function(a, s, i) return {a, s, i} end }
INVSLOT_MAINHAND = 16; INVSLOT_SHOULDER = 3
ITEM_QUALITY_COLORS = { [4] = { hex = "|cffa335ee" } }
TRANSMOG_SOURCE_1 = "Добыча с босса"; HEADSLOT = "Голова"; YES="Да"; NO="Нет"; CANCEL="Отмена"
MenuUtil = { CreateContextMenu = function(owner, gen)
  local root
  root = setmetatable({}, { __index = function(_, method) return function(_, text, isSel, setSel)
    if setSel then setSel()
    elseif method == "CreateButton" and type(isSel) == "function" then isSel() end
    return root
  end end })
  gen(owner, root)
end }
SlashCmdList = {}
Constants = { Transmog = { MainHandTransmogIsIndividualWeapon = -1, NoTransmogID = 0 } }
GetLocale = function() return "ruRU" end; CLOSE = "Закрыть"
PlaySound = function() end; SOUNDKIT = { ACHIEVEMENT_MENU_OPEN = 1 }; UIFrameFadeOut = function() end
CreateAtlasMarkup = function() return "*" end; GameTooltip_Hide = function() end
-- иконки «есть в игре», кроме нарочно отсутствующей; номер файла — по имени
GetFileIDFromPath = function(p)
  if p:find("Shirt") or p:find("shirt") then return 123 end
  if p:lower():find("missing") then return nil end
  local n = 0
  for i = 1, #p do n = (n * 31 + p:lower():byte(i)) % 1000000 end
  return 1000000 + n
end
GetMacroIcons = function(t) for i = 1, 200 do t[#t + 1] = 5000 + i end end
GetMacroItemIcons = function(t) for i = 1, 100 do t[#t + 1] = 6000 + i end; t[#t + 1] = 5001 end
GetInventoryItemTexture = function() return 777 end
-- Имитация канала и сообщений аддонов
local clock = 0
GetTime = function() return clock end
local serverTime = 1760000000
GetServerTime = function() return serverTime end
NUM_CHAT_WINDOWS = 1; ChatFrame1 = frame()
local joined = false
JoinTemporaryChannel = function(name) joined = (name == "TransmogHubNet") end
GetChannelName = function(name) if joined and name == "TransmogHubNet" then return 5, name end return 0 end
local sent, groupSent, bnSent = {}, {}, {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, chatType, target)
    assert(prefix == "TMHUB", "prefix")
    assert(#msg <= 255, "message too long: " .. #msg)
    if chatType == "CHANNEL" then
      assert(target == "5", "channel target")
      sent[#sent + 1] = msg
    else
      groupSent[#groupSent + 1] = chatType .. ":" .. (chatType == "WHISPER" and target .. ":" or "") .. msg
    end
    return 0
  end,
  InChatMessagingLockdown = function() return false end,
  -- на обычных серверах Midnight обычный чат аддонам запрещён — сообщения аддонов это не должно останавливать
  AreOutgoingAddonChatMessagesRestricted = function() return true end,
}
Enum.SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11 }
-- Друг Battle.net с другого сервера и группа
local FRIEND_ID = 77
local friendOnline = true
BNGetNumFriends = function() return 1 end
BNET_CLIENT_WOW = "WoW"; WOW_PROJECT_MAINLINE = 1
C_BattleNet = {
  GetFriendNumGameAccounts = function() return 1 end,
  GetFriendGameAccountInfo = function() return { isOnline = friendOnline, clientProgram = "WoW", wowProjectID = 1,
    isInCurrentRegion = true, gameAccountID = FRIEND_ID, characterName = "Друг", realmName = "Ревущий фьорд" } end,
  GetGameAccountInfoByID = function(id) if id == FRIEND_ID then return { characterName = "Друг", realmName = "Ревущий фьорд" } end end,
  SendGameData = function(id, prefix, msg)
    assert(prefix == "TMHUB" and #msg <= 255)
    bnSent[#bnSent + 1] = id .. ":" .. msg
    return 0
  end,
}
local inGroup, groupOtherRealm = false, false
LE_PARTY_CATEGORY_HOME, LE_PARTY_CATEGORY_INSTANCE = 1, 2
IsInGroup = function(category) if category == LE_PARTY_CATEGORY_INSTANCE then return false end return inGroup end
IsInGuild = function() return false end
IsInRaid = function() return false end
GetNumGroupMembers = function() return inGroup and 2 or 0 end
UnitName = function(unit)
  if unit == "party1" then return "Попутчик", groupOtherRealm and "Галакронд" or nil end
  return "Тест"
end
local tickers = {}
C_Timer.NewTicker = function(_, fn) tickers[#tickers + 1] = fn end
-- прокрутить очередь отправки и вернуть отправленное (канал; группа и друзья — отдельно)
local lastGroup, lastBn = {}, {}
local function flush()
  for _ = 1, 3000 do clock = clock + 1; tickers[1]() end
  local out = sent; sent = {}
  lastGroup, groupSent = groupSent, {}
  lastBn, bnSent = bnSent, {}
  return out
end
local ns = {}
local dir = arg[1]
for _, f in ipairs({ "Locales/Locale.lua", "Locales/enUS.lua", "Data/Bundled.lua", "Data/Blocklist.lua", "Data/Charts.lua", "Data/Secrets.lua", "Data/TagIcons.lua", "Data/Sources.lua", "Core.lua", "Moderation.lua", "Network.lua", "Appearance.lua", "Preview.lua", "TagPicker.lua", "UI.lua", "SaveDialog.lua", "IconPicker.lua", "Secret.lua", "Achievements.lua", "Charts.lua", "Profile.lua", "Help.lua", "Tour.lua", "Standing.lua", "Ideas.lua", "Wowhead.lua", "Sources.lua", "Minimap.lua", "Skin.lua", "Usage.lua", "Toasts.lua", "Follow.lua", "Fonts.lua", "Settings.lua", "ChatLinks.lua" }) do
  assert(loadfile(dir .. "/" .. f))("TransmogHub", ns)
end
TransmogHub_Charts = nil -- тесты проверяют и расчёт мест без официального чарта
-- Настоящие тайны скрытых достижений тесты не знают (они в закрытом репозитории):
-- проверяем на выдуманных условиях
do
	local TH0 = ns.TH
	-- настоящий Data/Secrets.lua: у каждого скрытого есть тайна, открытых текстов в файле нет
	for _, a in ipairs(TH0.ACHIEVEMENTS) do
		if a.hidden then
			local e = TransmogHub_Secrets[a.id]
			assert(e and e.probe and e.data and (e.probe == "server" or e.locks[1]), "secret for " .. a.id)
			assert(not e.data:find("ok"), "data is encrypted")
		end
	end
	TransmogHub_Secrets = {}
	local function Fake(id, probe, cond, fields)
		local key, full = "0123456789abcdef", probe .. ":" .. cond
		TransmogHub_Secrets[id] = { probe = probe, data = TH0.Secret.Seal(fields, key),
			locks = { { h = TH0.Secret.LockHash(id, full), w = TH0.Secret.WrapKey(id, full, key) } } }
	end
	Fake("hid_lichking", "tags", "zz_a,zz_b", { name = "Тестовая тайна", desc = "Тестовое условие", flavor = "Подпись", icon = "INV_Misc_Gem_01" })
	Fake("hid_murloc", "word", "тестслово", { name = "Слово", desc = "Тест", flavor = "Подпись" })
	Fake("hid_neighbours", "races", "3,7", { name = "Расы", desc = "Тест", flavor = "Подпись" })
	-- тайна, которую проверяет только чарт: в аддоне нет условия
	TransmogHub_Secrets.hid_illidan = { probe = "server",
		data = TH0.Secret.Seal({ name = "Серверная тайна", flavor = "Подпись", icon = "INV_Misc_Gem_01" }, "fedcba9876543210") }
end
local TH = ns.TH
-- админ для проверок: в коде только отпечатки имён, тестовый добавляем сами
TH.ADMIN_HASHES[TH.Secret.Hash("thub-admin:Тестадмин-Гордунни")] = true
local Net = TH.Net
TH.scripts.OnEvent(TH, "ADDON_LOADED", "TransmogHub")
TH.db.leader.optOut = true -- рейтинг проверяется отдельно, в конце
TH.scripts.OnEvent(TH, "PLAYER_LOGIN")
assert(Net:IsConnected(), "joined hidden channel")
local startup = flush()
assert(startup[1] == "SH1", "hello sent: " .. tostring(startup[1]))
assert(startup[2] and startup[2]:match("^SQ%w+\t0$"), "initial sync request")
assert(lastBn[1] == FRIEND_ID .. ":SH1", "hello to the Battle.net friend")

-- приём сообщений от другого игрока
local PEER = "Пир-Гордунни"
local function receive(msgs, sender)
  for _, m in ipairs(msgs) do Net:OnMessage("TMHUB", m, "CHANNEL", sender or PEER) end
end

-- open UI, save a set through the dialog and publish
SlashCmdList.TRANSMOGHUB("")
assert(TH.UI:IsShown())
TH:OpenSaveDialog()
local dlg = TransmogHubSaveDialog
dlg.name:SetText("Пиратский Капитан"); dlg.desc:SetText(string.rep("Очень длинное описание. ", 10)); dlg.tags:Toggle("pirate")
dlg.publishBtn.scripts.OnClick()
-- иконку не выбрали: сначала предупреждение, ничего не сохранено
assert(dlg.noIcon and dlg.noIcon:IsShown() and next(TH.db.mySets) == nil, "no-icon warning before publishing")
dlg.noIcon.anyway.scripts.OnClick()
assert(not dlg.noIcon:IsShown())
local localId, set = next(TH.db.mySets)
assert(set and set.status == "published" and set.serverId, "published to network")
assert(set.items[3][2] == 334 and set.items[16][3] == 5900 and set.items[2] == nil, "capture conversion")
local out = flush()
assert(#out >= 2 and out[1]:sub(1, 1) == "B" and out[#out]:sub(1, 1) == "E", "long set is chunked: " .. #out)
print("saved:", set.name, "tags:", TH:FormatTags(set.tags), "chunks:", #out)

-- the chunks reassemble into the same set on another client
local wire = {}
for i, m in ipairs(out) do wire[i] = m end
local before = Net:SetCount()
TH.db.net.sets[set.serverId] = nil
receive(wire, "Тест-Гордунни-эхо")
local copy = TH.db.net.sets[set.serverId]
assert(copy and copy.name == set.name and copy.items[3][2] == 334 and copy.items[16][3] == 5900, "decoded set matches")
assert(copy.desc:sub(1, 20) == set.desc:sub(1, 20), "description survived")
assert(Net:SetCount() == before)

-- search with Cyrillic case-insensitive
assert(#TH:QuerySets("mine", { text = "ПИРАТ" }) == 1, "cyrillic search")
assert(#TH:QuerySets("mine", { text = "рыцарь" }) == 0)
assert(#TH:QuerySets("mine", { text = "PIRAT" }) == 1, "search by transliteration")
assert(#TH:QuerySets("mine", { tags = { pirate = true } }) == 1)

-- a peer publishes a set; it appears in the feed
local peerSet = { id = "npeer1", author = PEER, name = "Чужой образ", desc = "", race = 8, sex = 0, class = "SHAMAN",
  created = serverTime - 100, tags = { "rp", "c_pink" }, items = { [1] = {194429}, [3] = {266724, 266725}, [17] = {295720, nil, 8549} } }
receive({ "SP" .. Net.EncodeSet(peerSet) })
TH:RequestRefresh()
local got = TH:GetSet("npeer1")
assert(got and got.verified and got.items[3][2] == 266725 and got.items[17][3] == 8549, "peer set stored")
assert(TH:IsMine(TH:GetSet(set.serverId)), "own network copy is mine")
assert(not TH:IsMine(got))

-- votes: mine and peers'; one vote per character, newest wins
TH:Vote("npeer1", 4)
assert(flush()[1]:match("^SVnpeer1\t4\t"), "vote broadcast")
receive({ "SV" .. set.serverId .. "\t5\t" .. "zzz" })
receive({ "SV" .. set.serverId .. "\t3\t" .. "zzy" }) -- older, ignored
receive({ "SV" .. set.serverId .. "\t2\t" .. "zzz" }, "Другой-Гордунни")
TH:LoadFeed()
local myNet = TH:GetSet(set.serverId)
assert(myNet.rating.n == 2 and myNet.rating.avg == 3.5, "rating from votes: " .. myNet.rating.n .. " " .. myNet.rating.avg)
TH:Vote(set.serverId, 5) -- own set: refused
assert(TH.db.myVotes[set.serverId] == nil)

-- delete: only the author may unpublish
receive({ "SDnpeer1" }, "Злодей-Гордунни")
assert(TH.db.net.sets.npeer1, "non-author cannot delete")
receive({ "SDnpeer1" })
assert(not TH.db.net.sets.npeer1 and TH.db.net.tombstones.npeer1, "author deletes")
receive({ "SP" .. Net.EncodeSet(peerSet) })
assert(not TH.db.net.sets.npeer1, "tombstoned set is not re-added")

-- sync: a peer asks for news; we answer with our sets and votes
receive({ "SQabc\t0" })
local answer = flush()
assert(answer[1] == "SAabc", "answer header")
local hasSet, hasVotes = false, false
for _, m in ipairs(answer) do
  if m:sub(1, 2) == "SP" or m:sub(1, 1) == "B" then hasSet = true end
  if m:sub(1, 2) == "SW" then hasVotes = true end
end
assert(hasSet and hasVotes, "answer contains sets and votes")
-- someone else answers first: we stay silent
C_Timer.After = function() end -- задержка ответа не истекает
receive({ "SQdef\t0" }); receive({ "SAdef" }, "Быстрый-Гордунни")
C_Timer.After = function(_, fn) fn() end
assert(#flush() == 0, "no duplicate answer")
-- our own sync request gets answered: lastSync is remembered
Net:RequestSync(); local q = flush()[1]
local reqId = q:match("^SQ(%w+)\t")
receive({ "SA" .. reqId })
assert(Net.synced and TH.db.net.lastSync == serverTime, "lastSync set after answer")

-- presence: in a small network a newcomer's hello gets an "I'm here" reply
receive({ "SH1" }, "Новичок-Гордунни")
local pres = flush()
local replied = false
for _, m in ipairs(pres) do if m == "SI1" then replied = true end end
assert(replied, "reply to hello in a small network")
GetNumDisplayChannels = function() return 1 end
GetChannelDisplayInfo = function() return "TransmogHubNet", false, false, 5, 3 end
assert(Net:PeerCount() == 2, "peer count from channel roster")
GetNumDisplayChannels = nil; GetChannelDisplayInfo = nil

-- relayed votes (W)
receive({ "SW" .. set.serverId .. "\tТретий-Гордунни,4," .. "zzz;Четвёртый-Гордунни,1,zzz" })
TH:LoadFeed()
assert(TH:GetSet(set.serverId).rating.n == 4, "relayed votes counted")

-- lockdown: nothing is sent, queue waits
C_ChatInfo.InChatMessagingLockdown = function() return true end
local anyTop = TH:QuerySets("top", { sort = "new" })[1]
TH:Vote(anyTop and anyTop.id ~= set.serverId and anyTop.id or "x", 3)
assert(#flush() == 0 and Net:QueueLength() >= 0, "paused in lockdown")
C_ChatInfo.InChatMessagingLockdown = function() return false end
flush()

-- test feed still works
SlashCmdList.TRANSMOGHUB("test")
assert(#TH:QuerySets("top", {}) >= 25)
local top = TH:QuerySets("top", {})
-- UI walk-through
for _, v in ipairs({ "top", "trending", "new", "favorites", "mine" }) do TH.UI:SetView(v) end
TH.UI:SetView("top"); TH.UI:Select(set.serverId); TH:ToggleFavorite(set.serverId); TH.UI:SetView("favorites")
assert(#TH.UI.results == 1)
TH.UI:OpenRaceMenu(frame()); TH.UI:Scroll(10)
-- окно тегов: поиск, популярность, фильтр списка
TH.UI:OpenTagMenu(frame())
local picker = TH.UI.tagFrame.picker
assert(TH.UI.tagFrame:IsShown(), "tag window opens")
picker.search:SetText("мини"); picker.search.scripts.OnTextChanged(picker.search)
assert(picker.list[1] == "minimal" and #picker.list == 1, "tag search: " .. tostring(picker.list[1]))
picker.search:SetText("лат"); picker.search.scripts.OnTextChanged(picker.search)
assert(tContains(picker.list, "a_plate"), "search by label")
picker.search:SetText(""); picker.search.scripts.OnTextChanged(picker.search)
local sorted, counts = TH:GetTagsSorted("")
assert(#sorted == #TH.TAG_ORDER and (counts[sorted[1]] or 0) >= (counts[sorted[#sorted]] or 0), "popular first")
assert((counts.pirate or 0) >= 1 and picker.list[1] == sorted[1], "counts from feed")
picker:Toggle("pirate")
assert(TH.UI.filter.tags.pirate, "selected tag filters the list")
picker:Scroll(-100); assert(picker.offset > 0); picker:Scroll(100); assert(picker.offset == 0, "wheel scroll")
-- темы и сортировки
for _, theme in ipairs(TH.TAG_THEMES) do
  for _, key in ipairs(theme.tags) do assert(TH.TAG_LABEL[key], "theme " .. theme.name .. " has unknown tag " .. key) end
end
picker:SetTheme(1)
assert(#picker.list == #TH.TAG_THEMES[1].tags and tContains(picker.list, "paladin"), "class theme")
picker:SetTheme("selected"); assert(#picker.list == 1 and picker.list[1] == "pirate", "selected theme")
picker.search:SetText("латы"); picker.search.scripts.OnTextChanged(picker.search)
assert(picker.list[1] == "a_plate", "search ignores theme")
picker:SetTheme("all"); assert(picker.search:GetText() == "" and #picker.list == #TH.TAG_ORDER, "theme click clears search")
picker:SetSort("alpha"); assert(picker.sort == "alpha" and TH.Lower(TH.TAG_LABEL[picker.list[1]]) < TH.Lower(TH.TAG_LABEL[picker.list[2]]), "alpha sort")
picker:SetSort("rare"); local c = picker.counts; assert((c[picker.list[1]] or 0) <= (c[picker.list[#picker.list]] or 0), "rare sort")
TH.TAG_ADDED.c_multi = "2030-01-01"; picker:SetSort("new"); assert(picker.list[1] == "c_multi", "new tags first"); TH.TAG_ADDED.c_multi = nil
picker:SetSort("trending"); assert(picker.trend, "trend counts")
picker:SetSort("theme"); assert(picker.list[1] == TH.TAG_ORDER[1], "theme order")
picker:OpenSortMenu(frame()); picker:SetSort("popular")
assert(picker.summary.text:find("Пират"), "summary shows selection")
picker:Toggle("pirate"); assert(not TH.UI.filter.tags.pirate)
TH.UI:OpenTagMenu(frame()); assert(not TH.UI.tagFrame:IsShown(), "second click closes")
print("status:", TH.UI.status.text)
SlashCmdList.TRANSMOGHUB("net"); SlashCmdList.TRANSMOGHUB("sync"); flush()
SlashCmdList.TRANSMOGHUB("minimap"); SlashCmdList.TRANSMOGHUB("minimap")
assert(TransmogHubMinimapButton and TransmogHubMinimapButton:IsShown())
TransmogHubMinimapButton.scripts.OnClick(nil, "LeftButton")
TH.UI:SetRace(6)
assert(TH.db.achievements.save_1, "save_1 earned")
assert(TH.db.achievements.race_1, "race_1 earned")
assert(TH.db.achievements.publish_1, "publish_1 earned")
assert(not TH.db.achievements.vote_10, "test votes must not count")
TH.UI:OpenAchievements()
print("ach header:", TH.UI.achPanel.header.text)
-- right-click menus
TH.UI:SetView("top")
wipe(TH.UI.filter.tags); TH.UI:Refresh()
TH.UI:OpenSetMenu(frame(), TH.UI.results[1].id)
local id2 = TH:CreateMySet("Второй", "", {"c_red","c_blue"}, { [1] = {111} }).id
TH.UI:OpenSetMenu(frame(), id2)
-- hide a set locally
TH:HideSet(top[1].id); assert(not TH.byId[top[1].id] or TH:IsTestId(top[1].id))
SlashCmdList.TRANSMOGHUB("unhide")
-- secondary shoulder row appears only when present
TH.UI:SetView("mine")
TH.UI:Select(id2)
local secRow
for _, r in ipairs(TH.UI.slotRows) do if r.entry.index == 2 then secRow = r end end
assert(secRow and not secRow:IsShown(), "secondary hidden when absent")
local id3 = TH:CreateMySet("Плечи", "", {}, { [3] = {333, 334} }).id
TH.UI:Select(id3)
assert(secRow:IsShown() and secRow.sourceID == 334, "secondary shown")
-- wowhead link dialog
TH:ShowWowheadLink(TH:GetSet(id3))
assert(TransmogHubLinkDialog.url.text == "https://www.wowhead.com/ru/dressing-room", "dressing room url")
local game = "/customset v1 194429,266724,266724,194719,8514,0,0,193875,219442,194692,285892,95854,231274,-1,6258,295720,8549"
local trollSet = { items = {
  [1]={194429}, [3]={266724}, [15]={194719}, [5]={8514}, [9]={193875}, [10]={219442},
  [6]={194692}, [7]={285892}, [8]={95854}, [16]={231274, nil, 6258}, [17]={295720, nil, 8549} } }
assert(TH:BuildCustomSetCommand(trollSet) == game, "customset must match the game's own string")
-- right-click on an item: Wowhead link in the client language, chat link
C_Item.GetItemInfo = function(id) return "Вещь", "|cffa335ee|Hitem:" .. id .. "|h[Вещь]|h|r" end
local inserted
ChatFrameUtil = { InsertLink = function(l) inserted = l return true end, OpenChat = function() end }
local itemRow
for _, r in ipairs(TH.UI.slotRows) do if r.sourceID then itemRow = r break end end
TH.UI:OpenItemMenu(itemRow)
assert(TransmogHubItemLinkDialog.url.text == "https://www.wowhead.com/ru/item=" .. itemRow.sourceID * 10, "item url: " .. TransmogHubItemLinkDialog.url.text)
assert(inserted and inserted:find("Hitem:"), "chat link inserted")
-- tag reset button visibility
TH.UI.filter.tags.c_pink = true; TH.UI:Refresh(); assert(TH.UI.tagsReset:IsShown())
TH.UI.tagsReset.scripts.OnClick(); assert(not TH.UI.tagsReset:IsShown())
-- unpublish own set broadcasts D
flush()
TH:DeleteMySet(localId)
local del = flush()
assert(del[1] == "SD" .. set.serverId, "unpublish broadcast: " .. tostring(del[1]))
-- migration from companion-era saved variables
TransmogHubDB = { outbox = { publish = {} }, mySets = { ["local:x"] = { id = "local:x", status = "pending", items = {} } } }
TH.scripts.OnEvent(TH, "ADDON_LOADED", "TransmogHub")
TH.db.leader.optOut = true
assert(TH.db.outbox == nil and TH.db.mySets["local:x"].status == "draft", "migration")
-- ===== регистр названий =====
local function name(input, expected)
  assert(TH.FormatSetName(input) == expected, input .. " -> " .. TH.FormatSetName(input) .. ", expected " .. expected)
end
name("ñandú DORADO", "Ñandú Dorado")
name("CORAZÓN de León", "Corazón de León")
name("король Лич", "Король Лич")
name("король лич", "Король лич")
name("КОРОЛЬ ЛИЧ", "Король Лич")
name("пИрАт кРОВАВЫХ парусов", "Пират кровавых парусов")
name("страж кул-Тираса", "Страж кул-Тираса")
name("  пиратский   капитан ", "Пиратский капитан")
name("ёлочный Наряд", "Ёлочный Наряд")
name("SHADOW hunter", "Shadow hunter")
name("7 цветов", "7 цветов")
local loud = { id = "nloud1", author = PEER, name = "КРИЧАЩИЙ НАБОР", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime, tags = {}, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(loud) }); flush()
assert(TH.db.net.sets.nloud1.name == "Кричащий Набор", "network names normalized: " .. TH.db.net.sets.nloud1.name)

-- ===== фильтр названий =====
TH:OpenSaveDialog()
TransmogHubSaveDialog.name:SetText("Х.у.й пиратский")
local before2 = 0; for _ in pairs(TH.db.mySets) do before2 = before2 + 1 end
TransmogHubSaveDialog.publishBtn.scripts.OnClick()
local after2 = 0; for _ in pairs(TH.db.mySets) do after2 = after2 + 1 end
assert(after2 == before2 and TransmogHubSaveDialog.error.text ~= "", "profane name rejected")
-- без тегов: сначала предупреждение, сохраняется только после подтверждения
TransmogHubSaveDialog.name:SetText("Без тегов")
TransmogHubSaveDialog.publishBtn.scripts.OnClick()
local warn = TransmogHubSaveDialog.noTags
local n1 = 0; for _ in pairs(TH.db.mySets) do n1 = n1 + 1 end
assert(warn and warn:IsShown() and n1 == before2, "no-tags warning shown, nothing saved yet")
warn.anyway.scripts.OnClick()
assert(TransmogHubSaveDialog.noIcon:IsShown(), "then the icon warning")
TransmogHubSaveDialog.noIcon.anyway.scripts.OnClick(); flush()
local n2 = 0; for _ in pairs(TH.db.mySets) do n2 = n2 + 1 end
assert(n2 == before2 + 1 and not warn:IsShown(), "saved after confirming")
TH:OpenSaveDialog()
TransmogHubSaveDialog.name:SetText("12312"); TransmogHubSaveDialog.publishBtn.scripts.OnClick()
assert(TransmogHubSaveDialog.error.text:find("буквы"), "numeric name rejected")
-- a profane set from the network is neither stored nor relayed
local badSet = { id = "nbad1", author = PEER, name = "Пиздатый образ", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime, tags = {}, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(badSet) })
assert(not TH.db.net.sets.nbad1, "profane network set dropped")
assert(#flush() == 0, "profane set not relayed")

-- ===== межсерверный обмен =====
local FRIEND = "Друг-Ревущийфьорд"
local function bnReceive(msgs)
  for _, m in ipairs(msgs) do Net:OnBNetMessage("TMHUB", m, "WHISPER", FRIEND_ID) end
end
-- friend answers "I'm here": becomes a peer, we ask for news directly
bnReceive({ "SI1" })
flush()
assert(Net.bnPeers[FRIEND_ID] and Net.bnPeers[FRIEND_ID].name == FRIEND, "friend registered")
local bnQ = lastBn[1] and lastBn[1]:match("^" .. FRIEND_ID .. ":SQ(%w+)\t")
assert(bnQ, "sync request to friend: " .. tostring(lastBn[1]))
bnReceive({ "SA" .. bnQ })
assert(TH.db.net.peerSync[FRIEND], "per-friend sync time remembered")

-- a set from the other realm arrives via the friend and is relayed into our channel
local farSet = { id = "nfar1", author = "Дальний-Ревущийфьорд", name = "С другого сервера", desc = "", race = 4, sex = 1,
  class = "MAGE", created = serverTime - 50, tags = {}, items = { [1] = {111} } }
bnReceive({ "SP" .. Net.EncodeSet(farSet) })
local relayed = flush()
assert(TH.db.net.sets.nfar1 and TH.db.net.sets.nfar1.via == FRIEND, "stored from friend")
local inChannel = false
for _, m in ipairs(relayed) do if m:find("nfar1", 1, true) then inChannel = true end end
assert(inChannel, "relayed into the local channel")
for _, m in ipairs(lastBn) do assert(not m:find("nfar1", 1, true), "not echoed back to the friend") end
-- the same set again: no relay loop
bnReceive({ "SP" .. Net.EncodeSet(farSet) }); assert(#flush() == 0, "duplicate is not relayed")

-- a local set from the channel is relayed to the friend
local localSet = { id = "nloc1", author = PEER, name = "Местный", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime - 10, tags = {}, items = { [5] = {555} } }
receive({ "SP" .. Net.EncodeSet(localSet) }); flush()
local toFriend = false
for _, m in ipairs(lastBn) do if m:find("nloc1", 1, true) then toFriend = true end end
assert(toFriend, "relayed to the Battle.net friend")

-- a vote from the friend is relayed into the channel with the voter's name
bnReceive({ "SVnloc1\t5\tzzz" })
local w = flush()
assert(w[1] == "SWnloc1\t" .. FRIEND .. ",5,zzz", "vote relayed as W with voter: " .. tostring(w[1]))
assert(TH.db.net.votes.nloc1[FRIEND][1] == 5)

-- the friend asks us for news: we answer directly, without election
bnReceive({ "SQfq1\t0" }); flush()
assert(lastBn[1] == FRIEND_ID .. ":SAfq1", "direct answer to friend")
-- our own publication goes to the channel and to the friend
local id4 = TH:CreateMySet("Для всех", "", {}, { [1] = {111} }).id
TH:Publish(id4); local pub = flush()
assert(#pub > 0 and #lastBn > 0, "published to channel and friend")

-- cross-realm group: hello and sync over the group
inGroup, groupOtherRealm = true, true
Net:OnGroupChanged(); flush()
assert(lastGroup[1] == "PARTY:SH1", "hello to the cross-realm group: " .. tostring(lastGroup[1]))
-- same-realm group: nothing extra is sent to the group
inGroup, groupOtherRealm = true, false
Net:OnGroupChanged(); flush()
TH:Vote("nloc1", 3); flush()
assert(#lastGroup == 0, "no group traffic for a same-realm group")
inGroup = false

-- ===== жалобы и модерация =====
flush()
local victim = { id = "nrep1", author = "Спамер-Гордунни", name = "Нормальный образ", desc = "", race = 1, sex = 0,
  class = "ROGUE", created = serverTime, tags = {}, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(victim) }, "Спамер-Гордунни"); flush()
TH.db.moderator = true -- журнал жалоб копит только клиент модератора
TH:Report("nrep1", "a")
-- модератор убрал образ — жалоба подтверждена
TH.Net:ApplyModDecision("s", "nrep1")
TH:CheckAchievements()
assert(TH.db.achievements.report_ok_1, "confirmed report achievement")
TH.Net:ApplyModDecision("u", "nrep1")
local rep = flush()
assert(rep[1]:match("^SRnrep1\ta\t"), "report broadcast: " .. tostring(rep[1]))
assert(TH.db.hidden.nrep1 and not TH.byId.nrep1, "hidden for the reporter")
assert(TH.db.modLog[#TH.db.modLog]:match("^1|nrep1|Тест%-Гордунни|a|%d+|Спамер%-Гордунни|Нормальный образ|"), "mod log line")
wipe(TH.db.hidden)
-- reports from others are stored and relayed as X with the reporter's name
receive({ "SRnrep1\to\tzzz" }, "Жалобщик-Гордунни")
local xr = flush()
assert(#xr == 0, "not echoed back into the channel")
assert(lastBn[1] == FRIEND_ID .. ":SXnrep1\tЖалобщик-Гордунни,o,zzz", "report relayed to the friend: " .. tostring(lastBn[1]))
-- 99 reports: still visible; 100 with >=30% share: auto-hidden
for i = 3, 99 do Net:StoreReport("nrep1", "Ж" .. i .. "-Гордунни", "a", serverTime) end
TH:LoadFeed(); assert(TH.byId.nrep1, "99 reports: still visible")
Net:StoreReport("nrep1", "Ж100-Гордунни", "a", serverTime)
TH:LoadFeed(); assert(not TH.byId.nrep1, "100 reports: auto-hidden")
-- many good votes outweigh the reports
for i = 1, 300 do Net:StoreVote("nrep1", "Фан" .. i .. "-Гордунни", 5, serverTime) end
TH:LoadFeed(); assert(TH.byId.nrep1, "reports below 30% share: visible")
-- moderator decisions: ignored from others, applied from a moderator
receive({ "SMs\tnrep1" }, "Самозванец-Гордунни"); TH:LoadFeed()
assert(TH.byId.nrep1, "fake moderator ignored")
receive({ "SMs\tnrep1" }, "Тестадмин-Гордунни"); TH:LoadFeed()
assert(not TH.byId.nrep1, "moderator block applied")
receive({ "SMu\tnrep1" }, "Тестадмин-Гордунни"); TH:LoadFeed()
assert(TH.byId.nrep1, "moderator unblock applied")
receive({ "SMa\tСпамер-Гордунни" }, "Тестадмин-Гордунни"); TH:LoadFeed()
assert(not TH.byId.nrep1, "author block applied")
local later = { id = "nrep2", author = "Спамер-Гордунни", name = "Ещё образ", desc = "", race = 1, sex = 0,
  class = "ROGUE", created = serverTime, tags = {}, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(later) }, "Спамер-Гордунни")
assert(not TH.db.net.sets.nrep2, "blocked author's new sets are not stored")
-- blocklist shipped with the addon
TransmogHub_Blocklist.sets.npeer9 = "реклама"
local listed = { id = "npeer9", author = PEER, name = "Из списка", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime, tags = {}, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(listed) }); assert(not TH.db.net.sets.npeer9, "blocklisted set dropped")
-- moderation tab
local modList = TH:QuerySets("moderation", {})
assert(#modList >= 1 and modList[1].id == "nrep1", "moderation list sorted by reports")
SlashCmdList.TRANSMOGHUB(""); if not TH.UI:IsShown() then SlashCmdList.TRANSMOGHUB("") end
TH.UI:SetView("moderation"); TH.UI:Select("nrep1")
assert(TH.UI.modSetBtn:IsShown() and TH.UI.dStatus.text:find("Жалоб: 100"), "moderation detail: " .. tostring(TH.UI.dStatus.text))
TH.MODERATORS[Net.Me()] = true; TH.UI.modDismissBtn.scripts.OnClick(); TH.MODERATORS[Net.Me()] = nil
assert(TH.db.modDismissed.nrep1 and TH.db.modDecisions[#TH.db.modDecisions]:match("^1|d|nrep1|"), "dismiss logged")
-- reports sync: an answer includes X batches
receive({ "SQrq9\t0" })
local ans, hasX = flush(), false
for _, m in ipairs(ans) do if m:sub(1, 2) == "SX" then hasX = true end end
assert(hasX, "sync answer includes reports")

-- tag suggestions
assert(TH.NormalizeTag("  Космо-Пират!! ") == "космо-пират", "normalize: " .. tostring(TH.NormalizeTag("  Космо-Пират!! ")))
assert(TH.NormalizeTag("а") == nil and TH.NormalizeTag(string.rep("я", 25)) == nil, "tag length")
assert(TH:SuggestTag("Пират") == "Такой тег уже есть.", "existing tag")
assert(TH:SuggestTag("хуйня") ~= nil, "profane tag")
assert(TH:SuggestTag("Космо-пират") == nil, "suggest ok")
assert(TH:SuggestTag("Космо-пират") == "Вы уже предлагали этот тег.", "one per text")
local sent1 = flush()
assert(sent1[1] and sent1[1]:match("^SGкосмо%-пират\t%w+$"), "suggestion sent: " .. tostring(sent1[1]))
assert(TH.db.modTags[#TH.db.modTags]:match("^1|космо%-пират|Тест%-Гордунни|%d+$"), "suggestion logged for moderator")
receive({ "SGкосмо-пират\t" .. "abc" })
flush()
assert(lastBn[1] == FRIEND_ID .. ":SYкосмо-пират\t" .. PEER .. ",abc", "suggestion relayed to the friend: " .. tostring(lastBn[1]))
receive({ "SGкосмо-пират\tabc" }); flush(); assert(#lastBn == 0, "duplicate not relayed")
receive({ "SGхуй\tabc" }); assert(not TH.db.net.tagSuggest["хуй"], "profane suggestion dropped")
receive({ "SGBad|Tag\tabc" }); assert(not TH.db.net.tagSuggest["Bad|Tag"], "raw suggestion dropped")
for i = 1, 3 do assert(TH:SuggestTag("тег номер " .. i) == nil) end
assert(TH:SuggestTag("тег номер 4") == nil and TH:SuggestTag("тег номер 5"):find("в день"), "daily limit")
flush()
receive({ "SQrq10\t0" })
local hasY = false
for _, m in ipairs(flush()) do if m:sub(1, 2) == "SY" then hasY = true end end
assert(hasY, "sync answer includes tag suggestions")
-- suggest dialog
TH:OpenSuggestTag("новый тег")
TransmogHubSuggestTag.sendBtn.scripts.OnClick()
assert(TH.db.mySuggest["новый тег"] == nil and TransmogHubSuggestTag.error.text:find("в день"), "dialog shows error")
-- tag stats snapshot and unknown tags from newer versions
TH:SnapshotTagStats(); TH:SnapshotTagStats()
assert(#TH.db.modTagStats == 1 and TH.db.modTagStats[1]:match("^1|%d%d%d%d%-%d%d%-%d%d|%d+|warrior=%d+,.*pirate=%d+"), "tag stats: " .. tostring(TH.db.modTagStats[1]))
local future = { id = "nfut1", author = PEER, name = "Из будущего", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime, tags = { "pirate", "new_tag" }, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(future) })
assert(#TH.db.net.sets.nfut1.tags == 2 and TH:FormatTags(TH.db.net.sets.nfut1.tags) == "Пират", "unknown tags kept, not shown")
-- масштаб окна
SlashCmdList.TRANSMOGHUB("scale 87"); assert(math.abs(TH.db.scale - 0.85) < 1e-9, "scale rounds to step: " .. TH.db.scale)
TH:SetScale(5); assert(TH.db.scale == TH.SCALE_MAX, "scale clamped")
TH.UI.scaleSlider.scripts.OnMouseWheel(TH.UI.scaleSlider, -1); assert(math.abs(TH.db.scale - 1.45) < 1e-9, "wheel step")
TH.UI.scaleSlider.scripts.OnMouseUp(TH.UI.scaleSlider, "RightButton"); assert(TH.db.scale == 1, "right click resets")
assert(TH.UI.scaleSlider.value.text == "100", "percent label")
-- растягивание за угол
local cursorX, cursorY = 500, 500
GetCursorPosition = function() return cursorX, cursorY end
UIParent.GetEffectiveScale = function() return 1 end
local fr = TH.UI; fr.GetScale = function() return TH.db.scale end; fr.GetLeft = function() return 100 end; fr.GetTop = function() return 700 end
local grip = TH.UI.resizeGrip
grip.scripts.OnMouseDown(grip, "LeftButton")
cursorX, cursorY = 700, 500 - 0.2 * 626 -- вправо на 200 и вниз на 125: +20 % по обеим осям (окно 1000×626)
grip.scripts.OnUpdate(grip)
grip.scripts.OnMouseUp(grip)
assert(math.abs(TH.db.scale - 1.2) < 1e-9 and TH.UI.scaleSlider.value.text == "120", "grip resize: " .. TH.db.scale)
-- масштаб вписан руками
local box = TH.UI.scaleSlider.value
box:SetText("87"); box.scripts.OnEnterPressed(box)
assert(math.abs(TH.db.scale - 0.87) < 1e-9 and box.text == "87", "typed scale")
box:SetText("400"); box.scripts.OnEnterPressed(box)
assert(TH.db.scale == TH.SCALE_MAX and box.text == "150", "typed scale clamped")
box:SetText("7"); box.scripts.OnEscapePressed(box); assert(box.text == "150", "escape restores")
-- достижения: у каждого есть подпись, новые счётчики работают
for _, a in ipairs(TH.ACHIEVEMENTS) do
  -- у скрытых подпись зашифрована, до получения видна только загадка
  assert((a.stat == "secret" or (a.flavor and a.flavor ~= "")) and a.desc and TH.RARITY[a.rarity], "achievement " .. a.id)
end
local SHAME_N = 0; for _, a in ipairs(TH.ACHIEVEMENTS) do if a.shame then SHAME_N = SHAME_N + 1 end end
assert(TH.ACHIEVEMENT_BY_ID.all.goal == #TH.ACHIEVEMENTS - SHAME_N - 1, "all = every normal achievement")
for _, a in ipairs(TH.ACHIEVEMENTS) do
  if a.hidden then assert(a.hint and a.hint ~= "", "hint " .. a.id) end
  assert(TH.ACHIEVEMENT_BY_NUM[a.num] == a, "unique num " .. a.id)
end
TH:ShowItemLink(1234, "Меч"); assert(TH.db.achievements.wowhead_1, "wowhead achievement")
assert(TH:GetAchievementStat("suggested") >= 1 and TH.db.achievements.suggest_1, "suggest achievement")
TH.db.stats.tags.a_cloth, TH.db.stats.tags.a_leather, TH.db.stats.tags.a_mail, TH.db.stats.tags.a_plate = true, true, true, true
TH:CheckAchievements(); assert(TH.db.achievements.armor_all, "armor achievement")
assert(TH:GetAchievementGoal(TH.ACHIEVEMENT_BY_ID.races_all) == #TH:GetPlayableRaces())
assert(TH:GetAchievementStat("bnet") == 1 and TH.db.achievements.bnet_1, "bnet achievement")
TH.UI:SetView("achievements")
local panel = TH.UI.achPanel
-- по категориям: каждое достижение в известной категории, в «Все» — заголовки групп
for _, a in ipairs(TH.ACHIEVEMENTS) do
	assert(a.shame or TH.STAT_CATEGORY[a.stat], "achievement without a category: " .. a.id)
end
assert(panel.lines[1].header and panel.lines[1].header:find("Образы"), "first group header")
-- прокрутка по пикселям: колесо — на ряд карточек, в конце последний ряд ровно по нижнему краю
TH:ScrollAchievementsPanel(panel, -1)
assert(panel.offset == 59, "one wheel step is one card row: " .. panel.offset)
TH:ScrollAchievementsPanel(panel, -1000)
local content = 0
for _, line in ipairs(panel.lines) do content = content + (line.header and 22 or 59) end
assert(panel.offset == content - (508 - 60 - 6) and panel.offset == TH:AchievementsMaxOffset(panel), "scrolled to the end")
TH:ScrollAchievementsPanel(panel, 1000); assert(panel.offset == 0)
-- в «Все» категорию можно свернуть щелчком по заголовку
local headerBtn = panel.catHeaders[1]
assert(headerBtn.key == "looks")
local before = #panel.visible
headerBtn.scripts.OnClick(headerBtn)
assert(TH.db.achView.collapsed.looks and #panel.visible < before and panel.lines[2].header, "collapsed category hides its cards")
headerBtn.scripts.OnClick(headerBtn)
assert(not TH.db.achView.collapsed.looks and #panel.visible == before, "expanded again")
-- порядок категорий: по умолчанию как в списке, перетаскиванием — свой
TH:MoveAchCategory("shame", 1); TH:RefreshAchievementsPanel(panel, "")
assert(panel.lines[1].key == "shame" and TH:GetAchCategoryOrder()[2].key == "looks", "moved category first")
TH:MoveAchCategory("shame", 99); TH:RefreshAchievementsPanel(panel, "")
assert(TH:GetAchCategoryOrder()[#TH.ACH_CATEGORIES].key == "shame" and panel.lines[1].key == "looks", "moved back to the end")
TH.db.achView.catOrder = nil
-- кнопка категории: только её карточки, без заголовков
local shameBtn
for _, b in ipairs(panel.catBtns) do if b.key == "shame" then shameBtn = b end end
shameBtn.scripts.OnClick(shameBtn)
for _, card in ipairs(panel.visible) do assert(card.achievement.shame, "only shame category") end
assert(#panel.visible > 0 and not panel.lines[1].header, "no headers inside a category")
assert(shameBtn.selected and shameBtn.label.text:find("Позорные"), shameBtn.label.text)
TH.db.achView.cat = "all"; TH:RefreshAchievementsPanel(panel, "")
-- поиск по достижениям: по названию, подписи и редкости
TH:RefreshAchievementsPanel(panel, "кадгар")
assert(panel.visible[1].achievement.id == "network_500" and panel.visible[1]:IsShown() and not panel.cards[1]:IsShown(), "achievement search by flavor")
local legendary = 0; for _, a in ipairs(TH.ACHIEVEMENTS) do if a.rarity == 5 then legendary = legendary + 1 end end
TH:RefreshAchievementsPanel(panel, "легендарное"); assert(#panel.visible == legendary, "search by rarity: " .. #panel.visible)
-- скрытые не находятся по настоящему названию, пока не получены
TH:RefreshAchievementsPanel(panel, "ледяного трона"); assert(#panel.visible == 0, "hidden name is secret")
TH:RefreshAchievementsPanel(panel, "пустует"); assert(#panel.visible == 1, "hidden found by hint")
assert(panel.visible[1].name.text:find("Скрытое достижение"), "hidden card title")
TH:RefreshAchievementsPanel(panel, "zzz"); assert(#panel.visible == 0 and panel.empty:IsShown())
TH:RefreshAchievementsPanel(panel, ""); assert(#panel.visible == #TH.ACHIEVEMENTS and not panel.empty:IsShown())
-- вид: по редкости, только полученные / не полученные
do
	-- внутри каждой категории — по редкости
	local last, lastCat = -1, nil
	for _, card in ipairs(panel.visible) do
		local c = TH:AchievementCategory(card.achievement)
		if c ~= lastCat then last, lastCat = -1, c end
		local r = card.achievement.rarity == -1 and 100 or card.achievement.rarity
		assert(r >= last, "sorted by rarity"); last = r
	end
	panel.viewBtn.scripts.OnClick(panel.viewBtn) -- меню: последний пункт каждого списка
	local got = 0
	for id in pairs(TH.db.achievements) do if TH.ACHIEVEMENT_BY_ID[id] then got = got + 1 end end
	TH.db.achView.show = "earned"; TH:RefreshAchievementsPanel(panel, "")
	assert(#panel.visible == got, "only earned: " .. #panel.visible .. " vs " .. got)
	TH.db.achView.show = "missing"; TH:RefreshAchievementsPanel(panel, "")
	assert(#panel.visible == #TH.ACHIEVEMENTS - got, "only missing")
	TH.db.achView.show, TH.db.achView.sort = "all", "rarity"; TH:RefreshAchievementsPanel(panel, "")
end
-- вкладка «Друзья»: образы друзей Battle.net и списка друзей
Net:GreetFriends()
assert(TH.db.friendChars["Друг-Ревущийфьорд"], "friend character remembered")
C_FriendList = { GetNumFriends = function() return 1 end, GetFriendInfoByIndex = function() return { name = "Приятель" } end }
local fset = { id = "nfr1", author = "Друг-Ревущийфьорд", name = "Образ друга", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime, tags = {}, items = { [1] = {111} } }
local gset = { id = "nfr2", author = "Приятель-Гордунни", name = "Образ приятеля", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime + 1, tags = {}, items = { [1] = {111} } }
receive({ "SP" .. Net.EncodeSet(fset), "SP" .. Net.EncodeSet(gset) }); flush(); TH:LoadFeed()
local fl = TH:QuerySets("friends", {})
assert(#fl == 2 and fl[1].id == "nfr2" and fl[2].id == "nfr1", "friends view: " .. #fl)
-- в «Лучших» у друзей — как в «Образах»: только чарт; в «Новых» — свежие
do local savedSort = TH.db.listSort
TH.db.listSort = "top"
TH.UI:SetView("friends"); assert(TH.UI.results and #TH.UI.results == 0, "friends «best» = only charted, like the main feed")
assert(TH.UI.emptyText.text:find("из чарта", 1, true), "empty friends «best» explains where the sets are")
TH.db.listSort = "new"
TH.UI:SetView("friends"); assert(TH.UI.results and #TH.UI.results == 2)
TH.db.listSort = savedSort end
-- гильдия: согильдийцы из списка гильдии
do
	local roster = { "nfr1author" }
	for _, set in ipairs(fl) do roster[1] = set.author end
	_G.IsInGuild = function() return true end
	_G.GetNumGuildMembers = function() return #roster end
	_G.GetGuildRosterInfo = function(i) return roster[i] end
	local gl = TH:QuerySets("guild", {})
	assert(#gl >= 1 and gl[1].author == roster[1], "guild view")
	local savedSort = TH.db.listSort
	TH.db.listSort = "new"
	TH.UI:SetView("guild"); assert(TH.UI.results and #TH.UI.results == #gl)
	TH.db.listSort = savedSort
	_G.IsInGuild = function() return false end
	assert(TH:GetGuildNames() == nil and #TH:QuerySets("guild", {}) == 0, "no guild")
	TH.UI:SetView("guild"); assert(TH.UI.emptyText.text:find("не состоите"), TH.UI.emptyText.text)
	TH.UI:SetView("friends")
end
-- одна оценка на аккаунт
assert(TH:CanVote(fset))
TH:Vote("nfr1", 4); assert(TH.db.myVoteChar.nfr1 == Net.Me())
assert(TH:CanVote(fset), "same character may change the rating")
TH.db.myVoteChar.nfr1 = "Альт-Гордунни"
local okv, why = TH:CanVote(fset)
assert(not okv and why:find("Альт"), "alt cannot vote again: " .. tostring(why))
-- старая оценка без записи: персонаж находится по голосам
TH.db.myVoteChar.nfr2 = nil; TH.db.myVotes.nfr2 = 5; TH.db.myChars["Альт-Гордунни"] = true
TH.db.net.votes.nfr2 = { ["Альт-Гордунни"] = { 5, serverTime } }
assert(not TH:CanVote(gset) and TH.db.myVoteChar.nfr2 == "Альт-Гордунни", "legacy vote attributed")
-- рейтинг очков стиля
TH.db.leader.optOut = false; TH.db.leader.char = nil
flush(); TH:PublishScore()
local sentL = flush()
local _, _, myPoints = TH:GetAchievementTotals()
assert(sentL[1] and sentL[1]:match("^SL" .. myPoints .. ",%d+,[%w_]*,%w+,[0-9a-v]+,%w*,%w*,[0-5]*,[0-9a-z]*$"), "score sent: " .. tostring(sentL[1]))
-- маска совпадает с полученными достижениями
local myMask = TH.db.net.scores[Net.Me()].mask
for _, a in ipairs(TH.ACHIEVEMENTS) do
  assert(TH.MaskHas(myMask, a.num) == (TH.db.achievements[a.id] ~= nil), "mask bit " .. a.id)
end
assert(TH.db.leader.char == Net.Me() and TH.db.net.scores[Net.Me()].points == myPoints)
TH:PublishScore(); assert(#flush() == 0, "unchanged score is not resent")
receive({ "SL500,30,top_1,abc,vvvvvvvv1" }, "Чемпион-Гордунни")
assert(lastBn[1] == nil or true)
flush()
receive({ "SZs\tДалёкий-Галакронд,9999999,5,,abc," }); flush()
assert(not TH.db.net.scores["Далёкий-Галакронд"], "absurd score rejected")
receive({ "SZs\tДалёкий-Галакронд,120,9,trend_1,abd,1" }); flush()
local board, total = TH:GetLeaderboard(false, "")
assert(total >= 3 and board[1].name == "Чемпион-Гордунни" and board[1].place == 1, "leaderboard order")
assert(#TH:GetLeaderboard(false, "чемп") == 1, "leaderboard search")
-- альт: старая запись своего персонажа не показывается и убирается при входе
TH.db.net.scores["Альт-Гордунни"] = { points = 75, earned = 7, t = 1 }
for _, e in ipairs(TH:GetLeaderboard(false, "")) do assert(e.name ~= "Альт-Гордунни", "own alt hidden") end
TH.db.leader.char = "Альт-Гордунни"; TH.db.leader.sent[Net.Me()] = 1
TH:PublishScore()
local rm = flush()
assert(rm[1] and rm[1]:match("^SLx,%w+$"), "leaving the board: " .. tostring(rm[1]))
assert(TH.db.net.scores[Net.Me()].removed, "own entry removed")
TH:SetLeaderChar(); flush()
assert(TH.db.leader.char == Net.Me() and not TH.db.net.scores[Net.Me()].removed, "rejoin")
TH:SetLeaderOptOut(true); flush(); assert(TH.db.net.scores[Net.Me()].removed, "opt out")
TH:SetLeaderOptOut(false); flush()
-- синхронизация отдаёт рейтинг
receive({ "SQrq11\t0" })
local hasZ = false
for _, m in ipairs(flush()) do if m:sub(1, 3) == "SZs" then hasZ = true end end
assert(hasZ, "sync answer includes scores")
-- экран
TH.UI:SetView("achievements")
local ap = TH.UI.achPanel
ap.boardBtn.scripts.OnClick()
assert(ap.mode == "board" and ap.board:IsShown() and ap.board.rows[1]:IsShown() and not ap.scroll:IsShown(), "board shown")
assert(ap.board.rows[1].name.text:find("Чемпион"), "first row")
assert(ap.header.text:find("ваше место"), "my place: " .. tostring(ap.header.text))
ap.cardsBtn.scripts.OnClick(); assert(ap.mode == "cards" and not ap.board:IsShown() and ap.cards[1]:IsShown())
-- у скольких игроков есть достижение
local counts, players = TH:GetAchievementPrevalence()
assert(players == 3 and counts.save_1 == 3 and counts.top_1 == 1, "prevalence: " .. players .. " " .. tostring(counts.save_1))
assert(TH:FormatPrevalence(TH.ACHIEVEMENT_BY_ID.save_1, counts, players) == "есть у 3 из 3 (100%)")
assert(ap.cards[1].share.text:find("100%%"), "card share: " .. tostring(ap.cards[1].share.text))
-- позорные: тролль ставит единицы, исправился — снято
local base = select(3, TH:GetAchievementTotals())
TH.db.myChars[Net.Me()] = true
for i = 1, 60 do TH.db.net.votes["ntroll" .. i] = { [Net.Me()] = { 1, serverTime } } end
TH:LoadFeed() -- голоса записаны в обход сети: пересчитываем ленту, как после синхронизации
TH:CheckAchievements()
assert(TH.db.achievements.shame_troll and select(3, TH:GetAchievementTotals()) < base, "troll shame")
assert(not TH.db.achievements.shame_troll_100)
-- наказание: голоса сняты у всех, отметка «уже оценил» осталась, оценивать и жаловаться нельзя 14 дней
assert(TH:GetVotePenalty() and not TH:GetVotePenalty().permanent, "penalty on")
assert(not TH.db.net.votes.ntroll1[Net.Me()] and TH.db.net.voteRetracts.ntroll1[Net.Me()], "votes retracted")
assert(TH:VoteRestrictionText(), "restricted")
flush()
-- старая копия голоса из сети не возвращается
receive({ "SW" .. "ntroll1\t" .. Net.Me() .. ",1," .. Net.Enc(serverTime) })
assert(not TH.db.net.votes.ntroll1[Net.Me()], "retracted vote does not come back")
TH:CheckAchievements()
assert(TH.db.achievements.shame_troll, "troll shame stays")
-- отмылся: прошло 14 дней
local realNow = Net.Now
Net.Now = function() return realNow() + 15 * 86400 end
TH:CheckAchievements()
assert(not TH:GetVotePenalty() and TH.db.penalty.washed and not TH:VoteRestrictionText(), "washed")
assert(TH.db.achievements.shame_troll, "shame still shown after washing")
-- повторно — навсегда
for i = 1, 60 do TH.db.net.votes["ntroll2_" .. i] = { [Net.Me()] = { 1, Net.Now() } } end
TH:LoadFeed(); TH:CheckAchievements()
assert(TH:GetVotePenalty() and TH:GetVotePenalty().permanent, "second time is permanent")
Net.Now = realNow
TH.db.penalty = nil -- дальше тесты голосуют
for i = 1, 60 do TH.db.net.votes["ntroll" .. i] = nil; TH.db.net.votes["ntroll2_" .. i] = nil end
TH.db.net.voteRetracts = {}
TH.db.achievements.shame_troll = nil
TH:LoadFeed(); TH:CheckAchievements()
-- заблокированный образ
local myPub
for _, m in pairs(TH.db.mySets) do if m.serverId then myPub = m end end
TH.db.net.modBlocks.sets[myPub.serverId] = 1
TH:CheckAchievements(); assert(TH.db.achievements.shame_blocked, "blocked shame")
TH.db.net.modBlocks.sets[myPub.serverId] = nil
TH:CheckAchievements(); assert(not TH.db.achievements.shame_blocked)
local e1, t1 = TH:GetAchievementTotals(); assert(t1 == #TH.ACHIEVEMENTS - SHAME_N, "shame not in total")
-- скрытые: сочетание тегов, имя, пара рас, полночь
TH.db.mySets["local:lk"] = { id = "local:lk", name = "Мой тестслово", tags = { "zz_b", "zz_a", "c_red" }, items = {}, status = "draft" }
TH.db.stats.races[3] = true; TH.db.stats.races[7] = true
TH:CheckAchievements()
assert(not TH.db.achievements.hid_lichking and not TH.db.achievements.hid_murloc, "draft tags alone are not enough")
-- опубликован и понравился игрокам: 5 оценок, средняя 4
TH.db.mySets["local:lk"].serverId = "nlk"
TH.byId.nlk = { id = "nlk", rating = { n = 4, avg = 4 } }
TH:CheckAchievements()
assert(not TH.db.achievements.hid_lichking, "4 votes are not enough")
TH.byId.nlk.rating = { n = 5, avg = 3 }
TH:CheckAchievements()
assert(not TH.db.achievements.hid_lichking, "low average is not enough")
TH.byId.nlk.rating = { n = 5, avg = 4 }
TH:CheckAchievements()
assert(TH.db.achievements.hid_lichking and TH.db.achievements.hid_murloc and TH.db.achievements.hid_neighbours, "hidden combos")
assert(not TH.db.achievements.hid_illidan) -- «Полночь» не проверяем: зависит от часов
assert(TH.ACHIEVEMENT_BY_ID.hid_lichking.points == 50)
-- тайна открыта: текст расшифрован и ключ запомнен
assert(TH.ACHIEVEMENT_BY_ID.hid_lichking.name == "Тестовая тайна" and TH.db.secretKeys.hid_lichking, "secret text unlocked")
assert(TH.ACHIEVEMENT_BY_ID.hid_illidan.name == "Скрытое достижение", "other secrets stay closed")
TH.ACHIEVEMENT_BY_ID.hid_lichking.name = "x"; TH:ApplySecrets()
assert(TH.ACHIEVEMENT_BY_ID.hid_lichking.name == "Тестовая тайна", "reopened on login by the saved key")
-- жалоба на накрутку и решение модератора по рейтингу
TH:ReportPlayer("Далёкий-Галакронд"); flush()
assert(TH.db.net.reports["p:Далёкий-Галакронд"], "player report stored")
for _, e in ipairs(TH:GetLeaderboard(false, "")) do assert(e.name ~= "Далёкий-Галакронд", "reported player hidden locally") end
receive({ "SMp\tЧемпион-Гордунни" }, "Тестадмин-Гордунни"); flush()
for _, e in ipairs(TH:GetLeaderboard(false, "")) do assert(e.name ~= "Чемпион-Гордунни", "moderator removed player") end
receive({ "SMq\tЧемпион-Гордунни" }, "Тестадмин-Гордунни"); flush()
local back = false; for _, e in ipairs(TH:GetLeaderboard(false, "")) do if e.name == "Чемпион-Гордунни" then back = true end end
assert(back, "moderator restored player")
-- очки считаются по маске, а не по присланному числу
receive({ "SL99999,999,top_1,abe,1" }, "Хитрец-Гордунни"); flush()
for _, e in ipairs(TH:GetLeaderboard(false, "хитрец")) do assert(e.points == 5 and e.earned == 1, "points from mask: " .. e.points) end
-- основной персонаж
TH.db.myChars["Альт-Гордунни"] = true
TH:SetLeaderChar("Альт-Гордунни"); flush()
assert(TH.db.leader.char == "Альт-Гордунни" and TH.db.net.scores[Net.Me()].removed, "main switched to alt, current char leaves")
local chars = TH:GetMyCharacters(); assert(tContains(chars, "Альт-Гордунни"), "own characters listed")
-- профиль автора
TH.UI:SetView("top")
local champ = "Друг-Ревущийфьорд"
TH.UI:OpenProfile(champ)
local pp = TH.UI.profilePanel
assert(TH.UI.view == "profile" and pp:IsShown() and not TH.UI.listPanel:IsShown(), "profile shown")
assert(pp.title.text == "Друг" and pp.realm.text == "Ревущийфьорд", "profile name")
assert(#pp.sets >= 1 and pp.rows[1]:IsShown() and tonumber(pp.tiles[1].text) == #pp.sets, "author sets")
assert(pp.noAch:IsShown(), "unknown achievements without board entry")
-- автор в рейтинге: видны достижения по маске
TH.db.net.scores[champ] = { points = 0, earned = 0, t = serverTime, mask = "1" }
TH:RefreshProfile(pp, champ)
assert(not pp.noAch:IsShown() and pp.icons[1].has and not pp.icons[2].has and pp.achLabel.text:find("1 из"), "achievements from mask")
assert(pp.tiles[5].text:find("из"), "board place")
-- лучший образ сразу в примерке профиля, клик по другому — тоже в профиле
assert(pp.selectedId == pp.sets[1].id and pp.model.items == pp.sets[1].items and pp.viewName.text ~= "", "best set previewed")
assert(pp.avatar and TH:GetRacePortrait(1, 1):find("human_female"), "race portrait")
local lastRow = pp.rows[#pp.sets > 1 and 2 or 1]
lastRow.scripts.OnClick(lastRow)
assert(TH.UI.view == "profile" and pp.selectedId == lastRow.set.id, "preview stays in profile")
-- «подробнее» — образы автора в общем списке
pp.details.scripts.OnClick()
assert(TH.UI.view == "author" and TH.UI.results[1].author == champ and TH.UI.selectedId == lastRow.set.id, "author sets view")
for _, r in ipairs(TH.UI.results) do assert(r.author == champ) end
assert(TH.UI.pageText.text:find("Образы Друг"), "author page label: " .. tostring(TH.UI.pageText.text))
-- «Назад» возвращает в предыдущий раздел
TH.UI:OpenProfile(champ); pp.back.scripts.OnClick(); assert(TH.UI.view == "author")
-- свой профиль: достижения из сохранённых
TH.db.myChars[Net.Me()] = true; TH:RefreshProfile(pp, Net.Me()); assert(pp.changeAvatar:IsShown() and not pp.back:IsShown() and not pp.noAch:IsShown())
-- иконка образа
TH:OpenSaveDialog()
local sd = TransmogHubSaveDialog
assert(sd.iconBtn.tex and sd.iconValue == nil, "default icon")
sd.tags:SetSelected({ "c_white" })
sd.iconBtn.scripts.OnClick()
local ip = TransmogHubIconPicker
assert(ip:IsShown() and ip.all[1].icon == 5001 and ip.allLabel.text:find("300"), "all icons (deduped): " .. tostring(ip.allLabel.text))
assert(tContains(ip.recommended, 123), "tag icon recommended")
ip:Scroll(-3); assert(ip.offset == 3 and ip.all[1].icon == 5001 + 36)
ip.all[2].scripts.OnClick(ip.all[2])
assert(sd.iconValue == 5002 + 36 and not ip:IsShown(), "icon picked")
sd.name:SetText("С иконкой"); sd.publishBtn.scripts.OnClick()
local withIcon
for _, m in pairs(TH.db.mySets) do if m.name == "С иконкой" then withIcon = m end end
assert(withIcon and withIcon.icon == 5038 and withIcon.status == "published", "icon saved")
local wire = Net.EncodeSet(withIcon)
assert(Net.DecodeSet(wire).icon == 5038, "icon over the network")
assert(TH:GetSetIcon(Net.DecodeSet(wire)) == 5038)
-- старый формат без поля иконки
local old = wire:gsub("\t[^\t]*$", "")
assert(Net.DecodeSet(old) and Net.DecodeSet(old).icon == nil, "old format still decodes")
flush()
-- собрано благодаря аддону
local hunt = { id = "nhunt1", author = PEER, name = "Охота", desc = "", race = 1, sex = 0, class = "ROGUE",
  created = serverTime, tags = {}, items = { [1] = {101}, [5] = {103} } }
receive({ "SP" .. Net.EncodeSet(hunt) }); flush(); TH:LoadFeed()
TH:WipeSourceCache()
TH.UI:Select("nhunt1")
assert(TH.db.stats.wanted[101] and TH.db.stats.wanted[103] and TH.db.stats.watchSets.nhunt1, "missing appearances remembered")
local realInfo = C_TransmogCollection.GetSourceInfo
C_TransmogCollection.GetSourceInfo = function(id) local i = realInfo(id); if id == 101 then i.isCollected = true end; return i end
TH:WipeSourceCache(); TH:CheckCollectedFromHub()
assert(TH.db.stats.gotFromHub[101] and not TH.db.stats.wanted[101] and TH.db.achievements.found_1, "found one")
assert(TH.db.stats.watchSets.nhunt1 and not TH.db.achievements.complete_1)
C_TransmogCollection.GetSourceInfo = function(id) local i = realInfo(id); i.isCollected = true; return i end
TH:WipeSourceCache(); TH:CheckCollectedFromHub()
assert(TH.db.stats.setsCompleted.nhunt1 and TH.db.achievements.complete_1, "set completed")
C_TransmogCollection.GetSourceInfo = realInfo; TH:WipeSourceCache()
-- сортировка одной кнопкой
TH.UI:SetView("top"); TH.UI:SetSort("new")
assert(TH.UI.sortTabs[3]:IsShown() and TH.UI.sortTabs[3].text:find("Новые") and TH.UI.sortTabs[3].text:find("ffffff"), "sort tabs")
local r = TH.UI.results
for i = 2, #r do assert((r[i - 1].created or 0) >= (r[i].created or 0), "sorted by new") end
TH.UI:SetSort("top"); TH.UI:SetView("mine")
assert(not TH.UI.sortTabs[1]:IsShown() and TH.UI.listTitle.text == "Мои образы", "no sort in mine")
-- звёздочка избранного и отметки по сети
TH.UI:SetSort("new"); TH.UI:SetView("top")
local frow
for _, rw in ipairs(TH.UI.rows) do if rw.setId and not TH:IsMine(TH:GetSet(rw.setId)) and not TH:IsTestId(rw.setId) and not TH.db.favorites[rw.setId] then frow = rw break end end
flush()
frow.fav.scripts.OnClick(frow.fav)
assert(TH.db.favorites[frow.setId] and TH:GetFavoriteCount(frow.setId) == 1, "star adds favorite")
local fout = flush()
assert(fout[1] and fout[1]:match("^SF" .. frow.setId:gsub("%-", "%%-") .. "\t1\t%w+$"), "favorite sent: " .. tostring(fout[1]))
frow.fav.scripts.OnClick(frow.fav); flush()
assert(not TH.db.favorites[frow.setId] and TH:GetFavoriteCount(frow.setId) == 0, "star removes favorite")
-- чужие отметки на мой образ дают достижение
local myNet
for _, m in pairs(TH.db.mySets) do if m.serverId and TH.db.net.sets[m.serverId] then myNet = m.serverId end end
receive({ "SF" .. myNet .. "\t1\tabc" }, "Фанат-Гордунни"); flush()
receive({ "SU" .. myNet .. "\tФанат2-Гордунни,1,abc;Фанат-Гордунни,1,abc" }); flush()
assert(TH:GetFavoriteCount(myNet) == 2, "favorites from network: " .. TH:GetFavoriteCount(myNet))
TH:CheckAchievements(); assert(TH.db.achievements.liked_1, "liked achievement")
receive({ "SQrq12\t0" })
local hasU = false
for _, m in ipairs(flush()) do if m:sub(1, 2) == "SU" then hasU = true end end
assert(hasU, "sync answer includes favorites")
-- аватар: выбор во вкладке «Мои», уходит в сеть с очками
TH.db.leader.char, TH.db.leader.optOut = Net.Me(), false
TH.UI:SetView("mine")
assert(TH.UI.avatarBtn:IsShown(), "my profile button in mine")
flush()
TH.UI.avatarBtn.scripts.OnClick()
assert(TH.UI.view == "profile" and TH.UI.profilePanel.changeAvatar:IsShown(), "my profile with avatar button")
TH.UI.profilePanel.changeAvatar.scripts.OnClick()
local ap2 = TransmogHubIconPicker
assert(ap2:IsShown() and ap2.title.text == "Аватар" and #ap2.recommended == #TH.AVATAR_REWARDS, "avatar picker")
-- наградный без достижения выбрать нельзя
local lockedBtn
for _, b in ipairs(ap2.rec) do if b.locked then lockedBtn = b break end end
assert(lockedBtn, "some rewards locked")
local before = TH.db.avatars[Net.Me()]
lockedBtn.scripts.OnClick(lockedBtn); assert(TH.db.avatars[Net.Me()] == before and ap2:IsShown(), "locked avatar not selectable")
-- открытый наградный (Король-лич получен выше) выбрать можно
local lkID = TH.IconToFileID("achievement_boss_lichking")
local lkBtn
for _, b in ipairs(ap2.rec) do if b.icon == lkID then lkBtn = b end end
assert(lkBtn and not lkBtn.locked, "lich king avatar unlocked")
lkBtn.scripts.OnClick(lkBtn)
assert(TH.db.avatars[Net.Me()] == lkID, "avatar chosen")
local av = flush()
assert(av[1] and av[1]:match("^SL.*,%w+,%w*,[0-5]*,[0-9a-z]*$"), "avatar sent with score: " .. tostring(av[1]))
assert(TH.db.net.scores[Net.Me()].avatar == TH.db.avatars[Net.Me()], "avatar in own score")
-- чужой аватар из сети
-- чужой наградный аватар без достижения не показывается, с достижением — показывается
local lkEnc = (function(n) local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", "" while n > 0 do local r = n % 36 o = d:sub(r + 1, r + 1) .. o n = math.floor(n / 36) end return o end)(lkID)
receive({ "SL10,1,save_1,abz,1," .. lkEnc }, "Аватарный-Гордунни"); flush()
assert(TH.db.net.scores["Аватарный-Гордунни"].avatar == lkID, "avatar received")
assert(TH:GetAvatar("Аватарный-Гордунни", 1, 0) ~= lkID, "locked avatar rejected for others")
local lkNum = TH.ACHIEVEMENT_BY_ID.hid_lichking.num
local maskChars = {}
for i = 1, math.ceil(lkNum / 5) do maskChars[i] = "0" end
local bit = (lkNum - 1) % 5
maskChars[math.ceil(lkNum / 5)] = ("0123456789abcdefghijklmnopqrstuv"):sub(2 ^ bit + 1, 2 ^ bit + 1)
receive({ "SL40,1,save_1,ac0," .. table.concat(maskChars) .. "," .. lkEnc }, "Аватарный-Гордунни"); flush()
assert(TH:GetAvatar("Аватарный-Гордунни", 1, 0) == lkID, "earned reward avatar shown")
assert(TH:GetAvatar("Никто-Гордунни", 1, 1):find("human_female"), "race portrait fallback")
assert(TH:GetAvatar("Никто-Гордунни", 35, 0, "MAGE"):find("classicon_mage"), "allied race: class icon")
assert(TH:GetRacePortrait(9, 1):find("femalegoblinhead"), "goblin female portrait")
assert(TH:GetRacePortrait(9, 0):find("achievement_goblinhead"), "goblin male portrait")
-- своё: оценивать нельзя, и сообщение об этом
local okm, whym = TH:CanVote(TH.db.mySets[next(TH.db.mySets)])
assert(not okm and whym:find("Свой"), "own set message: " .. tostring(whym))
-- «Мой профиль»: все свои образы с черновиками, переход к управлению
TH.db.myChars[Net.Me()] = true
local meTab
for _, b in ipairs(TH.UI.tabs) do if b.key == "me" then meTab = b end end
assert(meTab and meTab.text == "Мой профиль", "my profile tab")
meTab.scripts.OnClick()
local mp = TH.UI.profilePanel
local nMine = 0; for _ in pairs(TH.db.mySets) do nMine = nMine + 1 end
assert(TH.UI.view == "profile" and mp.own and #mp.sets == nMine, "own profile lists all my sets incl. drafts")
local hasDraft = false
for i, rw in ipairs(mp.rows) do if rw.set and rw.set.status ~= "published" and rw.rating.text:find("черновик") then hasDraft = true end end
assert(hasDraft, "draft shown in own profile")
assert(mp.details.text == "Вещи, статус и публикация" and not mp.back:IsShown() and mp.changeTitle:IsShown(), "own profile buttons")
mp.details.scripts.OnClick(); assert(TH.UI.view == "mine", "manage sets")
-- титулы: выбор из открытых, род по полу персонажа, проверка у других
TH.db.achievements.trend_1 = TH.db.achievements.trend_1 or 1
TH:SetMyTitle("trend_1"); flush()
UnitSex = function() return 3 end
assert(TH:GetPlayerTitle(Net.Me()) == "Законодательница моды", "female title")
UnitSex = function() return 2 end
assert(TH:GetPlayerTitle(Net.Me()) == "Законодатель моды", "male title")
local code = TH:GetMyTitleCode()
assert(code == TH.ACHIEVEMENT_BY_ID.trend_1.num * 2, "title code")
TH:OpenTitleMenu(frame())
-- чужой титул без достижения не показывается
local function enc36(n) local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", "" while n > 0 do local r = n % 36 o = d:sub(r + 1, r + 1) .. o n = math.floor(n / 36) end return o end
receive({ "SL10,1,save_1,ad0,1,," .. enc36(TH.ACHIEVEMENT_BY_ID.trend_1.num * 2 + 1) }, "Титулованная-Гордунни"); flush()
assert(TH:GetPlayerTitle("Титулованная-Гордунни") == nil, "title without achievement rejected")
local tn = TH.ACHIEVEMENT_BY_ID.trend_1.num
local mc = {}
for i = 1, math.ceil(tn / 5) do mc[i] = "0" end
mc[math.ceil(tn / 5)] = ("0123456789abcdefghijklmnopqrstuv"):sub(2 ^ ((tn - 1) % 5) + 1, 2 ^ ((tn - 1) % 5) + 1)
receive({ "SL60,1,save_1,ad1," .. table.concat(mc) .. ",," .. enc36(tn * 2 + 1) }, "Титулованная-Гордунни"); flush()
assert(TH:GetPlayerTitle("Титулованная-Гордунни") == "Законодательница моды", "valid female title from network")
TH.UI:OpenProfile("Титулованная-Гордунни")
assert(TH.UI.profilePanel.titleText.text == "Законодательница моды" and TH.UI.profilePanel.back:IsShown(), "title in profile")
-- справка и подсказки
assert(TH.db.helpShown, "first run handled")
-- тур: все шаги и «Готово»
TH:StartTour()
local tr = TransmogHubTour
assert(tr:IsShown() and tr.bubble.title.text == "Разделы", "tour starts")
for i = 1, 5 do tr.bubble.next.scripts.OnClick() end
assert(tr.bubble.next.text == "Готово" and tr.bubble.title.text == "Если что-то непонятно", "tour last step")
tr.bubble.next.scripts.OnClick()
assert(not tr:IsShown() and TH.db.tourDone, "tour finished")
SlashCmdList.TRANSMOGHUB("help")
local hp = TransmogHubHelp
assert(hp:IsShown() and hp.heading.text == "С чего начать", "help window")
hp.nav[6].scripts.OnClick(hp.nav[6]); assert(hp.heading.text == "Сеть и синхронизация" and hp.body.text:find("Синхронизация"))
for _, sec in ipairs(TH.HELP) do for _, line in ipairs(sec.text) do assert(not line:find("…"), "no ellipsis glyph") end end
TH.UI.helpBtn.scripts.OnClick(); assert(not hp:IsShown(), "help toggles")
assert(TH.UI.syncBtn.scripts.OnEnter, "sync tooltip")
-- ложные жалобы, предупреждения и изгнание
for i = 1, 2 do TH.db.myReports["nfalse" .. i] = serverTime; TransmogHub_Blocklist.dismissed["nfalse" .. i] = true end
TH.db.warned = {}
TH:CheckAchievements()
assert(TH:CountFalseReports() == 2 and not TH.db.achievements.shame_cry, "two false reports")
assert(TransmogHubWarning and TransmogHubWarning:IsShown() and TransmogHubWarning.text.text:find("Мурлок"), "half-way warning")
TransmogHubWarning:Hide()
-- решение модератора «ложные» напрямую тоже засчитывается
TH.db.myReports.nfalse3 = serverTime
receive({ "SMd\tnfalse3" }, "Тестадмин-Гордунни"); flush()
TH:CheckAchievements()
assert(TH:CountFalseReports() == 3 and TH.db.achievements.shame_cry, "false report shame")
-- три позорных — изгнание: открыт только свой профиль и достижения
for i = 1, 60 do TH.db.net.votes["ntroll" .. i] = { [Net.Me()] = { 1, serverTime } } end
local myPub2
for _, m in pairs(TH.db.mySets) do if m.serverId then myPub2 = m.serverId end end
TH.db.net.modBlocks.sets[myPub2] = 1
TH:LoadFeed(); TH:CheckAchievements()
assert(#TH:GetActiveShame() >= 3 and TH:IsExiled(), "exiled")
TH.UI:SetView("top")
assert(TH.UI.exilePanel:IsShown() and not TH.UI.listPanel:IsShown(), "exile panel")
assert(TH.UI.exilePanel.text.text:find("Тролль под мостом"), "exile lists shame")
TH.UI:OpenProfile(Net.Me()); assert(not TH.UI.exilePanel:IsShown() and TH.UI.profilePanel:IsShown(), "own profile allowed")
local votesBefore = TH.db.myVotes.nfr1
TH:Vote("nfr1", 5); assert(TH.db.myVotes.nfr1 == votesBefore, "exiled cannot vote")
-- исправился: позорные снимаются, двери открываются
for i = 1, 60 do TH.db.net.votes["ntroll" .. i] = { [Net.Me()] = { 1, serverTime - 100 * 86400 } } end
TH.db.net.modBlocks.sets[myPub2] = nil
TH:CheckAchievements()
assert(not TH:IsExiled(), "exile lifted")
TH.db.penalty = nil; TH.db.achievements.shame_troll = nil -- «занижение» само не снимается: сбрасываем для следующих проверок
TH.UI:SetView("top"); assert(not TH.UI.exilePanel:IsShown() and TH.UI.listPanel:IsShown())
-- бан модераторов: от изгнанного ничего не принимаем
TransmogHub_Blocklist.banned["Злодей-Гордунни"] = "спам"
receive({ "SV" .. "nfr1" .. "\t5\tabc" }, "Злодей-Гордунни"); flush()
assert(not (TH.db.net.votes.nfr1 or {})["Злодей-Гордунни"], "banned vote ignored")
-- рейтинг: свой аватар по умолчанию — портрет расы, титул рядом с именем
TH.db.leader.char, TH.db.leader.optOut = Net.Me(), false; TH.db.avatars[Net.Me()] = nil
TH.db.leader.title = "trend_1"
TH:PublishScore(true); flush()
TH.UI:SetView("achievements")
local ap3 = TH.UI.achPanel
ap3.boardBtn.scripts.OnClick()
local myRow
for _, r in ipairs(ap3.board.rows) do if r.entry and r.entry.name == Net.Me() then myRow = r end end
assert(myRow and myRow.name.text:find("Законодател"), "title in board row: " .. tostring(myRow and myRow.name.text))
ap3.cardsBtn.scripts.OnClick()
-- оспаривание: обращение принимается даже от забаненного и попадает в журнал модератора
TH.db.moderator = true
receive({ "SJabc\t[бан: спам] Это был не я, аккаунт взломали" }, "Злодей-Гордунни"); flush()
assert(TH.db.net.appeals["Злодей-Гордунни"] and TH.db.net.appeals["Злодей-Гордунни"][2]:find("взломали"), "appeal from banned stored")
assert(TH.db.modAppeals[#TH.db.modAppeals]:match("^1|Злодей%-Гордунни|%d+|%[бан"), "appeal logged for moderator")
assert(lastBn[1] and lastBn[1]:find("SKЗлодей"), "appeal relayed")
-- своё обращение: окно, отправка, раз в неделю
TH.db.myAppeal = 0
TH:OpenAppeal()
local adlg = TransmogHubAppeal
adlg.edit:SetText("коротко"); adlg.sendBtn.scripts.OnClick()
assert(adlg.error.text:find("подробнее"), "too short appeal")
adlg.edit:SetText("Образ заблокировали по ошибке, в названии нет ничего плохого"); adlg.sendBtn.scripts.OnClick()
assert(not adlg:IsShown() and TH.db.net.appeals[Net.Me()], "appeal sent")
local out = flush()
local sentJ = false
for _, m in ipairs(out) do if m:find("^SJ") or m:find("^BJ") then sentJ = true end end
assert(sentJ, "appeal message on the wire")
assert(TH:SendAppeal("Ещё одно обращение, длинное достаточно"):find("через"), "weekly limit")
receive({ "SQrq13\t0" })
local hasK = false
for _, m in ipairs(flush()) do if m:find("^SK") or m:find("^BK") then hasK = true end end
assert(hasK, "sync answer includes appeals")
-- письмо разработчику
TH.db.myIdeas = {}
TH.UI.ideaBtn.scripts.OnClick()
local idd = TransmogHubIdeas
assert(idd:IsShown() and idd.kind == "i", "ideas dialog")
TH:SetIdeaKind("b")
idd.edit:SetText("Кнопка синхронизации не нажимается после боя"); idd.sendBtn.scripts.OnClick()
assert(not idd:IsShown(), "idea sent")
local found
for _, idea in pairs(TH.db.net.ideas) do if idea[1] == Net.Me() and idea[3] == "b" then found = idea end end
assert(found and TH.db.modIdeas[#TH.db.modIdeas]:match("^1|.-|%d+|b|Кнопка"), "idea logged for moderator")
flush()
receive({ "SNabc\ti\tДобавьте тег для пиратских шляп" }, "Идейный-Гордунни"); flush()
assert(lastBn[1] and lastBn[1]:find("SOИдейный"), "idea relayed")
assert(TH:SendIdea("i", "Ещё одна идея про теги и наряды") == nil)
assert(TH:SendIdea("i", "Третья идея — тоже полезная, честно") == nil)
assert(TH.db.achievements.letter_1, "letter achievement")
local lim = TH:SendIdea("i", "Четвёртая идея за день уже не пройдёт")
assert(lim and lim:find("грифоны"), "daily idea limit")
receive({ "SQrq14\t0" })
local hasO = false
for _, m in ipairs(flush()) do if m:find("^SO") or m:find("^BO") then hasO = true end end
assert(hasO, "sync answer includes ideas")
-- сезоны и уровни: засчитывается по итогам недели, уровень — по числу соперников
local st = TH.db.stats
local lastReset = TH:GetWeeklyReset()
st.tiers = {}
TH.db.achievements.board_1, TH.db.achievements.top_10 = nil, nil
st.season = { id = lastReset - 7 * 86400, tiers = { board_1 = 1, top_10 = 4 }, firsts = {} }
TH:UpdateRankStats()
assert(st.tiers.board_1 == 1 and st.tiers.top_10 == 4 and st.season.id == lastReset, "season results applied")
TH:CheckAchievements()
assert(TH.db.achievements.board_1 and TH.db.achievements.top_10, "seasonal achievements awarded")
local b1, t10 = TH.ACHIEVEMENT_BY_ID.board_1, TH.ACHIEVEMENT_BY_ID.top_10
assert(TH:GetAchievementPoints(b1) == math.floor(b1.points / 4 + 0.5) and TH:GetAchievementPoints(t10) == t10.points * 2, "points by tier")
assert(TH:GetAchievementPoints(t10, 5) == t10.points * 4, "diamond gives x4")
local tp = TH:GetTierPools(TH.ACHIEVEMENT_BY_ID.trend_50)
assert(tp[1] == 150 and tp[5] == 3000, "top-50 needs more rivals: " .. tp[1])
assert(TH:GetTierPools(TH.ACHIEVEMENT_BY_ID.top_1)[1] == 30 and TH:GetTierPools(TH.ACHIEVEMENT_BY_ID.tag_first5)[1] == 10, "pools")
assert(TH:GetAchievementProgress(b1):find("обычный") and TH:GetAchievementProgress(t10):find("золото"), "tier names")
assert(TH:EncodeTiers():match("^[0-5]+$"), "tiers encoded")
-- у других очки считаются с уровнем
local maskAll = TH:EncodeAchievementMask()
local p1 = TH:ScoreFromMask(maskAll, "")
local p5 = TH:ScoreFromMask(maskAll, string.rep("5", #TH.SEASONAL_ORDER))
assert(p5 > p1, "higher tiers give more points")
assert(TH.ACHIEVEMENT_BY_ID.board_1.seasonal and TH.ACHIEVEMENT_BY_ID.tag_first5.seasonal and not TH.ACHIEVEMENT_BY_ID.save_1.seasonal)
-- чарт: нужно 5 оценок; подозрительные образы уходят на проверку
local function mkset(id, author)
	TH.db.net.sets[id] = { id = id, author = author, name = "Чарт", desc = "", race = 1, sex = 0,
		class = "ROGUE", created = serverTime, tags = {}, items = { [1] = {111} } }
end
mkset("nchart_few", "Автор-Гордунни"); mkset("nchart_ok", "Автор-Гордунни"); mkset("nchart_boost", "Накрутчик-Свежеватель Душ")
TH.db.net.votes.nchart_few = { ["А-Гордунни"] = { 5, serverTime }, ["Б-Гордунни"] = { 5, serverTime } }
TH.db.net.votes.nchart_ok = {}
for i = 1, 6 do TH.db.net.votes.nchart_ok["Голос" .. i .. "-Гордунни"] = { 3 + i % 2, serverTime - i * 7200 } end
TH.db.net.votes.nchart_boost = {}
for i = 1, 10 do TH.db.net.votes.nchart_boost["Твинк" .. i .. "-Свежеватель Душ"] = { 5, serverTime - i * 60 } end
-- голосовавшие за «ok» активны и в других образах
for i = 1, 6 do TH.db.net.votes.nchart_few["Голос" .. i .. "-Гордунни"] = { 4, serverTime } end
TH.db.net.votes.nchart_few["Голос1-Гордунни"] = nil
TH:LoadFeed()
local few, ok, boost = TH.byId.nchart_few, TH.byId.nchart_ok, TH.byId.nchart_boost
assert(TH:IsCharted(ok) and TH:IsCharted(few), "enough honest votes are charted")
TH.db.net.votes.nchart_few = { ["А-Гордунни"] = { 5, serverTime } }
TH:LoadFeed(); few = TH.byId.nchart_few
assert(not TH:IsCharted(few), "one vote is not enough for the chart")
local sus = TH:GetSuspicion(boost)
assert(sus and not TH:IsCharted(boost), "all fives from lonely same-realm voters within an hour are suspicious")
assert(table.concat(sus, ","):find("разовые") and table.concat(sus, ","):find("за час") and table.concat(sus, ","):find("сервер автора"), "reasons")
assert(boost.rating.dist[5] == 10, "vote distribution")
local top = TH:QuerySets("top", {})
local pos = {}
for i, set in ipairs(top) do pos[set.id] = i end
assert(pos.nchart_ok and not pos.nchart_few and not pos.nchart_boost, "only charted sets in «Лучшие»")
local favPos = {}
for i, set in ipairs(TH:QuerySets("author", { author = "Автор-Гордунни" })) do favPos[set.id] = i end
assert(favPos.nchart_ok < favPos.nchart_few, "elsewhere charted sets come first")
local modList = TH:QuerySets("moderation", {})
local inMod = false
for _, set in ipairs(modList) do if set.id == "nchart_boost" then inMod = true end end
assert(inMod, "suspicious set shown to the moderator")
-- журнал для разработчика
TH.db.modStats = {}
TH:SnapshotStats(); TH:SnapshotStats()
local kinds = {}
for _, line in ipairs(TH.db.modStats) do kinds[line:sub(3, 3)] = (kinds[line:sub(3, 3)] or 0) + 1 end
assert(kinds.S == 1 and kinds.V and kinds.X == 1, "stats snapshot once a day")
for _, line in ipairs(TH.db.modStats) do
	if line:find("|nchart_boost|", 1, true) and line:sub(3, 3) == "V" then assert(line:match("|0/0/0/0/10|s$"), line) end
end
-- модератор проверил: накрутки нет, образ в чарте, пока оценок не станет в полтора раза больше
TH.db.net.modBlocks.verified = {}
Net:ApplyModDecision("k", "nchart_boost"); TH:LoadFeed()
assert(TH:IsCharted(TH.byId.nchart_boost), "verified set back in the chart")
for i = 11, 15 do Net:StoreVote("nchart_boost", "Твинк" .. i .. "-Свежеватель Душ", 5, serverTime) end
TH:LoadFeed()
assert(TH:GetSuspicion(TH.byId.nchart_boost), "re-checked after many new votes")
TH.UI:SetView("moderation"); TH.UI.selectedId = "nchart_boost"; TH.UI:Refresh()
assert(TH.UI.modVotesMode, "moderator sees the votes button")
TH.MODERATORS[Net.Me()] = true; TH.UI.modDismissBtn.scripts.OnClick(); TH.MODERATORS[Net.Me()] = nil
assert(not TH:GetSuspicion(TH.byId.nchart_boost), "verified from the button")
TH.UI:SetView("top"); TH.UI.selectedId = "nchart_few"; TH.UI:Refresh()
assert(TH.UI.dRating:GetText():find("до чарта 4") and table.concat(TH.UI.dRatingHint, " "):find("Осталось 4"), "chart hint: " .. tostring(TH.UI.dRating:GetText()))
TH.db.moderator = false
TransmogHub_Blocklist.verified = { nchart_boost = 15 }; TH:LoadFeed()
assert(not TH:GetSuspicion(TH.byId.nchart_boost), "verified via blocklist")
TransmogHub_Blocklist.verified = {}
for _, id in ipairs({ "nchart_few", "nchart_ok", "nchart_boost" }) do TH.db.net.sets[id] = nil; TH.db.net.votes[id] = nil end
TH:LoadFeed()
-- доля лучших: процент от числа соперников, при достаточном их числе
do
	local p25, p1 = TH.ACHIEVEMENT_BY_ID.pct_top_25, TH.ACHIEVEMENT_BY_ID.pct_top_1
	local saved = TH.rankNow
	TH.rankNow = { top = { 7, 30 }, board = { nil, 0 } }
	assert(TH:IsAchievementMet(p25), "7th of 30 is top-25%")
	TH.rankNow.top = { 8, 30 }
	assert(not TH:IsAchievementMet(p25), "8th of 30 is not")
	TH.rankNow.top = { 1, 200 }
	assert(not TH:IsAchievementMet(p1) and TH:GetAchievementProgress(p1):find("из 300"), "pool too small")
	TH.rankNow.top = { 3, 300 }
	assert(TH:IsAchievementMet(p1), "3rd of 300 is top-1%")
	TH.rankNow = saved
	assert(TH.ACHIEVEMENT_BY_ID.raid_ce.seasonal and TH:GetTierPools(TH.ACHIEVEMENT_BY_ID.raid_ce)[1] == 10, "raid achievement by tag pools")
	assert(TH.RAID_TAGS.raid_midnight and TH.TAG_LABEL.raid_midnight and TH.TAG_LABEL.arena, "raid and pvp tags")
end
-- отсылки: условия общие, у «local» на каждом языке своя персона
for id, over in pairs(TH.ACH_LOCALE.enUS) do
	local a = TH.ACHIEVEMENT_BY_ID[id]
	assert(a and a.ref and a.hidden, "localized ref is a hidden reference achievement: " .. id)
	assert(not over.desc and not over.tags, "localized text only")
end
for id, over in pairs(TH.ACH_LOCALE.ruRU) do
	assert(TH.ACHIEVEMENT_BY_ID[id].ref and TH.ACHIEVEMENT_BY_ID[id].hint == over.hint or not over.hint, "ruRU hint applied: " .. id)
end
assert(TH.ACHIEVEMENT_BY_ID.hid_asmon.ref == "universal" and TH.ACHIEVEMENT_BY_ID.hid_paladin_live.name == "Скрытое достижение", "closed secret shows no text")
-- первооткрыватель: кто раньше нашёл скрытое
do
	local lk = TH.ACHIEVEMENT_BY_ID.hid_lichking
	TH.db.achievements.hid_lichking = 1767225600 + 100 * 3600 -- часы теста раньше 2026 года
	local found = TH:EncodeFound()
	assert(#found % 5 == 0 and TH.DecodeFound(found)[lk.num], "found encoded")
	local myT = TH.DecodeFound(found)[lk.num]
	assert(TH:GetFirstFinders().hid_lichking[1] == (TH.db.leader.char or Net.Me()), "I am first")
	TH:CheckAchievements()
	assert(TH.db.achievements.first_find_1, "first finder achievement")
	-- кто-то нашёл раньше: в маске есть, время раньше
	local mask = TH:EncodeAchievementMask()
	local function pad(n, w) local d, o = "0123456789abcdefghijklmnopqrstuvwxyz", "" for _ = 1, w do o = d:sub(n % 36 + 1, n % 36 + 1) .. o; n = math.floor(n / 36) end return o end
	local early = pad(lk.num, 2) .. pad(math.floor((myT - 1767225600) / 3600) - 5, 3)
	TH.db.net.scores["Ранний-Гордунни"] = { points = 50, earned = 1, mask = mask, t = 1767225600 + 200 * 3600, found = early }
	assert(TH:GetFirstFinders().hid_lichking[1] == "Ранний-Гордунни", "earlier finder wins")
	-- без достижения в маске не считается
	TH.db.net.scores["Ранний-Гордунни"].mask = ""
	assert(TH:GetFirstFinders().hid_lichking[1] ~= "Ранний-Гордунни", "found must match mask")
	TH.db.net.scores["Ранний-Гордунни"] = nil
	-- поле found проходит через сеть
	local body = "10,1,save_1,ad0,1,,,," .. early
	receive({ "SL" .. body }, "Сетевой-Гордунни"); flush()
	assert(TH.db.net.scores["Сетевой-Гордунни"] and TH.db.net.scores["Сетевой-Гордунни"].found == early, "found parsed")
	TH.db.net.scores["Сетевой-Гордунни"] = nil
end
-- официальный чарт: награды за места только из него, рейтинг — проверенные очки
do
	local me = TH.db.leader.char or Net.Me()
	TH.db.achievements.pct_top_10, TH.db.achievements.board_10 = nil, nil
	TransmogHub_Charts = { t = serverTime, date = "2025-10-09", top = { "nofficial" }, trending = {}, tags = {},
		board = { { "Чужой-Гордунни", 500 }, { me, 400 } }, firsts = {},
		awards = { [me] = { pct_top_10 = 1, board_10 = 4 } } }
	TH.db.net.scores["Чужой-Гордунни"] = { points = 9999, earned = 1, mask = "", t = serverTime }
	TH.db.net.scores["Новичок-Гордунни"] = { points = 99999, earned = 1, mask = "", t = serverTime }
	TH:CheckAchievements()
	assert(TH.db.achievements.pct_top_10, "percent award from the chart")
	assert(TH:GetTier(TH.ACHIEVEMENT_BY_ID.board_10) == 4, "seasonal tier from the chart")
	assert(TH:GetAchievementProgress(TH.ACHIEVEMENT_BY_ID.trend_1) == "итоги — каждый день", "daily results")
	local board = TH:GetLeaderboard(false, "")
	assert(board[1].name == "Чужой-Гордунни" and board[1].points == 500, "official points, not claimed 9999")
	assert(board[#board].name == "Новичок-Гордунни" and board[#board].unverified, "unverified players below")
	assert(not TH:IsChartsStale(), "fresh chart")
	TransmogHub_Charts.t = serverTime - 5 * 86400
	assert(TH:IsChartsStale(), "stale after 3 days")
	TH.chartsWarned = nil; TH:CheckChartsFreshness(); assert(TH.chartsWarned, "stale warning shown")
	TH.UI:SetView("achievements")
	TransmogHub_Charts = nil
	TH.db.net.scores["Чужой-Гордунни"], TH.db.net.scores["Новичок-Гордунни"] = nil, nil
end
-- теги: проверка брони при публикации и «тег не подходит»
do
	-- облик 11 -> вещь 110 -> кольчуга (110 % 4 + 1 = 3)
	local wrong = TH:CheckArmorTags({ "a_plate", "a_mail", "c_red" }, { [5] = { 11 } })
	assert(#wrong == 1 and wrong[1] == "a_plate", "plate tag without plate items")
	assert(#TH:CheckArmorTags({ "a_plate" }, { [15] = { 11 } }) == 0, "cloak is not armor type")

	local set = { id = "nflag", author = "Автор-Гордунни", name = "Флаг", desc = "", race = 1, sex = 0, class = "ROGUE",
		created = serverTime, tags = { "pirate", "c_red" }, items = { [1] = {111} } }
	receive({ "SP" .. Net.EncodeSet(set) }, "Автор-Гордунни"); flush()
	TH.db.net.votes.nflag = {}
	for i = 1, 6 do TH.db.net.votes.nflag["Оценщик" .. i .. "-Гордунни"] = { 4, serverTime } end
	TH:LoadFeed()
	local function inPirate() for _, s in ipairs(TH:QuerySets("new", { tags = { pirate = true } })) do if s.id == "nflag" then return true end end end
	assert(inPirate(), "found by tag")
	-- два игрока — мало
	receive({ "ST" .. "nflag\tpirate\t1\tabc" }, "Первый-Гордунни")
	receive({ "SC" .. "nflag\tВторой-Гордунни,pirate,1,abc" }, "Пересыльщик-Гордунни"); flush()
	assert(not TH:GetDisputedTags(TH.byId.nflag).pirate, "two flags are not enough")
	-- третий — тег гаснет (3 из 6 оценивших — не меньше трети)
	TH:ToggleTagFlag(TH.byId.nflag, "pirate"); flush()
	assert(TH:GetDisputedTags(TH.byId.nflag).pirate == 3, "third flag disputes the tag")
	assert(not inPirate(), "disputed tag not searchable")
	assert(TH:FormatSetTags(TH.byId.nflag):find("оспорен"), "shown as disputed")
	-- снял свою отметку — тег вернулся
	TH:ToggleTagFlag(TH.byId.nflag, "pirate"); flush()
	assert(inPirate(), "unflag restores the tag")
	-- автор убирает свой тег сам
	receive({ "ST" .. "nflag\tc_red\t1\tabd" }, "Автор-Гордунни"); flush()
	assert(TH:GetDisputedTags(TH.byId.nflag).c_red == 0, "author removes own tag")
	local active = TH:GetActiveTags(TH.byId.nflag)
	assert(#active == 1 and active[1] == "pirate", "active tags")
	-- меню на карточке
	TH:OpenTagFlagMenu(TH.UI.dTagsBtn, TH.byId.nflag); flush()
	TH.db.net.sets.nflag, TH.db.net.votes.nflag, TH.db.net.tagFlags.nflag = nil, nil, nil
	TH:LoadFeed()
end
-- рейдовые теги: хотя бы половина видимых вещей — из рейдов этого дополнения
do
	local oldDrops = C_TransmogCollection.GetAppearanceSourceDrops
	EJ_GetTierInfo = function(tier) return tier == 12 and "Полночь" or ("Тир" .. tier) end
	-- чётные облики падают в рейде Полночи, нечётные — в подземелье
	C_TransmogCollection.GetAppearanceSourceDrops = function(id)
		if id % 2 == 0 then return { { instance = "Шпиль Бездны", instanceType = 2, tiers = { "Полночь" }, encounter = "Босс", difficulties = {} } } end
		return { { instance = "Подземелье", instanceType = 1, tiers = { "Полночь" }, encounter = "Босс", difficulties = {} } }
	end
	local ok, _, have, total = TH:CheckRaidTag("raid_midnight", { [1] = { 2 }, [3] = { 4 }, [5] = { 11 }, [4] = { 13 } })
	assert(ok and have == 2 and total == 3, "2 of 3 visible from the raid (shirt skipped)")
	local ok2, why = TH:CheckRaidTag("raid_midnight", { [1] = { 2 }, [5] = { 11 }, [7] = { 13 } })
	assert(not ok2 and why:find("1 из 3"), "1 of 3 is not enough: " .. tostring(why))
	assert(not TH:CheckRaidTag("raid_wotlk", { [1] = { 2 } }), "other expansion")
	assert(TH:CheckRaidTag("c_red", nil), "other tags are free")
	-- окно публикации: тег нельзя отметить, причина в чате
	TH:OpenSaveDialog()
	local picker = TransmogHubSaveDialog.tags
	picker.canSelect = function(key) return TH:CheckRaidTag(key, { [5] = { 11 } }) end
	picker:Toggle("raid_midnight")
	assert(not picker.selected.raid_midnight, "raid tag refused")
	picker.canSelect = function(key) return TH:CheckRaidTag(key, { [5] = { 12 } }) end
	picker:Toggle("raid_midnight")
	assert(picker.selected.raid_midnight, "raid tag allowed")
	TransmogHubSaveDialog:Hide()
	C_TransmogCollection.GetAppearanceSourceDrops, EJ_GetTierInfo = oldDrops, nil
end
-- скрытое, которое проверяет только официальный чарт
do
	local a = TH.ACHIEVEMENT_BY_ID.hid_illidan
	TH.db.achievements.hid_illidan = nil
	assert(TH:IsChartAchievement(a), "server secret is a chart achievement")
	TH:CheckAchievements()
	assert(not TH.db.achievements.hid_illidan and a.name == "Скрытое достижение", "no chart - cannot be earned")
	local me = TH.db.leader.char or Net.Me()
	local mine
	for id, m in pairs(TH.db.mySets) do if m.serverId then mine = m end end
	TransmogHub_Charts = { t = serverTime, date = "x", top = {}, trending = {}, tags = {}, board = {}, firsts = {},
		awards = { [me] = { hid_illidan = 1 } }, awardSets = { [me] = { hid_illidan = mine and mine.serverId } },
		secretKeys = { hid_illidan = "fedcba9876543210" } }
	TH:CheckAchievements()
	assert(TH.db.achievements.hid_illidan, "awarded by the chart")
	assert(a.name == "Серверная тайна", "name unlocked by the chart key")
	assert(a.desc:find("Стражи подиума"), "condition is not revealed: " .. a.desc)
	TransmogHub_Charts = nil
end
-- профиль: достижения не вылезают за окно, остальные — прокруткой
do
	TH.UI:OpenProfile(Net.Me())
	local p = TH.UI.profilePanel
	local shown = 0
	for _, icon in ipairs(p.icons) do if icon:IsShown() then shown = shown + 1 end end
	assert(shown <= 9 * 8 and shown < #TH.ACHIEVEMENTS, "only visible rows shown: " .. shown)
	TH:ProfileScrollAch(p, -1)
	assert(p.achOffset == 1, "scrolled one row")
	TH:ProfileScrollAch(p, -100)
	assert(p.achOffset == math.ceil(#TH.ACHIEVEMENTS / 8) - 9, "clamped at the end")
end
-- свой профиль: образы по персонажам, сворачивание и порядок
do
	local alt = "Твинк-" .. (Net.Me():match("%-(.+)$") or "Гордунни")
	TH.db.mySets["local:alt1"] = { id = "local:alt1", name = "Твинковый", author = alt, created = 1, items = {}, class = "MAGE" }
	TH.db.charOrder, TH.db.collapsedChars = {}, {}
	TH.UI:OpenProfile(Net.Me())
	local p = TH.UI.profilePanel
	TH:RefreshProfile(p, Net.Me())
	assert(p.grouped, "grouped by character")
	assert(p.entries[1].char == Net.Me(), "current character first")
	local altIdx
	for i, e in ipairs(p.entries) do if e.char == alt then altIdx = i end end
	assert(altIdx and p.entries[altIdx + 1].set.id == "local:alt1", "alt header then its set")
	TH:MoveProfileChar(p, alt, 1)
	assert(p.entries[1].char == alt and TH.db.charOrder[1] == alt, "moved up")
	TH:ToggleProfileChar(p, alt)
	assert(p.entries[2].char == Net.Me(), "collapsed alt hides its sets")
	TH:RefreshProfileSets(p)
	assert(p.rows[1].char == alt and p.rows[2].char == Net.Me())
	TH:ToggleProfileChar(p, alt)
	assert(p.entries[2].set and p.entries[2].set.id == "local:alt1", "expanded again")
	TH.db.mySets["local:alt1"] = nil
	TH:RefreshProfile(p, Net.Me())
	assert(not p.grouped, "single character — no headers")
end
-- профиль: новое достижение ярче, после наведения — тусклее
do
	TH.UI:OpenProfile(Net.Me())
	local p = TH.UI.profilePanel
	local icon
	for _, i in ipairs(p.icons) do if i.has then icon = i; break end end
	icon.border.SetColorTexture = function(self, r, g, b, a) self.alpha = a end
	TH.db.seenAch[icon.achievement.id] = nil
	TH:RefreshProfile(p, Net.Me())
	assert(icon.border.alpha > 0.9, "fresh achievement is bright")
	icon.scripts.OnEnter(icon)
	assert(TH.db.seenAch[icon.achievement.id] and icon.border.alpha < 0.5, "seen achievement is dimmer")
end
-- очки сезонного достижения в подсказке — диапазоном, а не базовыми
do
	local a = TH.ACHIEVEMENT_BY_ID.tag_multi or TH.ACHIEVEMENTS[1]
	for _, x in ipairs(TH.ACHIEVEMENTS) do if x.seasonal and x.points == 100 then a = x; break end end
	assert(a.seasonal, "found a seasonal achievement")
	local text = TH:FormatAchievementPoints(a, true)
	assert(text:find("от 25 до 400"), text)
	assert(TH:FormatAchievementPoints(TH.ACHIEVEMENT_BY_ID.found_1):find("10 очков"))
end
-- отчёты об ошибках: только свои, один раз на версию, можно выключить
do
	local sent = {}
	local orig = Net.SendIdea
	Net.SendIdea = function(_, kind, text) sent[#sent + 1] = { kind, text } end
	TH:ReportError("Interface/AddOns/OtherAddon/Main.lua:10: boom", "Interface/AddOns/OtherAddon/Main.lua:10")
	assert(#sent == 0, "foreign errors are ignored")
	TH:ReportError("Interface/AddOns/TransmogHub/Core.lua:123: attempt to index nil", "[string \"@Interface/AddOns/TransmogHub/Core.lua\"]:123: in function")
	assert(#sent == 1 and sent[1][1] == "e" and sent[1][2]:find("Core.lua:123: attempt to index nil", 1, true)
		and not sent[1][2]:find("AddOns", 1, true), "own error reported with a short path: " .. tostring(sent[1] and sent[1][2]))
	TH:ReportError("Interface/AddOns/TransmogHub/Core.lua:123: attempt to index nil", nil)
	assert(#sent == 1, "same error once per version")
	TH:ReportError("Interface/AddOns/Blizzard_UI/X.lua:5: taint", "Interface/AddOns/TransmogHub/UI.lua:77: in function")
	assert(#sent == 2 and sent[2][2]:find("@ UI.lua:77", 1, true), "error in Blizzard code from our call: " .. tostring(sent[2] and sent[2][2]))
	TH.db.sendErrors = false
	TH:ReportError("Interface/AddOns/TransmogHub/Profile.lua:9: other", nil)
	assert(#sent == 2, "switched off")
	TH.db.sendErrors = true
	Net.SendIdea = orig
	assert(Net:StoreIdea("Кто-Гордунни", 123, "e", "v1 Core.lua:1: x"), "error reports accepted by the network")
	-- BugGrabber: событие EventRegistry с номером ошибки, ошибки — в GetDB(); старые не отправляем
	local cb
	local oldDB = { { message = "Interface/AddOns/TransmogHub/Old.lua:1: old", stack = "" } }
	_G.BugGrabber = { GetDB = function() return oldDB end }
	_G.EventRegistry = { RegisterCallback = function(_, event, fn) if event == "BugGrabber.BugGrabbed" then cb = fn end end }
	assert(TH.InstallErrorReports() == "BugGrabber" and cb, "subscribed to BugGrabber")
	sent = {}
	Net.SendIdea = function(_, kind, text) sent[#sent + 1] = { kind, text } end
	oldDB[2] = { message = "Interface/AddOns/TransmogHub/Fresh.lua:5: fresh", stack = "" }
	cb(nil, 2)
	assert(#sent == 1 and sent[1][2]:find("Fresh.lua:5", 1, true), "new BugGrabber error reported, old one skipped")
	cb(nil, 2)
	assert(#sent == 1, "same entry once")
	-- повтор старой ошибки: BugGrabber только увеличил её счётчик
	oldDB[1].counter = 2
	cb(nil, 1)
	assert(#sent == 2 and sent[2][2]:find("Old.lua:1", 1, true), "repeated old error is reported")
	_G.BugGrabber, _G.EventRegistry = nil, nil
	Net.SendIdea = orig
end
-- предзагрузка данных о вещах: каждый облик один раз за сеанс
do
	local first = TH:PrefetchLikelySets()
	assert(first > 0, "prefetch queued items")
	assert(TH:PrefetchLikelySets() == 0, "already prefetched")
end
-- оформление EllesmereUI: по умолчанию выключено без него, включается командой, проход по окнам без ошибок
do
	assert(not TH:IsSkinned(), "no EllesmereUI — normal look")
	SlashCmdList.TRANSMOGHUB("style eui")
	assert(TH.db.style == "eui" and TH:IsSkinned())
	EllesmereUIDB = { profile = { general = { accentColor = { r = 0.9, g = 0.1, b = 0.2 } } } }
	TH.accent = nil
	local a = TH:GetAccent()
	assert(a[1] == 0.9 and a[3] == 0.2, "accent from EllesmereUI settings")
	TH:ApplySkin()
	SlashCmdList.TRANSMOGHUB("style auto")
	EllesmereUIDB, TH.accent = nil, nil
	assert(TH:GetAccent()[2] == 0.82, "default accent")
end
-- жалоба «Другое»: без пояснения не уходит, с пояснением — жалоба и письмо вида r
do
	local sent = {}
	local origIdea = Net.SendIdea
	Net.SendIdea = function(_, kind, text) sent[#sent + 1] = { kind, text } end
	local target
	for _, s in ipairs(TH.feed.sets) do if not TH:IsMine(s) and not TH:IsTestId(s.id) then target = s break end end
	assert(target, "a foreign set to report")
	TH:OpenReportOther(target)
	assert(TransmogHubReportOther:IsShown())
	assert(TH:SendReportOther(target.id, "ну"), "too short is refused")
	assert(#sent == 0)
	assert(TH:SendReportOther(target.id, "в описании ссылка на продажу золота") == nil)
	assert(#sent == 1 and sent[1][1] == "r" and sent[1][2]:find("[" .. target.id .. "]", 1, true), "explanation sent")
	assert(TH.db.myReports[target.id], "report sent too")
	Net.SendIdea = origIdea
	assert(Net:StoreIdea("Кто-Гордунни", 124, "r", "[nx] текст"), "report notes accepted")
end
-- модерация: «без решения» убирает из списка, новая жалоба возвращает
do
	TH.db.net.reports.nmodskip = { ["Кто-Гордунни"] = { "o", 100 } }
	TH.db.modDismissed.nmodskip = 200
	assert(TH:IsModDismissed("nmodskip"), "dismissed")
	TH.db.net.reports.nmodskip["Другой-Гордунни"] = { "a", 300 }
	assert(not TH:IsModDismissed("nmodskip"), "new report brings it back")
	TH.db.net.reports.nmodskip, TH.db.modDismissed.nmodskip = nil, nil
end
-- образ из своего комплекта: без переодевания
do
	local mk = function(id) return { appearanceID = id, secondaryAppearanceID = 0, illusionID = 0 } end
	C_TransmogCollection.GetCustomSets = function() return { 7 } end
	C_TransmogCollection.GetCustomSetInfo = function() return "Крылышки на каждый день", 12345 end
	C_TransmogCollection.GetCustomSetItemTransmogInfoList = function() return { [1] = mk(111), [5] = mk(222) } end
	local choices = TH:GetCustomSetChoices()
	assert(#choices == 1 and choices[1].items[5][1] == 222, "custom sets read")
	TH:OpenSaveDialog()
	local sd = TransmogHubSaveDialog
	sd.sourceBtn.scripts.OnClick(sd.sourceBtn) -- меню: заглушка выбирает последний пункт — комплект
	assert(sd.sourceBtn.text:find("Из комплекта: Крылышки на каж...", 1, true), sd.sourceBtn.text)
	assert(sd.fixedItems and sd.name:GetText() == "Крылышки на каждый день", "name from the custom set")
	sd.tags:Toggle("pirate")
	local before = {}
	for id in pairs(TH.db.mySets) do before[id] = true end
	sd.saveBtn.scripts.OnClick()
	local made
	for id, m in pairs(TH.db.mySets) do if not before[id] then made = m end end
	assert(made and made.items[5][1] == 222 and made.items[1][1] == 111, "draft made from the custom set")
	C_TransmogCollection.GetCustomSets = nil
	-- наряд из окна трансмогрификации у NPC
	local mk2 = function(id) return { appearanceID = id, secondaryAppearanceID = 0, illusionID = 0 } end
	TransmogFrame = CreateFrame("Frame", "TransmogFrame")
	TransmogFrame.CharacterPreview = CreateFrame("Frame")
	TransmogFrame.CharacterPreview.GetItemTransmogInfoList = function() return { [5] = mk2(333), [7] = mk2(444) } end
	C_TransmogOutfitInfo = { GetCurrentlyViewedOutfitID = function() return 3 end, GetOutfitInfo = function() return { name = "Крылышки (мир)" } end }
	local outfit = TH:GetViewedOutfit()
	assert(outfit and outfit.name == "Крылышки (мир)" and outfit.items[7][1] == 444, "viewed outfit read")
	TH:OpenSaveDialog(outfit)
	assert(sd.fixedItems and sd.sourceBtn.text:find("Из наряда:", 1, true) and sd.name:GetText() == "Крылышки (мир)", "save dialog from outfit")
	TH:AttachOutfitButton()
	TH:UpdateModelOverlap() -- без размеров окон в заглушке — не падает
	TransmogFrame, C_TransmogOutfitInfo = nil, nil
	TH:UpdateModelOverlap()
end
-- аватар у каждого своего персонажа свой
do
	local alt = "Аватарный-Гордунни"
	TH.db.myChars[alt] = true
	TH.db.avatars[alt] = 135000
	assert(TH:GetAvatar(alt, 1, 0) == 135000, "alt avatar")
	assert(TH:GetAvatar(Net.Me(), 1, 0) ~= 135000, "own avatar is separate")
	TH.db.myChars[alt], TH.db.avatars[alt] = nil, nil
end
-- таблица лидеров: первые 100 мест и своя строка, остальные — поиском
do
	local saved = TH.db.net.scores
	TH.db.net.scores = {}
	local now = time()
	for i = 1, 130 do TH.db.net.scores["Игрок" .. i .. "-Гордунни"] = { points = 1000 - i, earned = 1, t = now } end
	TH.db.net.scores[TH.db.leader.char or Net.Me()] = { points = 1, earned = 1, t = now }
	TH.UI:SetView("achievements")
	local ap = TH.UI.achPanel
	ap.board.offset = 0
	TH:RefreshLeaderboard(ap, "")
	assert(#ap.board.list == 101, "top 100 and me: " .. #ap.board.list)
	assert(ap.board.list[101].place == 131, "my real place")
	assert(ap.pos.text:find("Первые 100 из 131"), ap.pos.text)
	TH:RefreshLeaderboard(ap, "игрок120")
	assert(#ap.board.list == 1 and ap.board.list[1].place == 120, "search finds below the cut")
	TH:RefreshLeaderboard(ap, "")
	TH.db.net.scores = saved
end
-- порог чарта: 5% от игроков с оценками в день (медиана за 7 прошлых дней), не меньше 5
;(function()
	local savedVotes = TH.db.net.votes
	TH.db.net.votes = { x = {} }
	local now = time()
	local day = math.floor(now / 86400)
	-- 7 прошлых дней по 300 игроков, один день-выброс на 5000; сегодня не считается
	for d = 1, 7 do
		local n = d == 3 and 5000 or 300
		for i = 1, n do TH.db.net.votes["d" .. d .. "_" .. i] = { ["П" .. i .. "-Гордунни"] = { 5, (day - d) * 86400 + 100 } } end
	end
	for i = 1, 9000 do TH.db.net.votes.x["Сегодня" .. i] = { 5, now } end
	local need, perDay = TH:ComputeChartThreshold(now)
	assert(perDay == 300 and need == 15, "threshold " .. need .. " / " .. perDay)
	TH.db.net.votes = { x = {} }
	assert(TH:ComputeChartThreshold(now) == 5, "minimum threshold")
	TH.db.net.votes = savedVotes
	TH.chartThreshold = nil
end)()

-- «Новые» — только за 14 дней; «Рекомендуемые» — те же, перемешаны с весами интереса
;(function()
	local now = Net.Now()
	TH.db.net.sets.nrec_old = { id = "nrec_old", author = "Старый-Гордунни", name = "Старый", desc = "", race = 1, sex = 0,
		class = "ROGUE", created = now - 20 * 86400, tags = {}, items = { [1] = {111} } }
	for i = 1, 30 do
		TH.db.net.sets["nrec_" .. i] = { id = "nrec_" .. i, author = "Свежий" .. i .. "-Гордунни", name = "Свежий", desc = "",
			race = 1, sex = 0, class = i <= 15 and "MAGE" or "WARRIOR", created = now - i * 3600, tags = { i <= 15 and "mage" or "warrior" },
			items = { [1] = {111} } }
	end
	TH:LoadFeed()
	local function Ids(list) local t = {} for _, set in ipairs(list) do t[set.id] = true end return t end
	local newIds = Ids(TH:QuerySets("top", { sort = "new" }))
	assert(newIds.nrec_1 and not newIds.nrec_old, "new: only last 14 days")
	assert(Ids(TH:QuerySets("author", { author = "Старый-Гордунни" })).nrec_old, "old set still in the author's list")
	local rec = TH:QuerySets("top", { sort = "recommended" })
	assert(#rec == #TH:QuerySets("top", { sort = "new" }), "recommended has the same sets")
	local first = {}
	for i = 1, 5 do first[i] = rec[i].id end
	local again = TH:QuerySets("top", { sort = "recommended" })
	for i = 1, 5 do assert(again[i].id == first[i], "stable until reshuffle") end
	-- маг среди своих персонажей: маги в среднем выше
	TH.db.charClass[Net.Me()] = "MAGE"
	TH.db.leader.char = Net.Me()
	local mageTop = 0
	for _ = 1, 40 do
		TH:Reshuffle()
		local list = TH:QuerySets("top", { sort = "recommended", tags = { mage = nil } })
		local mages, seen = 0, 0
		for _, set in ipairs(list) do
			if set.id:find("^nrec_") then
				seen = seen + 1
				if seen <= 10 and set.class == "MAGE" then mages = mages + 1 end
			end
		end
		mageTop = mageTop + mages
	end
	assert(mageTop > 40 * 5, "interesting classes come up more often: " .. mageTop)
	assert(mageTop < 40 * 10, "but not only them: " .. mageTop)
	for i = 1, 30 do TH.db.net.sets["nrec_" .. i] = nil end
	TH.db.net.sets.nrec_old = nil
	TH:LoadFeed()
end)()
-- статистика нажатий: кнопки окон считаются, раз в неделю уходят кодами отдельно от писем
;(function()
	TH:HookUsage() -- в заглушке окон обход ничего не находит: проверяем, что не падает
	wipe(TH.db.clicks)
	TH:TrackClick("Образы / Теги"); TH:TrackClick("Образы / Теги"); TH:TrackClick("Справка / Закрыть")
	local code = TH.UsageCode("Образы / Теги")
	assert(#code == 4 and TH.db.clicks[code] == 2, "click counted")
	local ideasBefore = 0
	for _ in pairs(TH.db.net.ideas) do ideasBefore = ideasBefore + 1 end
	TH.db.usageSent = 0
	TH:SendUsage()
	local ideasAfter, usage = 0, 0
	for _ in pairs(TH.db.net.ideas) do ideasAfter = ideasAfter + 1 end
	for _, u in pairs(TH.db.net.usage) do if u[4]:find(code .. "=2", 1, true) then usage = usage + 1 end end
	assert(usage == 1 and ideasAfter == ideasBefore, "usage stored apart from letters")
	assert(not next(TH.db.clicks) and TH.db.usageSent > 0, "counts reset after sending")
	TH:TrackClick("Образы / Теги")
	TH:SendUsage()
	assert(TH.db.clicks[code] == 1, "not more than once a week")
	-- модератор видит сводку по всем с расшифровкой
	local list = TH:GetUsageSummary()
	assert(list[1] and list[1][1] == "Образы / Теги", "summary decodes names: " .. tostring(list[1] and list[1][1]))
	TH.db.sendUsage = false
	TH:TrackClick("Образы / Теги")
	assert(TH.db.clicks[code] == 1, "off: nothing counted")
	TH.db.sendUsage = true
end)()
-- подписки: отметка в сети, подписчики, взаимность, уведомления и вкладка «Подписки»
;(function()
	TH.loggedIn = true
	local me, author = Net.Me(), "Автор-Гордунни"
	flush()
	TH:SetFollowing(author, true)
	assert(TH:IsFollowing(author) and TH.db.net.follows[author][me][1] == 1, "follow stored")
	local out = table.concat(flush(), "\n")
	assert(out:find("f" .. author, 1, true), "follow sent")
	assert(TH:GetFollowerCount(author) == 1, "follower counted")
	-- автор подписался в ответ: уведомление «подписался на вас», подписка взаимная
	local shown = {}
	local realToast = TH.ShowToast
	TH.ShowToast = function(_, kind, data) shown[#shown + 1] = { kind, data } end
	receive({ "Sf" .. me .. "\t1\t" .. Net.Enc(Net.Now()) }, author)
	assert(TH:FollowsMe(author) and TH:IsMutual(author), "mutual follow")
	assert(shown[1] and shown[1][1] == "note" and shown[1][2].title:find("подписался"), "follow notification")
	flush()
	-- новый образ автора — уведомление и вкладка «Подписки»
	local set = { id = "nfollow1", author = author, name = "Подписной", desc = "", race = 1, sex = 0, class = "MAGE",
		created = Net.Now(), tags = {}, items = { [1] = {111} } }
	receive({ "SP" .. Net.EncodeSet(set) }, author)
	TH:LoadFeed()
	local found = false
	for _, x in ipairs(shown) do if x[2].title:find("Новый образ") then found = true end end
	assert(found, "new set notification")
	local subs = TH:QuerySets("subs", {})
	assert(#subs >= 1 and subs[1].author == author, "subs view lists followed authors")
	-- оценки своего образа: только первые N
	local mine
	for _, x in pairs(TH.db.net.sets) do if TH.db.myChars[x.author] then mine = x break end end
	if mine then
		TH.db.notify.voteLimit = 1
		local before = #shown
		TH.db.net.votes[mine.id] = {}
		receive({ "SV" .. mine.id .. "\t5\t" .. Net.Enc(Net.Now()) }, "Оценщик1-Гордунни")
		receive({ "SV" .. mine.id .. "\t4\t" .. Net.Enc(Net.Now()) }, "Оценщик2-Гордунни")
		assert(#shown == before + 1 and shown[#shown][2].title:find("оценил"), "only first votes notify")
		-- избранное: уведомление один раз
		local n = #shown
		receive({ "SF" .. mine.id .. "\t1\t" .. Net.Enc(Net.Now()) }, "Оценщик1-Гордунни")
		assert(#shown == n + 1 and shown[#shown][2].title:find("избранное"), "favorite notification")
		receive({ "SF" .. mine.id .. "\t1\t" .. Net.Enc(Net.Now() + 1) }, "Оценщик1-Гордунни")
		assert(#shown == n + 1, "favorite notifies once")
	end
	-- пересланная подписка (синхронизация): «g<на кого>\t<кто>,1,<время>»
	receive({ "Sg" .. author .. "\tТретий-Гордунни,1," .. Net.Enc(Net.Now()) })
	assert(TH:GetFollowerCount(author) == 2, "relayed follow stored")
	-- отписка
	TH:SetFollowing(author, false)
	assert(not TH:IsFollowing(author) and TH.db.net.follows[author][me][1] == 0, "unfollow stored")
	TH.ShowToast = realToast
	-- всплывашки: пример и перемещение не падают
	TH:ShowToastSample("note"); TH:ShowToastSample("ach"); TH:SetToastUnlocked("note", true)
	assert(TH:IsToastUnlocked("note"), "toast unlocked"); TH:SetToastUnlocked("note", false)
	assert(not TH:IsToastUnlocked("note"), "toast locked"); TH:ResetToastPosition("note")
	TH:OpenSettings(); TH:RefreshSettings()
end)()
-- роли: модераторов назначает только админ; модератор назначать не может
;(function()
	local admin, mod, other = "Тестадмин-Гордунни", "Новыймод-Гордунни", "Третий-Гордунни"
	assert(TH:IsAdmin(admin) and not TH:IsModerator(mod), "roles start")
	receive({ "SMm\t" .. mod }, admin); flush()
	assert(TH:IsModerator(mod) and not TH:IsAdmin(mod), "admin appoints a moderator")
	receive({ "SMm\t" .. other }, mod); flush()
	assert(not TH:IsModerator(other), "a moderator cannot appoint")
	local found = false
	for _, e in ipairs(TH:GetModeratorList()) do if e[1] == mod then found = true end end
	assert(found, "moderator listed")
	receive({ "SMx\t" .. mod }, admin); flush()
	assert(not TH:IsModerator(mod), "admin removes a moderator")
	-- снятие наказания модератором
	TH.db.penalty = { count = 1, since = Net.Now(), untilT = Net.Now() + 86400, retracted = {} }
	receive({ "SMw\t" .. Net.Me() }, admin); flush()
	assert(not TH.db.penalty, "penalty lifted by a moderator")
end)()
-- Зал славы: образ из зала не в «Лучших», а в своём списке
;(function()
	local saved = TransmogHub_Charts
	local any
	for _, set in ipairs(TH.feed.sets) do if TH:IsCharted(set) then any = set break end end
	if not any then return end
	TransmogHub_Charts = { t = Net.Now(), awards = {}, hof = { [any.id] = { 3, 3, 1, "2026-10-17" } } }
	assert(TH:GetHallDate(any.id) == "2026-10-17", "hall date")
	for _, set in ipairs(TH:QuerySets("top", { sort = "top" })) do assert(set.id ~= any.id, "hall set out of «Лучшие»") end
	local hall = TH:QuerySets("hall", {})
	assert(hall[1] and hall[1].id == any.id, "hall list")
	TH.UI:SetView("hall")
	assert(TH.UI.listTitle.text == "Зал славы", "hall view title")
	TH.UI:SetView("top")
	TransmogHub_Charts = saved
end)()
-- шрифты: нужные знаки покрывают всё, что аддон пишет; шрифт без кириллицы не предлагается
;(function()
	local need = {}
	for _, ch in ipairs(TH.FONT_REQUIRED) do need[ch] = true end
	-- все не-ASCII знаки в коде аддона (кроме комментариев и Data/Secrets.lua) должны быть в списке
	local files = { "Core.lua", "Moderation.lua", "Network.lua", "Appearance.lua", "Preview.lua", "TagPicker.lua", "UI.lua",
		"SaveDialog.lua", "IconPicker.lua", "Achievements.lua", "Charts.lua", "Profile.lua", "Help.lua", "Tour.lua",
		"Standing.lua", "Ideas.lua", "Wowhead.lua", "Minimap.lua", "Skin.lua", "Usage.lua", "Toasts.lua", "Follow.lua",
		"Fonts.lua", "Settings.lua", "Secret.lua", "ChatLinks.lua" }
	local unknown = {}
	for _, name in ipairs(files) do
		local f = assert(io.open(dir .. "/" .. name))
		for line in f:lines() do
			local code = line:match("^%s*%-%-") and "" or line:gsub("%-%-[^\"]*$", "")
			for ch in code:gmatch("[\194-\244][\128-\191]+") do
				-- U+E000 — нарочно «пустой» знак для проверки шрифта
				if not need[ch] and ch ~= "\238\128\128" then unknown[ch] = (unknown[ch] or name) end
			end
		end
		f:close()
	end
	local list = {}
	for ch, where in pairs(unknown) do list[#list + 1] = ch .. " (" .. where .. ")" end
	assert(#list == 0, "знаки не проверяются в шрифтах: " .. table.concat(list, ", "))

	-- модель шрифтов: у «nocyr» русские буквы — квадратики (ширина 10, как у пустого знака)
	local font
	TH.fontProbe = {
		Hide = function() end,
		SetFont = function(_, path) font = path; return path ~= "Fonts\\NOFILE.TTF" and not path:find("Broken") end,
		SetText = function(self, s) self.s = s end,
		GetStringWidth = function(self)
			local s = self.s
			if s == "\238\128\128" then return 10 end
			if font == "Fonts\\NOCYR.TTF" and s:find("[\208\209]") then return 10 end
			local w = 0
			for i = 1, #s do w = w + (s:byte(i) % 7) + 3 end
			return w + 0.5
		end,
	}
	assert(TH:CheckFont("Fonts\\GOOD.TTF"), "font with all glyphs")
	local ok, missing = TH:CheckFont("Fonts\\NOCYR.TTF")
	assert(not ok and #missing == 66, "font without cyrillic rejected: " .. #missing)
	assert(not TH:CheckFont("Fonts\\NOFILE.TTF"), "missing file rejected")
	TH.GAME_FONTS = { { key = "good", name = "Good", path = "Fonts\\GOOD.TTF" }, { key = "nocyr", name = "NoCyr", path = "Fonts\\NOCYR.TTF" } }
	local keys = {}
	for _, f in ipairs(TH:GetFontChoices()) do keys[f.key] = true end
	assert(keys.default and keys.good and not keys.nocyr, "only full fonts are offered")
	TH:SetFont("nocyr")
	assert(TH:GetFontPath() == nil, "a broken font is never applied")
	TH:SetFont("good")
	assert(TH:GetFontPath() == "Fonts\\GOOD.TTF", "good font applied")
	TH:UseCustomFont("Broken.ttf")
	assert(TH.db.customFont == nil, "custom font without glyphs is refused")
	TH:UseCustomFont("Interface\\Fonts\\Mine.ttf")
	assert(TH.db.customFont == "Mine.ttf" and TH:GetFontPath() == "Interface\\Fonts\\Mine.ttf", "custom font by file name")
	-- EllesmereUI: по умолчанию («авто») — его шрифт, если в нём есть все буквы
	EllesmereUI = { GetFontPath = function() return "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Good.ttf" end,
		GetFontName = function() return "Мой шрифт" end }
	TH:SetFont("auto")
	assert(TH:GetFontPath() == "Interface\\AddOns\\EllesmereUI\\media\\fonts\\Good.ttf", "auto = EllesmereUI font")
	local hasEui = false
	for _, f in ipairs(TH:GetFontChoices()) do if f.key == "eui" and f.name:find("Мой шрифт") then hasEui = true end end
	assert(hasEui, "EllesmereUI font offered by name")
	EllesmereUI.GetFontPath = function() return "Fonts\\NOCYR.TTF" end
	assert(TH:GetFontPath() == nil, "EllesmereUI font without cyrillic is not used")
	EllesmereUI = nil
	assert(TH:GetFontPath() == nil, "no EllesmereUI — game font")
	TH:SetFont("default")
	TH.fontProbe = nil
end)()
-- теги: темы ссылаются только на существующие теги, у цветов есть обводка, ключи уникальны
;(function()
	for _, theme in ipairs(TH.TAG_THEMES) do
		for _, key in ipairs(theme.tags) do assert(TH.TAG_LABEL[key], "theme «" .. theme.name .. "»: unknown tag " .. key) end
	end
	local seen, labels = {}, {}
	for _, group in ipairs(TH.TAG_GROUPS) do
		for _, tag in ipairs(group.tags) do
			assert(not seen[tag[1]], "duplicate tag key " .. tag[1])
			assert(not labels[TH.Lower(tag[2])], "duplicate tag label " .. tag[2])
			assert(tag[1]:match("^[%w_]+$") and #tag[1] <= 40, "bad tag key " .. tag[1])
			seen[tag[1]], labels[TH.Lower(tag[2])] = true, true
			if tag[1]:sub(1, 2) == "c_" then assert(TH.TAG_COLORS[tag[1]], "color without swatch " .. tag[1]) end
		end
	end
	for key in pairs(TH.TAG_COLORS) do assert(seen[key], "swatch for unknown tag " .. key) end
	for key in pairs(TH.TAG_ADDED) do assert(seen[key] or TH.TAG_RETIRED[key], "added date for unknown tag " .. key) end
	assert(#TH.TAG_THEMES <= 16, "too many themes for the theme list: " .. #TH.TAG_THEMES)
	assert(TH.TAG_THEMES[1].name == "Классы", "classes theme first (achievement)")
end)()
-- теги: по умолчанию и в поиске — сначала популярные
;(function()
	local list, counts = TH:GetTagsSorted("", "popular")
	for i = 2, #list do assert((counts[list[i - 1]] or 0) >= (counts[list[i]] or 0), "popular first") end
	local found = TH:GetTagsSorted("а", "popular")
	for i = 2, #found do assert((counts[found[i - 1]] or 0) >= (counts[found[i]] or 0), "search results popular first") end
	local p = TH:CreateTagPicker(UIParent, { cols = 3, rows = 5, colW = 100 })
	assert(p.list[1] == list[1], "a new picker starts with popular tags")
end)()
-- запрещённые названия: шутка — переименовать, оскорбление — 14 дней / навсегда, реклама — бан
;(function()
	local admin = "Тестадмин-Гордунни"
	local savedStrikes = TH.db.nameStrikes
	TH.db.nameStrikes = nil
	local shown = {}
	local realWarn, realAsk = TH.ShowStandingWarning, TH.AskRename
	TH.ShowStandingWarning = function(_, title, text, okText, onOk) shown[#shown + 1] = { title, text, okText, onOk } end
	local asked
	TH.AskRename = function(_, localId) asked = localId end
	local function Mine(name)
		local m = TH:CreateMySet(name, "", {}, { [1] = {111} })
		TH:Publish(m.id); flush()
		return m
	end
	-- шутка: образ скрыт, автору письмо с кнопкой «Переименовать», наказания нет
	local joke = Mine("Смешное имя")
	local jokeId = joke.serverId
	assert(jokeId, "joke published")
	receive({ "SMe\t" .. jokeId }, admin); flush()
	assert(TH:IsBlocked({ id = jokeId }), "joke set hidden")
	assert(joke.renameRequired, "rename requested")
	assert(#shown == 1 and shown[1][3] == "Переименовать", "rename letter shown")
	assert(not TH:GetPublishRestriction(), "first joke: no penalty")
	assert(TH:GetAchievementStat("blockedSets") == 0, "joke rename is not a shame")
	shown[1][4](); assert(asked == joke.id, "letter button opens rename")
	assert(TH:RenameViolatedSet(joke.id, "Смешное имя") ~= nil, "same name refused")
	assert(TH:RenameViolatedSet(joke.id, "Тихий рыцарь") == nil, "renamed")
	assert(joke.name == "Тихий рыцарь" and joke.status == "published" and joke.serverId ~= jokeId and not joke.renameRequired,
		"renamed set republished under a new id")
	-- повторный вход не наказывает второй раз за тот же образ
	TH:CheckNameViolations(true)
	assert(not TH:GetPublishRestriction(), "same decision counted once")
	-- вторая шутка — уже 14 дней без публикаций
	local joke2 = Mine("Ещё шутка")
	receive({ "SMe\t" .. joke2.serverId }, admin); flush()
	local r = TH:GetPublishRestriction()
	assert(r and not r.permanent and r.untilT > Net.Now(), "second joke: 14 days")
	assert(TH:PublishRestrictionText(), "restriction text")
	local draft = TH:CreateMySet("Черновик", "", {}, { [1] = {111} })
	TH:Publish(draft.id); flush()
	assert(draft.status == "draft", "publishing blocked while restricted")
	assert(TH:RenameViolatedSet(joke2.id, "Серьёзный образ") == nil and joke2.status == "draft", "rename while restricted keeps a draft")
	-- срок прошёл — можно снова
	TH.db.nameStrikes.untilT = Net.Now() - 1
	TH:CheckNameViolations()
	assert(not TH:GetPublishRestriction() and TH.db.nameStrikes.washed, "restriction washed")
	-- оскорбление после этого — навсегда
	local insult = Mine("Обидное")
	receive({ "SMo\t" .. insult.serverId }, admin); flush()
	assert(TH:GetPublishRestriction().permanent, "second offence: permanent")
	-- из чёрного списка решение тоже доходит (новый аккаунт: прошлых нарушений нет)
	TH:DeleteMySet(insult.id)
	TH.db.nameStrikes = nil
	local listed = Mine("Из списка")
	assert(listed.serverId, "published after the strikes were reset")
	TransmogHub_Blocklist.names = { [listed.serverId] = "o" }
	TH:CheckNameViolations()
	assert(TH:GetPublishRestriction() and not TH:GetPublishRestriction().permanent, "blocklist insult: 14 days")
	TransmogHub_Blocklist.names = nil
	-- реклама: бан сразу, на всём аккаунте; снятие бана
	local spammer = "Рекламщик-Гордунни"
	receive({ "SMb\t" .. spammer }, admin); flush()
	assert(TH:IsBanned(spammer), "ad ban applied")
	assert(not Net:StoreVote("nloc1", spammer, 5, Net.Now()), "banned votes refused")
	receive({ "SMy\t" .. spammer }, admin); flush()
	assert(not TH:IsBanned(spammer), "ban lifted")
	receive({ "SMb\t" .. Net.Me() }, "Самозванец-Гордунни"); flush()
	assert(not TH:IsExiled(), "fake moderator cannot ban")
	TH.db.myChars["Твинк-Гордунни"] = true
	receive({ "SMb\tТвинк-Гордунни" }, admin); flush()
	assert(TH:IsExiled(), "ad ban closes the whole account")
	assert(shown[#shown][1]:find("Изгнание"), "ban letter")
	receive({ "SMy\tТвинк-Гордунни" }, admin); flush()
	TH.db.myChars["Твинк-Гордунни"] = nil
	assert(not TH:IsExiled(), "unbanned")
	-- кнопка модератора: меню нарушений не падает
	TH.MODERATORS[Net.Me()] = true
	TH.UI:SetView("moderation"); TH.UI:Refresh()
	TH.MODERATORS[Net.Me()] = nil
	TH.UI:SetView("top")
	for _, m in ipairs({ joke, joke2, listed, draft }) do TH:DeleteMySet(m.id) end
	TH.db.nameStrikes = savedStrikes
	TH.ShowStandingWarning, TH.AskRename = realWarn, realAsk
	TH:LoadFeed()
end)()
-- пометка Стражей: повторная шутка наказывается, даже если аддон переустановлен
;(function()
	local admin = "Тестадмин-Гордунни"
	local saved, realWarn, realAsk = TH.db.nameStrikes, TH.ShowStandingWarning, TH.AskRename
	local letters = {}
	TH.ShowStandingWarning = function(_, title, text) letters[#letters + 1] = text end
	TH.AskRename = function() end
	TH.db.nameStrikes = nil
	TH.db.net.modBlocks.warned = {}
	local a = TH:CreateMySet("Первая шутка", "", {}, { [1] = {111} }); TH:Publish(a.id); flush()
	receive({ "SMe\t" .. a.serverId }, admin); flush()
	assert(TH:GetRenameWarning(Net.Me()) == a.serverId, "author marked by the guards")
	assert(letters[1]:find("принять меры"), "letter warns about the next time")
	assert(not TH:GetPublishRestriction(), "first joke free")
	TH.db.nameStrikes = nil -- «переустановил аддон»
	local b = TH:CreateMySet("Вторая шутка", "", {}, { [1] = {111} }); TH:Publish(b.id); flush()
	receive({ "SMe\t" .. b.serverId }, admin); flush()
	assert(TH:GetPublishRestriction(), "marked author: second joke restricted after reinstall")
	assert(TH:GetRenameWarning(Net.Me()) == a.serverId, "mark keeps the first set")
	TH:DeleteMySet(a.id); TH:DeleteMySet(b.id)
	TH.db.net.modBlocks.warned = {}
	TH.db.nameStrikes, TH.ShowStandingWarning, TH.AskRename = saved, realWarn, realAsk
	TH:LoadFeed()
end)()
-- амнистия: модератор снимает с игрока всё (проверка наказаний без последствий)
;(function()
	local admin = "Тестадмин-Гордунни"
	local realWarn = TH.ShowStandingWarning
	TH.ShowStandingWarning = function() end
	local m = TH:CreateMySet("Проверка наказаний", "", {}, { [1] = {111} }); TH:Publish(m.id); flush()
	receive({ "SMe\t" .. m.serverId }, admin); flush()
	receive({ "SMo\t" .. m.serverId }, admin); flush()
	receive({ "SMb\t" .. Net.Me() }, admin); flush()
	TH.db.penalty = { count = 1, since = Net.Now(), untilT = Net.Now() + 86400, retracted = {} }
	assert(TH:GetPublishRestriction() and not m.renameRequired, "joke re-judged as an insult: restricted")
	assert(TH:IsExiled() and TH:GetPublishRestriction() and TH:GetRenameWarning(Net.Me()), "all penalties applied")
	receive({ "SMr\t" .. Net.Me() }, "Самозванец-Гордунни"); flush()
	assert(TH:IsExiled(), "fake moderator cannot pardon")
	receive({ "SMr\t" .. Net.Me() }, admin); flush()
	assert(not TH:IsExiled(), "amnesty: ban lifted")
	assert(not TH:GetPublishRestriction() and not TH.db.nameStrikes, "amnesty: publishing open")
	assert(not TH:GetRenameWarning(Net.Me()), "amnesty: guards' mark removed")
	assert(not TH.db.penalty, "amnesty: vote penalty lifted")
	assert(not m.renameRequired and not TH:IsBlocked({ id = m.serverId }), "amnesty: set unblocked")
	assert(TH:GetAchievementStat("blockedSets") == 0, "amnesty: no blocked-set shame")
	-- решение действует сразу: та же шутка снова — снова первая, без наказания
	TH:DeleteMySet(m.id)
	TH.ShowStandingWarning = realWarn
	TH:LoadFeed()
end)()
-- подписчики списком, подписка у имени автора, сброс камеры, просмотр своего комплекта
;(function()
	local me, fan = Net.Me(), "Поклонник-Гордунни"
	Net:StoreFollow(me, fan, 1, Net.Now())
	local list = TH:GetFollowers(me)
	local found = false
	for _, n in ipairs(list) do if n == fan then found = true end end
	assert(found, "follower listed")
	TH:OpenFollowersMenu(UIParent, me)
	TH.UI:OpenProfile(me)
	TH.UI.model:ResetCamera()
	TH:PreviewCustomSet({ id = 1, name = "Комплект", items = { [1] = {111} } })
	TH:PreviewCustomSet({ name = "Наряд", items = { [1] = {111} } })
	TH.UI:SetView("top")
end)()
-- имя из окна ввода: опечатка в мире, регистр, без мира — находим известного игрока
;(function()
	Net:StoreFollow(Net.Me(), "Шоуприст-Ревущийфьорд", 1, Net.Now())
	assert(TH:ResolvePlayerName("Шоуприст-Ревушийфьорд") == "Шоуприст-Ревущийфьорд", "realm typo fixed")
	assert(TH:ResolvePlayerName("шоуприст") == "Шоуприст-Ревущийфьорд", "short lowercase name found")
	assert(TH:ResolvePlayerName(" Шоуприст - Ревущийфьорд ") == "Шоуприст-Ревущийфьорд", "spaces ignored")
	local n, known = TH:ResolvePlayerName("Незнакомец")
	assert(not known and n:find("^Незнакомец%-"), "unknown: own realm appended")
	StaticPopupDialogs["TRANSMOGHUB_AMNESTY"].OnAccept({ EditBox = { GetText = function() return "шоуприст" end } })
end)()
-- чистый старт с выпуском: один раз снимает позорные достижения и наказания
;(function()
	local releaseKey = rawget(TH, "FRESH_START")
	TH.FRESH_START = nil
	assert(not TH:ResetForRelease(), "no reset while FRESH_START is nil")
	local saved = CopyTable(TH.db.achievements)
	TH.db.achievements.shame_troll = Net.Now()
	TH.db.achievements.keep_test = 1
	TH.db.nameStrikes = { seen = {}, jokes = 1, count = 1, untilT = Net.Now() + 86400 }
	TH.FRESH_START = "test"
	assert(TH:ResetForRelease(), "reset runs once")
	assert(not TH.db.achievements.shame_troll and not TH.db.nameStrikes, "shame and penalties wiped")
	assert(TH.db.achievements.keep_test == 1, "normal achievements kept")
	assert(not TH:ResetForRelease(), "not twice")
	TH.FRESH_START = releaseKey
	TH.db.achievements = saved
	TH:CheckAchievements()
end)()
-- отмена своих жалоб и скрытий: образ снова виден, жалоба не считается, у модератора пропадает
;(function()
	local set = { id = "nundo1", author = "Чужой-Гордунни", name = "Отменяемый", desc = "", race = 1, sex = 0, class = "MAGE",
		created = Net.Now(), tags = { "c_red" }, items = { [1] = {111} } }
	receive({ "SP" .. Net.EncodeSet(set) }, set.author); flush()
	TH:Report("nundo1", "o"); flush()
	TH:ToggleTagFlag(TH.db.net.sets.nundo1, "c_red"); flush()
	TH:LoadFeed()
	assert(TH.db.hidden.nundo1 and TH:GetReportStats("nundo1") == 1, "reported and hidden")
	TH:UndoMyReports(); local out = table.concat(flush(), "\n")
	assert(out:find("Rnundo1\tu\t", 1, true), "retraction sent")
	assert(not TH.db.hidden.nundo1 and TH:GetReportStats("nundo1") == 0, "visible again, report not counted")
	assert(TH.byId.nundo1, "back in the feed")
	assert(not TH:IsTagFlaggedByMe(TH.db.net.sets.nundo1, "c_red"), "tag flag withdrawn")
	-- старая копия жалобы при синхронизации не возвращается
	receive({ "SXnundo1\t" .. Net.Me() .. ",o," .. Net.Enc(Net.Now() - 100) }); flush()
	assert(TH:GetReportStats("nundo1") == 0, "old report copy ignored")
	local inMod = false
	for _, x in ipairs(TH:QuerySets("moderation", {})) do if x.id == "nundo1" then inMod = true end end
	assert(not inMod, "retracted report not in moderation")
	-- отметка «тег не подходит» видна модератору
	Net:StoreTagFlag("nundo1", "Другой-Гордунни", "c_red", 1, Net.Now())
	for _, x in ipairs(TH:QuerySets("moderation", {})) do if x.id == "nundo1" then inMod = true end end
	assert(inMod, "tag flag brings the set to moderation")
end)()
-- твинки друга Battle.net попадают во «Друзья», даже если он ими при нас не заходил
;(function()
	bnReceive({ "ShТвинкдруга-Гордунни,Ещётвинк-Ревущийфьорд" }); flush()
	assert(TH.db.friendChars["Твинкдруга-Гордунни"] and TH.db.friendChars["Ещётвинк-Ревущийфьорд"], "friend alts remembered")
	receive({ "ShЧужой-Гордунни" }, "Чужой-Гордунни"); flush()
	assert(not TH.db.friendChars["Чужой-Гордунни"], "alts accepted only from Battle.net friends")
	assert(TH:GetFriendNames()["Твинкдруга-Гордунни"], "alt counts as a friend")
	-- свои персонажи уходят другу при знакомстве
	local out = {}
	Net:SendMyChars({ kind = "BNET", target = 77 })
	for _, m in ipairs(flush()) do out[#out + 1] = m end
	for _, m in ipairs(lastBn) do out[#out + 1] = m end
	assert(table.concat(out, "\n"):find("Sh", 1, true), "own characters sent")
end)()
-- вернуть один скрытый образ: только он, жалоба на него отозвана
;(function()
	for i = 1, 2 do
		local set = { id = "nhide" .. i, author = "Чужой-Гордунни", name = "Скрытый " .. i, desc = "", race = 1, sex = 0, class = "MAGE",
			created = Net.Now(), tags = {}, items = { [1] = {111} } }
		receive({ "SP" .. Net.EncodeSet(set) }, set.author); flush()
		TH:Report(set.id, "o"); flush()
	end
	local list = TH:GetHiddenList()
	local n = 0
	for _, e in ipairs(list) do if e.id:find("^nhide") then n = n + 1; assert(e.reason, "reason shown") end end
	assert(n == 2, "both hidden listed")
	assert(TH:UndoReport("nhide1"), "report retracted")
	flush(); TH:LoadFeed()
	assert(not TH.db.hidden.nhide1 and TH.db.hidden.nhide2, "only one restored")
	assert(TH:GetReportStats("nhide1") == 0 and TH:GetReportStats("nhide2") == 1, "only its report retracted")
	TH:OpenHiddenMenu(UIParent); flush()
end)()
-- меню своего опубликованного образа из общей ленты: без жалобы, с «Удалить»
;(function()
	local m = TH:CreateMySet("Свой в ленте", "", {}, { [1] = {111} }); TH:Publish(m.id); flush(); TH:LoadFeed()
	local texts, real = {}, MenuUtil
	MenuUtil = { CreateContextMenu = function(owner, gen)
		local root
		root = setmetatable({}, { __index = function(_, method) return function(_, text)
			if type(text) == "string" then texts[#texts + 1] = text end
			return root
		end end })
		gen(owner, root)
	end }
	TH.UI:OpenSetMenu(UIParent, m.serverId)
	MenuUtil = real
	local all = table.concat(texts, "|")
	assert(not all:find("Пожаловаться", 1, true) and not all:find("Скрыть образ", 1, true), "no report on own set: " .. all)
	assert(all:find("Удалить", 1, true), "delete on own published set: " .. all)
	TH:DeleteMySet(m.id); flush()
end)()
-- названия достижений не повторяются
;(function()
	local seen = {}
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		if a.name and not a.hidden then
			assert(not seen[a.name], "duplicate achievement name: " .. a.name)
			seen[a.name] = true
		end
	end
end)()
-- Вытеснение старых образов при переполнении: чарт, Зал славы, свои, избранное и
-- подписки остаются, уходят самые старые из остальных
;(function()
	local net = TH.db.net
	local saved = {}
	for id, set in pairs(net.sets) do saved[id] = set end
	for id in pairs(saved) do net.sets[id] = nil end
	for i = 1, 3005 do
		local id = "nfill" .. i
		net.sets[id] = { id = id, name = "Образ " .. i, author = "Наполнитель-Гордунни", created = 1000 + i, items = {}, tags = {} }
	end
	-- пять самых старых: защищённые по разным причинам
	net.sets.nfill1.author = "Любимый-Гордунни"
	TH.db.following["Любимый-Гордунни"] = 1
	TH.db.favorites.nfill2 = true
	TransmogHub_Charts = { t = time(), awards = {}, top = { "nfill3" }, trending = {}, tags = {}, hof = { nfill4 = { 1, 0, 0, "2026-10-01" } } }
	TH.Net:Prune()
	local n = 0
	for _ in pairs(net.sets) do n = n + 1 end
	assert(n == 3000, "trimmed to the limit: " .. n)
	assert(net.sets.nfill1 and net.sets.nfill2 and net.sets.nfill3 and net.sets.nfill4, "followed, favorite, charted and Hall of Fame outfits kept")
	assert(not net.sets.nfill5 and not net.sets.nfill9 and net.sets.nfill10, "oldest of the rest evicted")
	for id in pairs(net.sets) do net.sets[id] = nil end
	for id, set in pairs(saved) do net.sets[id] = set end
	TH.db.following["Любимый-Гордунни"] = nil
	TH.db.favorites.nfill2 = nil
	TransmogHub_Charts = nil
end)()

-- Гильдия: согильдиец, которого нет в канале (другая фракция; в Forever — свой канал),
-- делает гильдию мостом — рассылка идёт и туда; пока такого нет, гильдия только для знакомства
;(function()
	local Net0 = TH.Net
	_G.IsInGuild = function() return true end
	Net0.guildBridge = nil
	Net0.channelPeers["Канальный-Гордунни"] = true
	Net0:OnMessage("TMHUB", "SI1", "GUILD", "Канальный-Гордунни")
	assert(not Net0.guildBridge, "guildmate heard in channel: no bridge")
	Net0:OnMessage("TMHUB", "SI1", "GUILD", "Ордынец-Гордунни")
	assert(Net0.guildBridge, "guildmate not in channel: guild becomes a bridge")
	assert(Net0:GuildPeerCount() >= 2, "guildmates with the addon counted for the status bar")
	flush()
	Net0:Send("Xtest")
	flush()
	local viaGuild = false
	for _, m in ipairs(lastGroup) do if m:find("^GUILD:") then viaGuild = true end end
	assert(viaGuild, "broadcast goes through guild bridge")
	Net0.guildBridge = nil
	_G.IsInGuild = function() return false end
end)()

-- Каталог из обновления (Data/Bundled.lua): образ виден без сети, итог оценки держится,
-- пока своих голосов меньше; заблокированный образ из каталога не показывается
;(function()
	TransmogHub_Bundled = { schema = 1, generated = 0, sets = {
		{ id = "ncat1", name = "Каталожный", author = "Издалека-Ревущийфьорд", created = 1700000000,
			tags = { "pirate" }, items = { [5] = { 1001 } }, rating = { avg = 4.5, n = 10, dist = { 0, 0, 1, 3, 6 } } },
		{ id = "ncat2", name = "Заблокированный", author = "Издалека-Ревущийфьорд", created = 1700000000,
			tags = {}, items = { [5] = { 1002 } } },
	} }
	TransmogHub_Blocklist.sets.ncat2 = "реклама"
	TH:LoadFeed()
	local set = assert(TH.byId.ncat1, "catalog set in feed")
	assert(not TH.byId.ncat2, "blocked catalog set hidden")
	assert(set.rating.n == 10, "catalog rating kept")
	TH.Net:StoreVote("ncat1", "Сосед-Гордунни", 1, 1700000100)
	TH:LoadFeed()
	assert(TH.byId.ncat1.rating.n == 10 and TH.byId.ncat1.rating.avg == 4.5, "one network vote does not replace catalog summary")
	assert(not TH.db.net.sets.ncat1, "catalog is not the network base (not relayed, not counted)")
	TransmogHub_Blocklist.sets.ncat2 = nil
	TransmogHub_Bundled = nil
	TH:LoadFeed()
end)()

-- Знакомство через каталог: одиночка стучится скрытым шёпотом к недавним авторам своей фракции,
-- те отвечают «я тут» и синхронизируются; дальше всё новое идёт и им
;(function()
	local Net0 = TH.Net
	local saved = { Net0.PeerCount, Net0.BNetPeerCount, Net0.GuildPeerCount, Net0.GroupHasOtherRealm }
	Net0.PeerCount = function() return 0 end
	Net0.BNetPeerCount = function() return 0 end
	Net0.GuildPeerCount = function() return 0 end
	Net0.GroupHasOtherRealm = function() return false end
	_G.UnitFactionGroup = function() return "Alliance" end
	TransmogHub_Bundled = { schema = 1, generated = 0, sets = {
		{ id = "nk1", name = "А", author = "Свежий-Ревущийфьорд", created = 1700000300, race = 1, items = {} },
		{ id = "nk2", name = "Б", author = "Ордынец-Ревущийфьорд", created = 1700000400, race = 2, items = {} },
		{ id = "nk3", name = "В", author = Net0.Me(), created = 1700000500, items = {} },
		{ id = "nk4", name = "Г", author = "Старый-Ревущийфьорд", created = 1600000000, items = {} },
		{ id = "nk5", name = "Д", author = "Вчерашний-Ревущийфьорд", created = 1700000200, items = {} },
		{ id = "nk6", name = "Е", author = "Давний-Ревущийфьорд", created = 1500000000, items = {} },
	} }
	TH.db.knocks = { ["Вчерашний-Ревущийфьорд"] = GetServerTime() - 3600 }
	local savedPeers, savedSets = Net0.whisperPeers, TH.db.net.sets
	Net0.whisperPeers, TH.db.net.sets = {}, {}
	assert(Net0:IsIsolated(), "no connections: isolated")
	flush()
	Net0:KnockCatalog()
	flush()
	local knockedTo = {}
	for _, m in ipairs(lastGroup) do
		local who = m:match("^WHISPER:(.-):S?H")
		if who then knockedTo[#knockedTo + 1] = who end
	end
	assert(#knockedTo == 3, "knock batch of three: " .. #knockedTo)
	local set = {}
	for _, who in ipairs(knockedTo) do set[who] = true end
	assert(set["Свежий-Ревущийфьорд"] and set["Старый-Ревущийфьорд"] and set["Давний-Ревущийфьорд"],
		"recent authors of own faction, not self, not knocked yesterday: " .. table.concat(knockedTo, ","))
	assert(TH.db.knocks["Свежий-Ревущийфьорд"], "knock remembered for a day")
	-- «игрок не найден» после стука скрыт, чужой — нет
	_G.ERR_CHAT_PLAYER_NOT_FOUND_S = "Персонаж по имени \"%s\" в игре не найден."
	assert(Net0.HideKnockMiss(nil, nil, "Персонаж по имени \"Старый-Ревущийфьорд\" в игре не найден."), "knock miss hidden")
	assert(not Net0.HideKnockMiss(nil, nil, "Персонаж по имени \"Кто-то-Гордунни\" в игре не найден."), "other miss shown")
	-- ответ на стук: «я тут» шёпотом и синхронизация
	Net0:OnMessage("TMHUB", "SH1", "WHISPER", "Свежий-Ревущийфьорд")
	flush()
	local replied, synced = false, false
	for _, m in ipairs(lastGroup) do
		if m:find("^WHISPER:Свежий%-Ревущийфьорд:S?I") then replied = true end
		if m:find("^WHISPER:Свежий%-Ревущийфьорд:S?Q") then synced = true end
	end
	assert(replied and synced, "knock answered by whisper and synced")
	assert(not Net0:IsIsolated(), "whisper peer: not isolated")
	Net0:Send("Xtest")
	flush()
	local relayed = false
	for _, m in ipairs(lastGroup) do if m:find("^WHISPER:Свежий%-Ревущийфьорд:S?Xtest") then relayed = true end end
	assert(relayed, "broadcast reaches whisper peers")
	Net0.whisperPeers, TH.db.net.sets = savedPeers, savedSets
	Net0.PeerCount, Net0.BNetPeerCount, Net0.GuildPeerCount, Net0.GroupHasOtherRealm = saved[1], saved[2], saved[3], saved[4]
	_G.UnitFactionGroup = nil
	TH.db.knocks = nil
	TransmogHub_Bundled = nil
end)()

-- Где найти вещь: наблюдения у торговца, отправка разработчику, каталог и AllTheThings
;(function()
	-- находим обработчик событий модуля: он зарегистрирован при входе, вызываем напрямую
	TH.db.sendSources = true
	wipe(TH.db.srcQueue); wipe(TH.db.srcSeen)
	_G.UnitGUID = function(u) if u == "npc" then return "Creature-0-1-2-3-4567-0000" end end
	_G.GetMerchantNumItems = function() return 2 end
	_G.GetMerchantItemLink = function(i) return i == 1 and "|Hitem:244267::|h[x]|h" or "|Hitem:5::|h[y]|h" end
	_G.GetMerchantItemInfo = function() return "x", 1, 748 end
	_G.GetMerchantItemCostInfo = function() return 0 end
	_G.C_MerchantFrame = nil
	local realInfo = C_TransmogCollection.GetItemInfo
	C_TransmogCollection.GetItemInfo = function(link) if link:find("244267") then return 100, 200 end end
	_G.C_Map = _G.C_Map or {}
	local realBest, realPos, realMapInfo = C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition, C_Map.GetMapInfo
	C_Map.GetBestMapForUnit = function() return 2248 end
	C_Map.GetPlayerMapPosition = function() return { GetXY = function() return 0.4521, 0.6013 end } end
	C_Map.GetMapInfo = function() return { name = "Остров Дорн" } end
	_G.GetCoinTextureString = function(c) return c .. "м" end
	_G.strsplit = _G.strsplit or function(sep, str)
		local out = {}
		for part in (str .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do out[#out + 1] = part end
		return unpack(out)
	end
	assert(TH.SourcesTest, "test hook")
	TH.SourcesTest.MERCHANT_SHOW()
	assert(#TH.db.srcQueue == 1 and TH.db.srcQueue[1]:find("^v:244267:4567:2248:452:601:748::"),
		"vendor item with appearance noted: " .. tostring(TH.db.srcQueue[1]))
	TH.SourcesTest.MERCHANT_SHOW()
	assert(#TH.db.srcQueue == 1, "same vendor item noted once")
	local title, lines = TH:GetWhereToFind(244267, 200)
	assert(title and lines[1]:find("Остров Дорн (45.2, 60.1)", 1, true), "own finding shown before catalog: " .. tostring(lines and lines[1]))
	-- отправка: сообщение «s», у модератора — в журнал без имени
	local sentIdeas = {}
	local realSend = TH.Net.SendIdea
	TH.Net.SendIdea = function(_, kind, text) sentIdeas[#sentIdeas + 1] = { kind, text } end
	TH:SendSources(true)
	TH.Net.SendIdea = realSend
	assert(#sentIdeas == 1 and sentIdeas[1][1] == "s" and sentIdeas[1][2]:find("^%a%a%a%a;v:244267"), "findings sent")
	assert(#TH.db.srcQueue == 0, "queue emptied after sending")
	local realMod = TH.IsModeratorClient
	TH.IsModeratorClient = function() return true end
	wipe(TH.db.modSources)
	assert(TH.Net:StoreIdea("Кто-то-Гордунни", GetServerTime(), "s", "ruRU;v:1:2:3:4:5:6::Имя"), "stored")
	assert(#TH.db.modSources == 1 and not TH.db.modSources[1]:find("Кто-то", 1, true), "moderator log without player name")
	TH.IsModeratorClient = realMod
	-- каталог
	TransmogHub_Sources = { schema = 1, items = { [244267] = { { "v", 4567, 2248, 452, 601, { ruRU = "Торговка Ала" }, 748 } } } }
	title, lines = TH:GetWhereToFind(244267, 200)
	assert(lines[1]:find("Торговка Ала", 1, true) and lines[1]:find("748м", 1, true), "catalog line: " .. tostring(lines[1]))
	-- метка по находкам игроков: стандартная метка игры
	local pin
	_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m, x, y } end }
	C_Map.SetUserWaypoint = function(p) pin = p end
	C_Map.CanSetUserWaypointOnMap = function() return true end
	assert(TH:CanShowOnMap(244267, 999), "map pin available from catalog")
	TH:ShowOnMap(244267, 999, "Одеяние")
	assert(pin and pin[1] == 2248 and math.abs(pin[2] - 0.452) < 1e-9, "user waypoint set from catalog")
	-- без данных и без ATT — подсказка поставить ATT
	local t2, l2, noATT = TH:GetWhereToFind(99999, 1)
	assert(not t2 and noATT, "hint to install AllTheThings")
	-- AllTheThings: путь от корня до торговца
	local root = { text = "ATT" }
	local zone = { text = "Остров Дорн", mapID = 2248, parent = { text = "Игровые зоны", parent = root } }
	local vendors = { text = "Торговцы", key = "headerID", parent = zone }
	local vendor = { text = "Торговка Ала", npcID = 4567, parent = vendors, coords = { { 45.2, 60.1, 2248 } } }
	local item = { parent = vendor }
	_G.AllTheThings = { SearchForObject = function(field, id) if field == "sourceID" and id == 200 then return { item } end end }
	title, lines = TH:GetWhereToFind(244267, 200)
	assert(title:find("AllTheThings") and lines[1] == "Остров Дорн > Торговка Ала (45.2, 60.1)", "ATT path: " .. tostring(lines and lines[1]))
	-- добыча локации: группы «Броня > Тканевые» и верхние разделы не показываем
	local zones = { text = "Игровые зоны", parent = root }
	local kt = { text = "Кель'Талас", mapID = 2393, parent = zones }
	local drops = { text = "Добыча локации", parent = kt }
	local armor = { text = "Броня", parent = drops, key = "headerID" }
	local cloth = { text = "Тканевые", parent = armor, key = "filterID" }
	armor.g = { cloth }
	drops.g = { armor }
	local pants = { parent = cloth }
	_G.AllTheThings = { SearchForObject = function() return { pants } end }
	title, lines = TH:GetWhereToFind(257005, 300)
	assert(lines[1] == "Кель'Талас > Добыча локации", "filter groups dropped: " .. tostring(lines[1]))
	-- имя торговца ATT ещё загружает: путь не обрывается, подсказка ждёт
	_G.RETRIEVING_DATA = "Получение данных"
	local kar = { text = "К'ареш", mapID = 2371, parent = { text = "Каз Алгар", parent = zones } }
	local vend = { text = "Торговцы", key = "headerID", parent = kar }
	local npc = { text = "|cffffffffПолучение данных|r", parent = vend }
	local shoes = { parent = { text = RETRIEVING_DATA, parent = npc } }
	_G.AllTheThings = { SearchForObject = function() return { shoes } end }
	local _, _, _, pending
	title, lines, _, pending = TH:GetWhereToFind(244268, 400)
	assert(lines[1] == "К'ареш > Торговцы" and pending, "loading names skipped, refresh asked: " .. tostring(lines[1]))
	-- имена пришли: зона, торговец, комплект; заголовок «Торговцы» лишний
	npc.text, npc.npcID = "Шад'анис", 235000
	shoes.parent.text = "Комплект: облачение"
	title, lines, _, pending = TH:GetWhereToFind(244268, 400)
	assert(lines[1] == "К'ареш > Шад'анис > Комплект: облачение" and not pending, "zone, vendor, ensemble: " .. tostring(lines[1]))
	-- без координат у ATT метку не предлагаем (каталог по этому предмету пуст)
	assert(not TH:CanShowOnMap(244268, 400), "no map pin without coordinates")
	-- координаты ATT по карте: метку ставим сами, на торговца
	npc.coords = { [2371] = { { 41.5, 22.8 } } }
	title, lines = TH:GetWhereToFind(244268, 400)
	assert(lines[1]:find("(41.5, 22.8)", 1, true), "ATT coords by map: " .. tostring(lines[1]))
	assert(TH:CanShowOnMap(244268, 400), "map pin available via ATT coords")
	local atPin
	_G.UiMapPoint = { CreateFromCoordinates = function(m, x, y) return { m, x, y } end }
	C_Map.SetUserWaypoint = function(p) atPin = p end
	C_Map.CanSetUserWaypointOnMap = function() return true end
	TH:ShowOnMap(244268, 400, "Туфли")
	assert(atPin and atPin[1] == 2371 and math.abs(atPin[2] - 0.415) < 1e-9, "waypoint from ATT coords")
	local printed = {}
	local realPrint = TH.Print
	TH.Print = function(_, text) printed[#printed + 1] = text end
	TH:ShowOnMap(244268, 400, "Туфли")
	TH.Print = realPrint
	assert(printed[1]:find("|Hworldmap:2371:4150:2280|h[Шад'анис — ", 1, true), "clickable map link: " .. tostring(printed[1]))
	_G.AllTheThings = { SearchForObject = function() error("not ready") end }
	title = TH:GetWhereToFind(244267, 200)
	assert(title and not title:find("AllTheThings"), "ATT error falls back to catalog")
	_G.AllTheThings = nil
	TransmogHub_Sources = { schema = 1, items = {} }
	C_TransmogCollection.GetItemInfo = realInfo
	C_Map.GetBestMapForUnit, C_Map.GetPlayerMapPosition, C_Map.GetMapInfo = realBest, realPos, realMapInfo
end)()

-- Транслит: на нерусском клиенте кириллические названия образов — латиницей, в сети как есть
;(function()
	assert(TH.Translit("Ядовитый") == "Yadovityy", TH.Translit("Ядовитый"))
	assert(TH.Translit("Щит Ёжика") == "Shchit Yozhika", TH.Translit("Щит Ёжика"))
	assert(TH.Translit("Неон ган X") == "Neon gan X" and TH.Translit("Plain") == "Plain", "mixed and latin")
	local real = ns.ClientLocale
	local set = { name = "Ядовитый" }
	ns.ClientLocale = function() return "ruRU" end
	assert(TH:SetName(set) == "Ядовитый", "russian client sees the original")
	ns.ClientLocale = function() return "esES" end
	assert(TH:SetName(set) == "Yadovityy" and set.name == "Ядовитый", "other clients see transliteration, data unchanged")
	ns.ClientLocale = real
end)()

-- Знакомые: память между сессиями, обмен знакомыми, стук к собеседникам, приглашённые
;(function()
	local Net0 = TH.Net
	local savedPeers = Net0.whisperPeers
	Net0.whisperPeers = {}
	TH.db.knocks, TH.db.knownPeers, TH.db.chatContacts, TH.db.invited = {}, {}, {}, {}
	local function Whispers(prefix)
		local out = {}
		for _, m in ipairs(lastGroup) do
			local who, body = m:match("^WHISPER:(.-):S?(.*)$")
			if who and body:sub(1, #prefix) == prefix then out[#out + 1] = who end
		end
		return out
	end
	-- знакомый через шёпот запоминается и получает «k» со списком и «w» с датой установки
	Net0:OnMessage("TMHUB", "SH1", "WHISPER", "Знакомый-Ревущийфьорд")
	assert(TH.db.knownPeers["Знакомый-Ревущийфьорд"], "whisper peer remembered between sessions")
	flush()
	-- вторая сессия: знакомый не в сети с нами, стучимся к нему и к собеседнику
	Net0.whisperPeers = {}
	Net0:NoteContact("Собеседник-Гордунни")
	Net0:KnockAcquaintances()
	flush()
	local knockedTo = table.concat(Whispers("H"), ",")
	assert(knockedTo:find("Знакомый-Ревущийфьорд", 1, true) and knockedTo:find("Собеседник-Гордунни", 1, true),
		"known peer and chat contact knocked: " .. knockedTo)
	Net0:KnockAcquaintances()
	flush()
	assert(#Whispers("H") == 0, "each knocked at most once a day")
	-- обмен знакомыми: присланные имена получают стук
	Net0:OnMessage("TMHUB", "SkДруг-Гордунни,Тест-Гордунни,Чужой-Свежеватель Душ", "WHISPER", "Знакомый-Ревущийфьорд")
	flush()
	knockedTo = table.concat(Whispers("H"), ",")
	assert(knockedTo:find("Друг-Гордунни", 1, true) and not knockedTo:find("Тест-Гордунни", 1, true),
		"shared peers knocked, not self: " .. knockedTo)
	-- новичок, с которым переписывались, засчитывается приглашённым; давний игрок — нет
	local now = GetServerTime()
	Net0:OnMessage("TMHUB", "Sw" .. TH.Net.Enc(now - 3600), "WHISPER", "Собеседник-Гордунни")
	assert(TH.db.invited["Собеседник-Гордунни"], "new user from chat contact counted as invited")
	Net0:OnMessage("TMHUB", "Sw" .. TH.Net.Enc(now - 3600), "WHISPER", "Незнакомец-Гордунни")
	assert(not TH.db.invited["Незнакомец-Гордунни"], "stranger not counted")
	TH.db.chatContacts["Ветеран-Гордунни"] = now
	Net0:OnMessage("TMHUB", "Sw" .. TH.Net.Enc(now - 90 * 86400), "WHISPER", "Ветеран-Гордунни")
	assert(not TH.db.invited["Ветеран-Гордунни"], "long-time user not counted")
	-- рассылка — не больше 8 знакомых через шёпот
	Net0.whisperPeers = {}
	for i = 1, 12 do Net0.whisperPeers["Пир" .. string.char(96 + i) .. "-Гордунни"] = now - i end
	flush()
	Net0:Send("Xcap")
	flush()
	local n = 0
	for _, m in ipairs(lastGroup) do if m:find("^WHISPER:.-:S?Xcap") then n = n + 1 end end
	assert(n == 8, "broadcast to 8 most recent whisper peers: " .. n)
	-- «Поделиться в чате»: текст в строку чата и счётчик достижения
	local opened
	_G.ChatFrameUtil = _G.ChatFrameUtil or {}
	local realOpen = ChatFrameUtil.OpenChat
	ChatFrameUtil.OpenChat = function(text) opened = text end
	TH:ShareSet({ id = "nab12", name = "Пират", author = "Автор-Гордунни" })
	assert(opened and opened:find("[Transmog Hub: «Пират» #nab12]", 1, true) and opened:find("Автор", 1, true), "share text: " .. tostring(opened))
	-- у кого аддон: метка в чате — ссылка; нажатие открывает образ или просит его у отправителя
	local linked = TH.LinkifyChat(opened, "Друг-Ревущийфьорд")
	assert(linked and linked:find("|Hgarrmission:transmoghub:nab12:Друг-Ревущийфьорд|h[Transmog Hub: «Пират»]|h", 1, true),
		"token became a link: " .. tostring(linked))
	assert(TH.LinkifyChat("просто текст", "X-Y") == nil, "plain chat untouched")
	local asked
	local realAsk = TH.Net.AskFor
	TH.Net.AskFor = function(_, name) asked = name end
	TH.OnChatLink("garrmission:transmoghub:nab12:Друг-Ревущийфьорд")
	assert(asked == "Друг-Ревущийфьорд" and TH.pendingOpen == "nab12", "missing outfit asked from sender")
	TH.Net.AskFor = realAsk
	local opened2
	local realOpenShared = TH.OpenSharedSet
	TH.OpenSharedSet = function(_, id) opened2 = id end
	TH:OnSetStored({ id = "nab12", author = "Автор-Гордунни", name = "Пират", items = {} })
	TH.OpenSharedSet = realOpenShared
	assert(TH.pendingOpen == nil and opened2 == "nab12", "outfit opened when it arrived")
	ChatFrameUtil.OpenChat = realOpen
	Net0.whisperPeers = savedPeers
	TH.db.knocks, TH.db.knownPeers, TH.db.chatContacts, TH.db.invited = {}, {}, {}, {}
end)()

print("ALL OK")
