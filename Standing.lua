local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Репутация у Стражей подиума (так в лоре зовутся модераторы аддона).
--  * На полпути к позорному достижению — мягкое предупреждение.
--  * Позорные достижения снимаются, когда поведение исправилось.
--  * Три позорных одновременно или решение модераторов (Blocklist.banned) —
--    изгнание в «Тканевые пустоши»: на этом персонаже аддон закрыт, кроме
--    профиля и достижений (там видно, что исправить).
---------------------------------------------------------------------------
local FALSE_REPORT_WINDOW = 90 * 86400
local EXILE_SHAME = 3            -- столько позорных одновременно — изгнание
local WARN_EVERY = 3 * 86400     -- одно и то же предупреждение — не чаще раза в 3 дня

local function Blocklist()
	return TransmogHub_Blocklist or {}
end

-- Изгнан ли персонаж решением модераторов
function TH:IsBanned(name)
	if name == nil then return false end
	local banned = Blocklist().banned
	if banned and banned[name] ~= nil then return true end
	-- бан за рекламу, полученный от модератора напрямую (до обновления чёрного списка)
	local mod = self.db and self.db.net and self.db.net.modBlocks.banned
	return mod ~= nil and mod[name] ~= nil
end

-- Ваши ложные жалобы за 90 дней. Список ложных — без имён (только номера
-- образов), а на что жаловались вы, знает только ваш аддон.
function TH:CountFalseReports()
	local dismissed = Blocklist().dismissed or {}
	local mine, falseReports = self.db.myReports, self.db.falseReports
	for setId, t in pairs(mine) do
		if dismissed[setId] and not falseReports[setId] then falseReports[setId] = t end
	end
	local now, n = self.Net.Now(), 0
	for setId, t in pairs(falseReports) do
		if now - t < FALSE_REPORT_WINDOW then n = n + 1 else falseReports[setId] = nil end
	end
	return n
end

