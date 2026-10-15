local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Редкость — как у предметов: 0 серое … 5 легендарное
---------------------------------------------------------------------------
TH.RARITY = {
	[0] = { name = "Низкое", points = 5 },
	[1] = { name = "Обычное", points = 10 },
	[2] = { name = "Необычное", points = 15 },
	[3] = { name = "Редкое", points = 25 },
	[4] = { name = "Эпическое", points = 50 },
	[5] = { name = "Легендарное", points = 100 },
}

local FALLBACK_COLORS = {
	[0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00",
	[3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000",
}

function TH:RarityHex(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	return c and c.hex or FALLBACK_COLORS[q]
end

function TH:RarityRGB(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

---------------------------------------------------------------------------
-- Список достижений
-- stat — откуда брать прогресс (см. GetAchievementStat)
-- rank = true — «место в рейтинге»: выполнено, если место <= goal
---------------------------------------------------------------------------
TH.ACHIEVEMENTS = {
	-- Серые
	{ id = "save_1", rarity = 0, stat = "saved", goal = 1, icon = "INV_Shirt_White_01",
		name = "Первый выход в свет", desc = "Сохраните свой первый образ." },
	{ id = "race_1", rarity = 0, stat = "races", goal = 1, icon = "spell_magic_polymorphrabbit",
		name = "Свет мой, зеркальце", desc = "Примерьте набор на другую расу." },

	-- Белые
	{ id = "save_5", rarity = 1, stat = "saved", goal = 5, icon = "Inv_misc_bag_08",
		name = "Своя гардеробная", desc = "Сохраните 5 образов." },
	{ id = "publish_1", rarity = 1, stat = "published", goal = 1, icon = "INV_BannerPVP_01",
		name = "Дебют на подиуме", desc = "Опубликуйте первый набор." },
	{ id = "vote_10", rarity = 1, stat = "votesCast", goal = 10, icon = "INV_Misc_Note_02",
		name = "Строгий критик", desc = "Оцените 10 чужих наборов." },
	{ id = "fav_5", rarity = 1, stat = "favorites", goal = 5, icon = "Item_Shop_GiftBox01",
		name = "Копилка вдохновения", desc = "Добавьте 5 наборов в избранное." },

	-- Зелёные
	{ id = "ratings_10", rarity = 2, stat = "ratingsReceived", goal = 10, icon = "achievement_guildperk_honorablemention",
		name = "Первые аплодисменты", desc = "Получите 10 оценок на свои наборы." },
	{ id = "publish_5", rarity = 2, stat = "published", goal = 5, icon = "inv_misc_tournaments_banner_orc",
		name = "Завсегдатай подиума", desc = "Опубликуйте 5 наборов." },
	{ id = "race_10", rarity = 2, stat = "races", goal = 10, icon = "Spell_Shaman_SpectralTransformation",
		name = "Тысяча лиц", desc = "Примерьте наборы на 10 разных рас." },
	{ id = "colors_5", rarity = 2, stat = "colors", goal = 5, icon = "UI_LemixGem_White",
		name = "Все цвета радуги", desc = "Используйте 5 разных цветовых тегов." },
	{ id = "hidden_5", rarity = 2, stat = "hidden", goal = 5, icon = "Ability_Stealth",
		name = "Меньше — значит больше", desc = "Скройте 5 слотов в одном образе." },
	{ id = "trend_50", rarity = 2, stat = "trendRank", rank = true, goal = 50, icon = "achievement_bg_wineos_underxminutes",
		name = "Ветер перемен", desc = "Попадите в топ-50 «В тренде»." },

	-- Синие
	{ id = "ratings_100", rarity = 3, stat = "ratingsReceived", goal = 100, icon = "achievement_guildperk_everybodysfriend",
		name = "Народная любовь", desc = "Получите 100 оценок на свои наборы." },
	{ id = "five_25", rarity = 3, stat = "fiveStars", goal = 25, icon = "spell_holy_surgeoflight",
		name = "Безупречный вкус", desc = "Получите 25 оценок «5 звёзд»." },
	{ id = "trend_10", rarity = 3, stat = "trendRank", rank = true, goal = 10, icon = "Achievement_Quests_Completed_06",
		name = "На гребне волны", desc = "Попадите в топ-10 «В тренде»." },
	{ id = "vote_100", rarity = 3, stat = "votesCast", goal = 100, icon = "inv_misc_scrollunrolled01",
		name = "Член жюри", desc = "Оцените 100 чужих наборов." },
	{ id = "save_25", rarity = 3, stat = "saved", goal = 25, icon = "inv_chest_cloth_17",
		name = "Модный дом", desc = "Сохраните 25 образов." },

	-- Фиолетовые
	{ id = "ratings_1000", rarity = 4, stat = "ratingsReceived", goal = 1000, icon = "Achievement_General_StayClassy",
		name = "Икона стиля", desc = "Получите 1000 оценок на свои наборы." },
	{ id = "top_10", rarity = 4, stat = "topRank", rank = true, goal = 10, icon = "achievement_legionpvp2tier3",
		name = "Зал славы", desc = "Попадите в топ-10 «Лучшие»." },
	{ id = "publish_20", rarity = 4, stat = "published", goal = 20, icon = "INV_Helmet_08",
		name = "Кутюрье Азерота", desc = "Опубликуйте 20 наборов." },
	{ id = "trend_1", rarity = 4, stat = "trendRank", rank = true, goal = 1, icon = "Achievement_LegionPVPTier4",
		name = "Законодатель моды", desc = "Займите 1-е место «В тренде»." },

	-- Оранжевые
	{ id = "top_1", rarity = 5, stat = "topRank", rank = true, goal = 1, icon = "spell_holy_guardianspirit",
		name = "Легенда подиума", desc = "Займите 1-е место среди лучших." },
	{ id = "all", rarity = 5, stat = "earned", goal = 0, icon = "achievement_reputation_01",
		name = "Повелитель гардероба", desc = "Получите все остальные достижения." },
}

TH.ACHIEVEMENT_BY_ID = {}
for _, a in ipairs(TH.ACHIEVEMENTS) do
	TH.ACHIEVEMENT_BY_ID[a.id] = a
	a.points = TH.RARITY[a.rarity].points
	-- Если иконки нет в игре, показываем знак вопроса
	local path = "Interface\\Icons\\" .. a.icon
	a.texture = GetFileIDFromPath and GetFileIDFromPath(path) and path or "Interface\\Icons\\INV_Misc_QuestionMark"
end
TH.ACHIEVEMENT_BY_ID.all.goal = #TH.ACHIEVEMENTS - 1

---------------------------------------------------------------------------
-- Статистика
---------------------------------------------------------------------------
local function CountKeys(t, skipTest)
	local n = 0
	for k, v in pairs(t) do
		if v and not (skipTest and TH:IsTestId(k)) then n = n + 1 end
	end
	return n
end

-- Лучшее место моих опубликованных наборов в реальной ленте (без тестовых)
local function BestRank(view)
	local sets = {}
	for _, set in ipairs(TH.feed.sets) do sets[#sets + 1] = set end
	if view == "trending" then
		table.sort(sets, function(a, b) return (a.trend or 0) > (b.trend or 0) end)
	else
		table.sort(sets, function(a, b) return TH:GetScore(a) > TH:GetScore(b) end)
	end
	for i, set in ipairs(sets) do
		if TH:IsMine(set) then return i end
	end
end

-- Сохраняем лучший результат: место в рейтинге со временем может упасть
function TH:UpdateRankStats()
	local s = self.db.stats
	local server = self.user and self.user.stats or {}
	for stat, view in pairs({ trendRank = "trending", topRank = "top" }) do
		local candidates = { s[stat], server[stat], BestRank(view) }
		for _, r in pairs(candidates) do
			if r and (not s[stat] or r < s[stat]) then s[stat] = r end
		end
	end
end

function TH:GetAchievementStat(stat)
	local s = self.db.stats
	local server = self.user and self.user.stats or {}
	if stat == "saved" then
		return s.saved
	elseif stat == "published" then
		return math.max(s.published, server.published or 0)
	elseif stat == "votesCast" then
		return CountKeys(self.db.myVotes, true)
	elseif stat == "favorites" then
		return CountKeys(self.db.favorites, true)
	elseif stat == "races" then
		return CountKeys(s.races)
	elseif stat == "colors" then
		return CountKeys(s.colors)
	elseif stat == "hidden" then
		return s.maxHidden
	elseif stat == "ratingsReceived" then
		local localSum = 0
		for _, set in ipairs(self.feed.sets) do
			if set.rating and self:IsMine(set) then localSum = localSum + (set.rating.n or 0) end
		end
		return math.max(localSum, server.ratingsReceived or 0)
	elseif stat == "fiveStars" then
		return server.fiveStarsReceived or 0
	elseif stat == "trendRank" or stat == "topRank" then
		return s[stat]
	elseif stat == "earned" then
		local n = 0
		for id in pairs(self.db.achievements) do
			if id ~= "all" and self.ACHIEVEMENT_BY_ID[id] then n = n + 1 end
		end
		return n
	end
	return 0
end

function TH:IsAchievementMet(a)
	local value = self:GetAchievementStat(a.stat)
	if a.rank then return value ~= nil and value <= a.goal end
	return (value or 0) >= a.goal
end

-- Текст прогресса для карточки
function TH:GetAchievementProgress(a)
	local value = self:GetAchievementStat(a.stat)
	if a.rank then
		return value and ("лучшее место: " .. value) or "пока не в рейтинге"
	end
	return string.format("%d / %d", math.min(value or 0, a.goal), a.goal)
end

function TH:GetAchievementTotals()
	local earned, points = 0, 0
	for id, _ in pairs(self.db.achievements) do
		local a = self.ACHIEVEMENT_BY_ID[id]
		if a then
			earned = earned + 1
			points = points + a.points
		end
	end
	return earned, #self.ACHIEVEMENTS, points
end

-- Вызывается после любых действий; новые достижения показываются всплывашкой
function TH:CheckAchievements()
	if not self.db then return end
	self:UpdateRankStats()
	local new = {}
	-- Два прохода: «Повелитель гардероба» зависит от остальных
	for _ = 1, 2 do
		for _, a in ipairs(self.ACHIEVEMENTS) do
			if not self.db.achievements[a.id] and self:IsAchievementMet(a) then
				self.db.achievements[a.id] = time()
				new[#new + 1] = a
			end
		end
	end
	for _, a in ipairs(new) do
		self:ShowAchievementToast(a)
	end
	if #new > 0 and self.UI and self.UI.RefreshAchievements then self.UI:RefreshAchievements() end
end

-- Учёт действий для статистики
function TH:TrackSavedSet(set)
	local s = self.db.stats
	s.saved = s.saved + 1
	for _, tag in ipairs(set.tags or {}) do
		if tag:sub(1, 2) == "c_" then s.colors[tag] = true end
	end
	local hidden = 0
	for _, it in pairs(set.items or {}) do
		local d = self:GetSourceDetails(it[1])
		if d and d.hidden then hidden = hidden + 1 end
	end
	if hidden > s.maxHidden then s.maxHidden = hidden end
end

-- Пересчёт по уже сохранённым наборам: они могли появиться до того,
-- как аддон начал вести статистику.
function TH:RebuildStatsFromSets()
	local s = self.db.stats
	local saved, published = 0, 0
	for _, set in pairs(self.db.mySets) do
		saved = saved + 1
		if set.serverId or set.status == "pending" or set.status == "published" then
			set.everPublished = true
		end
		if set.everPublished then published = published + 1 end
		for _, tag in ipairs(set.tags or {}) do
			if tag:sub(1, 2) == "c_" then s.colors[tag] = true end
		end
		local hidden = 0
		for _, it in pairs(set.items or {}) do
			local d = self:GetSourceDetails(it[1])
			if d and d.hidden then hidden = hidden + 1 end
		end
		if hidden > s.maxHidden then s.maxHidden = hidden end
	end
	if saved > s.saved then s.saved = saved end
	if published > s.published then s.published = published end
end

function TH:TrackRaceTried(raceID)
	if raceID then self.db.stats.races[raceID] = true end
end

---------------------------------------------------------------------------
-- Всплывающее уведомление
---------------------------------------------------------------------------
local toast
local queue = {}

local function BuildToast()
	toast = CreateFrame("Frame", "TransmogHubAchievementToast", UIParent, "BackdropTemplate")
	toast:SetSize(340, 72)
	toast:SetPoint("TOP", 0, -150)
	toast:SetFrameStrata("DIALOG")
	toast:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	toast:SetBackdropColor(0, 0, 0, 0.9)
	toast:Hide()

	toast.icon = toast:CreateTexture(nil, "ARTWORK")
	toast.icon:SetSize(48, 48)
	toast.icon:SetPoint("LEFT", 12, 0)

	toast.header = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	toast.header:SetPoint("TOPLEFT", toast.icon, "TOPRIGHT", 10, -2)
	toast.header:SetText("Достижение Transmog Hub")

	toast.name = toast:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	toast.name:SetPoint("TOPLEFT", toast.header, "BOTTOMLEFT", 0, -4)
	toast.name:SetWidth(250)
	toast.name:SetJustifyH("LEFT")

	toast.points = toast:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	toast.points:SetPoint("TOPLEFT", toast.name, "BOTTOMLEFT", 0, -4)

	toast:EnableMouse(true)
	toast:SetScript("OnMouseUp", function()
		toast:Hide()
		TH.UI:OpenAchievements()
	end)
end

local function ShowNext()
	if not toast then BuildToast() end
	if toast:IsShown() or #queue == 0 then return end
	local a = tremove(queue, 1)
	local r, g, b = TH:RarityRGB(a.rarity)
	toast:SetBackdropBorderColor(r, g, b)
	toast.icon:SetTexture(a.texture)
	toast.name:SetText(TH:RarityHex(a.rarity) .. a.name .. "|r")
	toast.points:SetText(TH.RARITY[a.rarity].name .. " · +" .. a.points .. " очков стиля")
	toast:SetAlpha(1)
	toast:Show()
	PlaySound(SOUNDKIT.ACHIEVEMENT_MENU_OPEN)
	C_Timer.After(5, function()
		UIFrameFadeOut(toast, 1, 1, 0)
		C_Timer.After(1, function()
			toast:Hide()
			ShowNext()
		end)
	end)
end

function TH:ShowAchievementToast(a)
	self:Print("Получено достижение: " .. self:RarityHex(a.rarity) .. "[" .. a.name .. "]|r")
	tinsert(queue, a)
	ShowNext()
end

---------------------------------------------------------------------------
-- Вкладка «Достижения»
---------------------------------------------------------------------------
local COLS, CARD_W, CARD_H, GAP = 3, 316, 56, 3

local function ShowCardTooltip(card)
	local a = card.achievement
	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	GameTooltip:SetText(TH:RarityHex(a.rarity) .. a.name .. "|r")
	GameTooltip:AddLine(TH.RARITY[a.rarity].name .. " · " .. a.points .. " очков стиля", 0.8, 0.8, 0.8)
	GameTooltip:AddLine(a.desc, 1, 1, 1, true)
	local earnedAt = TH.db.achievements[a.id]
	if earnedAt then
		GameTooltip:AddLine("Получено " .. date("%d.%m.%Y", earnedAt), 0.25, 1, 0.25)
	else
		GameTooltip:AddLine("Прогресс: " .. TH:GetAchievementProgress(a), 1, 0.82, 0)
	end
	GameTooltip:Show()
end

function TH:BuildAchievementsPanel(panel)
	panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	panel.header:SetPoint("TOPLEFT", 12, -10)

	panel.cards = {}
	for i, a in ipairs(self.ACHIEVEMENTS) do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		local card = CreateFrame("Frame", nil, panel)
		card:SetSize(CARD_W, CARD_H)
		card:SetPoint("TOPLEFT", 8 + col * (CARD_W + 6), -32 - row * (CARD_H + GAP))
		card:EnableMouse(true)
		card.achievement = a

		card.bg = card:CreateTexture(nil, "BACKGROUND")
		card.bg:SetAllPoints()

		card.stripe = card:CreateTexture(nil, "BORDER")
		card.stripe:SetPoint("TOPLEFT")
		card.stripe:SetPoint("BOTTOMLEFT")
		card.stripe:SetWidth(3)

		card.icon = card:CreateTexture(nil, "ARTWORK")
		card.icon:SetSize(40, 40)
		card.icon:SetPoint("LEFT", 10, 0)
		card.icon:SetTexture(a.texture)

		card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, 0)
		card.name:SetWidth(220)
		card.name:SetJustifyH("LEFT")
		card.name:SetWordWrap(false)

		card.points = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		card.points:SetPoint("TOPRIGHT", -6, -6)
		card.points:SetText(a.points)

		card.desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		card.desc:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -2)
		card.desc:SetWidth(250)
		card.desc:SetJustifyH("LEFT")
		card.desc:SetMaxLines(1)
		card.desc:SetText(a.desc)

		card.progress = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		card.progress:SetPoint("BOTTOMRIGHT", -6, 5)

		card:SetScript("OnEnter", ShowCardTooltip)
		card:SetScript("OnLeave", GameTooltip_Hide)
		panel.cards[i] = card
	end
end

function TH:RefreshAchievementsPanel(panel)
	local earned, total, points = self:GetAchievementTotals()
	panel.header:SetText(string.format("Получено: %d из %d  ·  Очки стиля: %d", earned, total, points))
	for _, card in ipairs(panel.cards) do
		local a = card.achievement
		local at = self.db.achievements[a.id]
		local r, g, b = self:RarityRGB(a.rarity)
		card.stripe:SetColorTexture(r, g, b, at and 1 or 0.35)
		card.bg:SetColorTexture(r, g, b, at and 0.12 or 0.03)
		card.icon:SetDesaturated(not at)
		card.icon:SetAlpha(at and 1 or 0.4)
		-- Неполученные заметно тусклее, чтобы полученные серые от них отличались
		card.name:SetText(at and (self:RarityHex(a.rarity) .. a.name .. "|r") or ("|cff5a5a5a" .. a.name .. "|r"))
		if at then card.desc:SetTextColor(1, 1, 1) else card.desc:SetTextColor(0.45, 0.45, 0.45) end
		card.progress:SetText(at and ("|cff40ff40" .. date("%d.%m.%Y", at) .. "|r") or self:GetAchievementProgress(a))
	end
end
