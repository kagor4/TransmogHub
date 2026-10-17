local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Выбор иконки образа: сверху рекомендуемые (вещи образа и иконки к тегам),
-- ниже все иконки игры — тот же список, что в окне выбора иконки макроса.
---------------------------------------------------------------------------
local COLS, ICON, GAP = 12, 36, 4
local REC_ROWS, ALL_ROWS = 2, 6
local MAX_REC_ROWS = 4 -- рекомендуемых может быть больше строк за счёт общего списка
local picker
local allIcons -- все иконки игры, собираются при первом открытии

-- Иконка как номер файла (в сети передаётся только номер)
local function ToFileID(icon)
	if type(icon) == "number" then return icon end
	if type(icon) ~= "string" or icon == "" then return nil end
	local path = icon:find("\\", 1, true) and icon or ("Interface\\Icons\\" .. icon)
	return GetFileIDFromPath and GetFileIDFromPath(path) or nil
end
TH.IconToFileID = ToFileID

local function CollectAllIcons()
	if allIcons then return allIcons end
	local raw = {}
	for _, name in ipairs({ "GetLooseMacroIcons", "GetLooseMacroItemIcons", "GetMacroIcons", "GetMacroItemIcons" }) do
		if _G[name] then _G[name](raw) end
	end
	allIcons = {}
	local seen = {}
	for _, icon in ipairs(raw) do
		local id = tonumber(icon) or ToFileID(icon)
		if id and not seen[id] then
			seen[id] = true
			allIcons[#allIcons + 1] = id
		end
	end
	return allIcons
end

-- Рекомендуемые: иконки вещей образа, потом иконки к выбранным тегам
function TH:GetRecommendedIcons(items, tags)
	local out, seen = {}, {}
	local function Add(icon)
		local id = ToFileID(icon)
		if id and not seen[id] then
			seen[id] = true
			out[#out + 1] = id
		end
	end
	for _, slot in ipairs({ 5, 1, 3, 15, 16, 17, 7, 10, 6, 8, 9, 4, 19 }) do
		local it = items and items[slot]
		local det = it and self:GetSourceDetails(it[1])
		if det and not det.hidden then Add(det.icon) end
	end
	for _, tag in ipairs(tags or {}) do
		for _, name in ipairs(TransmogHub_TagIcons and TransmogHub_TagIcons[tag] or {}) do Add(name) end
	end
	return out
end

local function IconButton(parent, x, y)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(ICON, ICON)
	b:SetPoint("TOPLEFT", x, y)
	b.tex = b:CreateTexture(nil, "ARTWORK")
	b.tex:SetAllPoints()
	-- рамка в цвет (у наградных аватаров — редкость достижения)
	b.border = b:CreateTexture(nil, "BACKGROUND")
	b.border:SetPoint("TOPLEFT", -2, 2)
	b.border:SetPoint("BOTTOMRIGHT", 2, -2)
	b.border:Hide()
	b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	b.sel = b:CreateTexture(nil, "OVERLAY")
	b.sel:SetPoint("TOPLEFT", -3, 3)
	b.sel:SetPoint("BOTTOMRIGHT", 3, -3)
	b.sel:SetColorTexture(1, 0.82, 0, 0.45)
	b.sel:Hide()
	b:SetScript("OnClick", function(btn)
		if btn.icon and not btn.locked then picker:Pick(ToFileID(btn.icon)) end
	end)
	b:SetScript("OnEnter", function(btn)
		local tip = btn.icon and picker.tooltips and picker.tooltips[btn.icon]
		if not tip then return end
		GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
		GameTooltip:SetText(tip[1])
		if tip[2] then GameTooltip:AddLine(tip[2], 1, 1, 1, true) end
		if btn.locked then GameTooltip:AddLine(L["Ещё не открыт"], 1, 0.3, 0.3) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", GameTooltip_Hide)
	return b
end

local function Build()
	picker = CreateFrame("Frame", "TransmogHubIconPicker", UIParent, "BasicFrameTemplateWithInset")
	picker:SetSize(COLS * (ICON + GAP) + 56, 470)
	picker:SetPoint("CENTER", 0, 40)
	picker:SetFrameStrata("FULLSCREEN_DIALOG")
	picker:SetToplevel(true)
	picker:EnableMouse(true)
	picker:SetMovable(true)
	picker:RegisterForDrag("LeftButton")
	picker:SetScript("OnDragStart", picker.StartMoving)
	picker:SetScript("OnDragStop", picker.StopMovingOrSizing)
	tinsert(UISpecialFrames, picker:GetName())

	picker.title = picker:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	picker.title:SetPoint("TOP", 0, -6)

	picker.recLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	picker.recLabel:SetPoint("TOPLEFT", 16, -32)
	picker.recLabel:SetText(L["Рекомендуемые: вещи образа и иконки к тегам"])
	picker.rec = {}
	for i = 1, COLS * MAX_REC_ROWS do
		local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
		picker.rec[i] = IconButton(picker, 16 + col * (ICON + GAP), -52 - row * (ICON + GAP))
	end

	picker.allLabel = picker:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	picker.all, picker.offset = {}, 0
	for i = 1, COLS * ALL_ROWS do
		local b = IconButton(picker, 0, 0)
		b:EnableMouseWheel(true)
		b:SetScript("OnMouseWheel", function(_, delta) picker:Scroll(delta * 2) end)
		picker.all[i] = b
	end

	-- быстрая прокрутка: полоса со стрелками справа от сетки
	picker.bar = TH.CreateScrollBar(picker, function(value)
		if value ~= picker.offset then
			picker.offset = value
			picker:RefreshAll()
		end
		picker.bar:Sync(picker.offset, picker:MaxOffset())
	end)

	-- раскладка: recRows строк рекомендуемых, остальное — общий список
	function picker:Layout(recRows)
		self.recRows, self.allRows = recRows, REC_ROWS + ALL_ROWS - recRows
		for i, b in ipairs(self.rec) do
			if i > COLS * recRows then b:Hide() end
		end
		self.allLabel:ClearAllPoints()
		self.allLabel:SetPoint("TOPLEFT", 16, -52 - recRows * (ICON + GAP) - 10)
		local allTop = -52 - recRows * (ICON + GAP) - 30
		for i, b in ipairs(self.all) do
			local col, row = (i - 1) % COLS, math.floor((i - 1) / COLS)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", 16 + col * (ICON + GAP), allTop - row * (ICON + GAP))
		end
		self.bar:ClearAllPoints()
		self.bar:SetPoint("TOPLEFT", 16 + COLS * (ICON + GAP) + 5, allTop - 18)
		self.bar:SetHeight(self.allRows * (ICON + GAP) - GAP - 36)
	end
	picker:Layout(REC_ROWS)

	picker.defaultBtn = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
	TH.PadButton(picker.defaultBtn)
	picker.defaultBtn:SetSize(170, 24)
	picker.defaultBtn:SetPoint("BOTTOMLEFT", 14, 12)
	picker.defaultBtn:SetText(L["По умолчанию"])
	picker.defaultBtn:SetScript("OnClick", function() picker:Pick(nil) end)
	picker.defaultBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["По умолчанию"])
		GameTooltip:AddLine(picker.defaultHint, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	picker.defaultBtn:SetScript("OnLeave", GameTooltip_Hide)

	local cancel = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
	TH.PadButton(cancel)
	cancel:SetSize(100, 24)
	cancel:SetPoint("BOTTOMRIGHT", -14, 12)
	cancel:SetText(CANCEL)
	cancel:SetScript("OnClick", function() picker:Hide() end)

	picker:EnableMouseWheel(true)
	picker:SetScript("OnMouseWheel", function(_, delta) picker:Scroll(delta * 2) end)

	function picker:Pick(fileID)
		self:Hide()
		if self.onPick then self.onPick(fileID) end
	end

	function picker:MaxOffset()
		return math.max(0, math.ceil(#self.list / COLS) - self.allRows)
	end

	function picker:Scroll(delta)
		self.offset = math.min(math.max(self.offset - delta, 0), self:MaxOffset())
		self.bar:Sync(self.offset, self:MaxOffset())
		self:RefreshAll()
	end

	local function Mark(b, icon)
		b.icon = icon
		b.locked = icon ~= nil and picker.locked and picker.locked[icon] or false
		b.tex:SetTexture(icon)
		b.tex:SetDesaturated(b.locked)
		-- закрытые: ч/б и затемнены, но непрозрачны — рамка не просвечивает сквозь значок
		b.tex:SetVertexColor(b.locked and 0.45 or 1, b.locked and 0.45 or 1, b.locked and 0.45 or 1)
		b.sel:SetShown(icon ~= nil and ToFileID(icon) == picker.current)
		local c = icon ~= nil and picker.borders and picker.borders[icon]
		if c then b.border:SetColorTexture(c[1], c[2], c[3], b.locked and 0.45 or 0.6) end
		b.border:SetShown(c and true or false)
		b:SetShown(icon ~= nil)
	end

	function picker:RefreshRecommended()
		for i, b in ipairs(self.rec) do
			if i <= COLS * self.recRows then Mark(b, self.recommended[i]) end
		end
	end

	function picker:RefreshAll()
		local first = self.offset * COLS
		for i, b in ipairs(self.all) do
			Mark(b, i <= COLS * self.allRows and self.list[first + i] or nil)
		end
	end
end

-- opts: current (fileID или nil), tags, items (или getItems(callback)), onPick(fileID или nil);
-- для других целей: title, recommended (свой список), recLabel, defaultHint,
-- list (свой список вместо всех иконок игры), allLabel, locked[fileID], tooltips[fileID] = { заголовок, текст },
-- borders[fileID] = { r, g, b } (рамка), recRows (строк рекомендуемых, до 4)
function TH:OpenIconPicker(opts)
	if not picker then Build() end
	CollectAllIcons()
	picker.current, picker.onPick, picker.offset = opts.current, opts.onPick, 0
	picker.title:SetText(opts.title or L["Иконка образа"])
	picker.recLabel:SetText(opts.recLabel or L["Рекомендуемые: вещи образа и иконки к тегам"])
	picker.defaultHint = opts.defaultHint or L["Иконка вещи на груди из образа."]
	if opts.recommended then
		picker.recommended = {}
		for _, icon in ipairs(opts.recommended) do
			local id = ToFileID(icon)
			if id and not tContains(picker.recommended, id) then picker.recommended[#picker.recommended + 1] = id end
		end
	else
		picker.recommended = self:GetRecommendedIcons(opts.items, opts.tags)
	end
	picker.list = opts.list or allIcons
	picker.locked, picker.tooltips, picker.borders = opts.locked, opts.tooltips, opts.borders
	picker:Layout(opts.recRows or REC_ROWS)
	picker.allLabel:SetText(opts.allLabel or string.format(L["Все иконки игры (%d) — колесо мыши или ползунок"], #allIcons))
	picker.bar:Sync(0, picker:MaxOffset())
	picker:RefreshRecommended()
	picker:RefreshAll()
	self:ApplyScale()
	picker:SetScale(self.db.scale or 1)
	picker:Show()
	TH:SkinNow(picker)
	-- вещи образа узнаём, только сняв облик: подгружаем и дополняем рекомендации
	if not opts.recommended and not opts.items and opts.getItems then
		opts.getItems(function(items)
			if not items or not picker:IsShown() then return end
			picker.recommended = self:GetRecommendedIcons(items, opts.tags)
			picker:RefreshRecommended()
		end)
	end
end
