local _, ns = ...
local TH = ns.TH

local UI = CreateFrame("Frame", "TransmogHubFrame", UIParent, "BasicFrameTemplateWithInset")
UI:Hide()
TH.UI = UI

local W, H = 1000, 600
local ROWS, ROW_H = 10, 46
local SLOT_ROW_H = 19

local VIEWS = {
	{ key = "top", text = "Лучшие" },
	{ key = "trending", text = "В тренде" },
	{ key = "new", text = "Новые" },
	{ key = "favorites", text = "Избранное" },
	{ key = "mine", text = "Мои" },
	{ key = "achievements", text = "Достижения" },
}

local EMPTY_TEXT = {
	mine = "Сохранённых образов пока нет.\n\nНаденьте трансмог и нажмите «Сохранить облик».",
	favorites = "В избранном пусто.",
	default = "Наборов не найдено.\n\nЕсли база пуста, запустите компаньон\nили введите /thub test для тестовой ленты.",
}

local STATUS_TEXT = {
	draft = "|cff999999черновик|r",
	published = "|cff40ff40опубликован|r",
	rejected = "|cffff4040отклонён|r",
}

UI.view = "top"
UI.filter = { text = "", tags = {} }
UI.offset = 0
UI.raceID = nil -- раса для примерки; nil — свой персонаж

---------------------------------------------------------------------------
-- Мелкие конструкторы
---------------------------------------------------------------------------
local function Button(parent, text, w, h)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w, h or 22)
	b:SetText(text)
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
	self:SetScript("OnShow", function() self.model:Reload() end)
	tinsert(UISpecialFrames, self:GetName())

	local title = self:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText("Transmog Hub " .. (C_AddOns.GetAddOnMetadata("TransmogHub", "Version") or ""))

	self:BuildToolbar()
	self.listPanel = Panel(self, 10, -58, 322, 508)
	self.previewPanel = Panel(self, 336, -58, 300, 508)
	self.detailPanel = Panel(self, 640, -58, 350, 508)
	self:BuildList(self.listPanel)
	self:BuildPreview(self.previewPanel)
	self:BuildDetail(self.detailPanel)

	self.achPanel = Panel(self, 10, -58, 980, 508)
	TH:BuildAchievementsPanel(self.achPanel)
	self.achPanel:Hide()

	self.status = Label(self, "GameFontHighlightSmall", 760)
	self.status:SetPoint("BOTTOMLEFT", 14, 13)
	self.syncBtn = Button(self, "Синхронизировать", 150)
	self.syncBtn:SetPoint("BOTTOMRIGHT", -12, 8)
	self.syncBtn:SetScript("OnClick", function()
		TH.Net:RequestSync()
		TH:Print("Запрос синхронизации отправлен.")
	end)
end

function UI:BuildToolbar()
	self.tabs = {}
	for i, v in ipairs(VIEWS) do
		local b = Button(self, v.text, 84)
		b:SetPoint("TOPLEFT", 12 + (i - 1) * 86, -30)
		b.key = v.key
		b:SetScript("OnClick", function() self:SetView(v.key) end)
		self.tabs[i] = b
	end

	local search = CreateFrame("EditBox", nil, self, "SearchBoxTemplate")
	self.search = search
	search:SetSize(150, 20)
	search:SetPoint("TOPRIGHT", -304, -31)
	search:SetAutoFocus(false)
	search:HookScript("OnTextChanged", function(eb)
		self.filter.text = eb:GetText() or ""
		self.offset = 0
		self:Refresh()
	end)

	self.tagsBtn = Button(self, "Теги", 90)
	self.tagsBtn:SetPoint("TOPRIGHT", -172, -30)
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
		GameTooltip:SetText("Сбросить теги")
		GameTooltip:Show()
	end)
	self.tagsReset:SetScript("OnLeave", GameTooltip_Hide)
	self.tagsReset:Hide()

	local saveBtn = Button(self, "Сохранить облик", 150)
	saveBtn:SetPoint("TOPRIGHT", -14, -30)
	saveBtn:SetScript("OnClick", function() TH:OpenSaveDialog() end)
