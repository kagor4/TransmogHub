local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Ссылка на образ в чате. Своих ссылок игра в чат не пропускает, поэтому в сообщение
-- уходит обычный текст «[Transmog Hub: «Название» #id]» (у кого нет аддона, видят его так),
-- а у кого аддон есть, фильтр чата превращает его в ссылку (тип garrmission, как у
-- WeakAuras: такой игра показывает и не трогает). Нажатие открывает образ; если его ещё
-- нет — аддон просит образы у отправителя и откроет, когда придёт.
---------------------------------------------------------------------------
local LINK_COLOR = "|cff4fc3f7"
local TOKEN = "%[Transmog Hub: «(.-)» #(n%x+)%]"

local function Secret(v)
	return issecretvalue and issecretvalue(v)
end

-- «Поделиться в чате»: готовый текст в строке чата, отправляет сам игрок
function TH:ShareSet(set)
	if not set then return end
	local name = self:SetName(set) or "?"
	-- у своего черновика ссылки нет: в сети его ещё не видели
	local id = set.serverId or (tostring(set.id or ""):match("^n%x+$") and set.id)
	local what = id and ("[Transmog Hub: «" .. name .. "» #" .. id .. "]") or ("«" .. name .. "» Transmog Hub")
	local text
	if self:IsMine(set) then
		text = string.format(L["Мой образ %s — аддон с образами игроков на CurseForge."], what)
	else
		local author = (set.author or "?"):gsub("%-.*", "")
		text = string.format(L["Образ %s от %s — аддон с образами игроков на CurseForge."], what, author)
	end
	if ChatFrameUtil and ChatFrameUtil.OpenChat then
		ChatFrameUtil.OpenChat(text)
	elseif ChatFrame_OpenChat then
		ChatFrame_OpenChat(text)
	end
	self:TrackCount("shared")
end

-- Текст сообщения с метками -> со ссылками (отправитель — чтобы попросить образ у него)
function TH.LinkifyChat(msg, sender)
	if type(msg) ~= "string" or Secret(msg) or not msg:find("[Transmog Hub: «", 1, true) then return nil end
	local who = (type(sender) == "string" and not Secret(sender)) and sender:gsub(":", "") or ""
	local out, n = msg:gsub(TOKEN, function(name, id)
		return LINK_COLOR .. "|Hgarrmission:transmoghub:" .. id .. ":" .. who .. "|h[Transmog Hub: «" .. name .. "»]|h|r"
	end)
	return n > 0 and out or nil
end

local function Filter(_, _, msg, sender, ...)
	local out = TH.LinkifyChat(msg, sender)
	if out then return false, out, sender, ... end
	return false
end

function TH:OpenSharedSet(id, sender)
	if self:GetSet(id) then
		self.UI:Open()
		self.UI:SetView("top")
		self.UI:Select(id)
		return true
	end
	self.pendingOpen = id
	if sender and sender ~= "" then
		self.Net:AskFor(sender)
		self:Print(string.format(L["Этого образа у вас ещё нет — попросили у %s. Окно откроется, когда образ придёт."], sender))
	else
		self:Print(L["Этого образа у вас ещё нет: он придёт по сети."])
	end
	return false
end

-- Нажатие на ссылку (garrmission с нашим словом — не миссия гарнизона: игра его не откроет)
function TH.OnChatLink(link)
	if type(link) ~= "string" then return end
	local id, sender = link:match("^garrmission:transmoghub:(n%x+):?(.*)$")
	if id then TH:OpenSharedSet(id, sender) end
end

-- Пришёл образ, который ждали по ссылке, — открыть
local onSetStored = TH.OnSetStored
function TH:OnSetStored(set)
	if onSetStored then onSetStored(self, set) end
	if self.pendingOpen and set and set.id == self.pendingOpen then
		self.pendingOpen = nil
		C_Timer.After(1, function()
			self:LoadFeed()
			self:OpenSharedSet(set.id)
		end)
	end
end

local EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER", "CHAT_MSG_PARTY",
	"CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_COMMUNITIES_CHANNEL",
}
if ChatFrame_AddMessageEventFilter then
	for _, e in ipairs(EVENTS) do ChatFrame_AddMessageEventFilter(e, Filter) end
end
if SetItemRef and hooksecurefunc then hooksecurefunc("SetItemRef", TH.OnChatLink) end
