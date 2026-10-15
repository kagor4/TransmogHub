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
GetLocale = function() return "ruRU" end; GetTime = os.clock; CLOSE = "Закрыть"
PlaySound = function() end; SOUNDKIT = { ACHIEVEMENT_MENU_OPEN = 1 }; UIFrameFadeOut = function() end
CreateAtlasMarkup = function() return "*" end; GameTooltip_Hide = function() end
GetFileIDFromPath = function(p) if p:find("Shirt") then return 123 end end
local ns = {}
local dir = arg[1]
for _, f in ipairs({ "Data/Bundled.lua", "Data/Live.lua", "Core.lua", "Appearance.lua", "Preview.lua", "UI.lua", "SaveDialog.lua", "Achievements.lua", "Wowhead.lua", "Minimap.lua" }) do
  assert(loadfile(dir .. "/" .. f))("TransmogHub", ns)
end
local TH = ns.TH
TH.scripts.OnEvent(TH, "ADDON_LOADED", "TransmogHub")
TH.scripts.OnEvent(TH, "PLAYER_LOGIN")

-- open UI, save a set through the dialog
SlashCmdList.TRANSMOGHUB("")
assert(TH.UI:IsShown())
TH:OpenSaveDialog()
local dlg = TransmogHubSaveDialog
dlg.name:SetText("Пиратский Капитан"); dlg.checks[1]:SetChecked(true)
dlg.publishBtn.scripts.OnClick()
local localId, set = next(TH.db.mySets)
assert(set and set.status == "pending", "set should be pending")
assert(set.items[3][2] == 334 and set.items[16][3] == 5900 and set.items[2] == nil, "capture conversion")
assert(#TH.db.outbox.publish == 1)
print("saved:", set.name, "tags:", TH:FormatTags(set.tags))

-- search with Cyrillic case-insensitive
assert(#TH:QuerySets("mine", { text = "ПИРАТ" }) == 1, "cyrillic search")
assert(#TH:QuerySets("mine", { text = "рыцарь" }) == 0)
assert(#TH:QuerySets("mine", { tags = { pirate = true } }) == 1)

-- test feed, vote
SlashCmdList.TRANSMOGHUB("test")
local top = TH:QuerySets("top", {})
assert(#top == 25)
TH:Vote(top[1].id, 4)
assert(TH.db.myVotes[top[1].id] == 4)
TH:Vote(localId, 5) -- must be refused
assert(TH.db.myVotes[localId] == nil)

-- simulate companion: server acks publish
local uid = TH.db.outbox.publish[1].uid
TransmogHub_Live = { schema = 1, generated = os.time(), sets = { { id = "s_1", name = "Серверный", author = "Х", tags = {}, items = { [1] = {111} }, rating = { avg = 4.5, n = 10 } } },
  user = { lastSync = os.time(), acked = { [uid] = true }, published = { [localId] = { id = "s_1", status = "published" } }, votes = { s_1 = 3 } } }
TH:LoadFeed(); TH:ApplyServerAcks()
assert(#TH.db.outbox.publish == 0 and set.status == "published" and set.serverId == "s_1")
assert(TH:IsMine(TH:GetSet("s_1")), "server copy recognized as mine")

-- UI walk-through
for _, v in ipairs({ "top", "trending", "new", "favorites", "mine" }) do TH.UI:SetView(v) end
TH.UI:SetView("top"); TH.UI:Select("s_1"); TH:ToggleFavorite("s_1"); TH.UI:SetView("favorites")
assert(#TH.UI.results == 1)
TH.UI:OpenRaceMenu(frame()); TH.UI:OpenTagMenu(frame()); TH.UI:Scroll(10)
TH:DeleteMySet(localId)
assert(#TH.db.outbox.unpublish == 1)
print("status:", TH.UI.status.text)
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
-- right-click menu on a feed set and on own set
TH.UI:SetView("top")
TH.UI:OpenSetMenu(frame(), "s_1")
wipe(TH.UI.filter.tags); TH.UI:Refresh()
TH.UI:OpenSetMenu(frame(), TH.UI.results[1].id)
local id2 = TH:CreateMySet("Второй", "", {"c_red","c_blue"}, { [1] = {111} }).id
TH.UI:OpenSetMenu(frame(), id2)
TH:Report("s_1"); assert(#TH.db.outbox.reports == 1)
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
print("cmd:", TransmogHubLinkDialog.command.text)
-- the in-game copy for the troll outfit; capture drops secondary==main and mainhand -1
local game = "/customset v1 194429,266724,266724,194719,8514,0,0,193875,219442,194692,285892,95854,231274,-1,6258,295720,8549"
local trollSet = { items = {
  [1]={194429}, [3]={266724}, [15]={194719}, [5]={8514}, [9]={193875}, [10]={219442},
  [6]={194692}, [7]={285892}, [8]={95854}, [16]={231274, nil, 6258}, [17]={295720, nil, 8549} } }
local ours = TH:BuildCustomSetCommand(trollSet)
print("ours:", ours)
assert(ours == game, "customset must match the game's own string")
-- tag reset button visibility
TH.UI.filter.tags.c_pink = true; TH.UI:Refresh(); assert(TH.UI.tagsReset:IsShown())
TH.UI.tagsReset.scripts.OnClick(); assert(not TH.UI.tagsReset:IsShown())
print("ALL OK")