function TH:GetActiveShame()
	local list = {}
	local washed = self.db.penalty and self.db.penalty.washed
	for _, a in ipairs(self.ACHIEVEMENTS) do
		-- «занижение» остаётся навсегда, но после отмывания к изгнанию не считается
		if a.shame and self.db.achievements[a.id] and not (a.sticky and washed) then list[#list + 1] = a end
	end
	return list
end

---------------------------------------------------------------------------
-- Наказание за занижение оценок. Получили «Тролль под мостом» или «Повелитель
-- единиц» — все голоса аккаунта снимаются (у всех в сети), но отметка «уже оценил»
-- остаётся: твинком те же образы не оценить. На 14 дней нельзя оценивать и
-- жаловаться, остальное работает. Потом ограничения снимаются («отмылся»),
-- позорное достижение остаётся. Второй раз — навсегда.
---------------------------------------------------------------------------
local PENALTY_DAYS = 14

function TH:GetVotePenalty()
	local p = self.db and self.db.penalty
	if not p then return nil end
	if p.permanent then return p end
	if p.untilT and self.Net.Now() < p.untilT then return p end
	return nil
end

-- nil или причина, почему нельзя оценивать и жаловаться
function TH:VoteRestrictionText()
	local p = self:GetVotePenalty()
	if not p then return nil end
	if p.permanent then
		return L["Оценки и жалобы закрыты навсегда: повторное занижение оценок."]
	end
	return L["Оценки и жалобы закрыты до "] .. date("%d.%m", p.untilT) .. L[" за занижение оценок. Потом всё вернётся."]
end

-- Снять голоса этого персонажа (каждый персонаж снимает свои — при входе)
function TH:RetractMyVotes()
	local me, n = self.Net.Me(), 0
	for setId, list in pairs(self.db.net.votes) do
		if list[me] then
			self.Net:SendVote(setId, 0)
			n = n + 1
		end
	end
	if n > 0 then self:LoadFeed() end
	return n
end

function TH:CheckVotePenalty()
	local p = self.db.penalty
	local now = self.Net.Now()
	local trolling = false
	for _, id in ipairs({ "shame_troll", "shame_troll_100" }) do
		local a = self.ACHIEVEMENT_BY_ID[id]
		if a and self:IsAchievementMet(a) then trolling = true end
	end
	if trolling and not self:GetVotePenalty() then
		local count = (p and p.count or 0) + 1
		p = { count = count, since = now, permanent = count >= 2, untilT = count < 2 and (now + PENALTY_DAYS * 86400) or nil, retracted = {} }
		self.db.penalty = p
		self:Notify(p.permanent and L["Повторное занижение оценок: ваши оценки сняты, оценивать и жаловаться больше нельзя."]
			or string.format(L["Занижение оценок: ваши оценки сняты, оценивать и жаловаться нельзя %d дней."], PENALTY_DAYS))
	end
	p = self.db.penalty
	if not p then return end
	-- каждый персонаж аккаунта снимает свои голоса, пока наказание не отбыто
	if self:GetVotePenalty() and not p.retracted[self.Net.Me()] then
		p.retracted[self.Net.Me()] = true
		self:RetractMyVotes()
	end
	if not p.permanent and not p.washed and p.untilT and now >= p.untilT then
		p.washed = now
		self:Notify(L["Ограничения за занижение оценок сняты: снова можно оценивать и жаловаться. Повторное занижение — навсегда."])
	end
end

-- Модератор снял наказание (ошибка): всё возвращается, счётчик повторов сбрасывается
function TH:LiftVotePenalty()
	if not self.db.penalty then return end
	self.db.penalty = nil
	self:Notify(L["Модератор снял ограничения за занижение оценок."])
	self:NotifyChanged()
end

---------------------------------------------------------------------------
-- Запрещённые названия. Что это — решает модератор:
--  * шутка («e») — образ скрыт, Стражи просят его переименовать, наказания нет;
--    вторая такая шутка уже наказывается, как оскорбление;
--  * оскорбление («o») — 14 дней нельзя публиковать образы, второй раз — навсегда
--    (смотреть, сохранять и оценивать можно);
--  * реклама («b») — бан сразу (изгнание, на всех персонажах аккаунта).
-- Решение приходит напрямую от модератора или с обновлением аддона (Blocklist.names).
---------------------------------------------------------------------------
local NAME_BAN_DAYS = 14

-- "e", "o" или nil
function TH:GetNameViolation(setId)
	if not setId then return nil end
	local mod = self.db.net.modBlocks.names
	local list = Blocklist().names
	return (mod and mod[setId]) or (list and list[setId]) or nil
end

-- Автора уже просили переименовать образ: id того образа (пометка из чёрного списка
-- или от модератора напрямую), иначе nil
function TH:GetRenameWarning(name)
	if not name then return nil end
	local list = Blocklist().warned
	local mod = self.db.net.modBlocks.warned
	return (list and list[name]) or (mod and mod[name]) or nil
end

-- Это уже повторная шутка аккаунта (пометка стоит за другим образом)
local function WarnedBefore(self, setId)
	for name in pairs(self.db.myChars) do
		local first = self:GetRenameWarning(name)
		if first and first ~= setId then return true end
	end
	return false
end

local function Strikes(self)
	local s = self.db.nameStrikes
	if not s then
		s = { seen = {}, jokes = 0, count = 0 }
		self.db.nameStrikes = s
	end
	return s
end

function TH:GetPublishRestriction()
	local s = self.db and self.db.nameStrikes
	if not s or (s.count or 0) == 0 then return nil end
	if s.permanent then return s end
	if s.untilT and self.Net.Now() < s.untilT then return s end
	return nil
end

-- nil или причина, почему нельзя публиковать
function TH:PublishRestrictionText()
	local s = self:GetPublishRestriction()
	if not s then return nil end
	if s.permanent then return L["Публикация образов закрыта навсегда: повторное нарушение с названием образа."] end
	return L["Публиковать образы можно будет с "] .. date("%d.%m", s.untilT) .. L[": Стражи подиума наказали за название образа."]
end

local function Quote(mine)
	return "«" .. (mine.name or "?") .. "»"
end

-- Письмо Стражей: шуточное название — переименуйте
local function RenameLetter(self, localId, mine)
	self:ShowStandingWarning(L["Письмо Стражей подиума"],
		L["Стражи подиума остановили ваш образ "] .. Quote(mine) .. L[" у ворот Штормграда: название рассмешило стражу, "]
		.. L["но не всех прохожих.\n\nОбраз скрыт, пока вы его не переименуете, — потом он снова выйдет на подиум "]
		.. L["(оценки старого образа не сохранятся). На этот раз обойдёмся без наказания, но Стражи занесли ваше имя "]
		.. L["в свою книгу.\n\n|cffff9020Если в названии снова окажется брань или подобная шутка, Стражи будут вынуждены "]
		.. L["принять меры: публикация образов закроется на "] .. NAME_BAN_DAYS .. L[" дней.|r"],
		L["Переименовать"], function() self:AskRename(localId) end)
end

local function PenaltyLetter(self, mine, joke)
	local s = self.db.nameStrikes
	local reason = joke
		and (L["Стражи подиума уже просили вас не шутить с названиями, а образ "] .. Quote(mine) .. L[" снова остановлен у ворот."])
		or (L["Стражи подиума сняли ваш образ "] .. Quote(mine) .. L[": такие слова не звучат даже в тавернах Пиратской бухты."])
	local verdict = s.permanent
		and L["\n\nЭто уже второе нарушение: публиковать образы вы больше не можете. Смотреть, сохранять и оценивать — можно."]
		or ("\n\n" .. NAME_BAN_DAYS .. L[" дней (до "] .. date("%d.%m", s.untilT) .. L[") вы не можете публиковать образы. "]
			.. L["Смотреть, сохранять и оценивать — можно. Повторное нарушение — запрет на публикацию навсегда."])
	self:ShowStandingWarning(L["Решение Стражей подиума"], reason .. verdict)
end

-- Проверить свои образы: не пришло ли решение модератора по названию.
-- Вызывается при входе и когда решение приходит.
function TH:CheckNameViolations(remind)
	if not self.db then return end
	local now = self.Net.Now()
	local letter, rename
	for localId, mine in pairs(self.db.mySets) do
		local id = mine.serverId
		local kind = id and self:GetNameViolation(id)
		if kind then
			local s = Strikes(self)
			-- одно решение по образу считается один раз; «шутку» модератор может
			-- пересмотреть на «оскорбление» — тогда наказание всё же будет
			local upgrade = s.seen[id] == "e" and kind == "o"
			if not s.seen[id] or upgrade then
				s.seen[id] = kind
				if kind == "e" then
					s.jokes = s.jokes + 1
					-- пометка Стражей: аддон могли переустановить, но повтор есть повтор
					if s.jokes < 2 and WarnedBefore(self, id) then s.jokes = 2 end
				end
				if kind == "o" or s.jokes >= 2 then
					s.count = s.count + 1
					s.since = now
					s.washed = nil
					if s.count >= 2 then
						s.permanent, s.untilT = true, nil
					else
						s.untilT = now + NAME_BAN_DAYS * 86400
					end
					letter = { mine, kind == "e" }
				end
				-- шуточное название можно исправить (опубликуется, когда снимут запрет)
				if upgrade then mine.renameRequired = nil end
				if kind == "e" then
					mine.renameRequired = true
					rename = rename or { localId, mine, fresh = not letter }
				end
			elseif remind and mine.renameRequired then
				rename = rename or { localId, mine }
			end
		end
	end
	local s = self.db.nameStrikes
	if s and not s.permanent and s.untilT and not s.washed and now >= s.untilT then
		s.washed = now
		self:Notify(L["Запрет на публикацию снят: снова можно публиковать образы. Повторное нарушение — навсегда."])
	end
	if letter then
		PenaltyLetter(self, letter[1], letter[2])
	elseif rename then
		RenameLetter(self, rename[1], rename[2])
	end
	if letter or rename then self:NotifyChanged() end
end

function TH:AskRename(localId)
	local mine = self.db.mySets[localId]
	if not mine then return end
	StaticPopup_Show("TRANSMOGHUB_RENAME_SET", mine.name, nil, localId)
end

-- Новое название вместо шуточного: старый образ снимается, новый публикуется
-- (если публикация не закрыта). Возвращает текст ошибки или nil.
function TH:RenameViolatedSet(localId, name)
	local mine = self.db.mySets[localId]
	if not mine then return L["Образ не найден."] end
	name = self.FormatSetName(strtrim(name or ""))
	if name == mine.name then return L["Придумайте другое название."] end
	local err = self:ValidateSetText(name, mine.desc)
	if err then return err end
	if mine.serverId then
		self.Net:Unpublish(mine.serverId)
		self.db.favorites[mine.serverId] = nil
	end
	mine.serverId = nil
	mine.status = "draft"
	mine.renameRequired = nil
	mine.name = name
	local restricted = self:PublishRestrictionText()
	if restricted then
		self:Notify(L["Образ переименован в «"] .. name .. L["» и сохранён черновиком. "] .. restricted)
		self:LoadFeed()
		self:NotifyChanged()
	else
		self:Publish(localId)
		self:Notify(L["Образ переименован в «"] .. name .. L["» и снова на подиуме. Спасибо!"])
	end
end

-- Амнистия от модератора (ошибка или проверка наказаний): снимается всё на аккаунте —
-- запрет на публикацию и счёт нарушений с названиями, просьбы переименовать, наказание
-- за занижение оценок, «вечные» позорные достижения и ложные жалобы
function TH:Amnesty()
	local mod = self.db.net.modBlocks
	self.db.nameStrikes = nil
	self.db.penalty = nil
	for name in pairs(self.db.myChars) do
		for _, key in ipairs({ "banned", "authors", "players", "warned" }) do
			if mod[key] then mod[key][name] = nil end
		end
	end
	for _, mine in pairs(self.db.mySets) do
		mine.renameRequired = nil
		if mine.serverId then
			mod.sets[mine.serverId] = nil
			if mod.names then mod.names[mine.serverId] = nil end
		end
	end
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if a.shame then self.db.achievements[a.id] = nil end
	end
	wipe(self.db.falseReports)
	self:Notify(L["Стражи подиума сняли с вас все ограничения и наказания. Чистый лист!"])
	self:LoadFeed()
	self:NotifyChanged()
end

-- Бан за рекламу пришёл напрямую от модератора
function TH:OnAdBan()
	self:ShowStandingWarning(L["Изгнание в Тканевые пустоши"],
		L["Стражи подиума поймали вас на рекламе: Transmog Hub — подиум для образов, а не доска объявлений у аукциона.\n\n"]
		.. L["Двери Transmog Hub для вас закрыты. Если это ошибка — оспорьте решение на экране изгнания."])
	if self.UI and self.UI.Refresh and self.UI.frame then self.UI:Refresh() end
end

-- Бан за рекламу закрывает аддон на всех персонажах аккаунта
function TH:IsAccountBanned()
	for name in pairs(self.db.myChars) do
		if self:IsBanned(name) then return true end
	end
	return false
end

function TH:IsExiled()
	if not self.db then return false end
	return self:IsBanned(self.Net.Me()) or self:IsAccountBanned() or #self:GetActiveShame() >= EXILE_SHAME
end

function TH:ExileNotice()
	self:Print(L["|cffff6060Стражи подиума закрыли для этого персонажа Transmog Hub.|r Что исправить — в своём профиле и на вкладке «Достижения»."])
end

---------------------------------------------------------------------------
-- Предупреждения
---------------------------------------------------------------------------
-- Ваши оценки (всех ваших персонажей) за 90 дней: всего и единиц.
-- Старые не считаются — позорное за единицы со временем снимается само.
-- Обходит все голоса сети — дорого, поэтому один раз на пересчёт ленты
local recentCache
function TH:CountRecentVotes()
	local stamp = (self.feedGen or 0) .. ":" .. (self.Net.voteCount or 0)
	if recentCache and recentCache.stamp == stamp then return recentCache.votes, recentCache.ones end
	local votes, ones = self:CountRecentVotesRaw()
	recentCache = { stamp = stamp, votes = votes, ones = ones }
	return votes, ones
end

function TH:CountRecentVotesRaw()
	local now, votes, ones = self.Net.Now(), 0, 0
	for _, list in pairs(self.db.net.votes) do
		for voter, v in pairs(list) do
			if self.db.myChars[voter] and now - v[2] < FALSE_REPORT_WINDOW then
				votes = votes + 1
				if v[1] == 1 then ones = ones + 1 end
			end
		end
	end
	return votes, ones
end

local function VoteShare(self)
	return self:CountRecentVotes()
end

-- Наиболее важное предупреждение сейчас: ключ, заголовок, текст
function TH:GetStandingWarning()
	local shame = #self:GetActiveShame()
	if self:IsBanned(self.Net.Me()) then return nil end -- изгнанному показываем экран изгнания
	if shame >= EXILE_SHAME then return nil end
	if shame == EXILE_SHAME - 1 then
		return "shame2", L["Последнее предупреждение"],
			L["Стражи подиума хмурятся всё сильнее. Ещё одно позорное достижение, и вас отправят в Тканевые пустоши: на этом персонаже Transmog Hub закроется, пока вы не исправитесь.\n\nПозорные достижения снимаются сами, когда поведение исправилось."]
	end
	if shame == 1 then
		return "shame1", L["Ваше имя в книге Стражей"],
			L["Стражи подиума записали ваше имя в свою книгу. Позорное достижение снимется, когда исправитесь.\n\nНо если таких наберётся три, Стражи закроют для этого персонажа двери Transmog Hub."]
	end
	local votes, ones = VoteShare(self)
	if votes >= 10 and ones / votes >= 0.7 and not self.db.achievements.shame_troll then
		return "troll", L["Шёпот Стражей подиума"],
			L["Вы ставите единицы почти всем подряд. Тролли под мостом тоже так начинали.\n\nОценивайте честно: если так пойдёт и дальше, к вашему имени приклеится позорное достижение."]
	end
	if self:CountFalseReports() == 2 and not self.db.achievements.shame_cry then
		return "cry", L["Шёпот Стражей подиума"],
			L["Стражи дважды бежали на ваш крик «Мурлок!», а мурлоков не было: две ваши жалобы признаны ложными.\n\nЖалуйтесь только на мат, оскорбления и рекламу. Третья ложная жалоба — и вас запишут в книгу ложных глашатаев."]
	end
	for _, mine in pairs(self.db.mySets) do
		local id = mine.serverId
		if id and self:GetReportStats(id) >= 10 and not self:IsBlocked({ id = id, author = mine.author }) then
			return "reported:" .. id, L["На ваш образ жалуются"],
				L["Игроки жалуются на ваш образ «"] .. (mine.name or "?") .. L["». Загляните в правила: может, в названии или описании есть что-то лишнее?\n\nЕсли модератор заблокирует образ, вы получите позорное достижение."]
		end
	end
end

local warnFrame

local function BuildWarning()
	warnFrame = CreateFrame("Frame", "TransmogHubWarning", UIParent, "BackdropTemplate")
	warnFrame:SetSize(420, 200)
	warnFrame:SetPoint("CENTER", 0, 120)
	warnFrame:SetFrameStrata("DIALOG")
	warnFrame:SetToplevel(true)
	warnFrame:EnableMouse(true)
	warnFrame:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	warnFrame:SetBackdropColor(0.08, 0.04, 0.02, 0.95)
	warnFrame:SetBackdropBorderColor(1, 0.5, 0.2)
	tinsert(UISpecialFrames, warnFrame:GetName())

	warnFrame.icon = warnFrame:CreateTexture(nil, "ARTWORK")
	warnFrame.icon:SetSize(48, 48)
	warnFrame.icon:SetPoint("TOPLEFT", 14, -14)
	warnFrame.icon:SetTexture("Interface\\Icons\\Spell_Holy_SealOfSacrifice")

	warnFrame.title = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	warnFrame.title:SetPoint("TOPLEFT", warnFrame.icon, "TOPRIGHT", 12, -2)
	warnFrame.who = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	warnFrame.who:SetPoint("TOPLEFT", warnFrame.title, "BOTTOMLEFT", 0, -3)
	warnFrame.who:SetText(L["Стражи подиума — модераторы Transmog Hub"])

	warnFrame.text = warnFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	warnFrame.text:SetPoint("TOPLEFT", warnFrame.icon, "BOTTOMLEFT", 0, -10)
	warnFrame.text:SetWidth(390)
	warnFrame.text:SetJustifyH("LEFT")

	local ok = CreateFrame("Button", nil, warnFrame, "UIPanelButtonTemplate")
	TH.PadButton(ok)
	ok:SetSize(160, 22)
	ok:SetPoint("BOTTOMRIGHT", -12, 12)
	ok:SetText(L["Понял, исправлюсь"])
	ok:SetScript("OnClick", function()
		warnFrame:Hide()
		local onOk = warnFrame.onOk
		warnFrame.onOk = nil
		if onOk then onOk() end
	end)
	warnFrame.ok = ok

	local rules = CreateFrame("Button", nil, warnFrame, "UIPanelButtonTemplate")
	TH.PadButton(rules)
	rules:SetSize(100, 22)
	rules:SetPoint("RIGHT", ok, "LEFT", -6, 0)
	rules:SetText(L["Правила"])
	rules:SetScript("OnClick", function()
		warnFrame:Hide()
		TH:OpenHelp(8) -- «Стражи подиума»
	end)
end

-- okText/onOk — своя главная кнопка (например, «Переименовать»)
function TH:ShowStandingWarning(title, text, okText, onOk)
	if not warnFrame then BuildWarning() end
	warnFrame.onOk = onOk
	warnFrame.ok:SetText(okText or L["Понял, исправлюсь"])
	warnFrame.title:SetText(title)
	warnFrame.text:SetText(text)
	warnFrame:SetHeight((warnFrame.text:GetStringHeight() or 60) + 120)
	warnFrame:SetScale(self.db.scale or 1)
	warnFrame:Show()
	self:SkinNow(warnFrame)
end

-- Вызывается после проверки достижений
function TH:CheckStanding()
	if not self.db then return end
	local key, title, text = self:GetStandingWarning()
	if not key then return end
	local now = self.Net.Now()
	if self.db.warned[key] and now - self.db.warned[key] < WARN_EVERY then return end
	self.db.warned[key] = now
	self:ShowStandingWarning(title, text)
end

---------------------------------------------------------------------------
-- Экран изгнания (вместо списка образов)
---------------------------------------------------------------------------
function TH:BuildExilePanel(p)
	p.icon = p:CreateTexture(nil, "ARTWORK")
	p.icon:SetSize(64, 64)
	p.icon:SetPoint("TOP", 0, -50)
	p.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Charm")

	p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	p.title:SetPoint("TOP", p.icon, "BOTTOM", 0, -14)
	p.title:SetText(L["Изгнание в Тканевые пустоши"])

	p.text = p:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	p.text:SetPoint("TOP", p.title, "BOTTOM", 0, -16)
	p.text:SetWidth(620)
	p.text:SetJustifyH("CENTER")
	p.text:SetSpacing(3)

	p.profile = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.profile)
	p.profile:SetSize(160, 24)
	p.profile:SetPoint("BOTTOM", -84, 40)
	p.profile:SetText(L["Мой профиль"])
	p.profile:SetScript("OnClick", function() TH.UI:OpenProfile(TH.Net.Me()) end)

	p.ach = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.ach)
	p.ach:SetSize(160, 24)
	p.ach:SetPoint("BOTTOM", 84, 40)
	p.ach:SetText(L["Достижения"])
	p.ach:SetScript("OnClick", function() TH.UI:SetView("achievements") end)

	p.appeal = CreateFrame("Button", nil, p)
	p.appeal:SetNormalFontObject("GameFontNormalSmall")
	p.appeal:SetHighlightFontObject("GameFontHighlightSmall")
	p.appeal:SetText(L["Считаете решение ошибкой? Оспорить"])
	p.appeal:SetSize(260, 20)
	p.appeal:SetPoint("BOTTOM", 0, 14)
	p.appeal:SetScript("OnClick", function() TH:OpenAppeal() end)