end

function UI:BuildList(list)
	self.rows = {}
	for i = 1, ROWS do
		local row = CreateFrame("Button", nil, list)
		row:SetSize(306, ROW_H - 2)
		row:SetPoint("TOPLEFT", 8, -6 - (i - 1) * ROW_H)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

		row.sel = row:CreateTexture(nil, "BACKGROUND")
		row.sel:SetAllPoints()
		row.sel:SetColorTexture(1, 0.82, 0, 0.15)

		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(36, 36)
		row.icon:SetPoint("LEFT", 4, 0)

		row.name = Label(row, "GameFontNormal", 175)
		row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -2)
		row.name:SetWordWrap(false)

		row.author = Label(row, "GameFontHighlightSmall", 175)
		row.author:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
		row.author:SetWordWrap(false)

		row.rating = Label(row, "GameFontHighlightSmall")
		row.rating:SetPoint("TOPRIGHT", -6, -6)
		row.rating:SetJustifyH("RIGHT")

		row.extra = Label(row, "GameFontDisableSmall")
		row.extra:SetPoint("BOTTOMRIGHT", -6, 6)
		row.extra:SetJustifyH("RIGHT")

		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(r, mouse)
			self:Select(r.setId)
			if mouse == "RightButton" then self:OpenSetMenu(r, r.setId) end
		end)
		self.rows[i] = row
	end

	self.prevBtn = Button(list, "<", 30)
	self.prevBtn:SetPoint("BOTTOMLEFT", 8, 8)
	self.prevBtn:SetScript("OnClick", function() self:Scroll(-ROWS) end)
	self.nextBtn = Button(list, ">", 30)
	self.nextBtn:SetPoint("BOTTOMRIGHT", -8, 8)
	self.nextBtn:SetScript("OnClick", function() self:Scroll(ROWS) end)
	self.pageText = Label(list, "GameFontHighlightSmall")
	self.pageText:SetPoint("BOTTOM", 0, 14)

	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, delta) self:Scroll(-delta) end)

	self.emptyText = Label(list, "GameFontDisable", 280)
	self.emptyText:SetPoint("CENTER", 0, 20)
	self.emptyText:SetJustifyH("CENTER")
end

