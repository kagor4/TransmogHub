local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Окно настроек: шестерёнка в шапке, /thub settings и раздел аддона в настройках
-- игры (Esc → Настройки → Аддоны). Слева — уведомления, вид и приватность,
-- справа — всплывашки (стиль, место, размер, время) и данные.
---------------------------------------------------------------------------
local W, H = 660, 580
local frame

local function Label(parent, text, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

local function Tip(widget, title, text)
	widget:HookScript("OnEnter", function(w)
		GameTooltip:SetOwner(w, "ANCHOR_RIGHT")
		GameTooltip:SetText(title)
		if text then GameTooltip:AddLine(text, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	widget:HookScript("OnLeave", GameTooltip_Hide)
end

-- Колонка: элементы идут сверху вниз
local function Column(x)
	local col = { x = x, y = -36, controls = {} }
	function col:Header(text)
		self.y = self.y - (#self.controls > 0 and 10 or 0)
		local fs = Label(frame, text, "GameFontNormal")
		fs:SetPoint("TOPLEFT", self.x, self.y)
		self.y = self.y - 20
		self.controls[#self.controls + 1] = fs
		return fs
	end
	function col:Check(text, get, set, tip)
		local b = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
		b:SetSize(24, 24)
		b:SetPoint("TOPLEFT", self.x - 4, self.y + 2)
		local fs = Label(frame, text, "GameFontHighlightSmall")
		fs:SetPoint("LEFT", b, "RIGHT", 2, 0)
		fs:SetWidth(270)
		b:SetScript("OnClick", function(btn) set(btn:GetChecked()); TH:RefreshSettings() end)
		b.Sync = function() b:SetChecked(get() and true or false) end
		b.thLogKey = text
		if tip then Tip(b, text, tip) end
		self.y = self.y - 24
		self.controls[#self.controls + 1] = b
		return b
	end
	function col:Slider(text, min, max, step, get, set, fmt)
		local fs = Label(frame, text, "GameFontHighlightSmall")
		fs:SetPoint("TOPLEFT", self.x, self.y)
		local s = CreateFrame("Slider", nil, frame, "MinimalSliderTemplate")
		s:SetSize(170, 19)
		s:SetPoint("TOPLEFT", self.x, self.y - 16)
		s:SetMinMaxValues(min, max)
		s:SetValueStep(step)
		s:SetObeyStepOnDrag(true)
		local value = Label(frame, "", "GameFontHighlightSmall")
		value:SetPoint("LEFT", s, "RIGHT", 10, 0)
		s:SetScript("OnValueChanged", function(_, v, user)
			value:SetText(fmt(v))
			if user then set(v) end
		end)
		s.Sync = function() local v = get(); s:SetValue(v); value:SetText(fmt(v)) end
		self.y = self.y - 42
		self.controls[#self.controls + 1] = s
		return s
	end
	-- Кнопка-выбор: показывает текущее, по клику — меню вариантов
	function col:Choice(text, options, get, set)
		local fs = Label(frame, text, "GameFontHighlightSmall")
		fs:SetPoint("TOPLEFT", self.x, self.y - 4)
		local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
		b:SetSize(170, 22)
		b:SetPoint("TOPLEFT", self.x + 110, self.y)
		b.thLogKey = text
		b:SetScript("OnClick", function(btn)
			if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
			MenuUtil.CreateContextMenu(btn, function(_, root)
				for _, o in ipairs(type(options) == "function" and options() or options) do
					local r = root:CreateRadio(o.name, function() return get() == o.key end, function() set(o.key); TH:RefreshSettings() end)
					if o.hint and r.SetTooltip then
						r:SetTooltip(function(tooltip) GameTooltip_SetTitle(tooltip, o.name); GameTooltip_AddNormalLine(tooltip, o.hint) end)
					end
				end
			end)
		end)
		b.Sync = function()
			local list = type(options) == "function" and options() or options
			b:SetText(list[1] and list[1].name or "")
			for _, o in ipairs(list) do if o.key == get() then b:SetText(o.name) end end
		end
		self.y = self.y - 28
		self.controls[#self.controls + 1] = b
		return b
	end
	function col:Buttons(list)
		local x = self.x
		for _, item in ipairs(list) do
			local b = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
			b:SetSize(item.w or 120, 22)
			b:SetPoint("TOPLEFT", x, self.y)
			b:SetText(item.text)
			b:SetScript("OnClick", item.onClick)
			if item.text2 then b.Sync = function() b:SetText(item.text2()) end end
			if item.tip then Tip(b, item.text, item.tip) end
			x = x + (item.w or 120) + 6
			self.controls[#self.controls + 1] = b
		end
		self.y = self.y - 28
	end
	return col
end

local function Build()
	frame = CreateFrame("Frame", "TransmogHubSettings", UIParent, "BasicFrameTemplateWithInset")
	frame:SetSize(W, H)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetClampedToScreen(true)
	tinsert(UISpecialFrames, frame:GetName())
	local title = Label(frame, L["Настройки Transmog Hub"], "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	frame.all = {}

	local db = TH.db
	local left, right = Column(18), Column(W / 2 + 8)

	-- Подписки и уведомления
	left:Header(L["Уведомления подписок"])
	left:Check(L["Новые образы тех, на кого вы подписаны"], function() return db.notify.sets end, function(v) db.notify.sets = v end)
	left:Check(L["Кто-то подписался на вас"], function() return db.notify.follows end, function(v) db.notify.follows = v end)
	left:Check(L["Ваши образы оценили или добавили в избранное"], function() return db.notify.votes end, function(v) db.notify.votes = v end)
	left:Slider(L["Об оценках — только о первых"], 0, 20, 1, function() return db.notify.voteLimit or 5 end,
		function(v) db.notify.voteLimit = v end, function(v) return v == 0 and L["обо всех"] or (v .. L[" у образа"]) end)
	left:Check(L["Об образах и оценках — только от взаимных подписок"], function() return db.notify.mutualOnly end,
		function(v) db.notify.mutualOnly = v end, L["Взаимная подписка — вы подписаны на игрока, а он на вас."])
	left:Check(L["Дублировать уведомления в чат"], function() return db.notify.chat end, function(v) db.notify.chat = v end)

	-- Вид
	left:Header(L["Вид"])
	left:Slider(L["Масштаб окон"], TH.SCALE_MIN, TH.SCALE_MAX, TH.SCALE_STEP, function() return db.scale or 1 end,
		function(v) TH:SetScale(v) end, function(v) return math.floor(v * 100 + 0.5) .. "%" end)
	left:Choice(L["Оформление"], {
		{ key = "auto", name = L["Авто"], hint = L["Как EllesmereUI, если он стоит; иначе обычное. Меняется после /reload."] },
		{ key = "eui", name = "EllesmereUI", hint = L["Плоские тёмные окна с акцентным цветом. Меняется после /reload."] },
		{ key = "blizzard", name = L["Обычное"], hint = L["Как окна игры. Меняется после /reload."] },
	}, function() return db.style end, function(v) db.style = v; TH:Print(L["Оформление изменится после /reload."]) end)
	-- шрифт: только те, где есть все русские и латинские буквы (проверка в Fonts.lua)
	local fontBtn = left:Choice(L["Шрифт"], function()
		local list = TH:GetFontChoices()
		list[#list + 1] = { key = "pickcustom", name = L["Свой шрифт..."], hint = TH.CUSTOM_FONT_HINT }
		return list
	end, function() return db.font end, function(v)
		if v == "pickcustom" then StaticPopup_Show("TRANSMOGHUB_CUSTOM_FONT") else db.fontChosen = true; TH:SetFont(v) end
	end)
	Tip(fontBtn, L["Шрифт окон аддона"], L["В списке только шрифты, в которых есть все русские и латинские буквы, цифры и знаки аддона: каждый знак проверяется — квадратиков не будет. «Авто» — шрифт, выбранный в EllesmereUI (если он стоит), иначе шрифт игры. Шрифты других аддонов тоже здесь. Проверить все шрифты: /thub fonts.\n\n"] .. TH.CUSTOM_FONT_HINT)
	left:Check(L["Кнопка у миникарты"], function() return not db.minimap.hide end,
		function(v) if db.minimap.hide == v then TH:ToggleMinimapButton() end end)

	-- Приватность
	left:Header(L["Приватность"])
	left:Check(L["Отчёты об ошибках аддона разработчику"], function() return db.sendErrors end, function(v) db.sendErrors = v end,
		L["Уходят только ошибки Transmog Hub: текст ошибки и место в коде, без ваших данных."])
	left:Check(L["Статистика нажатий на кнопки"], function() return db.sendUsage end,
		function(v) db.sendUsage = v; if not v then wipe(db.clicks) end end,
		L["Раз в неделю разработчику уходят только названия кнопок аддона и число нажатий — чтобы улучшать интерфейс."])
	left:Check(L["Где встречаются вещи с обликами"], function() return db.sendSources end,
		function(v) db.sendSources = v; if not v then wipe(db.srcQueue) end end,
		L["Раз в день разработчику уходят торговцы, существа и задания, у которых вы видели вещи с обликами: предмет, зона, координаты и цена, без вашего имени. Из этого собирается подсказка «Где найти» для всех."])

	-- Всплывашки
	for _, kind in ipairs({ "ach", "note" }) do
		local s = db.toasts[kind]
		right:Header(L["Всплывашки: "] .. TH.TOAST_KINDS[kind].name)
		right:Choice(L["Стиль"], TH.TOAST_STYLES, function() return s.style end, function(v) s.style = v; TH:ShowToastSample(kind) end)
		right:Choice(L["Место"], TH.TOAST_PLACES, function() return s.place end, function(v) s.place = v; TH:ShowToastSample(kind) end)
		right:Slider(L["Размер"], 0.6, 1.6, 0.05, function() return s.scale or 1 end, function(v) s.scale = v end,
			function(v) return math.floor(v * 100 + 0.5) .. "%" end)
		right:Slider(L["Сколько показывать"], 2, 15, 1, function() return s.duration or 5 end, function(v) s.duration = v end,
			function(v) return v .. L[" с"] end)
		right:Check(L["Звук"], function() return s.sound ~= false end, function(v) s.sound = v end)
		right:Buttons({
			{ text = L["Пример"], w = 90, onClick = function() TH:ShowToastSample(kind) end },
			{ text = L["Разблокировать"], w = 130,
				text2 = function() return TH:IsToastUnlocked(kind) and L["Заблокировать"] or L["Разблокировать"] end,
				onClick = function() TH:SetToastUnlocked(kind, not TH:IsToastUnlocked(kind)); TH:RefreshSettings() end,
				tip = L["Разблокировать — всплывашка встанет на экран, перетащите её мышью куда удобно. Заблокировать — место запомнится. Место станет «своим»."] },
			{ text = L["Сбросить"], w = 80, onClick = function() TH:SetToastUnlocked(kind, false); TH:ResetToastPosition(kind); TH:RefreshSettings(); TH:ShowToastSample(kind) end },
		})
	end

	-- Данные
	right:Header(L["Данные"])
	right:Buttons({
		{ text = L["Синхронизировать"], w = 140, onClick = function() TH.Net:RequestSync() end,
			tip = L["Запросить у игроков в сети всё новое."] },
		{ text = L["Убрать тестовую ленту"], w = 160, onClick = function()
			wipe(db.testSets); TH:LoadFeed(); TH:NotifyChanged(); TH:Print(L["Тестовые образы удалены."]) end },
	})
	right:Buttons({
		{ text = L["Скрытые образы..."], w = 150, onClick = function(b) TH:OpenHiddenMenu(b) end,
			tip = L["Список того, что вы скрыли или на что пожаловались. Нажмите на образ — он снова будет виден, ваша жалоба на него отозвана."] },
		{ text = L["Вернуть все"], w = 150, onClick = function() StaticPopup_Show("TRANSMOGHUB_UNDO_REPORTS") end,
			tip = L["Все скрытые вами образы и игроки рейтинга снова видны, ваши жалобы и отметки «тег не подходит» отзываются у всех. Пригодится после проверки аддона."] },
	})

	for _, col in ipairs({ left, right }) do
		for _, c in ipairs(col.controls) do frame.all[#frame.all + 1] = c end
	end
	frame:SetScript("OnShow", function() TH:RefreshSettings() end)
	frame:SetScript("OnHide", function() TH:LockAllToasts() end) -- закрыли настройки — места запомнены
end

function TH:RefreshSettings()
	if not frame then return end
	for _, c in ipairs(frame.all) do
		if c.Sync then c:Sync() end
	end
end

function TH:OpenSettings()
	if not frame then Build() end
	self:ApplyScale()
	frame:SetScale(self.db.scale or 1)
	frame:Show()
	frame:Raise()
	-- окно создаётся уже показанным, и OnShow при первом открытии не срабатывает
	self:RefreshSettings()
end

function TH:ToggleSettings()
	if frame and frame:IsShown() then frame:Hide() else self:OpenSettings() end
end

-- Свой шрифт: имя файла в Interface\Fonts; берём, только если в нём есть все знаки
StaticPopupDialogs["TRANSMOGHUB_CUSTOM_FONT"] = {
	text = L["Имя файла шрифта в папке World of Warcraft\\_retail_\\Interface\\Fonts (например MyFont.ttf).\nПосле того как положили файл, игру нужно перезапустить целиком."],
	button1 = ACCEPT or L["Принять"], button2 = CANCEL or L["Отмена"], hasEditBox = true, maxLetters = 100,
	OnAccept = function(dialog)
		local eb = dialog.EditBox or dialog.editBox
		TH:UseCustomFont(eb and eb:GetText() or "")
	end,
	EditBoxOnEnterPressed = function(eb)
		TH:UseCustomFont(eb:GetText() or "")
		eb:GetParent():Hide()
	end,
	timeout = 0, whileDead = true, hideOnEscape = true,
}

function TH:UseCustomFont(file)
	file = strtrim(file or ""):gsub("^.*[\\/]", "")
	if file == "" then return end
	local ok, missing = self:CheckFont(self.CUSTOM_FONT_DIR .. file)
	if not ok then
		self:Notify(L["Шрифт «"] .. file .. L["» не подходит: "] .. ((missing[1] and #missing[1] > 4) and missing[1]
			or (L["нет знаков "] .. table.concat(missing, " ", 1, math.min(#missing, 15)) .. (#missing > 15 and " ..." or "")))
			.. L[". Проверьте имя файла и папку; новые файлы игра видит только после перезапуска."])
		return
	end
	self.db.customFont = file
	self:SetFont("custom")
	self:RefreshSettings()
	self:Notify(L["Шрифт «"] .. file .. L["» подключён."])
end

-- Раздел в настройках игры: кнопка открывает наше окно
function TH:RegisterBlizzardSettings()
	if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
	local panel = CreateFrame("Frame")
	local text = Label(panel, "Transmog Hub", "GameFontNormalLarge")
	text:SetPoint("TOPLEFT", 16, -16)
	local hint = Label(panel, L["Уведомления подписок, всплывашки, вид и приватность — в окне настроек аддона."], "GameFontHighlight")
	hint:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -10)
	local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	b:SetSize(220, 26)
	b:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
	b:SetText(L["Открыть настройки Transmog Hub"])
	b:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel.Hide then HideUIPanel(SettingsPanel) end
		TH:OpenSettings()
	end)
	local category = Settings.RegisterCanvasLayoutCategory(panel, "Transmog Hub")
	Settings.RegisterAddOnCategory(category)
end