end

function TH:RefreshExilePanel(p)
	local lines = {}
	if self:IsBanned(self.Net.Me()) or self:IsAccountBanned() then
		if self:IsBanned(self.Net.Me()) then
			lines[#lines + 1] = L["Стражи подиума решили закрыть для этого персонажа двери Transmog Hub."]
		else
			lines[#lines + 1] = L["Стражи подиума закрыли двери Transmog Hub для другого вашего персонажа —"]
			lines[#lines + 1] = L["а значит, и для всех персонажей этого аккаунта."]
		end
		lines[#lines + 1] = L["Образы, оценки и жалобы с него больше не принимаются у других игроков."]
		lines[#lines + 1] = ""
		lines[#lines + 1] = L["|cff999999Если это ошибка — нажмите «Оспорить» внизу.|r"]
	else
		lines[#lines + 1] = L["Ткачи судеб отвернулись от вас: на этом персонаже Transmog Hub закрыт,"]
		lines[#lines + 1] = L["пока на вас висят три позорных достижения:"]
		lines[#lines + 1] = ""
		for _, a in ipairs(self:GetActiveShame()) do
			lines[#lines + 1] = "|cffff6060" .. a.name .. "|r — " .. a.desc
		end
		lines[#lines + 1] = ""
		lines[#lines + 1] = L["Позорные достижения снимаются сами: оценки и жалобы старше 90 дней"]
		lines[#lines + 1] = L["не считаются, а заблокированный образ можно удалить в своём профиле."]
		lines[#lines + 1] = L["Снимите хотя бы одно — и двери откроются."]
	end
	p.text:SetText(table.concat(lines, "\n"))
end

---------------------------------------------------------------------------
-- Оспорить решение: обращение уходит скрыто, у модератора попадает в журнал,
-- коннектор выгружает его, а ответ приходит решением в обновлении аддона.
---------------------------------------------------------------------------
local APPEAL_COOLDOWN = 7 * 86400
local APPEAL_LETTERS = 140
local appealDlg

-- Что именно оспаривается — подставляется в обращение для модератора
function TH:GetAppealContext()
	local me = self.Net.Me()
	if self:IsBanned(me) then
		local reason = (Blocklist().banned or {})[me]
		return L["бан: "] .. (reason and tostring(reason) or L["реклама"])
	end
	for name in pairs(self.db.myChars) do
		if self:IsBanned(name) then return L["бан персонажа аккаунта "] .. name end
	end
	if self:GetPublishRestriction() then return L["запрет на публикацию за название"] end
	local names = {}
	for _, a in ipairs(self:GetActiveShame()) do names[#names + 1] = a.name end
	if #names > 0 then return L["позорные: "] .. table.concat(names, ", ") end
	return L["другое"]
end

function TH:SendAppeal(text)
	text = strtrim(text or "")
	if #text:gsub("[\128-\191]", "") < 15 then return L["Опишите подробнее, что не так (хотя бы пару предложений)."] end
	local now = self.Net.Now()
	if now - (self.db.myAppeal or 0) < APPEAL_COOLDOWN then
		local days = math.ceil((APPEAL_COOLDOWN - (now - self.db.myAppeal)) / 86400)
		return L["Обращение уже отправлено. Следующее — через "] .. days .. L[" дн."]
	end
	self.db.myAppeal = now
	self.Net:SendAppeal("[" .. self:GetAppealContext() .. "] " .. text)
	self:Thanks(L["Обращение отправлено Стражам подиума. Если решение изменят, это придёт с обновлением аддона."])
end

local function SendFromDialog()
	local err = TH:SendAppeal(appealDlg.edit:GetText())
	if err then
		appealDlg.error:SetText(err)
	else
		appealDlg:Hide()
	end
end

function TH:OpenAppeal()
	local d = appealDlg
	if not d then
		d = CreateFrame("Frame", "TransmogHubAppeal", UIParent, "BasicFrameTemplateWithInset")
		appealDlg = d
		d:SetSize(440, 270)
		d:SetPoint("CENTER", 0, 80)
		d:SetFrameStrata("FULLSCREEN_DIALOG")
		d:SetToplevel(true)
		d:EnableMouse(true)
		tinsert(UISpecialFrames, d:GetName())

		local title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText(L["Оспорить решение Стражей подиума"])

		d.info = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		d.info:SetPoint("TOPLEFT", 16, -34)
		d.info:SetWidth(408)
		d.info:SetJustifyH("LEFT")

		local box = CreateFrame("Frame", nil, d, "BackdropTemplate")
		box:SetPoint("TOPLEFT", 14, -104)
		box:SetSize(412, 90)
		box:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		box:SetBackdropColor(0, 0, 0, 0.6)
		d.edit = CreateFrame("EditBox", nil, box)
		d.edit:SetPoint("TOPLEFT", 8, -8)
		d.edit:SetPoint("BOTTOMRIGHT", -8, 8)
		d.edit:SetMultiLine(true)
		d.edit:SetAutoFocus(false)
		d.edit:SetFontObject("GameFontHighlight")
		d.edit:SetMaxLetters(APPEAL_LETTERS)
		d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
		d.edit:HookScript("OnTextChanged", function(e)
			d.error:SetText("")
			d.count:SetText(string.format("%d / %d", e.GetNumLetters and e:GetNumLetters() or #(e:GetText() or ""), APPEAL_LETTERS))
		end)
		box:EnableMouse(true)
		box:SetScript("OnMouseDown", function() d.edit:SetFocus() end)

		d.count = d:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		d.count:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -2, -3)
		d.error = d:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
		d.error:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -3)
		d.error:SetWidth(320)
		d.error:SetJustifyH("LEFT")

		local send = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
		TH.PadButton(send)
		send:SetSize(140, 24)
		send:SetPoint("BOTTOMLEFT", 14, 12)
		send:SetText(L["Отправить"])
		send:SetScript("OnClick", SendFromDialog)
		if TH.StylePrimaryButton then TH.StylePrimaryButton(send) end
		d.sendBtn = send

		local cancel = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
		TH.PadButton(cancel)
		cancel:SetSize(100, 24)
		cancel:SetPoint("BOTTOMRIGHT", -14, 12)
		cancel:SetText(CANCEL)
		cancel:SetScript("OnClick", function() d:Hide() end)
	end
	d.info:SetText(L["Оспаривается: |cffffd100"] .. self:GetAppealContext() .. "|r\n\n"
		.. L["Напишите, почему решение кажется вам ошибочным. Обращение прочитает модератор; "]
		.. L["если решение изменят, это придёт с обновлением аддона. Одно обращение — раз в неделю."])
	d.edit:SetText("")
	d.error:SetText("")
	d.count:SetText("0 / " .. APPEAL_LETTERS)
	d:SetScale(self.db.scale or 1)
	d:Show()
	TH:SkinNow(d)
	d.edit:SetFocus()
end
