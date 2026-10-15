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
C_Item = { GetItemNameByID = function() return "X" end, GetItemIconByID = function() return 1 end, RequestLoadItemDataByID = function() end }
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
  root = setmetatable({}, { __index = function() return function(_, text, isSel, setSel) if setSel then setSel() end return root end end })
  gen(owner, root)
end }
SlashCmdList = {}
Constants = { Transmog = { MainHandTransmogIsIndividualWeapon = -1, NoTransmogID = 0 } }
GetLocale = function() return "ruRU" end; CLOSE = "Закрыть"
PlaySound = function() end; SOUNDKIT = { ACHIEVEMENT_MENU_OPEN = 1 }; UIFrameFadeOut = function() end
CreateAtlasMarkup = function() return "*" end; GameTooltip_Hide = function() end
GetFileIDFromPath = function(p) if p:find("Shirt") then return 123 end end
-- Имитация канала и сообщений аддонов
local clock = 0
GetTime = function() return clock end
local serverTime = 1760000000
GetServerTime = function() return serverTime end
NUM_CHAT_WINDOWS = 1; ChatFrame1 = frame()
local joined = false
JoinTemporaryChannel = function(name) joined = (name == "TransmogHubNet") end
GetChannelName = function(name) if joined and name == "TransmogHubNet" then return 5, name end return 0 end
local sent = {}
C_ChatInfo = {
  RegisterAddonMessagePrefix = function() return true end,
  SendAddonMessage = function(prefix, msg, chatType, target)
    assert(prefix == "TMHUB" and chatType == "CHANNEL" and target == "5", "send args")
    assert(#msg <= 255, "message too long: " .. #msg)
    sent[#sent + 1] = msg
    return 0
  end,
  InChatMessagingLockdown = function() return false end,
  -- на обычных серверах Midnight обычный чат аддонам запрещён — сообщения аддонов это не должно останавливать
  AreOutgoingAddonChatMessagesRestricted = function() return true end,
}
Enum.SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11 }
local tickers = {}
C_Timer.NewTicker = function(_, fn) tickers[#tickers + 1] = fn end
-- прокрутить очередь отправки и вернуть отправленное
local function flush()
  for _ = 1, 2000 do clock = clock + 1; tickers[1]() end
  local out = sent; sent = {}; return out
end
local ns = {}
local dir = arg[1]
for _, f in ipairs({ "Data/Bundled.lua", "Core.lua", "Network.lua", "Appearance.lua", "Preview.lua", "UI.lua", "SaveDialog.lua", "Achievements.lua", "Wowhead.lua", "Minimap.lua" }) do
  assert(loadfile(dir .. "/" .. f))("TransmogHub", ns)
end
local TH = ns.TH
local Net = TH.Net
TH.scripts.OnEvent(TH, "ADDON_LOADED", "TransmogHub")
TH.scripts.OnEvent(TH, "PLAYER_LOGIN")
assert(Net:IsConnected(), "joined hidden channel")
local startup = flush()
assert(startup[1] == "SH1", "hello sent: " .. tostring(startup[1]))
assert(startup[2] and startup[2]:match("^SQ%w+\t0$"), "initial sync request")

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
dlg.name:SetText("Пиратский Капитан"); dlg.desc:SetText(string.rep("Очень длинное описание. ", 10)); dlg.checks[1]:SetChecked(true)
dlg.publishBtn.scripts.OnClick()
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
assert(#TH:QuerySets("mine", { tags = { pirate = true } }) == 1)

-- a peer publishes a set; it appears in the feed
local peerSet = { id = "npeer1", author = PEER, name = "Чужой набор", desc = "", race = 8, sex = 0, class = "SHAMAN",
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
TH:Vote(TH:QuerySets("top", {})[1].id ~= set.serverId and TH:QuerySets("top", {})[1].id or "x", 3)
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
TH.UI:OpenRaceMenu(frame()); TH.UI:OpenTagMenu(frame()); TH.UI:Scroll(10)
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
local game = "/customset v1 194429,266724,266724,194719,8514,0,0,193875,219442,194692,285892,95854,231274,-1,6258,295720,8549"
local trollSet = { items = {
  [1]={194429}, [3]={266724}, [15]={194719}, [5]={8514}, [9]={193875}, [10]={219442},
  [6]={194692}, [7]={285892}, [8]={95854}, [16]={231274, nil, 6258}, [17]={295720, nil, 8549} } }
assert(TH:BuildCustomSetCommand(trollSet) == game, "customset must match the game's own string")
-- tag reset button visibility
TH.UI.filter.tags.c_pink = true; TH.UI:Refresh(); assert(TH.UI.tagsReset:IsShown())
TH.UI.tagsReset.scripts.OnClick(); assert(not TH.UI.tagsReset:IsShown())
-- unpublish own set broadcasts D
TH:DeleteMySet(localId)
local del = flush()
assert(del[1] == "SD" .. set.serverId, "unpublish broadcast")
-- migration from companion-era saved variables
TransmogHubDB = { outbox = { publish = {} }, mySets = { ["local:x"] = { id = "local:x", status = "pending", items = {} } } }
TH.scripts.OnEvent(TH, "ADDON_LOADED", "TransmogHub")
assert(TH.db.outbox == nil and TH.db.mySets["local:x"].status == "draft", "migration")
print("ALL OK")