function UI:BuildPreview(panel)
	self.model = TH:CreatePreview(panel)
	self.model.scene:SetPoint("TOPLEFT", 4, -4)
	self.model.scene:SetPoint("BOTTOMRIGHT", -4, 66)

	local hint = Label(panel, "GameFontDisableSmall", 280)
	hint:SetPoint("TOP", 0, -8)
	hint:SetJustifyH("CENTER")
	hint:SetText("ЛКМ — вращать · колесо — приблизить")

	-- Предупреждение, если набор собран на модели другого пола
	self.sexHint = Label(panel, "GameFontNormalSmall", 280)
	self.sexHint:SetPoint("TOP", hint, "BOTTOM", 0, -4)
	self.sexHint:SetJustifyH("CENTER")
	self.sexHint:SetTextColor(1, 0.6, 0.2)

	self.raceBtn = Button(panel, "Раса: свой персонаж", 186)
	self.raceBtn:SetPoint("BOTTOMLEFT", 8, 36)
	self.raceBtn:SetScript("OnClick", function(b) self:OpenRaceMenu(b) end)

	self.authorRaceBtn = Button(panel, "Как у автора", 94)
	self.authorRaceBtn:SetPoint("LEFT", self.raceBtn, "RIGHT", 4, 0)
	self.authorRaceBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if not set or not set.race then return end
		self:SetRace(set.race ~= select(3, UnitRace("player")) and set.race or nil)
	end)

	local me = Button(panel, "Мой персонаж", 130)
	me:SetPoint("BOTTOMLEFT", 8, 8)
	me:SetScript("OnClick", function() self:SetRace(nil) end)

	self.wowheadBtn = Button(panel, "Открыть в Wowhead", 150)
	self.wowheadBtn:SetPoint("LEFT", me, "RIGHT", 4, 0)
	self.wowheadBtn:SetScript("OnClick", function() TH:ShowWowheadLink(TH:GetSet(self.selectedId)) end)
	self.wowheadBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText("Примерочная Wowhead")
		GameTooltip:AddLine("Строка для импорта набора в примерочную Wowhead: там можно выбрать любую расу и пол.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	self.wowheadBtn:SetScript("OnLeave", GameTooltip_Hide)
end

function UI:BuildDetail(panel)
	self.detailEmpty = Label(panel, "GameFontDisable", 300)
	self.detailEmpty:SetPoint("CENTER")
	self.detailEmpty:SetJustifyH("CENTER")
	self.detailEmpty:SetText("Выберите набор слева")

	local c = CreateFrame("Frame", nil, panel)
	c:SetAllPoints()
	self.detail = c

	self.dName = Label(c, "GameFontNormalLarge", 330)
	self.dName:SetPoint("TOPLEFT", 10, -10)
	self.dName:SetWordWrap(false)

	self.dAuthor = Label(c, "GameFontHighlightSmall", 330)
	self.dAuthor:SetPoint("TOPLEFT", 10, -32)

	self.dRating = Label(c, "GameFontHighlight", 330)
	self.dRating:SetPoint("TOPLEFT", 10, -50)

	local voteLabel = Label(c, "GameFontHighlightSmall")
	voteLabel:SetPoint("TOPLEFT", 10, -74)
	voteLabel:SetText("Ваша оценка:")

	self.stars = {}
	for i = 1, 5 do
		local s = CreateFrame("Button", nil, c)
		s:SetSize(20, 20)
		s:SetPoint("LEFT", voteLabel, "RIGHT", 6 + (i - 1) * 22, 0)
		s.tex = s:CreateTexture(nil, "ARTWORK")
		s.tex:SetAllPoints()
		SetStarTexture(s.tex)
		s:SetScript("OnClick", function() TH:Vote(self.selectedId, i) end)
		s:SetScript("OnEnter", function() self:PaintStars(i) end)
		s:SetScript("OnLeave", function() self:PaintStars() end)
		self.stars[i] = s
	end
	self.dVoteHint = Label(c, "GameFontDisableSmall", 120)
	self.dVoteHint:SetPoint("LEFT", self.stars[5], "RIGHT", 8, 0)

	self.dTags = Label(c, "GameFontHighlightSmall", 330)
	self.dTags:SetPoint("TOPLEFT", 10, -96)
	self.dTags:SetTextColor(1, 0.82, 0)

	self.dDesc = Label(c, "GameFontDisableSmall", 330)
	self.dDesc:SetPoint("TOPLEFT", 10, -114)
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

		r.source = Label(r, "GameFontDisableSmall", 108)
		r.source:SetPoint("RIGHT", r.check, "LEFT", -4, 0)
		r.source:SetWordWrap(false)

		r.text = Label(r, "GameFontHighlightSmall")
		r.text:SetPoint("LEFT", r.slot, "RIGHT", 2, 0)
		r.text:SetPoint("RIGHT", r.source, "LEFT", -4, 0)
		r.text:SetWordWrap(false)

		r:SetScript("OnEnter", function(f) self:ShowSlotTooltip(f) end)
		r:SetScript("OnLeave", GameTooltip_Hide)
		self.slotRows[i] = r
	end

	self.dCollected = Label(c, "GameFontHighlight", 330)

	self.dStatus = Label(c, "GameFontHighlightSmall", 330)
	self.dStatus:SetPoint("TOPLEFT", self.dCollected, "BOTTOMLEFT", 0, -6)

	self.favBtn = Button(c, "В избранное", 150)
	self.favBtn:SetPoint("BOTTOMLEFT", 10, 10)
	self.favBtn:SetScript("OnClick", function() TH:ToggleFavorite(self.selectedId) end)

	self.publishBtn = Button(c, "Опубликовать", 110)
	self.publishBtn:SetPoint("LEFT", self.favBtn, "RIGHT", 6, 0)
	self.publishBtn:SetScript("OnClick", function() TH:Publish(self.selectedId) end)

	self.deleteBtn = Button(c, "Удалить", 70)
	self.deleteBtn:SetPoint("LEFT", self.publishBtn, "RIGHT", 6, 0)
	self.deleteBtn:SetScript("OnClick", function()
		local set = TH:GetSet(self.selectedId)
		if not set then return end
		local extra = set.serverId and "\n\nНабор будет снят с публикации." or ""
		StaticPopup_Show("TRANSMOGHUB_DELETE", set.name, extra, set.id)
	end)
end

StaticPopupDialogs["TRANSMOGHUB_DELETE"] = {
	text = "Удалить набор «%s»?%s",
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
function UI:Toggle()
	if not self.built then self:Build() end
	if self:IsShown() then
		self:Hide()
	else
		self:Show()
		self:Refresh()
	end
end

function UI:SetView(key)
	self.view = key
	self.offset = 0
	self.selectedId = nil
	local ach = key == "achievements"
	self.achPanel:SetShown(ach)
	self.listPanel:SetShown(not ach)
	self.previewPanel:SetShown(not ach)
	self.detailPanel:SetShown(not ach)
	self.search:SetShown(not ach)
	self.tagsBtn:SetShown(not ach)
	if ach then self.tagsReset:Hide() end
	self:Refresh()
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
	text = "Скрыть набор «%s»?\n\nОн пропадёт только у вас. Вернуть все скрытые: /thub unhide",
	button1 = "Скрыть",
	button2 = CANCEL,
	OnAccept = function(_, setId) TH:HideSet(setId) end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Меню по ПКМ на наборе в списке
function UI:OpenSetMenu(owner, setId)
	local set = TH:GetSet(setId)
	if not set or not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local mine = TH.db.mySets[set.id]
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(set.name or "Набор")

		root:CreateButton(TH.db.favorites[set.id] and "Убрать из избранного" or "В избранное",
			function() TH:ToggleFavorite(set.id) end)
		root:CreateButton("Открыть в Wowhead", function() TH:ShowWowheadLink(set) end)

		if TH:CanVote(set) then
			local rate = root:CreateButton("Оценить")
			for stars = 5, 1, -1 do
				rate:CreateRadio(string.rep(CreateAtlasMarkup("PetJournal-FavoritesIcon", 14, 14), stars),
					function() return TH.db.myVotes[set.id] == stars end,
					function() TH:Vote(set.id, stars) end)
			end
		end

		if mine then
			if mine.status == "draft" or mine.status == "rejected" then
				root:CreateButton("Опубликовать", function() TH:Publish(set.id) end)
			end
			root:CreateButton("|cffff6060Удалить|r", function()
				local extra = mine.serverId and "\n\nНабор будет снят с публикации." or ""
				StaticPopup_Show("TRANSMOGHUB_DELETE", mine.name, extra, mine.id)
			end)
		elseif not TH:IsTestId(set.id) and not TH:IsLocalId(set.id) then
			root:CreateButton("Скрыть набор", function()
				StaticPopup_Show("TRANSMOGHUB_REPORT", set.name, nil, set.id)
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
	self:RefreshList()
	self:RefreshDetail()
end

function UI:SetRace(raceID)
	self.raceID = raceID
	if raceID then
		TH:TrackRaceTried(raceID)
		TH:CheckAchievements()
	end
	self.raceBtn:SetText(raceID and ("Раса: " .. TH:GetRaceName(raceID)) or "Раса: свой персонаж")
	self.model:SetRace(raceID)
end

function UI:OpenRaceMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		if root.SetScrollMode then root:SetScrollMode(400) end
		root:CreateTitle("Примерить на расу")
		root:CreateRadio("Мой персонаж",
			function() return self.raceID == nil end,
			function() self:SetRace(nil) end)
		for _, race in ipairs(TH:GetPlayableRaces()) do
			root:CreateRadio(race.name,
				function() return self.raceID == race.id end,
				function() self:SetRace(race.id) end)
		end
	end)
end

function UI:OpenTagMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, group in ipairs(TH.TAG_GROUPS) do
			root:CreateTitle(group.name)
			for _, tag in ipairs(group.tags) do
				local key = tag[1]
				root:CreateCheckbox(tag[2],
					function() return self.filter.tags[key] == true end,
					function()
						self.filter.tags[key] = not self.filter.tags[key] or nil
						self.offset = 0
						self:Refresh()
					end)
			end
		end
		root:CreateDivider()
		root:CreateButton("Сбросить фильтр", function()
			wipe(self.filter.tags)
			self:Refresh()
		end)
	end)
end

function UI:ShowSlotTooltip(row)
	if not row.sourceID then return end
	local det = TH:GetSourceDetails(row.sourceID)
	if not det then return end
	GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
	if det.itemID then
		GameTooltip:SetItemByID(det.itemID)
	else
		GameTooltip:SetText(det.name)
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Источник: " .. (det.typeText or "?"), 1, 1, 1)
	if det.where then GameTooltip:AddLine(det.where, 0.8, 0.8, 0.8, true) end
	if not det.hidden then
		if det.collected then
			GameTooltip:AddLine("Облик собран", 0.25, 1, 0.25)
		else
			GameTooltip:AddLine("Облик не собран", 1, 0.25, 0.25)
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
		if b.key == self.view then b:LockHighlight() else b:UnlockHighlight() end
	end
	if self.view == "achievements" then
		TH:RefreshAchievementsPanel(self.achPanel)
		self:RefreshStatus()
		return
	end
	local nTags = 0
	for _ in pairs(self.filter.tags) do nTags = nTags + 1 end
	self.tagsBtn:SetText(nTags > 0 and ("Теги (" .. nTags .. ")") or "Теги")
	self.tagsReset:SetShown(nTags > 0)

	self.results = TH:QuerySets(self.view, { text = self.filter.text, tags = self.filter.tags })
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
			row.name:SetText(set.name or "Без названия")
			row.author:SetText(set.author or "")

			local items = set.items or {}
			local main = items[5] or items[1] or select(2, next(items))
			local det = main and TH:GetSourceDetails(main[1])
			row.icon:SetTexture(det and det.icon or 134400)

			if self.view == "mine" then
				row.rating:SetText(STATUS_TEXT[set.status] or "")
			else
				local r = set.rating
				if r and r.n and r.n > 0 then
					row.rating:SetText(string.format("|cffffd100%.1f|r (%d)", r.avg, r.n))
				else
					row.rating:SetText("|cff999999нет оценок|r")
				end
			end

			local have, total = TH:GetCollectedStats(set)
			row.extra:SetText(total > 0 and string.format("собрано %d/%d", have, total) or "")
			row.sel:SetShown(set.id == self.selectedId)
			row:Show()
		else
			row.setId = nil
			row:Hide()
		end
	end

	local n = #results
	self.pageText:SetText(n > 0 and string.format("%d–%d из %d", self.offset + 1, math.min(self.offset + ROWS, n), n) or "")
	self.prevBtn:SetEnabled(self.offset > 0)
	self.nextBtn:SetEnabled(self.offset + ROWS < n)
	self.emptyText:SetText(EMPTY_TEXT[self.view] or EMPTY_TEXT.default)
	self.emptyText:SetShown(n == 0)
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
	if not set then
		if self.model.items then self.model:SetItems(nil) end
		self.sexHint:SetText("")
		self.authorRaceBtn:SetEnabled(false)
		self.wowheadBtn:SetEnabled(false)
		return
	end

	self.dName:SetText(set.name or "Без названия")
	local who = set.author or "?"
	if set.race then who = who .. " · " .. TH:GetRaceName(set.race) end
	if set.sex then who = who .. " · " .. TH:SexLabel(set.sex) end
	self.dAuthor:SetText("Автор: " .. who)

	if set.sex and set.sex ~= TH:PlayerSex() then
		self.sexHint:SetText(string.format("Собран на %s модели — точный вид\nв примерочной Wowhead",
			set.sex == 1 and "женской" or "мужской"))
	else
		self.sexHint:SetText("")
	end
	self.authorRaceBtn:SetEnabled(set.race ~= nil)
	self.wowheadBtn:SetEnabled(true)

	-- У своего опубликованного набора рейтинг берём с его копии в сети
	local mineLocal = TH.db.mySets[set.id]
	local netCopy = mineLocal and mineLocal.serverId and TH.byId[mineLocal.serverId]
	local isLocal = TH:IsLocalId(set.id) and not netCopy
	local r = netCopy and netCopy.rating or set.rating
	if isLocal then
		self.dRating:SetText("Рейтинг появится после публикации")
	elseif r and r.n and r.n > 0 then
		self.dRating:SetText(string.format("Рейтинг: |cffffd100%.1f|r из 5 · голосов: %d", r.avg, r.n))
	else
		self.dRating:SetText("Оценок пока нет — будьте первым")
	end

	local canVote, reason = TH:CanVote(set)
	if not canVote then
		self.dVoteHint:SetText(reason)
	else
		self.dVoteHint:SetText("")
	end
	self:PaintStars()

	local tags = TH:FormatTags(set.tags)
	self.dTags:SetText(tags ~= "" and ("Теги: " .. tags) or "")
	self.dDesc:SetText(set.desc or "")

	local items = set.items or {}
	local y, last = -146, nil
	for _, row in ipairs(self.slotRows) do
		local entry = row.entry
		local it = items[entry.id]
		local sourceID = it and it[entry.index]
		-- Строка левого наплечника нужна, только если он отличается
		local visible = entry.index == 1 or sourceID ~= nil
		row:SetShown(visible)
		if visible then
			row:ClearAllPoints()
			row:SetPoint("TOPLEFT", 10, y)
			y = y - SLOT_ROW_H
			last = row
		end
		local det = sourceID and TH:GetSourceDetails(sourceID)
		row.sourceID = sourceID
		if det then
			row.icon:SetTexture(det.icon)
			if det.hidden then
				row.text:SetText("|cff999999скрыто|r")
				row.source:SetText("")
				row.check:Hide()
			else
				row.text:SetText(QualityName(det))
				row.source:SetText(det.typeText or "?")
				row.check:SetTexture(det.collected and "Interface\\RaidFrame\\ReadyCheck-Ready" or "Interface\\RaidFrame\\ReadyCheck-NotReady")
				row.check:Show()
			end
		else
			row.icon:SetTexture(nil)
			row.text:SetText("|cff666666—|r")
			row.source:SetText("")
			row.check:Hide()
		end
	end

	self.dCollected:ClearAllPoints()
	self.dCollected:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -6)

	local have, total = TH:GetCollectedStats(set)
	local color = (have == total) and "|cff40ff40" or "|cffffd100"
	self.dCollected:SetText(string.format("Собрано: %s%d из %d|r", color, have, total))

	if self.model.items ~= items then
		self.model:SetItems(items)
	end

	self.favBtn:SetText(TH.db.favorites[set.id] and "Убрать из избранного" or "В избранное")

	local mine = TH.db.mySets[set.id]
	self.deleteBtn:SetShown(mine ~= nil)
	self.publishBtn:SetShown(mine ~= nil and mine.status ~= "published")
	if mine then
		local s = "Статус: " .. (STATUS_TEXT[mine.status] or mine.status or "?")
		if mine.status == "published" then
			s = s .. "\n|cff999999Виден всем игрокам с аддоном.|r"
		end
		self.dStatus:SetText(s)
	else
		self.dStatus:SetText("")
	end
end

function UI:RefreshStatus()
	self.status:SetText(TH:NetworkStatusText())
	self.syncBtn:SetEnabled(TH.Net:IsConnected())
end
