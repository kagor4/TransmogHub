local _, ns = ...
local L = ns.L
local TH = ns.TH

local UI = CreateFrame("Frame", "TransmogHubFrame", UIParent, "BasicFrameTemplateWithInset")
UI:Hide()
TH.UI = UI

local W, H = 1000, 626 -- шапка в два ряда: разделы; поиск, теги и «Новый образ»
local ROWS, ROW_H = 10, 44
local LIST_TOP = 32 -- сверху над списком — переключатель сортировки
local SLOT_ROW_H = 19

local VIEWS = {
	{ key = "top", text = L["Образы"] },
	{ key = "friends", text = L["Друзья"] },
	{ key = "guild", text = L["Гильдия"] },
	{ key = "favorites", text = L["Избранное"] },
	{ key = "subs", text = L["Подписки"] },
	{ key = "me", text = L["Мой профиль"] }, -- свой профиль; старый список «Мои» открывается из него
	{ key = "achievements", text = L["Достижения"] },
	-- «Модерация» — не вкладкой, а щитом в шапке окна (он есть только у модераторов)
}

local EMPTY_TEXT = {
	mine = L["Сохранённых образов пока нет.\n\nНаденьте трансмог и нажмите «Новый образ»."],
	favorites = L["В избранном пусто."],
	friends = L["Друзья пока ничего не опубликовали.\n\nЗдесь образы друзей из списка друзей игры\nи Battle.net, у которых стоит аддон."],
	hall = L["В Зале славы пока никого.\n\nСюда попадают образы, которые трижды были первыми\nв «Лучших» за неделю или 8 недель держались в топ-10."],
	subs = L["Вы ни на кого не подписаны — или они ещё ничего не опубликовали.\n\nПодписаться: профиль автора > «Подписаться»\nили правый клик по образу."],
	guild = L["Согильдийцы пока ничего не опубликовали.\n\nЗдесь образы игроков вашей гильдии, у которых стоит аддон."],
	moderation = L["Жалоб и подозрительных оценок нет."],
	default = L["Пока здесь никого нет.\n\nОпубликуйте свой образ первым — его увидят\nвсе игроки с аддоном."],
}

local STATUS_TEXT = {
	draft = L["|cff999999черновик|r"],
	published = L["|cff40ff40опубликован|r"],
	rejected = L["|cffff4040отклонён|r"],
}

UI.view = "top"

-- Сортировка списков (кроме «Мои» и «Модерация»); выбирается кнопкой в шапке
local SORTS = {
	{ key = "top", text = L["Лучшие"], hint = L["По рейтингу с учётом числа оценок"] },
	{ key = "trending", text = L["В тренде"], hint = L["Больше всего звёзд за последние 7 дней"] },
	{ key = "new", text = L["Новые"], hint = L["Образы за последние 14 дней, сначала самые свежие."] },
	{ key = "recommended", text = L["Рекомендуемые"],
		hint = L["Образы за последние 14 дней в случайном порядке. Чаще выпадают образы классов ваших персонажей (главного — ещё чаще) и с тегами, которые вам нравятся: вы их ставите своим образам, добавляете в избранное, оцениваете на 4—5. Кубик справа — перемешать."] },
}
local SORT_TEXT = {}
for _, s in ipairs(SORTS) do SORT_TEXT[s.key] = s.text end
local SORTABLE = { top = true, friends = true, guild = true, favorites = true, author = true, subs = true }
local LIST_TITLES = { mine = L["Мои образы"], moderation = L["Жалобы и проверка оценок"], subs = L["Новые образы подписок"], hall = L["Зал славы"] }

function UI:GetSort()
	return TH.db and TH.db.listSort or "top"
end

function UI:SetSort(key)
	TH.db.listSort = key
	self.offset = 0
	self:Refresh()
end
UI.filter = { text = "", tags = {} }
UI.offset = 0
UI.raceID = nil -- раса для примерки; nil — свой персонаж

