local _, ns = ...
local TH = ns.TH

-- Выбор тегов: слева темы (вкладки), справа теги выбранной темы флажками,
-- сверху поиск по всем тегам и выбор сортировки, снизу — что выбрано.
-- opts: cols, rows, colW, rowH, max (ограничение выбора), onChange(selected)
local Picker = {}
local THEME_W = 140

-- Сортировка своя у каждого окна тегов и не запоминается: при каждом открытии — популярные
local function SortMode(picker)
	return picker and picker.sort or "popular"
end

local function SortText(mode)
	for _, s in ipairs(TH.TAG_SORTS) do
		if s.key == mode then return s.text end
	end
	return TH.TAG_SORTS[1].text
end

function Picker:GetSelectedList()
	local list = {}
	for _, key in ipairs(TH.TAG_ORDER) do
		if self.selected[key] then list[#list + 1] = key end
	end
	return list
end

function Picker:CountSelected()
	local n = 0
	for _ in pairs(self.selected) do n = n + 1 end
	return n
end

function Picker:SetSelected(keys)
	wipe(self.selected)
	for k, v in pairs(keys or {}) do
		if type(k) == "number" then self.selected[v] = true elseif v then self.selected[k] = true end
	end
	self.offset = 0
	self:Refresh()
end

-- Можно ли выбрать тег (окно публикации проверяет, например, рейдовые): ok, причина
function Picker:CanSelect(key)
	if not self.canSelect then return true end
	return self.canSelect(key)
end

function Picker:Toggle(key)
	local ok, why = self:CanSelect(key)
	if self.selected[key] then
		self.selected[key] = nil
	elseif not ok then
		TH:Print(TH.TAG_LABEL[key] .. ": " .. (why or "этот тег сейчас выбрать нельзя."))
		self:Refresh(true)
		return
	elseif self.max and self:CountSelected() >= self.max then
		TH:Print("Можно выбрать не больше " .. self.max .. " тегов.")
	else
		self.selected[key] = true
	end
	self:Refresh(true)
	if self.onChange then self.onChange(self.selected) end
end

function Picker:SetTheme(key)
	self.theme = key
	self.offset = 0
	self.search:SetText("")
	self:Refresh()
end

function Picker:SetSort(mode)
	self.sort = mode
	self.offset = 0
	self:Refresh()
end

function Picker:Scroll(delta)
	local maxOffset = math.max(0, math.ceil(#self.list / self.cols) - self.rows)
	self.offset = math.min(math.max(self.offset - delta, 0), maxOffset)
	self:Refresh(true)
end

-- Ключи тегов текущей темы; nil — все теги
function Picker:ThemeKeys()
	if self.theme == "selected" then return self:GetSelectedList() end
	local theme = TH.TAG_THEMES[tonumber(self.theme) or 0]
	return theme and theme.tags or nil
end

function Picker:OpenSortMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Сортировка тегов")
		for _, s in ipairs(TH.TAG_SORTS) do
			local radio = root:CreateRadio(s.text,
				function() return SortMode(self) == s.key end,
				function() self:SetSort(s.key) end)
			if s.hint and radio and radio.SetTooltip then
				radio:SetTooltip(function(tooltip) GameTooltip_SetTitle(tooltip, s.text); GameTooltip_AddNormalLine(tooltip, s.hint) end)
			end
		end
	end)
end

function Picker:Refresh(keepList)
	local query = self.search:GetText() or ""
	local searching = strtrim(query) ~= ""
	local mode = SortMode(self)
	if not keepList then
		-- поиск идёт по всем темам
		local keys = not searching and self:ThemeKeys() or nil
		if self.theme == "selected" and not searching then keys = self:GetSelectedList() end
		self.list, self.counts, self.trend = TH:GetTagsSorted(query, mode, keys)
		local maxOffset = math.max(0, math.ceil(#self.list / self.cols) - self.rows)
		if self.offset > maxOffset then self.offset = maxOffset end
	end

	local first = self.offset * self.cols
	for i, slot in ipairs(self.slots) do
		local key = self.list[first + i]
		if key then
			local n = (mode == "trending" and self.trend or self.counts)[key] or 0
			slot.key = key
			slot:SetChecked(self.selected[key] == true)
			local ok = self:CanSelect(key)
			local text = TH.TAG_SHORT[key] or TH.TAG_LABEL[key]
			local label = ok and text or ("|cff808080" .. text .. "|r")
			slot.label:SetText(label .. (n > 0 and (" |cff999999(" .. n .. ")|r") or ""))
			-- цветовой тег: квадратик обведён своим цветом
			local c = TH.TAG_COLORS[key]
			if c then slot.swatch:SetColorTexture(c[1], c[2], c[3], 1) end
			slot.swatch:SetShown(c ~= nil)
			slot:Show()
		else
			slot.key = nil
			slot:Hide()
		end
	end

	local rowsTotal = math.ceil(#self.list / self.cols)
	self.scrollBar:Sync(self.offset, rowsTotal - self.rows)
	self.empty:SetShown(#self.list == 0)
	self.emptyText:SetText(searching and "Такого тега пока нет." or "Ничего не выбрано.")
	self.suggestBtn:SetShown(searching)
	self.sortBtn:SetText(SortText(mode))

	-- вкладки тем: подсветка текущей и число выбранных в теме
	local total = self:CountSelected()
	for _, b in ipairs(self.themeButtons) do
		local n = 0
		if b.key == "selected" or b.key == "all" then
			n = b.key == "selected" and total or 0
		else
			for _, key in ipairs(TH.TAG_THEMES[b.key].tags) do
				if self.selected[key] then n = n + 1 end
			end
		end
		b.text:SetText(b.name .. (n > 0 and (" |cff40ff40(" .. n .. ")|r") or ""))
		b.sel:SetShown(not searching and b.key == self.theme)
	end

	local labels = {}
	for _, key in ipairs(self:GetSelectedList()) do labels[#labels + 1] = TH.TAG_LABEL[key] end
	self.summary:SetText(#labels > 0 and ("Выбрано: |cffffd100" .. table.concat(labels, ", ") .. "|r")
		or "|cff999999Теги не выбраны|r")
end

local function ThemeButton(p, key, name, y, h)
	local b = CreateFrame("Button", nil, p)
	b:SetSize(THEME_W, h)
	b:SetPoint("TOPLEFT", 0, y)
	b.key, b.name = key, name
	b.sel = b:CreateTexture(nil, "BACKGROUND")
	b.sel:SetAllPoints()
	b.sel:SetColorTexture(TH:SelColor(0.18))
	b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("LEFT", 6, 0)
	b.text:SetWidth(THEME_W - 8)
	b.text:SetJustifyH("LEFT")
	b.text:SetWordWrap(false)
	b:SetScript("OnClick", function() p:SetTheme(key) end)
	return b
end

function TH:CreateTagPicker(parent, opts)
	opts = opts or {}
	local cols, rows = opts.cols or 3, opts.rows or 10
	local colW, rowH = opts.colW or 165, opts.rowH or 22
	local gridX, gridY = THEME_W + 10, -28

	local p = CreateFrame("Frame", nil, parent)
	Mixin(p, Picker)
	p.cols, p.rows, p.max, p.onChange, p.canSelect = cols, rows, opts.max, opts.onChange, opts.canSelect
	p.selected, p.list, p.counts, p.offset, p.slots = {}, {}, {}, 0, {}
	p.theme = "all"
	p.width, p.height = gridX + cols * colW + 24, -gridY + rows * rowH + 22
	p:SetSize(p.width, p.height)

	local search = CreateFrame("EditBox", nil, p, "SearchBoxTemplate")
	search:SetSize(THEME_W + 120, 20)
	search:SetPoint("TOPLEFT", 6, 0)
	search:SetAutoFocus(false)
	if type(search.Instructions) == "table" then search.Instructions:SetText("Поиск по всем тегам") end
	search:HookScript("OnTextChanged", function()
		p.offset = 0
		p:Refresh()
	end)
	p.search = search

	-- сортировка
	local sortBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(sortBtn)
	sortBtn:SetSize(130, 22)
	sortBtn:SetPoint("TOPRIGHT", -22, 1)
	sortBtn:SetScript("OnClick", function(b) p:OpenSortMenu(b) end)
	p.sortBtn = sortBtn
	local sortLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	sortLabel:SetPoint("RIGHT", sortBtn, "LEFT", -4, 0)
	sortLabel:SetText("Сортировка:")

	-- темы
	local entries = { { "all", "Все теги" }, { "selected", "Выбранные" } }
	for i, theme in ipairs(TH.TAG_THEMES) do entries[#entries + 1] = { i, theme.name } end
	local h = math.min(18, math.floor(rows * rowH / #entries))
	p.themeButtons = {}
	for i, e in ipairs(entries) do
		p.themeButtons[i] = ThemeButton(p, e[1], e[2], gridY - (i - 1) * h, h)
	end
	local divider = p:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 1, 1, 0.12)
	divider:SetSize(1, rows * rowH)
	divider:SetPoint("TOPLEFT", THEME_W + 4, gridY)

	-- теги
	for i = 1, cols * rows do
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
		local cb = CreateFrame("CheckButton", nil, p, "UICheckButtonTemplate")
		cb:SetSize(22, 22)
		cb:SetPoint("TOPLEFT", gridX + col * colW, gridY - row * rowH)
		-- рамка цвета у цветовых тегов: четыре полоски по краю квадратика
		local edges = {}
		for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
			local t = cb:CreateTexture(nil, "OVERLAY", nil, -1)
			if side == "TOP" or side == "BOTTOM" then
				t:SetPoint(side .. "LEFT", 3, side == "TOP" and -3 or 3)
				t:SetPoint(side .. "RIGHT", -3, side == "TOP" and -3 or 3)
				t:SetHeight(2)
			else
				t:SetPoint("TOP" .. side, side == "LEFT" and 3 or -3, -3)
				t:SetPoint("BOTTOM" .. side, side == "LEFT" and 3 or -3, 3)
				t:SetWidth(2)
			end
			t:Hide()
			edges[#edges + 1] = t
		end
		cb.swatch = {
			SetColorTexture = function(_, r, g, b, a) for _, t in ipairs(edges) do t:SetColorTexture(r, g, b, a) end end,
			SetShown = function(_, on) for _, t in ipairs(edges) do t:SetShown(on) end end,
		}
		cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		cb.label:SetPoint("LEFT", cb, "RIGHT", 1, 0)
		cb.label:SetWidth(colW - 26)
		cb.label:SetJustifyH("LEFT")
		cb.label:SetWordWrap(false)
		cb:SetScript("OnClick", function(b) if b.key then p:Toggle(b.key) end end)
		cb:SetScript("OnEnter", function(b)
			if not b.key then return end
			GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
			GameTooltip:SetText(TH.TAG_LABEL[b.key])
			GameTooltip:AddLine(TH.TAG_GROUP[b.key], 0.7, 0.7, 0.7)
			GameTooltip:AddLine("Образов с тегом: " .. (p.counts[b.key] or 0), 1, 1, 1)
			if p.trend then GameTooltip:AddLine("За 14 дней: " .. (p.trend[b.key] or 0), 1, 1, 1) end
			local ok, why = p:CanSelect(b.key)
			if not ok and why then GameTooltip:AddLine(why, 1, 0.3, 0.3, true) end
			if TH.RAID_TAGS[b.key] and ok and p.canSelect then
				GameTooltip:AddLine("Подходит: не меньше половины видимых вещей — из рейдов этого дополнения.", 0.3, 1, 0.3, true)
			end
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", GameTooltip_Hide)
		cb:EnableMouseWheel(true)
		cb:SetScript("OnMouseWheel", function(_, delta) p:Scroll(delta) end)
		p.slots[i] = cb
	end

	-- полоса прокрутки со стрелками справа от сетки
	p.scrollBar = TH.CreateScrollBar(p, function(value)
		if value ~= p.offset then
			p.offset = value
			p:Refresh(true)
		end
	end)
	p.scrollBar:SetPoint("TOP", p, "TOPRIGHT", -9, gridY - 2 - 18)
	p.scrollBar:SetPoint("BOTTOM", p, "TOPRIGHT", -9, gridY - rows * rowH + 18)

	-- пусто: в поиске — предложить тег
	p.empty = CreateFrame("Frame", nil, p)
	p.empty:SetSize(cols * colW, 60)
	p.empty:SetPoint("TOPLEFT", gridX + 4, gridY - 4)
	p.emptyText = p.empty:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	p.emptyText:SetPoint("TOPLEFT", 0, 0)
	p.suggestBtn = CreateFrame("Button", nil, p.empty, "UIPanelButtonTemplate")
	TH.PadButton(p.suggestBtn)
	p.suggestBtn:SetSize(160, 22)
	p.suggestBtn:SetPoint("TOPLEFT", 0, -18)
	p.suggestBtn:SetText("Предложить тег")
	p.suggestBtn:SetScript("OnClick", function() TH:OpenSuggestTag(p.search:GetText()) end)

	p.summary = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.summary:SetPoint("BOTTOMLEFT", 6, 2)
	p.summary:SetWidth(p.width - 12)
	p.summary:SetJustifyH("LEFT")
	p.summary:SetWordWrap(false)

	p:EnableMouseWheel(true)
	p:SetScript("OnMouseWheel", function(_, delta) p:Scroll(delta) end)
	p:Refresh()
	return p
end

---------------------------------------------------------------------------
-- Окно «Предложить тег»
---------------------------------------------------------------------------
local suggestDlg

local function SendSuggestion()
	local err = TH:SuggestTag(suggestDlg.edit:GetText() or "")
	if err then
		suggestDlg.error:SetText(err)
		return
	end
	suggestDlg:Hide()
end

function TH:OpenSuggestTag(text)
	local d = suggestDlg
	if not d then
		d = CreateFrame("Frame", "TransmogHubSuggestTag", UIParent, "BasicFrameTemplateWithInset")
		suggestDlg = d
		d:SetSize(340, 170)
		d:SetPoint("CENTER", 0, 120)
		d:SetFrameStrata("FULLSCREEN_DIALOG")
		d:SetToplevel(true)
		d:EnableMouse(true)
		tinsert(UISpecialFrames, d:GetName())

		local title = d:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText("Предложить тег")

		local info = d:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		info:SetPoint("TOPLEFT", 16, -34)
		info:SetWidth(308)
		info:SetJustifyH("LEFT")
		info:SetText("Тег появится в обновлении аддона, если его предложат несколько игроков.")

		d.edit = CreateFrame("EditBox", nil, d, "InputBoxTemplate")
		d.edit:SetSize(296, 20)
		d.edit:SetPoint("TOPLEFT", 22, -72)
		d.edit:SetAutoFocus(false)
		d.edit:SetMaxLetters(24)
		d.edit:SetScript("OnEscapePressed", function() d:Hide() end)
		d.edit:SetScript("OnEnterPressed", SendSuggestion)
		d.edit:HookScript("OnTextChanged", function() d.error:SetText("") end)

		d.error = d:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
		d.error:SetPoint("TOPLEFT", 18, -98)
		d.error:SetWidth(304)
		d.error:SetJustifyH("LEFT")

		local send = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
		TH.PadButton(send)
		send:SetSize(120, 24)
		send:SetPoint("BOTTOMLEFT", 14, 12)
		send:SetText("Отправить")
		send:SetScript("OnClick", SendSuggestion)
		d.sendBtn = send

		local cancel = CreateFrame("Button", nil, d, "UIPanelButtonTemplate")
		TH.PadButton(cancel)
		cancel:SetSize(90, 24)
		cancel:SetPoint("BOTTOMRIGHT", -14, 12)
		cancel:SetText(CANCEL)
		cancel:SetScript("OnClick", function() d:Hide() end)
	end
	d.edit:SetText(strtrim(text or ""))
	d.error:SetText("")
	TH:ApplyScale()
	d:Show()
	TH:SkinNow(d)
	d.edit:SetFocus()
end