---------------------------------------------------------------------------
-- Мелкие конструкторы
---------------------------------------------------------------------------
local function Button(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	TH.PadButton(b)
	b:SetSize(w, h or 22)
	b:SetText(text)
	return b
end

-- Главное действие — зелёная кнопка (красную текстуру обесцвечиваем и красим)
local function StylePrimary(b)
	b.thPrimary = true -- в оформлении EllesmereUI — кнопка акцентного цвета
	for _, key in ipairs({ "Left", "Middle", "Right" }) do
		local t = b[key]
		if type(t) == "table" and t.SetDesaturated then
			t:SetDesaturated(true)
			t:SetVertexColor(0.35, 0.9, 0.35)
		end
	end
end
TH.StylePrimaryButton = StylePrimary

-- Второстепенное действие — плоская текстовая кнопка
local function FlatButton(parent, text)
	local b = CreateFrame("Button", nil, parent)
	b:SetNormalFontObject("GameFontNormalSmall")
	b:SetHighlightFontObject("GameFontHighlightSmall")
	b:SetDisabledFontObject("GameFontDisableSmall")
	b:SetText(text)
	b:SetSize((b:GetTextWidth() or 100) + 12, 20)
	local line = b:CreateTexture(nil, "ARTWORK")
	line:SetPoint("BOTTOMLEFT", 6, 2)
	line:SetPoint("BOTTOMRIGHT", -6, 2)
	line:SetHeight(1)
	line:SetColorTexture(1, 0.82, 0, 0.5)
	return b
end

local function Label(parent, font, w)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetJustifyH("LEFT")
	if w then fs:SetWidth(w) end
	return fs
end

local function Panel(parent, x, y, w, h)
	local p = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	p:SetPoint("TOPLEFT", x, y)
	p:SetSize(w, h)
	return p
end

-- Значки источников вещей (TRANSMOG_SOURCE_n): добыча, задание, торговец, мир,
-- достижение, профессия, магазин, торговая лавка
local SOURCE_ICONS = {
	[1] = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
	[2] = "Interface\\Icons\\INV_Misc_Note_02",
	[3] = "Interface\\Icons\\INV_Misc_Coin_01",
	[4] = "Interface\\Icons\\INV_Misc_Bag_10",
	[5] = "Interface\\Icons\\Achievement_Quests_Completed_06",
	[6] = "Interface\\Icons\\Trade_BlackSmithing",
	[7] = "Interface\\Icons\\INV_Misc_Coin_17",
	[8] = "Interface\\Icons\\Spell_Holy_BorrowedTime",
}

-- Подписи звёзд оценки
local STAR_LABELS = { L["1 — даже мурлок бы не надел"], L["2 — так себе"], L["3 — неплохо"], L["4 — красиво"], L["5 — восторг!"] }

local function QualityName(det)
	local c = det.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[det.quality]
	return c and (c.hex .. det.name .. "|r") or det.name
end

local function SetStarTexture(tex)
	if C_Texture.GetAtlasInfo("PetJournal-FavoritesIcon") then
		tex:SetAtlas("PetJournal-FavoritesIcon")
	else
		tex:SetTexture("Interface\\Common\\ReputationStar")
		tex:SetTexCoord(0, 0.5, 0, 0.5)
	end
end

---------------------------------------------------------------------------
-- Построение окна
---------------------------------------------------------------------------
function UI:Build()
	self.built = true
	self:SetSize(W, H)
	self:SetPoint("CENTER")
	self:SetFrameStrata("HIGH")
	self:SetToplevel(true)
	self:SetMovable(true)
	self:SetClampedToScreen(true)
	self:EnableMouse(true)
	self:RegisterForDrag("LeftButton")
	self:SetScript("OnDragStart", self.StartMoving)
	self:SetScript("OnDragStop", self.StopMovingOrSizing)
	self:SetScript("OnHide", function() if TH:IsTourShown() then TH:EndTour() end end)
	self:SetScript("OnShow", function()
		self.model:Refresh()
		TH:PrefetchLikelySets() -- данные о вещах своих образов и верха чартов — заранее
		TH:MarkClock() -- когда открывали окно (для одной тайны)
		TH:CheckAchievements()
	end)
	tinsert(UISpecialFrames, self:GetName())

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	local version = C_AddOns.GetAddOnMetadata("TransmogHub", "Version") or ""
	if version:find("@", 1, true) then version = "dev" end -- сборка не через упаковщик
	title:SetText("Transmog Hub " .. version)

	self:BuildToolbar()
	self.listPanel = Panel(self, 10, -84, 322, 508)
	self.previewPanel = Panel(self, 336, -84, 300, 508)
	self.detailPanel = Panel(self, 640, -84, 350, 508)
	self:BuildList(self.listPanel)
	self:BuildPreview(self.previewPanel)
	self:BuildDetail(self.detailPanel)

	self.achPanel = Panel(self, 10, -84, 980, 508)
	TH:BuildAchievementsPanel(self.achPanel)
	self.achPanel:Hide()

	self.profilePanel = Panel(self, 10, -84, 980, 508)
	TH:BuildProfilePanel(self.profilePanel)
	self.profilePanel:Hide()

	self.exilePanel = Panel(self, 10, -84, 980, 508)
	TH:BuildExilePanel(self.exilePanel)
	self.exilePanel:Hide()

	-- строка состояния: точка «сеть есть/нет» и три значка с числами
	self.status = Label(self, "GameFontHighlightSmall", 560) -- прочие пометки (пауза, отправка)
	self.netDot = self:CreateTexture(nil, "ARTWORK")
	self.netDot:SetSize(14, 14)
	self.netDot:SetPoint("BOTTOMLEFT", 14, 12)
	self.netLabel = Label(self, "GameFontHighlightSmall")
	self.netLabel:SetPoint("LEFT", self.netDot, "RIGHT", 4, 0)
	self.netStats, self.netIcons = {}, {}
	local prev = self.netLabel
	for i, icon in ipairs({ "Interface\\Icons\\INV_Misc_GroupLooking", "Interface\\Icons\\Achievement_GuildPerk_EverybodysFriend",
		"Interface\\Icons\\Achievement_GuildPerk_MrPopularity", "Interface\\Icons\\INV_Chest_Cloth_17" }) do
		local tex = self:CreateTexture(nil, "ARTWORK")
		tex:SetSize(16, 16)
		tex:SetPoint("LEFT", prev, "RIGHT", 16, 0)
		tex:SetTexture(icon)
		local num = Label(self, "GameFontHighlightSmall")
		num:SetPoint("LEFT", tex, "RIGHT", 4, 0)
		self.netStats[i] = num
		self.netIcons[i] = tex
		prev = num
	end
	self.status:ClearAllPoints()
	self.status:SetPoint("LEFT", prev, "RIGHT", 16, 0)
	self.status:SetWidth(260)
	self.syncBtn = FlatButton(self, L["Синхронизировать"])
	self.syncBtn:SetPoint("BOTTOMRIGHT", -40, 9) -- правее — рамка окна и уголок для растягивания
	self.syncBtn:SetScript("OnClick", function()
		TH.Net:RequestSync()
		TH:Print(L["Запрос синхронизации отправлен."])
	end)
	self:BuildScaleSlider()
	self:BuildResizeGrip()

	-- Кнопки в заголовке рядом с крестиком: маленькие иконки ровно в полосе заголовка
	-- (она 18 пикселей: от -1 до -19), с тонкой тёмной окантовкой
	local function TitleButton(icon)
		local b = CreateFrame("Button", nil, self)
		b:SetSize(14, 14)
		b.edge = b:CreateTexture(nil, "BACKGROUND")
		b.edge:SetPoint("TOPLEFT", -1, 1)
		b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
		b.edge:SetColorTexture(0, 0, 0, 0.9)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints()
		b.icon:SetTexture(icon)
		b.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
		b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
		b:SetScript("OnMouseDown", function() b.icon:SetAlpha(0.7) end)
		b:SetScript("OnMouseUp", function() b.icon:SetAlpha(1) end)
		return b
	end

	-- «?» — справка
	self.helpBtn = TitleButton("Interface\\Icons\\INV_Misc_QuestionMark")
	self.helpBtn:SetPoint("TOPRIGHT", -28, -3)
	self.helpBtn:SetScript("OnClick", function() TH:ToggleHelp() end)

	-- конверт — письмо разработчику
	self.ideaBtn = TitleButton("Interface\\Icons\\INV_Letter_15")
	self.ideaBtn:SetPoint("RIGHT", self.helpBtn, "LEFT", -5, 0)
	self.ideaBtn:SetScript("OnClick", function() TH:OpenIdeas() end)

	-- шестерёнка — настройки
	self.settingsBtn = TitleButton("Interface\\Icons\\Trade_Engineering")
	-- значок настроек игры (шестерёнка), если он есть в этой версии игры
	for _, atlas in ipairs({ "QuestLog-icon-setting", "questlog-icon-setting", "GM-icon-settings" }) do
		if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
			self.settingsBtn.icon:SetAtlas(atlas)
			self.settingsBtn.edge:SetColorTexture(0, 0, 0, 0.6)
			break
		end
	end
	self.settingsBtn:SetPoint("RIGHT", self.ideaBtn, "LEFT", -5, 0)
	self.settingsBtn:SetScript("OnClick", function() TH:ToggleSettings() end)
	self.settingsBtn.thLogKey = "Настройки"

	-- кисть — переключить оформление (EllesmereUI / обычное), нужна перезагрузка интерфейса
	self.styleBtn = TitleButton("Interface\\Icons\\INV_Chest_Cloth_17")
	-- значок трансмогрификации из интерфейса игры (как курсор у вендора трансмога)
	for _, atlas in ipairs({ "Crosshair_Transmogrify_32", "crosshair_transmogrify_32", "Crosshair_Transmogrify_64" }) do
		if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
			self.styleBtn.icon:SetAtlas(atlas)
			self.styleBtn.edge:SetColorTexture(0, 0, 0, 0.6)
			break
		end
	end
	self.styleBtn:SetPoint("RIGHT", self.settingsBtn, "LEFT", -5, 0)

	-- щит — модерация (только у модераторов)
	self.modBtn = TitleButton("Interface\\Icons\\Spell_Holy_SealOfProtection")
	self.modBtn:SetPoint("RIGHT", self.styleBtn, "LEFT", -5, 0)
	self.modBtn:SetScript("OnClick", function() self:SetView("moderation") end)
	self.modBtn.thLogKey = "Модерация"
	self.modBtn:SetShown(TH:IsModeratorClient())
	self.styleBtn:SetScript("OnClick", function() TH:ToggleStyle() end)
	self.styleBtn.thLogKey = "Оформление"

	self:AddTooltips()
	TH:ApplyScale()
end

-- Подсказка у курсора; существующие обработчики не затираем
local function Tip(frame, title, text)
	if not frame then return end
	frame.thTipTitle = frame.thTipTitle or title -- имя кнопки без надписи для статистики нажатий
	frame:HookScript("OnEnter", function(f)
		GameTooltip:SetOwner(f, "ANCHOR_TOP")
		GameTooltip:SetText(title)
		if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	frame:HookScript("OnLeave", GameTooltip_Hide)
end
UI.Tip = Tip

local TAB_TIPS = {
	top = { L["Образы"], L["Все образы игроков. Сверху над списком — сортировка: лучшие, в тренде, новые."] },
	friends = { L["Друзья"], L["Образы ваших друзей из списка друзей игры и Battle.net."] },
	guild = { L["Гильдия"], L["Образы ваших согильдийцев с аддоном."] },
	favorites = { L["Избранное"], L["Образы, отмеченные золотой звёздочкой в списке."] },
	subs = { L["Подписки"], L["Образы авторов, на которых вы подписаны: лучшие, в тренде, новые. Значок справа от сортировки — авторы: профиль, уведомления от каждого, отписка. Подписаться: профиль автора или правый клик по образу."] },
	me = { L["Мой профиль"], L["Ваши образы и черновики, достижения, место в рейтинге, аватар и звание."] },
	achievements = { L["Достижения"], L["Все достижения и рейтинг очков стиля среди игроков."] },
	moderation = { L["Модерация"], L["Образы с жалобами и с подозрением на накрутку оценок. Видна только модераторам."] },
}

function UI:AddTooltips()
	for _, b in ipairs(self.tabs) do
		local t = TAB_TIPS[b.key]
		if t then Tip(b, t[1], t[2]) end
	end
	Tip(self.helpBtn, L["Справка"], L["Что где искать и как всё устроено."])
	Tip(self.ideaBtn, L["Письмо разработчику"], L["Идея, ошибка или пожелание — каждое письмо прочитают."])
	Tip(self.settingsBtn, L["Настройки"], L["Уведомления подписок, всплывашки (стиль, место, размер), вид и приватность."])
	Tip(self.modBtn, L["Модерация"], L["Образы с жалобами и с подозрением на накрутку оценок, управление модераторами."])
	Tip(self.styleBtn, L["Оформление"], L["Переключить вид окон: в стиле EllesmereUI или обычный, как в игре. Нужна перезагрузка интерфейса."])
	Tip(self.search, L["Поиск"], L["По названию образа, автору, тегам и названиям вещей. На вкладке «Достижения» — по достижениям."])
	Tip(self.tagsBtn, L["Теги"], L["Показать только образы с выбранными тегами. Там же можно предложить новый тег."])
	Tip(self.saveBtn, L["Новый образ"], L["Сохранить то, что сейчас надето на персонаже (с трансмогом), и поделиться с другими игроками. Можно сохранить и черновиком."])
	Tip(self.syncBtn, L["Синхронизировать"], L["Спросить у других игроков с аддоном, что нового: образы, оценки, рейтинг. При входе в игру это происходит само — кнопка нужна, если кажется, что чего-то не хватает."])
	Tip(self.raceBtn, L["Раса для примерки"], L["Свой персонаж, раса автора образа или любая другая. Пол модели игра менять не даёт — для другого пола используйте Wowhead."])
	Tip(self.publishBtn, L["Опубликовать"], L["Отправить черновик другим игрокам."])
	Tip(self.deleteBtn, L["Удалить"], L["Удалить образ. Опубликованный пропадёт и у других игроков."])
	Tip(self.modSetBtn, L["Нарушение"], L["Выберите, что не так: шуточное название (автора попросят переименовать, без наказания), оскорбление (14 дней без публикаций, второй раз — навсегда), реклама (бан автора) или другое. Образ пропадёт у игроков, до которых дойдёт решение, и попадёт в чёрный список при разборе."])
	Tip(self.modAuthorBtn, L["Заблокировать автора"], L["Все образы автора пропадут; новые не будут приниматься."])
	Tip(self.modSkipBtn, L["Без решения"], L["Убрать образ из списка модерации без последствий: ничего не блокируется, жалобы не признаются ложными, у пожаловавшихся ничего не меняется. Новые жалобы вернут его в список."])
	Tip(self.modDismissBtn, L["Жалобы ложные / Оценки честные"], L["Жалобы: убрать образ из списка, жалобы необоснованны. Оценки: накрутки нет, образ возвращается в чарт (снова проверится, если оценок станет в полтора раза больше)."])

	-- строка состояния сети: у точки, каждого значка и строки отправки — своя подсказка
	local function Hover(from, to, title, lines)
		local h = CreateFrame("Frame", nil, self)
		h:SetPoint("TOPLEFT", from, "TOPLEFT", -3, 4)
		h:SetPoint("BOTTOMRIGHT", to, "BOTTOMRIGHT", 3, -4)
		h:EnableMouse(true)
		h:SetScript("OnEnter", function(f)
			GameTooltip:SetOwner(f, "ANCHOR_TOP")
			GameTooltip:SetText(title)
			for _, line in ipairs(type(lines) == "function" and lines() or lines) do
				GameTooltip:AddLine(line, 1, 1, 1, true)
			end
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine(L["Подробнее: /thub net"], 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		h:SetScript("OnLeave", GameTooltip_Hide)
		return h
	end
	Hover(self.netDot, self.netLabel, L["Подключение"], function()
		return { TH.Net:IsConnected()
			and L["|cff40ff40Зелёная точка|r — аддон подключён к своему скрытому каналу и обменивается образами с другими игроками."]
			or L["|cff999999Серая точка|r — аддон ещё подключается: так бывает первые секунды после входа или перезагрузки."],
			L["Сервера у аддона нет: игроки обмениваются образами напрямую."] }
	end)
	Hover(self.netIcons[1], self.netStats[1], L["Игроки с аддоном на вашем сервере"], {
		L["Сколько игроков с аддоном сейчас в сети на вашем сервере (и связанных с ним). От них приходят образы, оценки и рейтинг."],
		L["Игроков с других серверов аддон слышит через группу, гильдию и друзей Battle.net."] })
	Hover(self.netIcons[2], self.netStats[2], L["Друзья Battle.net с аддоном"], {
		L["Друзья Battle.net, которые сейчас в игре с аддоном, — на любом сервере и за любую фракцию."],
		L["Через них образы ходят между серверами: чем больше таких друзей, тем больше образов вы увидите."] })
	Hover(self.netIcons[3], self.netStats[3], L["Согильдийцы с аддоном"], {
		L["Согильдийцы, которые сейчас в игре с аддоном. При входе аддон знакомится с ними и забирает новые образы."],
		L["Если в гильдии есть игроки другой фракции или с других серверов, образы ходят и через гильдию."] })
	Hover(self.netIcons[4], self.netStats[4], L["Образов в базе"], {
		L["Сколько образов вы получили от других игроков."],
		L["Ещё сотни лучших и свежих образов приходят с каждым обновлением аддона — они в ленте, но в этом числе не считаются."] })
	Hover(self.status, self.status, L["Отправка"], {
		L["Сколько сообщений ждёт отправки. Игра ограничивает скорость, поэтому большой обмен идёт постепенно."],
		L["В бою и в подземельях отправка на паузе и продолжится сама."] })
end

-- Уголок справа внизу: тянем — окно увеличивается или уменьшается целиком
-- (пропорционально, как ползунок масштаба); левый верхний угол остаётся на месте.
function UI:BuildResizeGrip()
	local grip = CreateFrame("Button", nil, self)
	self.resizeGrip = grip
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -3, 3)
	grip:SetFrameLevel((self:GetFrameLevel() or 0) + 10)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")

	local function Cursor()
		local x, y = GetCursorPosition()
		local s = UIParent:GetEffectiveScale()
		return x / s, y / s
	end

	grip:SetScript("OnMouseDown", function(g, button)
		if button ~= "LeftButton" then return end
		local scale = self:GetScale()
		local cx, cy = Cursor()
		g.drag = { x = cx, y = cy, scale = scale,
			left = (self:GetLeft() or 0) * scale, top = (self:GetTop() or 0) * scale }
		g:SetScript("OnUpdate", function()
			local d = g.drag
			local x, y = Cursor()
			-- новый размер в единицах экрана, масштаб — среднее по ширине и высоте
			local sw = (W * d.scale + (x - d.x)) / W
			local sh = (H * d.scale - (y - d.y)) / H
			TH:SetScale((sw + sh) / 2, true)
			local s = TH.db.scale
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", d.left / s, d.top / s)
		end)
	end)
	grip:SetScript("OnMouseUp", function(g)
		g:SetScript("OnUpdate", nil)
		g.drag = nil
	end)
	grip:SetScript("OnEnter", function(g)
		GameTooltip:SetOwner(g, "ANCHOR_TOP")
		GameTooltip:SetText(L["Размер окна"])
		GameTooltip:AddLine(L["Потяните, чтобы увеличить или уменьшить окно."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	grip:SetScript("OnLeave", GameTooltip_Hide)
end

-- Ползунок «Масштаб окна» внизу справа
function UI:BuildScaleSlider()
	local slider = CreateFrame("Slider", nil, self, "MinimalSliderTemplate")
	self.scaleSlider = slider
	slider:SetSize(110, 19)
	slider:SetPoint("RIGHT", self.syncBtn, "LEFT", -56, 0)
	slider:SetMinMaxValues(TH.SCALE_MIN, TH.SCALE_MAX)
	slider:SetValueStep(TH.SCALE_STEP)
	slider:SetObeyStepOnDrag(true)

	local label = Label(self, "GameFontNormalSmall")
	label:SetPoint("RIGHT", slider, "LEFT", -8, 0)
	label:SetText(L["Масштаб окна"])
	-- число можно вписать руками: Enter — применить, Esc — отменить
	local edit = CreateFrame("EditBox", nil, self, "InputBoxTemplate")
	slider.value = edit
	edit:SetSize(30, 18)
	edit:SetPoint("LEFT", slider, "RIGHT", 10, 0)
	edit:SetAutoFocus(false)
	edit:SetNumeric(true)
	edit:SetMaxLetters(3)
	edit:SetJustifyH("CENTER")
	edit:SetScript("OnEnterPressed", function(e)
		local pct = tonumber(e:GetText())
		if pct then TH:SetScale(pct / 100, true) end
		e:ClearFocus()
		self:UpdateScaleSlider()
	end)
	edit:SetScript("OnEscapePressed", function(e)
		e:ClearFocus()
		self:UpdateScaleSlider()
	end)
	edit:SetScript("OnEditFocusLost", function() self:UpdateScaleSlider() end)
	edit:SetScript("OnEnter", function(e)
		GameTooltip:SetOwner(e, "ANCHOR_TOP")
		GameTooltip:SetText(L["Масштаб в процентах"])
		GameTooltip:AddLine(string.format(L["Впишите число от %d до %d и нажмите Enter."], TH.SCALE_MIN * 100, TH.SCALE_MAX * 100), 1, 1, 1, true)
		GameTooltip:Show()
	end)
	edit:SetScript("OnLeave", GameTooltip_Hide)
	local pctSign = Label(self, "GameFontHighlightSmall")
	pctSign:SetPoint("LEFT", edit, "RIGHT", 2, 0)
	pctSign:SetText("%")

	local function Percent(v) return tostring(math.floor(v * 100 + 0.5)) end
	-- при перетаскивании окно меняет размер только когда кнопку отпустили,
	-- иначе ползунок «уезжает» из-под курсора
	slider:SetScript("OnValueChanged", function(s, value)
		s.value:SetText(Percent(value))
		if not self.updatingScale and not (s.IsDraggingThumb and s:IsDraggingThumb()) then TH:SetScale(value) end
	end)
	slider:SetScript("OnMouseUp", function(s, button)
		if button == "RightButton" then TH:SetScale(1) else TH:SetScale(s:GetValue()) end
	end)
	slider:EnableMouseWheel(true)
	slider:SetScript("OnMouseWheel", function(_, delta)
		TH:SetScale(TH.db.scale + delta * TH.SCALE_STEP)
	end)
	slider:SetScript("OnEnter", function(s)
		GameTooltip:SetOwner(s, "ANCHOR_TOP")
		GameTooltip:SetText(L["Масштаб окна"])
		GameTooltip:AddLine(L["Перетащите ползунок или крутите колесо мыши. ПКМ — вернуть 100%."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	slider:SetScript("OnLeave", GameTooltip_Hide)
	self:UpdateScaleSlider()
end

function UI:UpdateScaleSlider()
	local slider = self.scaleSlider
	if not slider then return end
	self.updatingScale = true
	slider:SetValue(TH.db.scale)
	self.updatingScale = false
	if not (slider.value.HasFocus and slider.value:HasFocus()) then
		slider.value:SetText(tostring(math.floor(TH.db.scale * 100 + 0.5)))
	end
end

function UI:BuildToolbar()
	self.tabs = {}
	local moderator = TH:IsModeratorClient()
	-- ширина вкладок по надписи; если не помещаются — поля у надписей уже
	local n, textTotal = 0, 0
	for _, v in ipairs(VIEWS) do
		if not v.modOnly or moderator then
			n = n + 1
			local b = Button(self, v.text, 60)
			b.textW = math.ceil(b:GetTextWidth() or 50)
			textTotal = textTotal + b.textW
			b.key = v.key
			b:SetScript("OnClick", function()
				if v.key == "me" then self:OpenProfile(TH.Net.Me()) else self:SetView(v.key) end
			end)
			self.tabs[n] = b
		end
	end
	-- вкладки делят место до поиска: поля одинаковые, сколько останется от текста.
	-- Ширину текста меряем и при показе окна: при первом построении шрифт может быть ещё
	-- не загружен. Не хватает места и с узкими полями — шрифт мельче.
	local GAP = 3
	-- первый ряд: лента слева, личное (профиль, достижения, модерация) справа
	local RIGHT_KEYS = { me = true, achievements = true, moderation = true }
	local GROUP_GAP = 24
	local room = W - 12 - 12 - (n - 2) * GAP - GROUP_GAP
	local function FitTabs()
		local function Measure()
			local sum, widths = 0, {}
			for i, b in ipairs(self.tabs) do
				local fs = b:GetFontString()
				local w = fs and fs.GetStringWidth and fs:GetStringWidth()
				if type(w) ~= "number" or w <= 0 then w = b.textW or 50 end
				widths[i], sum = w, sum + w
			end
			return widths, sum
		end
		local widths, sum = Measure()
		if (room - sum) / n < 10 then
			for _, b in ipairs(self.tabs) do
				local fs = b:GetFontString()
				if fs then fs:SetFontObject(GameFontNormalSmall) end
			end
			widths, sum = Measure()
		end
		local pad = math.max(6, math.min(22, math.floor((room - sum) / n)))
		local x, right = 12, {}
		for i, b in ipairs(self.tabs) do
			local w = math.floor(widths[i] + pad)
			b.thMinW, b.thExtra = 0, pad - 24 -- PadButton держит ту же ширину при смене текста
			b:SetWidth(w)
			b:ClearAllPoints()
			if RIGHT_KEYS[b.key] then
				right[#right + 1] = { b, w }
			else
				b:SetPoint("TOPLEFT", x, -30)
				x = x + w + GAP
			end
		end
		-- правая группа — ровно над «Новым образом»: тот же правый край и та же общая ширина
		local SAVE_W, SAVE_RIGHT = 184, -14
		local total = (#right - 1) * GAP
		for _, r in ipairs(right) do total = total + r[2] end
		if #right > 0 then
			local extra = SAVE_W - total
			local sumW = total - (#right - 1) * GAP
			local left = extra
			for i, r in ipairs(right) do
				-- лишнее (или недостающее) делим по ширине кнопок; остаток — последней
				local add = (i == #right) and left or math.floor(extra * r[2] / sumW + 0.5)
				left = left - add
				r[2] = math.max(r[2] + add, 30)
				r[1]:SetWidth(r[2])
			end
		end
		local rx = SAVE_RIGHT
		for i = #right, 1, -1 do
			right[i][1]:SetPoint("TOPRIGHT", rx, -30)
			rx = rx - right[i][2] - GAP
		end
		return x
	end
	local x = FitTabs()
	self.FitViewTabs = FitTabs
	self:HookScript("OnShow", function()
		FitTabs()
		C_Timer.After(0.1, FitTabs)
	end)

	-- поиск занимает место между вкладками и кнопкой «Теги»
	-- второй ряд: поиск на всю ширину, «Теги» и «Новый образ» справа
	local searchW = W - 18 - 294 - 30 -- до «Теги» (и крестика сброса тегов слева от неё)
	local search = CreateFrame("EditBox", nil, self, "SearchBoxTemplate")
	self.search = search
	search:SetSize(searchW, 20)
	search:SetPoint("TOPLEFT", 18, -57)
	search:SetAutoFocus(false)
	-- лупа и подпись чуть левее: у шаблона игры они сдвинуты вправо от края поля
	local icon = search.searchIcon or search.SearchIcon
	if type(icon) == "table" and icon.SetPoint then
		icon:ClearAllPoints()
		icon:SetPoint("LEFT", 1, -1)
	end
	if type(search.Instructions) == "table" and search.Instructions.SetPoint and type(icon) == "table" then
		search.Instructions:ClearAllPoints()
		search.Instructions:SetPoint("LEFT", icon, "RIGHT", 2, 0)
		search.Instructions:SetPoint("RIGHT", -6, 0)
	end
	if search.SetTextInsets then search:SetTextInsets(16, 18, 0, 0) end
	search:HookScript("OnTextChanged", function(eb)
		self.filter.text = eb:GetText() or ""
		self.offset = 0
		self:Refresh()
	end)

	self.tagsBtn = Button(self, L["Теги"], 90)
	self.tagsBtn:SetPoint("TOPRIGHT", -204, -56) -- левее кнопки «Новый образ» (184)
	self.tagsBtn:SetScript("OnClick", function(b) self:OpenTagMenu(b) end)

	-- Сброс фильтра тегов: виден, только когда выбран хотя бы один тег
	self.tagsReset = CreateFrame("Button", nil, self, "UIPanelCloseButton")
	self.tagsReset:SetSize(26, 26)
	self.tagsReset:SetPoint("RIGHT", self.tagsBtn, "LEFT", -2, 0)
	self.tagsReset:SetScript("OnClick", function()
		wipe(self.filter.tags)
		self.offset = 0
		self:Refresh()
	end)
	self.tagsReset:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Сбросить теги"])
		GameTooltip:Show()
	end)
	self.tagsReset:SetScript("OnLeave", GameTooltip_Hide)
	self.tagsReset:Hide()

	-- главное действие окна: крупнее, ярче и с белым текстом, чтобы не терялось среди вкладок
	local saveBtn = Button(self, L["Новый образ"], 184, 26)
	StylePrimary(saveBtn)
	for _, key in ipairs({ "Left", "Middle", "Right" }) do
		local t = saveBtn[key]
		if type(t) == "table" and t.SetVertexColor then t:SetVertexColor(0.3, 1, 0.3) end
	end
	saveBtn:SetNormalFontObject("GameFontHighlight")
	saveBtn:SetHighlightFontObject("GameFontHighlight")
	local plus = saveBtn:CreateTexture(nil, "OVERLAY")
	plus:SetSize(14, 14)
	plus:SetPoint("LEFT", 10, 0)
	plus:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
	saveBtn.plus = plus
	-- текст сдвинут вправо, чтобы не заезжал на плюс
	saveBtn.thExtra = 20
	local fs = saveBtn:GetFontString()
	if type(fs) == "table" then
		fs:ClearAllPoints()
		fs:SetPoint("CENTER", 9, 0)
	end
	self.saveBtn = saveBtn
	saveBtn:SetPoint("TOPRIGHT", -14, -54)
	saveBtn:SetScript("OnClick", function() TH:OpenSaveDialog() end)
end

function UI:BuildList(list)
	self.rows = {}
	for i = 1, ROWS do
		local row = CreateFrame("Button", nil, list)
		row:SetSize(292, ROW_H - 2) -- справа — полоса прокрутки
		row:SetPoint("TOPLEFT", 8, -LIST_TOP - (i - 1) * ROW_H)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

		-- выбранный: заметная подсветка и золотая рамка
		row.sel = CreateFrame("Frame", nil, row)
		row.sel:SetAllPoints()
		local fill = row.sel:CreateTexture(nil, "BACKGROUND")
		fill:SetAllPoints()
		fill:SetColorTexture(TH:SelColor(0.28))
		for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", nil, 1 }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, 1 },
			{ "TOPLEFT", "BOTTOMLEFT", 1, nil }, { "TOPRIGHT", "BOTTOMRIGHT", 1, nil } }) do
			local line = row.sel:CreateTexture(nil, "BORDER")
			line:SetPoint(edge[1])
			line:SetPoint(edge[2])
			if edge[3] then line:SetWidth(edge[3]) else line:SetHeight(edge[4]) end
			line:SetColorTexture(TH:SelColor(0.9))
		end

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(36, 36)
		row.icon:SetPoint("LEFT", 4, 0)

		row.name = Label(row, "GameFontNormal", 175)
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
		row.name:SetWordWrap(false)

		row.author = Label(row, "GameFontHighlightSmall", 175)
		row.author:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.author:SetWordWrap(false)

		-- звёздочка избранного: серая — нет, золотая — в избранном
		row.fav = CreateFrame("Button", nil, row)
		row.fav:SetSize(18, 18)
		row.fav:SetPoint("TOPRIGHT", -4, -3)
		row.fav.tex = row.fav:CreateTexture(nil, "ARTWORK")
		row.fav.tex:SetAllPoints()
		SetStarTexture(row.fav.tex)
		row.fav:SetScript("OnClick", function()
			if row.setId then TH:ToggleFavorite(row.setId) end
		end)
		row.fav:SetScript("OnEnter", function(f)
			local r = row
			GameTooltip:SetOwner(f, "ANCHOR_RIGHT")
			GameTooltip:SetText(TH.db.favorites[r.setId] and L["Убрать из избранного"] or L["В избранное"])
			local n = r.setId and TH:GetFavoriteCount(r.setId) or 0
			if n > 0 then GameTooltip:AddLine(L["В избранном у игроков: "] .. n, 1, 1, 1) end
			GameTooltip:Show()
		end)
		row.fav:SetScript("OnLeave", GameTooltip_Hide)
		row.favCount = Label(row, "GameFontDisableSmall")
		row.favCount:SetPoint("RIGHT", row.fav, "LEFT", -1, 0)

		row.rating = Label(row, "GameFontHighlightSmall")
		row.rating:SetPoint("RIGHT", row.favCount, "LEFT", -6, 0)
		row.rating:SetJustifyH("RIGHT")

		row.extra = Label(row, "GameFontDisableSmall")
		row.extra:SetPoint("BOTTOMRIGHT", -6, 6)
		row.extra:SetJustifyH("RIGHT")

		-- «собрано» — полоской под иконкой: зелёная часть — собранные облики
		row.bar = row:CreateTexture(nil, "OVERLAY")
		row.bar:SetPoint("TOPLEFT", row.icon, "BOTTOMLEFT", 0, -1)
		row.bar:SetSize(36, 3)
		row.bar:SetColorTexture(0, 0, 0, 0.7)
		row.barFill = row:CreateTexture(nil, "OVERLAY", nil, 1)
		row.barFill:SetPoint("TOPLEFT", row.bar, "TOPLEFT")
		row.barFill:SetHeight(3)
		row.barFill:SetColorTexture(0.25, 1, 0.25, 0.9)
		row:SetScript("OnEnter", function(r)
			if not r.setId then return end
			local set = TH:GetSet(r.setId)
			if not set then return end
			local have, total = TH:GetCollectedStats(set)
			GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
			GameTooltip:SetText(TH:SetName(set) or "")
			if total > 0 then GameTooltip:AddLine(string.format(L["Собрано обликов: %d из %d"], have, total), 1, 1, 1) end
			GameTooltip:AddLine(L["ЛКМ — показать, ПКМ — меню"], 0.6, 0.6, 0.6)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)

		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(r, mouse)
			self:Select(r.setId)
			if mouse == "RightButton" then self:OpenSetMenu(r, r.setId) end
		end)
		self.rows[i] = row
	end

	-- зазор между вкладками: у кнопок игры скруглённые края, при 2 px они выглядят слипшимися
	local TAB_GAP = 5
	-- сортировка: кнопки над списком, выбранная подсвечена; справа кубик — перемешать.
	-- Кнопки подгоняются под текст (PadButton), поэтому каждая цепляется к предыдущей
	self.sortTabs = {}
	local prev
	for i, sort in ipairs(SORTS) do
		local b = Button(list, sort.text, 40, 22)
		local fs = b:GetFontString()
		if fs then fs:SetFontObject(GameFontNormalSmall) end
		b:SetText(sort.text) -- пересчитать ширину под мелкий шрифт
		if prev then
			b:SetPoint("LEFT", prev, "RIGHT", TAB_GAP, 0)
		else
			b:SetPoint("TOPLEFT", 8, -6)
		end
		prev = b
		b.key = sort.key
		b:SetScript("OnClick", function()
			-- «Рекомендуемые» ещё раз — перемешать
			if sort.key == "recommended" and self:GetSort() == "recommended" then TH:Reshuffle() end
			self:SetSort(sort.key)
		end)
		b:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_TOP")
			GameTooltip:SetText(sort.text)
			GameTooltip:AddLine(sort.hint, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		self.sortTabs[i] = b
	end
	-- вкладки делят ровно место до кубика: поля одинаковые, сколько останется от текста
	local function FitSortTabs()
		local avail = 292 - 20 - 4 - TAB_GAP * (#self.sortTabs - 1)
		local widths, sum = {}, 0
		for i, b in ipairs(self.sortTabs) do
			local fs = b:GetFontString()
			local w = fs and fs.GetStringWidth and fs:GetStringWidth()
			if type(w) ~= "number" or w <= 0 then return end
			widths[i], sum = w, sum + w
		end
		local pad = math.max(4, math.floor((avail - sum) / #self.sortTabs))
		for i, b in ipairs(self.sortTabs) do
			b.thMinW, b.thExtra = 0, pad - 24 -- PadButton держит ту же ширину при смене текста
			if i < #self.sortTabs then b:SetWidth(math.floor(widths[i] + pad)) end
		end
	end
	-- при первом показе шрифт может быть ещё не загружен и ширина текста неверна:
	-- пересчитываем при каждой перерисовке списка и ещё раз через мгновение после показа
	self.FitSortTabs = FitSortTabs
	FitSortTabs()
	list:HookScript("OnShow", function()
		FitSortTabs()
		C_Timer.After(0.1, FitSortTabs)
	end)
	self.shuffleBtn = CreateFrame("Button", nil, list)
	self.shuffleBtn:SetSize(20, 20)
	-- правый край — вровень со строками списка (они кончаются на 8 + 292)
	self.shuffleBtn:SetPoint("TOPLEFT", 8 + 292 - 20, -7)
	self.shuffleBtn:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Up")
	self.shuffleBtn:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Down")
	self.shuffleBtn:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Dice-Highlight", "ADD")
	self.shuffleBtn:SetScript("OnClick", function()
		TH:Reshuffle()
		self:SetSort("recommended")
	end)
	Tip(self.shuffleBtn, L["Перемешать"], L["Показать рекомендуемые новые образы в другом случайном порядке."])
	-- последняя вкладка растянута между соседкой и кубиком: на кубик она не залезет,
	-- даже если ширина текста посчитается неверно (шрифт ещё не загружен)
	local last = self.sortTabs[#self.sortTabs]
	last:ClearAllPoints()
	last:SetPoint("LEFT", self.sortTabs[#self.sortTabs - 1], "RIGHT", TAB_GAP, 0)
	last:SetPoint("RIGHT", self.shuffleBtn, "LEFT", -4, 0)
	-- в разделах без сортировки на этом месте — заголовок
	self.listTitle = Label(list, "GameFontNormal", 180)
	self.listTitle:SetPoint("TOPLEFT", 12, -10)

	-- «Мои»: свой профиль (там же смена аватара)
	self.avatarBtn = Button(list, L["Мой профиль"], 110, 22)
	self.avatarBtn:SetPoint("TOPRIGHT", -10, -5)
	self.avatarBtn:SetScript("OnClick", function() self:OpenProfile(TH.Net.Me()) end)
	self.avatarBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Мой профиль"])
		GameTooltip:AddLine(L["Как вас видят другие игроки: образы, достижения, место в рейтинге. Там же можно сменить аватар."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.avatarBtn:SetScript("OnLeave", GameTooltip_Hide)
	self.avatarIcon = list:CreateTexture(nil, "ARTWORK")
	self.avatarIcon:SetSize(22, 22)
	self.avatarIcon:SetPoint("RIGHT", self.avatarBtn, "LEFT", -4, 0)

	-- «Подписки»: список авторов — быстро открыть профиль
	-- «Подписки»: на месте кубика — авторы (профиль, уведомления, отписка)
	self.authorsBtn = CreateFrame("Button", nil, list)
	self.authorsBtn:SetAllPoints(self.shuffleBtn)
	self.authorsBtn.icon = self.authorsBtn:CreateTexture(nil, "ARTWORK")
	self.authorsBtn.icon:SetAllPoints()
	self.authorsBtn.icon:SetTexture("Interface\\Icons\\INV_Misc_GroupNeedMore")
	self.authorsBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	self.authorsBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	self.authorsBtn.thLogKey = "Авторы подписок"
	self.authorsBtn:SetScript("OnClick", function(b)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		MenuUtil.CreateContextMenu(b, function(_, root)
			local list = TH:GetFollowingList()
			root:CreateTitle(#list > 0 and string.format(L["Подписки (%d)"], #list) or L["Вы ни на кого не подписаны"])
			for _, name in ipairs(list) do
				local mutual = TH:FollowsMe(name)
				local muted = TH:IsFollowMuted(name)
				local sub = root:CreateButton(name:gsub("%-.*", "") .. (mutual and L["  |cff40ff40взаимно|r"] or "")
					.. (muted and L["  |cff888888без уведомлений|r"] or ""))
				sub:CreateButton(L["Открыть профиль"], function() self:OpenProfile(name) end)
				sub:CreateCheckbox(L["Уведомления от автора"], function() return not TH:IsFollowMuted(name) end,
					function() TH:SetFollowMuted(name, not TH:IsFollowMuted(name)) end)
				sub:CreateButton(L["Отписаться"], function() TH:SetFollowing(name, false) end)
			end
		end)
	end)
	Tip(self.authorsBtn, L["Авторы"], L["На кого вы подписаны: открыть профиль, включить или выключить уведомления от автора, отписаться. «взаимно» — он тоже подписан на вас."])

	-- «Модерация»: управление — модераторы (только админ) и снятие наказаний
	self.modsBtn = Button(list, L["Управление"], 110, 22)
	self.modsBtn:SetPoint("TOPRIGHT", -10, -5)
	self.modsBtn:SetScript("OnClick", function(b)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		local admin = TH:IsAdmin(TH.Net.Me())
		MenuUtil.CreateContextMenu(b, function(_, root)
			if admin then
				root:CreateTitle(L["Модераторы"])
				local list = TH:GetModeratorList()
				if #list == 0 then root:CreateTitle(L["|cff888888пока никого|r"]) end
				for _, e in ipairs(list) do
					local sub = root:CreateButton(e[1]:gsub("%-.*", "") .. "  |cff888888" .. e[2] .. "|r")
					sub:CreateButton(L["Снять с модераторов"], function() TH:SetModerator(e[1], false) end)
				end
				root:CreateButton(L["Назначить модератора..."], function() StaticPopup_Show("TRANSMOGHUB_ADD_MOD") end)
				root:CreateDivider()
			end
			root:CreateButton(L["Снять наказание за занижение..."], function() StaticPopup_Show("TRANSMOGHUB_LIFT_PENALTY") end)
			root:CreateButton(L["Снять бан за рекламу..."], function() StaticPopup_Show("TRANSMOGHUB_UNBAN") end)
			root:CreateDivider()
			root:CreateButton(L["Снять все ограничения (амнистия)..."], function() StaticPopup_Show("TRANSMOGHUB_AMNESTY") end)
			-- для проверки наказаний на своих персонажах
			root:CreateButton(L["Снять все ограничения с себя (проверка)"], function()
				for name in pairs(TH.db.myChars) do TH:ModDecision("r", name) end
			end)
		end)
	end)
	Tip(self.modsBtn, L["Управление"], L["Админ назначает и снимает модераторов. Модераторы разбирают жалобы и могут снять наказание за занижение оценок, если оно ошибочное."])

	-- список листается колесом мыши и ползунком; внизу — какие образы сейчас видны
	self.pageText = Label(list, "GameFontHighlightSmall")
	self.pageText:SetPoint("BOTTOM", 0, 14)

	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta) self:Scroll(-delta) end)
	self.listBar = TH.CreateScrollBar(list, function(value)
		self.offset = value
		self:RefreshList()
	end)
	self.listBar:SetPoint("TOPLEFT", 8 + 292 + 4, -LIST_TOP - 18)
	self.listBar:SetHeight(ROWS * ROW_H - 2 - 36)

	self.emptyText = Label(list, "GameFontDisable", 280)
	self.emptyText:SetPoint("CENTER", 0, 30)
	self.emptyText:SetJustifyH("CENTER")
	-- в пустом списке — сразу действие
	self.emptyBtn = Button(list, L["Новый образ"], 180, 24)
	StylePrimary(self.emptyBtn)
	self.emptyBtn:SetPoint("TOP", self.emptyText, "BOTTOM", 0, -14)
	self.emptyBtn:SetScript("OnClick", function() TH:OpenSaveDialog() end)
end

function UI:BuildPreview(panel)
	self.model = TH:CreatePreview(panel)
	self.model.scene:SetPoint("TOPLEFT", 4, -4)
	self.model.scene:SetPoint("BOTTOMRIGHT", -4, 88) -- ниже — оценка и кнопки

	local hint = Label(panel, "GameFontDisableSmall", 280)
	hint:SetPoint("TOP", 0, -8)
	hint:SetJustifyH("CENTER")
	hint:SetText(L["ЛКМ — вращать, колесо — приблизить, двойной клик — сброс"])

	-- поза модели и фотостудия — в нижних углах сцены
	self.poseBtn = FlatButton(panel, L["Поза"])
	self.poseBtn:SetPoint("BOTTOMLEFT", self.model.scene, "BOTTOMLEFT", 2, 2)
	self.poseBtn:SetScript("OnClick", function(b)
		local anchor = AnchorUtil and AnchorUtil.CreateAnchor and AnchorUtil.CreateAnchor("TOPLEFT", self, "TOPRIGHT", 4, 0)
		self:OpenPoseMenu(b, self.model, anchor)
	end)
	Tip(self.poseBtn, L["Поза"], L["Как стоит модель: стойки, эмоции, заклинания. Можно замереть на кадре и убрать оружие в ножны."])
	self.pauseBtn = FlatButton(panel, L["Продолжить"])
	self.pauseBtn:SetText(L["Пауза"])
	self.pauseBtn:SetPoint("LEFT", self.poseBtn, "RIGHT", 4, 0)
	self.pauseBtn:SetScript("OnClick", function(b) self:TogglePause(b, self.model) end)
	Tip(self.pauseBtn, L["Пауза"], L["Замереть на кадре"])
	self.photoBtn = FlatButton(panel, L["Фотостудия"])
	self.photoBtn:SetPoint("BOTTOMRIGHT", self.model.scene, "BOTTOMRIGHT", -2, 2)
	self.photoBtn:SetScript("OnClick", function() TH:OpenPhotoMode() end)
	Tip(self.photoBtn, L["Фотостудия"], L["Образ во весь экран на красивом фоне, без интерфейса игры: поза, ракурс, подпись и снимок экрана."])
	-- сцена с панорамированием перехватывает мышь — кнопки поверх неё
	local over = (self.model.scene:GetFrameLevel() or 1) + 100
	self.poseBtn:SetFrameLevel(over)
	self.photoBtn:SetFrameLevel(over)
	self.pauseBtn:SetFrameLevel(over)

	-- Предупреждение, если образ собран на модели другого пола
	self.sexHint = Label(panel, "GameFontNormalSmall", 280)
	self.sexHint:SetPoint("TOP", hint, "BOTTOM", 0, -4)
	self.sexHint:SetJustifyH("CENTER")
	self.sexHint:SetTextColor(1, 0.6, 0.2)

	-- одно меню расы (свой персонаж, как у автора, любая) и Wowhead
	-- две кнопки делят низ панели пополам с зазором (иначе, подгоняясь под текст, сходятся)
	self.raceBtn = Button(panel, L["Раса: свой персонаж"], 140)
	self.raceBtn:SetPoint("BOTTOMLEFT", 8, 8)
	self.raceBtn:SetPoint("BOTTOMRIGHT", panel, "BOTTOM", -2, 8)
	self.raceBtn:SetScript("OnClick", function(b) self:OpenRaceMenu(b) end)

	self.wowheadBtn = Button(panel, L["Открыть в Wowhead"], 140)
	self.wowheadBtn:SetPoint("BOTTOMRIGHT", -8, 8)
	self.wowheadBtn:SetPoint("BOTTOMLEFT", panel, "BOTTOM", 2, 8)
	self.wowheadBtn:SetScript("OnClick", function() TH:ShowWowheadLink(TH:GetSet(self.selectedId)) end)
	self.wowheadBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Примерочная Wowhead"])
		GameTooltip:AddLine(L["Строка для импорта образа в примерочную Wowhead: там можно выбрать любую расу и пол."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.wowheadBtn:SetScript("OnLeave", GameTooltip_Hide)
end

function UI:BuildDetail(panel)
	self.detailEmpty = Label(panel, "GameFontDisable", 300)
	self.detailEmpty:SetPoint("CENTER")
	self.detailEmpty:SetJustifyH("CENTER")
	self.detailEmpty:SetText(L["Выберите образ слева"])

	local c = CreateFrame("Frame", nil, panel)
	c:SetAllPoints()
	self.detail = c

	self.dName = Label(c, "GameFontNormalLarge", 300)
	self.dName:SetPoint("TOPLEFT", 10, -10)
	self.dName:SetWordWrap(false)

	self.dAuthor = Label(c, "GameFontHighlightSmall", 330)
	self.dAuthor:SetPoint("TOPLEFT", 10, -32)
	-- имя автора — ссылка на его профиль
	self.dAuthorBtn = CreateFrame("Button", nil, c)
	self.dAuthorBtn:SetPoint("TOPLEFT", self.dAuthor, "TOPLEFT", -2, 2)
	self.dAuthorBtn:SetPoint("BOTTOMRIGHT", self.dAuthor, "BOTTOMRIGHT", 2, -2)
	self.dAuthorBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	self.dAuthorBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if set and set.author then self:OpenProfile(set.author) end
	end)
	self.dAuthorBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Профиль автора"])
		GameTooltip:AddLine(L["Его образы, достижения и место в рейтинге."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.dAuthorBtn:SetScript("OnLeave", GameTooltip_Hide)

	self.dAuthorExtra = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	self.dAuthorExtra:SetWordWrap(false)

	-- подписка прямо у имени автора
	self.dFollow = CreateFrame("Button", nil, c)
	self.dFollow:SetFrameLevel((self.dAuthorBtn:GetFrameLevel() or 1) + 2)
	self.dFollow:SetHeight(16)
	self.dFollow:SetNormalFontObject("GameFontNormalSmall")
	self.dFollow:SetHighlightFontObject("GameFontHighlightSmall")
	self.dFollow:SetText(L["+ подписаться"])
	self.dFollow:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if set and set.author then TH:ToggleFollow(set.author) end
	end)
	self.dFollow:SetScript("OnEnter", function(b)
		local set = TH:GetSet(self.selectedId)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		if set and TH:IsFollowing(set.author) then
			GameTooltip:SetText(L["Вы подписаны"])
			GameTooltip:AddLine(L["Нажмите, чтобы отписаться."], 1, 1, 1, true)
		else
			GameTooltip:SetText(L["Подписаться на автора"])
			GameTooltip:AddLine(L["Его новые образы — во вкладке «Подписки» и во всплывашках."], 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	self.dFollow:SetScript("OnLeave", GameTooltip_Hide)

	self.dRating = Label(c, "GameFontHighlight", 330)
	self.dRating:SetPoint("TOPLEFT", 10, -50)
	self.dRating:SetWordWrap(false)
	-- подробности о рейтинге (чарт, проверка, официальное место) — в подсказке, чтобы строка не росла
	self.dRatingTip = CreateFrame("Frame", nil, c)
	self.dRatingTip:SetPoint("TOPLEFT", self.dRating, "TOPLEFT", 0, 2)
	self.dRatingTip:SetSize(330, 16)
	self.dRatingTip:EnableMouse(true)
	self.dRatingTip:SetScript("OnEnter", function(f)
		if not self.dRatingHint then return end
		GameTooltip:SetOwner(f, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Рейтинг"])
		for _, line in ipairs(self.dRatingHint) do GameTooltip:AddLine(line, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	self.dRatingTip:SetScript("OnLeave", GameTooltip_Hide)

	-- оценка — под примеркой, прямо под моделью: там на образ и смотрят
	local vp = self.previewPanel
	local voteLabel = Label(vp, "GameFontNormal")
	voteLabel:SetPoint("BOTTOMLEFT", vp, "BOTTOM", -118, 48)
	voteLabel:SetText(L["Ваша оценка:"])

	self.stars = {}
	for i = 1, 5 do
		local s = CreateFrame("Button", nil, vp)
		s:SetSize(24, 24)
		s:SetPoint("LEFT", voteLabel, "RIGHT", 8 + (i - 1) * 27, 0)
		s.tex = s:CreateTexture(nil, "ARTWORK")
		s.tex:SetAllPoints()
		SetStarTexture(s.tex)
		s:SetScript("OnClick", function() TH:Vote(self.selectedId, i) end)
		s:SetScript("OnEnter", function(b)
			self:PaintStars(i)
			GameTooltip:SetOwner(b, "ANCHOR_TOP")
			GameTooltip:SetText(STAR_LABELS[i])
			if i == 1 then
				GameTooltip:AddLine(L["Стражи подиума робко шепчут: а может, всё-таки двойку? Единица ранит сердце автора сильнее, чем Ледяная Скорбь."], 1, 0.6, 0.4, true)
			end
			GameTooltip:AddLine(L["Оценивайте образ, а не автора, и по-доброму: за каждым образом — чьи-то часы фарма и примерок."], 1, 1, 1, true)
			GameTooltip:AddLine(L["Как говорят жрицы Элуны: свет найдётся в каждом наряде, надо лишь присмотреться."], 0.9, 0.8, 0.5, true)
			GameTooltip:Show()
		end)
		s:SetScript("OnLeave", function()
			self:PaintStars()
			GameTooltip:Hide()
		end)
		self.stars[i] = s
	end
	self.dVoteHint = Label(vp, "GameFontDisableSmall", 280)
	self.dVoteHint:SetPoint("BOTTOM", vp, "BOTTOM", 0, 72)
	self.dVoteHint:SetJustifyH("CENTER")
	self.voteLabel = voteLabel

	self.dTags = Label(c, "GameFontHighlightSmall", 330)
	self.dTags:SetPoint("TOPLEFT", 10, -74)
	self.dTags:SetTextColor(1, 0.82, 0)
	-- клик по тегам — отметить неподходящий (автор — убрать свой)
	self.dTagsBtn = CreateFrame("Button", nil, c)
	self.dTagsBtn:SetPoint("TOPLEFT", self.dTags, "TOPLEFT", 0, 2)
	self.dTagsBtn:SetSize(330, 16)
	self.dTagsBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	self.dTagsBtn:SetScript("OnClick", function(btn)
		local set = TH:GetSet(self.selectedId)
		if set then TH:OpenTagFlagMenu(btn, set) end
	end)
	self.dTagsBtn:SetScript("OnEnter", function(btn)
		local set = TH:GetSet(self.selectedId)
		if not set then return end
		GameTooltip:SetOwner(btn, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Теги"])
		GameTooltip:AddLine(TH:IsMine(set) and L["Клик — убрать тег, который не подходит вашему образу."]
			or L["Клик — отметить тег, который не подходит образу. Если так считают несколько игроков, тег у образа погаснет: по нему образ перестанет находиться и не получит за него мест."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.dTagsBtn:SetScript("OnLeave", GameTooltip_Hide)

	self.dDesc = Label(c, "GameFontDisableSmall", 330)
	self.dDesc:SetPoint("TOPLEFT", 10, -92)
	self.dDesc:SetMaxLines(2)

	self.slotRows = {}
	for i, entry in ipairs(TH.DETAIL_SLOTS) do
		local slot = entry.slot
		local r = CreateFrame("Frame", nil, c)
		r:SetSize(330, SLOT_ROW_H)
		r:EnableMouse(true)
		r.entry = entry

		r.icon = r:CreateTexture(nil, "ARTWORK")
		r.icon:SetSize(16, 16)
		r.icon:SetPoint("LEFT")

		r.slot = Label(r, "GameFontDisableSmall", 58)
		r.slot:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
		r.slot:SetWordWrap(false)
		r.slot:SetText(entry.label or slot.short or slot.label)

		r.check = r:CreateTexture(nil, "ARTWORK")
		r.check:SetSize(14, 14)
		r.check:SetPoint("RIGHT")

		-- источник вещи — значком, подробности в подсказке строки
		r.source = r:CreateTexture(nil, "ARTWORK")
		r.source:SetSize(14, 14)
		r.source:SetPoint("RIGHT", r.check, "LEFT", -4, 0)

		r.text = Label(r, "GameFontHighlightSmall")
		r.text:SetPoint("LEFT", r.slot, "RIGHT", 2, 0)
		r.text:SetPoint("RIGHT", r.source, "LEFT", -4, 0)
		r.text:SetWordWrap(false)

		r:SetScript("OnEnter", function(f) self:ShowSlotTooltip(f) end)
		r:SetScript("OnMouseUp", function(f, mouse)
			if mouse == "RightButton" then self:OpenItemMenu(f) end
		end)
		r:SetScript("OnLeave", GameTooltip_Hide)
		self.slotRows[i] = r
	end

	self.dCollected = Label(c, "GameFontHighlight", 330)

	self.dStatus = Label(c, "GameFontHighlightSmall", 330)
	self.dStatus:SetPoint("TOPLEFT", self.dCollected, "BOTTOMLEFT", 0, -6)

	-- избранное — звёздочка у названия, как в списке
	self.dFav = CreateFrame("Button", nil, c)
	self.dFav:SetSize(22, 22)
	self.dFav:SetPoint("TOPRIGHT", -8, -8)
	self.dFav.tex = self.dFav:CreateTexture(nil, "ARTWORK")
	self.dFav.tex:SetAllPoints()
	SetStarTexture(self.dFav.tex)
	self.dFav:SetScript("OnClick", function() TH:ToggleFavorite(self.selectedId) end)
	self.dFav:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:SetText(TH.db.favorites[self.selectedId] and L["Убрать из избранного"] or L["В избранное"])
		local n = self.selectedId and TH:GetFavoriteCount(self.selectedId) or 0
		if n > 0 then GameTooltip:AddLine(L["В избранном у игроков: "] .. n, 1, 1, 1) end
		GameTooltip:Show()
	end)
	self.dFav:SetScript("OnLeave", GameTooltip_Hide)

	self.publishBtn = Button(c, L["Опубликовать"], 110)
	self.publishBtn:SetPoint("BOTTOMLEFT", 10, 10)
	self.publishBtn:SetScript("OnClick", function()
		local mine = TH.db.mySets[self.selectedId]
		if mine and mine.renameRequired then return TH:AskRename(self.selectedId) end
		TH:Publish(self.selectedId)
	end)

	self.deleteBtn = Button(c, L["Удалить"], 70)
	self.deleteBtn:SetPoint("LEFT", self.publishBtn, "RIGHT", 6, 0)
	self.deleteBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if not set then return end
		local extra = set.serverId and L["\n\nОбраз будет снят с публикации."] or ""
		StaticPopup_Show("TRANSMOGHUB_DELETE", TH:SetName(set), extra, set.id)
	end)

	-- Кнопки модератора (вместо обычных на вкладке «Модерация»)
	-- два ряда по две кнопки, по ширине панели
	local MOD_W = 160
	self.modSetBtn = Button(c, L["Нарушение..."], MOD_W)
	self.modSetBtn:SetPoint("BOTTOMLEFT", 10, 38)
	self.modSetBtn:SetScript("OnClick", function(b)
		local set = TH:GetSet(self.selectedId)
		if not set then return end
		if TH.db.net.modBlocks.sets[set.id] then return TH:ModDecision("u", set.id) end
		-- что за нарушение, решает модератор: от этого зависит наказание автора
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return TH:ModDecision("s", set.id) end
		MenuUtil.CreateContextMenu(b, function(_, root)
			root:CreateTitle(L["Что не так с образом?"])
			local warned = TH:GetRenameWarning(set.author)
			root:CreateButton(warned and warned ~= set.id and L["Название в шутку, повторно: 14 дней без публикаций"]
				or L["Название в шутку: попросить переименовать"], function() TH:ModDecision("e", set.id) end)
			root:CreateButton(L["Оскорбление: 14 дней без публикаций"], function() TH:ModDecision("o", set.id) end)
			root:CreateButton(L["Реклама: бан автора"], function()
				TH:ModDecision("s", set.id)
				if set.author then TH:ModDecision("b", set.author) end
			end)
			root:CreateDivider()
			root:CreateButton(L["Другое: просто скрыть образ"], function() TH:ModDecision("s", set.id) end)
		end)
	end)
	self.modAuthorBtn = Button(c, L["Блок. автора"], MOD_W)
	self.modAuthorBtn:SetPoint("LEFT", self.modSetBtn, "RIGHT", 4, 0)
	self.modAuthorBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if set and set.author then TH:ModDecision(TH.db.net.modBlocks.authors[set.author] and "v" or "a", set.author) end
	end)
	self.modDismissBtn = Button(c, L["Жалобы ложные"], MOD_W)
	self.modDismissBtn:SetPoint("BOTTOMLEFT", 10, 10)
	self.modDismissBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if not set then return end
		if self.modVotesMode then
			-- оценки проверены, накрутки нет: образ возвращается в чарт
			TH:VerifyVotes(set.id)
			self.selectedId = nil
			return self:Refresh()
		end
		TH.db.modDismissed[set.id] = TH.Net.Now()
		TH:LogDecision("d", set.id)
		self.selectedId = nil
		self:Refresh()
	end)
	-- без решения: убрать из списка, ничего не блокируя и не засчитывая ложных жалоб
	self.modSkipBtn = Button(c, L["Без решения"], MOD_W)
	self.modSkipBtn:SetPoint("LEFT", self.modDismissBtn, "RIGHT", 4, 0)
	self.modSkipBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if not set then return end
		TH.db.modDismissed[set.id] = TH.Net.Now()
		TH:LogDecision("n", set.id)
		self.selectedId = nil
		self:Refresh()
	end)
end

-- Имя персонажа «Имя-Сервер» (без сервера — ваш сервер)
local function NamePopup(text, onAccept)
	return {
		text = text, button1 = ACCEPT or L["Принять"], button2 = CANCEL or L["Отмена"], hasEditBox = true, maxLetters = 64,
		OnAccept = function(dialog)
			local eb = dialog.EditBox or dialog.editBox
			onAccept(eb and eb:GetText() or "")
		end,
		EditBoxOnEnterPressed = function(eb)
			onAccept(eb:GetText() or "")
			eb:GetParent():Hide()
		end,
		timeout = 0, whileDead = true, hideOnEscape = true,
	}
end
StaticPopupDialogs["TRANSMOGHUB_ADD_MOD"] = NamePopup(L["Назначить модератором персонажа (ник; мир — если другой):"],
	function(name) TH:SetModerator(name, true) end)
StaticPopupDialogs["TRANSMOGHUB_LIFT_PENALTY"] = NamePopup(L["Снять наказание за занижение оценок с персонажа (ник; мир — если другой):"],
	function(name)
		local known, matches
		name, known, matches = TH:ResolvePlayerName(name)
		if not name then return end
		if not known then
			TH:Notify(L["|cffff9020Игрок «"] .. name .. L["» аддону не встречался|r"] .. (matches and #matches > 1
				and (L[" (похожие: "] .. table.concat(matches, ", ") .. ")") or "") .. L[" — проверьте имя. Решение всё равно отправлено."])
		end
		TH:ModDecision("w", name)
		TH:Notify(L["Наказание снято: "] .. name .. L[". Дойдёт, когда игрок будет в сети."])
	end)

StaticPopupDialogs["TRANSMOGHUB_UNBAN"] = NamePopup(L["Снять бан за рекламу с персонажа (ник; мир — если другой):"],
	function(name)
		local known, matches
		name, known, matches = TH:ResolvePlayerName(name)
		if not name then return end
		if not known then
			TH:Notify(L["|cffff9020Игрок «"] .. name .. L["» аддону не встречался|r"] .. (matches and #matches > 1
				and (L[" (похожие: "] .. table.concat(matches, ", ") .. ")") or "") .. L[" — проверьте имя. Решение всё равно отправлено."])
		end
		TH:ModDecision("y", name)
		TH:Notify(L["Бан снят: "] .. name .. L[". Дойдёт до тех, кто сейчас в сети; насовсем — с обновлением чёрного списка."])
	end)

StaticPopupDialogs["TRANSMOGHUB_AMNESTY"] = NamePopup(L["Снять ВСЕ ограничения с персонажа (ник; мир — если другой): бан, блокировки, запрет на публикацию, пометку за шутку, наказание за занижение:"],
	function(name)
		local known, matches
		name, known, matches = TH:ResolvePlayerName(name)
		if not name then return end
		if not known then
			TH:Notify(L["|cffff9020Игрок «"] .. name .. L["» аддону не встречался|r"] .. (matches and #matches > 1
				and (L[" (похожие: "] .. table.concat(matches, ", ") .. ")") or "") .. L[" — проверьте имя. Решение всё равно отправлено."])
		end
		TH:ModDecision("r", name)
		TH:Notify(L["Амнистия: "] .. name .. L[". Дойдёт, когда игрок будет в сети; из чёрного списка уберёт ежедневный разбор."])
	end)

StaticPopupDialogs["TRANSMOGHUB_UNDO_REPORTS"] = {
	text = L["Вернуть все скрытые вами образы и игроков рейтинга, отозвать жалобы этого персонажа и отметки «тег не подходит»?"],
	button1 = ACCEPT or L["Да"], button2 = CANCEL or L["Отмена"],
	OnAccept = function() TH:UndoMyReports() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Новое название вместо шуточного (просьба Стражей подиума)
StaticPopupDialogs["TRANSMOGHUB_RENAME_SET"] = {
	text = L["Новое название для образа «%s»:"],
	button1 = L["Переименовать"], button2 = CANCEL or L["Отмена"], hasEditBox = true, maxLetters = 48,
	OnShow = function(dialog)
		local eb = dialog.EditBox or dialog.editBox
		if eb then eb:SetText(""); eb:SetFocus() end
	end,
	OnAccept = function(dialog, localId)
		local eb = dialog.EditBox or dialog.editBox
		local err = TH:RenameViolatedSet(localId, eb and eb:GetText() or "")
		if err then
			TH:Notify(err)
			C_Timer.After(0.1, function() TH:AskRename(localId) end)
		end
	end,
	EditBoxOnEnterPressed = function(eb)
		local dialog = eb:GetParent()
		local localId = dialog.data
		dialog:Hide()
		local err = TH:RenameViolatedSet(localId, eb:GetText() or "")
		if err then
			TH:Notify(err)
			C_Timer.After(0.1, function() TH:AskRename(localId) end)
		end
	end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

StaticPopupDialogs["TRANSMOGHUB_RELOAD_STYLE"] = {
	text = L["Оформление Transmog Hub: %s.\nПерезагрузить интерфейс сейчас?"],
	button1 = L["Перезагрузить"],
	button2 = L["Позже"],
	OnAccept = function() ReloadUI() end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

-- Переключить оформление: сейчас в стиле EllesmereUI — станет обычным, и наоборот
function TH:ToggleStyle()
	self.db.style = self:IsSkinned() and "blizzard" or "eui"
	StaticPopup_Show("TRANSMOGHUB_RELOAD_STYLE", self.db.style == "eui" and L["в стиле EllesmereUI"] or L["обычное"])
end

StaticPopupDialogs["TRANSMOGHUB_DELETE"] = {
	text = L["Удалить образ «%s»?%s"],
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, localId) TH:DeleteMySet(localId) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

---------------------------------------------------------------------------
-- Действия
---------------------------------------------------------------------------
-- Первое открытие: короткий тур по окну (справка — в последнем шаге)
function UI:ShowFirstRunHelp()
	if TH.db and not TH.db.tourDone and not TH:IsExiled() then
		TH.db.helpShown = true
		C_Timer.After(0.3, function() TH:StartTour() end)
	end
end

function UI:Toggle()
	if not self.built then self:Build() end
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
		self:Refresh()
		self:ShowFirstRunHelp()
	end
end

-- Открыть окно (если закрыто)
function UI:Open()
	if not self.built then self:Build() end
	if not self:IsShown() then self:Toggle() end
end

function UI:SetView(key)
	self.view = key
	-- список гильдии игра присылает по запросу
	if key == "guild" and C_GuildInfo and C_GuildInfo.GuildRoster then C_GuildInfo.GuildRoster() end
	self.offset = 0
	self.selectedId = nil
	local profile = key == "profile"
	local ach = key == "achievements" or profile -- панели во всю ширину
	self.achPanel:SetShown(key == "achievements")
	self.profilePanel:SetShown(profile)
	self.listPanel:SetShown(not ach)
	self.previewPanel:SetShown(not ach)
	self.detailPanel:SetShown(not ach)
	self.tagsBtn:SetShown(not ach)

	self.search:SetShown(not profile)
	if ach then
		self.tagsReset:Hide()
		if self.tagFrame then self.tagFrame:Hide() end
	end
	self:Refresh()
end

-- Профиль автора; «Назад» возвращает туда, откуда пришли
function UI:OpenProfile(name)
	if not name then return end
	if not self.built then self:Build() end
	if not self:IsShown() then self:Toggle() end
	if self.view ~= "profile" then self.prevView, self.prevSelected = self.view, self.selectedId end
	self.profileName = name
	self:SetView("profile")
end

function UI:CloseProfile()
	local view, selected = self.prevView or "top", self.prevSelected
	self:SetView(view)
	if selected and TH:GetSet(selected) then self:Select(selected) end
end

-- Образы одного автора в обычном списке
function UI:ShowAuthorSets(name, setId)
	self.authorFilter = name
	self:SetView("author")
	if setId then self:Select(setId) end
end

function UI:OpenAchievements()
	if not self.built then self:Build() end
	if not self:IsShown() then self:Toggle() end
	self:SetView("achievements")
end

function UI:RefreshAchievements()
	if self.built and self:IsShown() and self.view == "achievements" then
		TH:RefreshAchievementsPanel(self.achPanel)
	end
end

StaticPopupDialogs["TRANSMOGHUB_REPORT"] = {
	text = L["Скрыть образ «%s»?\n\nОн пропадёт только у вас. Вернуть все скрытые: /thub unhide"],
	button1 = L["Скрыть"],
	button2 = CANCEL,
	OnAccept = function(_, setId) TH:HideSet(setId) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Меню по ПКМ на образе в списке
function UI:OpenSetMenu(owner, setId)
	local set = TH:GetSet(setId)
	if not set or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	-- свой образ: в списке «Образы» у него id из сети, а сохранён он под своим
	local mine = TH.db.mySets[set.id]
	if not mine then
		for _, m in pairs(TH.db.mySets) do
			if m.serverId == set.id then mine = m break end
		end
	end
	local own = mine ~= nil or TH:IsMine(set)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(TH:SetName(set) or L["Образ"])

		root:CreateButton(TH.db.favorites[set.id] and L["Убрать из избранного"] or L["В избранное"],
			function() TH:ToggleFavorite(set.id) end)
		root:CreateButton(L["Открыть в Wowhead"], function() TH:ShowWowheadLink(set) end)
		root:CreateButton(L["Поделиться в чате"], function() TH:ShareSet(set) end)
		if set.author then
			root:CreateButton(L["Профиль автора"], function() self:OpenProfile(set.author) end)
			if not TH.db.myChars[set.author] then
				root:CreateButton(TH:IsFollowing(set.author) and L["Отписаться от автора"] or L["Подписаться на автора"],
					function() TH:ToggleFollow(set.author) end)
			end
		end

		if TH:CanVote(set) then
			local rate = root:CreateButton(L["Оценить"])
			for stars = 5, 1, -1 do
				rate:CreateRadio(string.rep(CreateAtlasMarkup("PetJournal-FavoritesIcon", 14, 14), stars),
					function() return TH.db.myVotes[set.id] == stars end,
					function() TH:Vote(set.id, stars) end)
			end
		end

		if mine then
			if mine.renameRequired then
				root:CreateButton(L["|cffff9020Переименовать|r"], function() TH:AskRename(set.id) end)
			end
			if mine.status == "draft" or mine.status == "rejected" then
				root:CreateButton(L["Опубликовать"], function() TH:Publish(set.id) end)
				-- у опубликованного иконку уже не поменять: другие игроки получили образ
				root:CreateButton(L["Сменить иконку"], function()
					TH:OpenIconPicker({ current = mine.icon, tags = mine.tags, items = mine.items,
						onPick = function(fileID)
							mine.icon = fileID
							TH:NotifyChanged()
						end })
				end)
			end
			root:CreateButton(L["|cffff6060Удалить|r"], function()
				local extra = mine.serverId and L["\n\nОбраз будет снят с публикации."] or ""
				StaticPopup_Show("TRANSMOGHUB_DELETE", mine.name, extra, mine.id)
			end)
		elseif not own and not TH:IsTestId(set.id) and not TH:IsLocalId(set.id) then
			local report = root:CreateButton(L["Пожаловаться"])
			for _, reason in ipairs(TH.REPORT_REASONS) do
				report:CreateButton(reason.label, function()
					-- «Другое» — сначала спросим, что не так
					if reason.key == "x" then TH:OpenReportOther(set) else TH:Report(set.id, reason.key) end
				end)
			end
			-- неподходящий тег — не жалоба на образ, а отметка тега (см. «тег не подходит»)
			if set.tags and #set.tags > 0 then
				local wrong = report:CreateButton(L["Неподходящие теги"])
				for _, key in ipairs(set.tags) do
					if TH.TAG_LABEL[key] then
						wrong:CreateCheckbox(TH.TAG_LABEL[key], function() return TH:IsTagFlaggedByMe(set, key) end,
							function() TH:ToggleTagFlag(set, key) end)
					end
				end
			end
			root:CreateButton(L["Скрыть образ"], function()
				StaticPopup_Show("TRANSMOGHUB_REPORT", TH:SetName(set), nil, set.id)
			end)
		end
	end)
end

function UI:Scroll(delta)
	local maxOffset = math.max(0, #(self.results or {}) - ROWS)
	self.offset = Clamp(self.offset + delta, 0, maxOffset)
	self:RefreshList()
end

function UI:Select(id)
	self.selectedId = id
	if id then TH:TrackViewed(TH:GetSet(id)) end
	self:RefreshList()
	self:RefreshDetail()
end

function UI:SetRace(raceID)
	self.raceID = raceID
	if raceID then
		TH:TrackRaceTried(raceID)
		TH:CheckAchievements()
	end
	self.raceBtn:SetText(raceID and (L["Раса: "] .. TH:GetRaceName(raceID)) or L["Раса: свой персонаж"])
	-- длинное название расы — мельче, чтобы влезло в половину панели
	local fs = self.raceBtn:GetFontString()
	if fs and fs.GetStringWidth then
		fs:SetFontObject(GameFontNormal)
		local w, bw = fs:GetStringWidth(), self.raceBtn:GetWidth()
		if type(w) == "number" and type(bw) == "number" and w > bw - 12 then fs:SetFontObject(GameFontNormalSmall) end
	end
	self.model:SetRace(raceID)
end

-- Меню поз для модели (предпросмотр или фотостудия)
-- Меню открывается у anchor (сбоку от окна), а не у курсора — чтобы не закрывать модель
local function OpenMenuAt(owner, anchor, generator)
	if anchor and Menu and Menu.GetManager and MenuUtil.CreateRootMenuDescription and MenuVariants and Menu.PopulateDescription then
		local ok = pcall(function()
			local desc = MenuUtil.CreateRootMenuDescription(MenuVariants.GetDefaultContextMenuMixin())
			Menu.PopulateDescription(generator, owner, desc)
			Menu.GetManager():OpenMenu(owner, desc, anchor)
		end)
		if ok then return end
	end
	MenuUtil.CreateContextMenu(owner, generator)
end

-- anchor — куда поставить меню (nil — у курсора)
function UI:OpenPoseMenu(owner, preview, anchor)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	OpenMenuAt(owner, anchor, function(_, root)
		if root.SetGridMode and MenuConstants and MenuConstants.VerticalGridDirection then
			root:SetGridMode(MenuConstants.VerticalGridDirection, 2) -- две колонки — меню вдвое ниже
		end
		for _, pose in ipairs(TH.POSES) do
			root:CreateRadio(pose.name, function() return (preview.poseKey or "stand") == pose.key end,
				function() preview:SetPose(pose.key, preview.freeze, preview.sheathe) end)
		end
		root:CreateCheckbox(L["Оружие в ножнах"], function()
			local pose = TH.POSE_BY_KEY[preview.poseKey or "stand"]
			if preview.sheathe == nil then return not (pose and pose.arms) end
			return preview.sheathe
		end, function()
			local pose = TH.POSE_BY_KEY[preview.poseKey or "stand"]
			local cur = preview.sheathe
			if cur == nil then cur = not (pose and pose.arms) end
			preview.sheathe = not cur
			preview:ApplyPose()
		end)
	end)
end

-- Кнопка паузы: замереть на кадре / продолжить
function UI:TogglePause(button, preview)
	preview:SetFrozen(not preview.freeze)
	button:SetText(preview.freeze and L["Продолжить"] or L["Пауза"])
end

function UI:OpenRaceMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		if root.SetScrollMode then root:SetScrollMode(400) end
		root:CreateTitle(L["Примерить на расу"])
		root:CreateRadio(L["Свой персонаж"],
			function() return self.raceID == nil end,
			function() self:SetRace(nil) end)
		local set = TH:GetSet(self.selectedId)
		if set and set.race and set.race ~= select(3, UnitRace("player")) then
			root:CreateRadio(L["Как у автора: "] .. TH:GetRaceName(set.race),
				function() return self.raceID == set.race end,
				function() self:SetRace(set.race) end)
		end
		root:CreateDivider()
		for _, race in ipairs(TH:GetPlayableRaces()) do
			root:CreateRadio(race.name,
				function() return self.raceID == race.id end,
				function() self:SetRace(race.id) end)
		end
	end)
end

-- Окно фильтра по тегам: поиск, популярные сверху, рядом число образов
function UI:OpenTagMenu(owner)
	local f = self.tagFrame
	if not f then
		f = CreateFrame("Frame", nil, self, "BasicFrameTemplateWithInset")
		f:SetFrameStrata("DIALOG")
		f:SetToplevel(true)
		f:EnableMouse(true)
		local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText(L["Фильтр по тегам"])

		f.picker = TH:CreateTagPicker(f, { cols = 3, rows = 11, colW = 165,
			onChange = function()
				self.offset = 0
				self:Refresh()
			end })
		f.picker.selected = self.filter.tags -- общий с фильтром списка
		f.picker:SetPoint("TOPLEFT", 12, -30)
		f:SetSize(f.picker.width + 20, f.picker.height + 72)
		f:Hide()

		local suggest = Button(f, L["Предложить тег"], 150)
		suggest:SetPoint("BOTTOMLEFT", 12, 10)
		suggest:SetScript("OnClick", function() TH:OpenSuggestTag(f.picker.search:GetText()) end)
		suggest:SetScript("OnEnter", function(b)
			GameTooltip:SetOwner(b, "ANCHOR_TOP")
			GameTooltip:SetText(L["Предложить тег"])
			GameTooltip:AddLine(L["Нужного тега нет? Предложите его: теги, которые просят многие, добавляются в обновлениях."], 1, 1, 1, true)
			GameTooltip:Show()
		end)
		suggest:SetScript("OnLeave", GameTooltip_Hide)

		local reset = Button(f, L["Сбросить"], 100)
		reset:SetPoint("BOTTOMRIGHT", -12, 10)
		reset:SetScript("OnClick", function()
			wipe(self.filter.tags)
			f.picker.search:SetText("")
			self.offset = 0
			self:Refresh()
		end)
		self.tagFrame = f
	end
	if f:IsShown() then f:Hide() return end
	f:ClearAllPoints()
	f:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
	f.picker.offset = 0
	f.picker.sort = "popular" -- каждый раз — сначала популярные
	f.picker:Refresh()
	f:Show()
	TH:SkinNow(f) -- окно создано позже главного: оформление EllesmereUI докрашиваем при показе
end

-- Меню по ПКМ на вещи в карточке образа
function UI:OpenItemMenu(row)
	if row.illusion then return end
	local det = row.sourceID and TH:GetSourceDetails(row.sourceID)
	if not det or not det.itemID or det.hidden or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	GameTooltip:Hide()
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(det.name)
		if TH.CanShowOnMap and TH:CanShowOnMap(det.itemID, row.sourceID) then
			root:CreateButton(L["Показать на карте"], function() TH:ShowOnMap(det.itemID, row.sourceID, det.name) end)
		end
		root:CreateButton(L["Ссылка на Wowhead"], function() TH:ShowItemLink(det.itemID, det.name) end)
		root:CreateButton(L["Вставить ссылку в чат"], function()
			local _, link = C_Item.GetItemInfo(det.itemID)
			if link and ChatFrameUtil and not ChatFrameUtil.InsertLink(link) then ChatFrameUtil.OpenChat(link) end
		end)
	end)
end

function UI:ShowSlotTooltip(row, refresh)
	if not row.sourceID then return end
	if not refresh then row.whereTries = 0 end
	local det = row.illusion and TH:GetIllusionDetails(row.sourceID) or TH:GetSourceDetails(row.sourceID)
	if not det then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	if det.itemID then
		GameTooltip:SetItemByID(det.itemID)
	else
		GameTooltip:SetText(det.name)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(L["Источник: "] .. (det.typeText or "?"), 1, 1, 1)
	if det.where then GameTooltip:AddLine(det.where, 0.8, 0.8, 0.8, true) end
	if not det.hidden and not det.illusion and TH.GetWhereToFind then
		local title, lines, noATT, pending = TH:GetWhereToFind(det.itemID, row.sourceID)
		-- ATT ещё загружает имена (торговцев, заданий): перерисуем, когда придут
		if pending and (row.whereTries or 0) < 10 then
			row.whereTries = (row.whereTries or 0) + 1
			C_Timer.After(0.5, function()
				if GameTooltip:IsOwned(row) then self:ShowSlotTooltip(row, true) end
			end)
		end
		if title then
			GameTooltip:AddLine(title, 1, 0.82, 0)
			for _, line in ipairs(lines) do GameTooltip:AddLine(line, 0.8, 0.8, 0.8, true) end
		elseif noATT and not (det.sourceType == 1 and det.where) then
			GameTooltip:AddLine(L["Подробнее, где искать, покажет аддон AllTheThings, если его установить."], 0.6, 0.6, 0.6, true)
		end
	end
	if not det.hidden then
		if det.collected then
			GameTooltip:AddLine(L["Облик собран"], 0.25, 1, 0.25)
		else
			GameTooltip:AddLine(L["Облик не собран"], 1, 0.25, 0.25)
		end
		if not det.illusion and TH.CanShowOnMap and TH:CanShowOnMap(det.itemID, row.sourceID) then
			GameTooltip:AddLine(L["ПКМ — метка на карте, ссылка на Wowhead"], 0.6, 0.6, 0.6)
		else
			GameTooltip:AddLine(L["ПКМ — ссылка на Wowhead"], 0.6, 0.6, 0.6)
		end
	end
	GameTooltip:Show()
	-- Сравнение с надетой вещью здесь только мешает
	if GameTooltip_HideShoppingTooltips then GameTooltip_HideShoppingTooltips(GameTooltip) end
end

---------------------------------------------------------------------------
-- Обновление
---------------------------------------------------------------------------
function UI:Refresh()
	if not self.built or not self:IsShown() then return end

	for _, b in ipairs(self.tabs) do
		local active = b.key == self.view
			or (b.key == "me" and (self.view == "mine" or (self.view == "profile" and self.profileName == TH.Net.Me())))
		if active then b:LockHighlight() else b:UnlockHighlight() end
	end
	-- изгнание: открыты только свой профиль и достижения — там видно, что исправить
	local exiled = TH:IsExiled()
	local allowed = self.view == "achievements" or (self.view == "profile" and self.profileName == TH.Net.Me())
	self.exilePanel:SetShown(exiled and not allowed)
	if exiled and not allowed then
		for _, panel in ipairs({ self.listPanel, self.previewPanel, self.detailPanel, self.achPanel, self.profilePanel }) do
			panel:Hide()
		end
		self.search:Hide()
		self.tagsBtn:Hide()
		self.tagsReset:Hide()
		TH:RefreshExilePanel(self.exilePanel)
		self:RefreshStatus()
		return
	end
	if self.view == "achievements" then
		TH:RefreshAchievementsPanel(self.achPanel, self.filter.text)
		self:RefreshStatus()
		return
	end
	if self.view == "profile" then
		TH:RefreshProfile(self.profilePanel, self.profileName)
		self:RefreshStatus()
		return
	end
	local nTags = 0
	for _ in pairs(self.filter.tags) do nTags = nTags + 1 end
	self.tagsBtn:SetText(nTags > 0 and (L["Теги ("] .. nTags .. ")") or L["Теги"])
	self.tagsReset:SetShown(nTags > 0)
	if self.tagFrame and self.tagFrame:IsShown() then self.tagFrame.picker:Refresh() end

	local sortable = SORTABLE[self.view]
	for _, b in ipairs(self.sortTabs) do
		b:SetShown(sortable)
		if b.key == self:GetSort() then b:LockHighlight() else b:UnlockHighlight() end
		b:SetText(b.key == self:GetSort() and ("|cffffffff" .. SORT_TEXT[b.key] .. "|r") or SORT_TEXT[b.key])
	end
	self.shuffleBtn:SetShown(sortable and self.view ~= "subs")
	if sortable and self.FitSortTabs then self.FitSortTabs() end
	self.listTitle:SetText(not sortable and (LIST_TITLES[self.view] or "") or "")
	self.authorsBtn:SetShown(self.view == "subs")
	self.modsBtn:SetShown(self.view == "moderation" and TH:IsModerator(TH.Net.Me()))
	local mineView = self.view == "mine"
	self.avatarBtn:SetShown(mineView)
	self.avatarIcon:SetShown(mineView)
	if mineView then
		self.avatarIcon:SetTexture(TH:GetAvatar(TH.Net.Me(), select(3, UnitRace("player")), (UnitSex("player") or 2) - 2,
			select(2, UnitClass("player"))))
	end
	self.results = TH:QuerySets(self.view, { text = self.filter.text, tags = self.filter.tags,
		author = self.view == "author" and self.authorFilter or nil, sort = sortable and self:GetSort() or nil })
	self.offset = Clamp(self.offset, 0, math.max(0, #self.results - ROWS))
	if not TH:GetSet(self.selectedId) then
		self.selectedId = self.results[1] and self.results[1].id
	end

	self:RefreshList()
	self:RefreshDetail()
	self:RefreshStatus()
end

function UI:RefreshList()
	local results = self.results or {}
	for i, row in ipairs(self.rows) do
		local set = results[self.offset + i]
		if set then
			row.setId = set.id
			row.name:SetText(TH:SetName(set) or L["Без названия"])
			row.author:SetText(set.author or "")

			row.icon:SetTexture(TH:GetSetIcon(set))

			if self.view == "mine" then
				row.rating:SetText(STATUS_TEXT[set.status] or "")
			elseif self.view == "moderation" then
				local total, by = TH:GetReportStats(set.id)
				row.rating:SetText(total > 0 and string.format(L["|cffff6060жалоб: %d|r"], total) or L["|cffff9020накрутка?|r"])
				row.author:SetText((set.author or "") .. (TH:IsBlocked(set) and L[" |cffff6060(блок)|r"] or ""))
			else
				local r = set.rating
				if r and r.n and r.n > 0 then
					-- вне чарта (мало оценок или проверка) — серым
					row.rating:SetText(string.format(TH:IsCharted(set) and "|cffffd100%.1f|r (%d)" or "|cff999999%.1f (%d)|r", r.avg, r.n))
				else
					row.rating:SetText(L["|cff999999нет оценок|r"])
				end
			end

			local fav = TH.db.favorites[set.id]
			row.fav.tex:SetDesaturated(not fav)
			row.fav.tex:SetAlpha(fav and 1 or 0.4)
			local favs = TH:GetFavoriteCount(set.id)
			row.favCount:SetText(favs > 0 and favs or "")

			local have, total = TH:GetCollectedStats(set)
			row.extra:SetText("")
			row.bar:SetShown(total > 0)
			row.barFill:SetShown(have > 0 and total > 0)
			if total > 0 then row.barFill:SetWidth(math.max(1, 36 * have / total)) end
			-- свой образ в общем списке — метка «ваш»
			if self.view ~= "mine" and self.view ~= "moderation" and TH:IsMine(set) then
				row.author:SetText((set.author or "") .. L["  |cff40ff40(ваш)|r"])
			end
			if self.view == "moderation" then
				local total, by = TH:GetReportStats(set.id)
				row.extra:SetText(total > 0 and string.format(L["р %d, о %d, д %d"], by.a, by.o, by.x)
					or string.format(L["оценок %d"], set.rating and set.rating.n or 0))
			end
			row.sel:SetShown(set.id == self.selectedId)
			row:Show()
		else
			row.setId = nil
			row:Hide()
		end
	end

	local n = #results
	self.listBar:Sync(self.offset, n - ROWS)
	local page = n > 0 and string.format(L["%d—%d из %d"], self.offset + 1, math.min(self.offset + ROWS, n), n) or ""
	if self.view == "author" then
		page = L["Образы "] .. (self.authorFilter or "?"):gsub("%-.*", "") .. (page ~= "" and (": " .. page) or "")
	end
	self.pageText:SetText(page)
	local filtered = (self.filter.text or "") ~= "" or next(self.filter.tags) ~= nil
	self.emptyText:SetText(filtered and L["По вашему запросу ничего нет.\n\nПопробуйте другие слова или сбросьте теги."]
		or (self.view == "guild" and not TH:GetGuildNames() and L["Вы не состоите в гильдии."])
		or (self.view == "top" and (self:GetSort() == "top" or self:GetSort() == "trending")
			and string.format(L["В чарте пока пусто: ни один образ не набрал %d оценок.\n\nСвежие образы — во вкладке «Новые»:\nоцените их, и лучшие попадут сюда."], TH:GetMinChartVotes()))
		-- друзья, гильдия, подписки: в «Лучших» только чарт, как в «Образах»
		or ((self.view == "friends" or self.view == "guild" or self.view == "subs")
			and (self:GetSort() == "top" or self:GetSort() == "trending")
			and #TH:QuerySets(self.view, { sort = "new" }) > 0
			and string.format(L["Здесь, как и в «Образах», только образы из чарта\n(от %d оценок) — таких пока нет.\n\nОстальные — во вкладке «Новые»."], TH:GetMinChartVotes()))
		or EMPTY_TEXT[self.view] or EMPTY_TEXT.default)
	self.emptyText:SetShown(n == 0)
	self.emptyBtn:SetShown(n == 0 and not filtered and (self.view == "top" or self.view == "mine"))
end

function UI:PaintStars(hover)
	local set = TH:GetSet(self.selectedId)
	local value = hover or (set and TH.db.myVotes[set.id]) or 0
	local canVote = set and TH:CanVote(set)
	for i, s in ipairs(self.stars) do
		local on = i <= value
		s.tex:SetDesaturated(not on)
		s.tex:SetAlpha(on and 1 or 0.35)
		s:SetEnabled(canVote and true or false)
	end
end

function UI:RefreshDetail()
	local set = TH:GetSet(self.selectedId)
	self.detail:SetShown(set ~= nil)
	self.detailEmpty:SetShown(set == nil)
	-- оценка под примеркой — только когда выбран образ
	self.voteLabel:SetShown(set ~= nil)
	for _, s in ipairs(self.stars) do s:SetShown(set ~= nil) end
	if not set then self.dVoteHint:SetText("") end
	if not set then
		if self.model.items then self.model:SetItems(nil) end
		self.sexHint:SetText("")
		self.wowheadBtn:SetEnabled(false)
		return
	end

	self.dName:SetText(TH:SetName(set) or L["Без названия"])
	local who = set.author or "?"
	if set.race then who = who .. ", " .. TH:GetRaceName(set.race) end
	if set.sex then who = who .. ", " .. TH:SexLabel(set.sex) end
	local author = set.author or "?"
	local extra = who:sub(#author + 1)
	-- ширина «Автор: Имя» — за ней ставим «подписаться», а раса и класс — после ссылки
	self.dAuthor:SetText(L["Автор: "] .. author)
	local nameW = self.dAuthor:GetStringWidth() or 0
	self.dAuthor:SetText(L["Автор: |cff69ccf0"] .. author .. "|r")
	self.dAuthorExtra:SetText((extra:gsub("^, ", "")))
	self.dAuthorBtn:SetShown(set.author ~= nil)
	local canFollow = set.author ~= nil and not TH.db.myChars[set.author] and not TH:IsTestId(set.id)
	self.dFollow:SetShown(canFollow)
	if canFollow then
		local following = TH:IsFollowing(set.author)
		self.dFollow:SetText(following and L["|cff40ff40вы подписаны|r"] or L["+ подписаться"])
		local fs = self.dFollow:GetFontString()
		self.dFollow:SetWidth((fs and fs:GetStringWidth() or 80) + 4)
		self.dFollow:ClearAllPoints()
		self.dFollow:SetPoint("LEFT", self.dAuthor, "LEFT", nameW + 8, 0)
	end
	-- раса и пол — после ссылки «подписаться» (или сразу после имени)
	self.dAuthorExtra:ClearAllPoints()
	local used = 10 + nameW + 8
	if canFollow then
		self.dAuthorExtra:SetPoint("LEFT", self.dFollow, "RIGHT", 8, 0)
		used = used + (self.dFollow:GetWidth() or 80) + 8
	else
		self.dAuthorExtra:SetPoint("LEFT", self.dAuthor, "LEFT", nameW + 8, 0)
	end
	-- не дальше правого края карточки: длинный ник — раса обрезается троеточием
	local card = self.dAuthor.GetParent and self.dAuthor:GetParent()
	local cardW = card and card.GetWidth and card:GetWidth() or 0
	if cardW > 0 then self.dAuthorExtra:SetWidth(math.max(cardW - used - 10, 1)) end
	self.dAuthorExtra:SetJustifyH("LEFT")

	if set.sex and set.sex ~= TH:PlayerSex() then
		self.sexHint:SetText(string.format(L["Собран на %s модели — точный вид\nв примерочной Wowhead"],
			set.sex == 1 and L["женской"] or L["мужской"]))
	else
		self.sexHint:SetText("")
	end
	self.wowheadBtn:SetEnabled(true)

	-- У своего опубликованного образа рейтинг берём с его копии в сети
	local mineLocal = TH.db.mySets[set.id]
	local netCopy = mineLocal and mineLocal.serverId and TH.byId[mineLocal.serverId]
	local isLocal = TH:IsLocalId(set.id) and not netCopy
	local r = netCopy and netCopy.rating or set.rating
	if isLocal then
		self.dRatingHint = nil
		self.dRating:SetText(L["Рейтинг появится после публикации"])
	elseif r and r.n and r.n > 0 then
		-- одна строка: рейтинг и короткая пометка; подробности — в подсказке
		local chartSet = netCopy or set
		local note, hint = "", { L["Рейтинг учитывает число оценок: пара пятёрок не обгонит образ с сотней четвёрок."] }
		if TH:GetSuspicion(chartSet) then
			note = L["  |cffff9020на проверке|r"]
			hint[#hint + 1] = L["|cffff9020Оценки на проверке у модератора: пока образ не в чарте.|r"]
		elseif r.n < TH:GetMinChartVotes() and chartSet.rating then
			local need, perDay = TH:GetMinChartVotes()
			local left = math.ceil(need - r.n)
			note = string.format(L["  |cff999999до чарта %d|r"], left)
			hint[#hint + 1] = string.format(L["В чарт («Лучшие» и «В тренде» вверху списка) образ попадает с %d оценок. Осталось %d."],
				need, left)
			hint[#hint + 1] = string.format(L["|cff999999Порог пересчитывается каждый день: %d%% от числа игроков, ставящих оценки за день (сейчас ~%d, медиана за неделю), но не меньше %d.|r"],
				TH.CHART_VOTES_SHARE * 100, perDay or 0, TH.MIN_CHART_VOTES)
		end
		-- Зал славы: образ вне конкурса
		local hall = TH:GetHallDate(chartSet.id)
		if hall then
			note = note .. L["  |cffe6cc80Зал славы|r"]
			hint[#hint + 1] = L["|cffe6cc80В Зале славы с "] .. hall .. L[": вне конкурса — в местах и наградах за места не участвует.|r"]
		end
		-- официальное место (проверенный ежедневный чарт)
		local place, pool = TH:GetOfficialRank("top", chartSet.id)
		if place then
			note = note .. string.format(L["  |cff40ff40№%d в «Лучших»|r"], place)
			hint[#hint + 1] = string.format(L["|cff40ff40Официально: %d из %d в «Лучших» (на %s).|r"], place, pool, TH:FormatChartsDate())
		end
		local tplace, tpool = TH:GetOfficialRank("trending", chartSet.id)
		if tplace then
			note = note .. string.format(L["  |cff40c0ff№%d «В тренде»|r"], tplace)
			hint[#hint + 1] = string.format(L["|cff40c0ffОфициально: %d из %d «В тренде» (на %s).|r"], tplace, tpool, TH:FormatChartsDate())
		end
		self.dRatingHint = hint
		self.dRating:SetText(string.format(L["Рейтинг: |cffffd100%.1f|r из 5, голосов: %d"], r.avg, r.n) .. note)
	else
		self.dRatingHint = nil
		self.dRating:SetText(L["Оценок пока нет — будьте первым"])
	end

	local canVote, reason = TH:CanVote(set)
	if not canVote then
		self.dVoteHint:SetText(reason)
	else
		self.dVoteHint:SetText("")
	end
	self:PaintStars()

	local tags = TH:FormatSetTags(set)
	self.dTags:SetText(tags ~= "" and (L["Теги: "] .. tags) or "")
	local netId = set.serverId or set.id
	self.dTagsBtn:SetShown(tags ~= "" and not TH:IsLocalId(netId) and not TH:IsTestId(netId))
	self.dDesc:SetText(set.desc or "")

	local items = set.items or {}
	local y, last = -146, nil
	for _, row in ipairs(self.slotRows) do
		local entry = row.entry
		local it = items[entry.id]
		local sourceID = it and it[entry.index]
		local det
		if entry.illusion then
			det = sourceID and TH:GetIllusionDetails(sourceID)
			if det and det.hidden then det = nil end
		else
			det = sourceID and TH:GetSourceDetails(sourceID)
		end
		-- Строка левого наплечника нужна, только если он отличается; чар — только если они есть
		local visible = (entry.index == 1 or sourceID ~= nil) and (not entry.illusion or det ~= nil)
		row:SetShown(visible)
		if visible then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 10, y)
			y = y - SLOT_ROW_H
			last = row
		end
		row.sourceID = sourceID
		row.illusion = entry.illusion
		if det then
			row.icon:SetTexture(det.icon)
			if det.hidden then
				row.text:SetText(L["|cff999999скрыто|r"])
				row.source:Hide()
				row.check:Hide()
			else
				row.text:SetText(QualityName(det))
				row.source:SetTexture(det.illusion and "Interface\\Icons\\INV_Enchant_Disenchant" or det.artifact and 1061303
					or det.fromSet and 1602705 or SOURCE_ICONS[det.sourceType] or "Interface\\Icons\\INV_Misc_QuestionMark")
				row.source:Show()
				row.check:SetTexture(det.collected and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
				row.check:Show()
			end
		else
			row.icon:SetTexture(nil)
			row.text:SetText("|cff666666—|r")
			row.source:Hide()
			row.check:Hide()
		end
	end

	self.dCollected:ClearAllPoints()
	self.dCollected:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)

	local have, total = TH:GetCollectedStats(set)
	local color = (have == total) and "|cff40ff40" or "|cffffd100"
	self.dCollected:SetText(string.format(L["Собрано: %s%d из %d|r"], color, have, total))

	if self.model.items ~= items then
		-- другой образ — камера заново: отдалённая колесом модель не остаётся крошечной
		if self.model.shownSetId ~= set.id then self.model:ResetCamera() end
		self.model.shownSetId = set.id
		self.model:SetItems(items)
	end

	local fav = TH.db.favorites[set.id]
	self.dFav.tex:SetDesaturated(not fav)
	self.dFav.tex:SetAlpha(fav and 1 or 0.45)

	-- Вкладка модерации: свои кнопки и разбор жалоб вместо обычного статуса
	local modView = self.view == "moderation"
	self.dFav:SetShown(not modView)
	self.modSetBtn:SetShown(modView)
	self.modAuthorBtn:SetShown(modView)
	self.modDismissBtn:SetShown(modView)
	self.modSkipBtn:SetShown(modView)
	if modView then
		local blocks = TH.db.net.modBlocks
		self.modSetBtn:SetText(blocks.sets[set.id] and L["Разблок. образ"] or L["Нарушение..."])
		self.modAuthorBtn:SetText(set.author and blocks.authors[set.author] and L["Разблок. автора"] or L["Блок. автора"])
		local total, by = TH:GetReportStats(set.id)
		local sus = TH:GetSuspicion(set)
		-- жалобы разбираем первыми, потом оценки
		self.modVotesMode = sus ~= nil and (total == 0 or TH.db.modDismissed[set.id] ~= nil)
		self.modDismissBtn:SetText(self.modVotesMode and L["Оценки честные"] or L["Жалобы ложные"])
		local lines = {}
		if total > 0 then
			lines[#lines + 1] = string.format(L["Жалоб: %d (реклама %d, оскорбление %d, другое %d)"], total, by.a, by.o, by.x)
		end
		-- пояснения к «Другое» (приходят письмами вида r: «[id] текст»)
		local prefix, notes = "[" .. set.id .. "] ", 0
		for _, idea in pairs(TH.db.net.ideas or {}) do
			if idea[3] == "r" and notes < 3 and idea[4]:sub(1, #prefix) == prefix then
				notes = notes + 1
				lines[#lines + 1] = "|cffbbbbbb«" .. idea[4]:sub(#prefix + 1) .. "»|r"
			end
		end
		-- отметки «тег не подходит», даже пока тег не погас
		local flagged = {}
		for tag, list in pairs(TH.db.net.tagFlags[set.id] or {}) do
			local n = 0
			for _, f in pairs(list) do if f[1] == 1 then n = n + 1 end end
			if n > 0 then flagged[#flagged + 1] = (TH.TAG_LABEL[tag] or tag) .. " (" .. n .. ")" end
		end
		if #flagged > 0 then lines[#lines + 1] = L["«Тег не подходит»: "] .. table.concat(flagged, ", ") end
		if sus then
			local d = set.rating and set.rating.dist or {}
			lines[#lines + 1] = L["|cffff9020Накрутка?|r "] .. table.concat(sus, ", ")
			lines[#lines + 1] = string.format(L["Оценки 1-5: %d / %d / %d / %d / %d"], d[1] or 0, d[2] or 0, d[3] or 0, d[4] or 0, d[5] or 0)
		end
		local disputed = {}
		for tag, n in pairs(TH:GetDisputedTags(set)) do disputed[#disputed + 1] = (TH.TAG_LABEL[tag] or tag) .. " (" .. n .. ")" end
		if #disputed > 0 then lines[#lines + 1] = L["Погасшие теги: "] .. table.concat(disputed, ", ") end
		if TH:IsBlocked(set) then
			local kind = TH:GetNameViolation(set.id)
			lines[#lines + 1] = L["|cffff6060Заблокирован|r"] .. (kind == "e" and L[" (просим переименовать)"] or kind == "o" and L[" (оскорбление)"] or "")
		end
		local warned = TH:GetRenameWarning(set.author)
		if warned and warned ~= set.id then lines[#lines + 1] = L["|cffff9020Автора уже просили переименовать образ|r"] end
		if set.author and TH:IsBanned(set.author) then lines[#lines + 1] = L["|cffff6060Автор забанен|r"] end
		self.dStatus:SetText(table.concat(lines, "\n"))
		self.deleteBtn:Hide()
		self.publishBtn:Hide()
		return
	end

	local mine = TH.db.mySets[set.id]
	self.deleteBtn:SetShown(mine ~= nil)
	self.publishBtn:SetShown(mine ~= nil and (mine.status ~= "published" or mine.renameRequired == true))
	self.publishBtn:SetText(mine and mine.renameRequired and L["Переименовать"] or L["Опубликовать"])
	if mine then
		local s = L["Статус: "] .. (STATUS_TEXT[mine.status] or mine.status or "?")
		if mine.renameRequired then
			s = s .. L["\n|cffff9020Стражи подиума скрыли образ из-за названия: переименуйте его.|r"]
		end
		if mine.status == "published" then
			s = s .. L["\n|cff999999Виден всем игрокам с аддоном.|r"]
			local net = mine.serverId and TH.byId[mine.serverId]
			local off = {}
			for tag in pairs(net and TH:GetDisputedTags(net) or {}) do off[#off + 1] = TH.TAG_LABEL[tag] or tag end
			if #off > 0 then s = s .. L["\n|cffff9020Погасли теги: "] .. table.concat(off, ", ") .. "|r" end
		end
		self.dStatus:SetText(s)
	else
		self.dStatus:SetText("")
	end
end

function UI:RefreshStatus()
	local Net = TH.Net
	local on = Net:IsConnected()
	self.netDot:SetTexture(on and "Interface\\COMMON\\Indicator-Green" or "Interface\\COMMON\\Indicator-Gray")
	self.netLabel:SetText(on and L["Сеть"] or L["|cff999999Подключение...|r"])
	self.netStats[1]:SetText(Net:PeerCount())
	self.netStats[2]:SetText(Net:BNetPeerCount())
	self.netStats[3]:SetText(Net:GuildPeerCount())
	self.netStats[4]:SetText(Net:SetCount())
	local note = ""
	if Net:IsLocked() and Net:QueueLength() > 0 then
		note = L["|cffffd100отправка на паузе (бой или подземелье)|r"]
	elseif Net:QueueLength() > 0 then
		note = string.format(L["|cffffd100отправляется: %d|r"], Net:QueueLength())
		local stall = Net:SendStallReason()
		if stall then note = note .. L[" |cffff9020(игра не даёт: "] .. stall .. ")|r" end
	end
	self.status:SetText(note)
	self.syncBtn:SetEnabled(TH.Net:IsConnected())
end
