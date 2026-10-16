local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Обучающий тур: несколько шагов, каждый подсвечивает часть окна золотой
-- рамкой и объясняет её в подсказке рядом. Запускается при первом открытии,
-- повторить — /thub tour или кнопкой в справке.
---------------------------------------------------------------------------
local tour

-- target(ui) — что подсветить; side — где пузырь: "below" | "above" | "right" | "left"
local STEPS = {
	{ title = "Разделы", side = "below",
		text = "Наверху вкладки: все образы, образы друзей, избранное, ваш профиль и достижения. Подсказка есть у каждой — наведите курсор.",
		target = function(ui) return ui.tabs[1], ui.tabs[#ui.tabs] end },
	{ title = "Список образов", side = "right",
		text = "Сверху сортировка: лучшие, в тренде, новые, рекомендуемые (кубик — перемешать). Клик по образу — примерить. Звёздочка справа — добавить в избранное, полоска под иконкой — сколько вещей уже собрано у вас.",
		target = function(ui) return ui.listPanel end },
	{ title = "Примерка", side = "right",
		text = "Образ на вашем персонаже. Мышью можно вращать и приближать, двойной клик — вернуть камеру. Снизу — другая раса и примерочная Wowhead (там можно выбрать и пол).",
		target = function(ui) return ui.previewPanel end },
	{ title = "Подробности", side = "left",
		text = "Название, автор (клик — его профиль), оценка звёздами, теги и все вещи: собрано ли и откуда (наведите на строку).",
		target = function(ui) return ui.detailPanel end },
	{ title = "Поделитесь своим", side = "below",
		text = "Наденьте трансмог и нажмите «Новый образ» — его увидят все игроки с аддоном.",
		target = function(ui) return ui.saveBtn end },
	{ title = "Если что-то непонятно", side = "below",
		text = "Справка всегда здесь: что где искать и как всё устроено. Удачи и красивых образов!",
		target = function(ui) return ui.helpBtn end },
}

local function Build()
	tour = CreateFrame("Frame", "TransmogHubTour", UIParent)
	tour:SetFrameStrata("FULLSCREEN_DIALOG")
	tour:Hide()

	-- рамка вокруг подсвеченной части окна, мягко пульсирует
	tour.glow = CreateFrame("Frame", nil, tour)
	local edges = {}
	for i = 1, 4 do
		local t = tour.glow:CreateTexture(nil, "OVERLAY")
		t:SetColorTexture(1, 0.82, 0, 1)
		edges[i] = t
	end
	edges[1]:SetPoint("TOPLEFT"); edges[1]:SetPoint("TOPRIGHT"); edges[1]:SetHeight(3)
	edges[2]:SetPoint("BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT"); edges[2]:SetHeight(3)
	edges[3]:SetPoint("TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT"); edges[3]:SetWidth(3)
	edges[4]:SetPoint("TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT"); edges[4]:SetWidth(3)
	local ag = tour.glow.CreateAnimationGroup and tour.glow:CreateAnimationGroup()
	if ag then
		ag:SetLooping("BOUNCE")
		local a = ag:CreateAnimation("Alpha")
		if a then
			a:SetFromAlpha(1)
			a:SetToAlpha(0.35)
			a:SetDuration(0.8)
			ag:Play()
		end
	end

	-- пузырь с текстом
	local b = CreateFrame("Frame", nil, tour, "BackdropTemplate")
	tour.bubble = b
	b:SetSize(300, 140)
	b:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	b:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
	b:SetBackdropBorderColor(1, 0.82, 0)
	b:EnableMouse(true)

	b.step = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	b.step:SetPoint("TOPRIGHT", -12, -10)
	b.title = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	b.title:SetPoint("TOPLEFT", 12, -10)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	b.text:SetPoint("TOPLEFT", b.title, "BOTTOMLEFT", 0, -8)
	b.text:SetWidth(276)
	b.text:SetJustifyH("LEFT")

	b.next = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
	TH.PadButton(b.next)
	b.next:SetSize(100, 22)
	b.next:SetPoint("BOTTOMRIGHT", -10, 10)
	b.next:SetScript("OnClick", function() TH:TourStep(tour.index + 1) end)
	if TH.StylePrimaryButton then TH.StylePrimaryButton(b.next) end

	b.skip = CreateFrame("Button", nil, b)
	b.skip:SetNormalFontObject("GameFontDisableSmall")
	b.skip:SetHighlightFontObject("GameFontHighlightSmall")
	b.skip:SetText("Пропустить")
	b.skip:SetSize(90, 20)
	b.skip:SetPoint("BOTTOMLEFT", 8, 11)
	b.skip:SetScript("OnClick", function() TH:EndTour() end)
end

function TH:TourStep(index)
	local ui = self.UI
	local step = STEPS[index]
	if not step or not ui:IsShown() then return self:EndTour() end
	tour.index = index
	local first, last = step.target(ui)
	last = last or first
	if not first then return self:TourStep(index + 1) end

	tour.glow:ClearAllPoints()
	tour.glow:SetPoint("TOPLEFT", first, "TOPLEFT", -4, 4)
	tour.glow:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 4, -4)

	local b = tour.bubble
	b.title:SetText(step.title)
	b.text:SetText(step.text)
	b.step:SetText(index .. " из " .. #STEPS)
	b.next:SetText(index == #STEPS and "Готово" or "Далее")
	b:SetHeight((b.text:GetStringHeight() or 60) + 80)
	b:ClearAllPoints()
	if step.side == "below" then
		b:SetPoint("TOP", tour.glow, "BOTTOM", 0, -10)
	elseif step.side == "above" then
		b:SetPoint("BOTTOM", tour.glow, "TOP", 0, 10)
	elseif step.side == "left" then
		b:SetPoint("RIGHT", tour.glow, "LEFT", -10, 0)
	else
		b:SetPoint("LEFT", tour.glow, "RIGHT", 10, 0)
	end
	b:SetClampedToScreen(true)
	tour:SetScale(self.db and self.db.scale or 1)
	tour:Show()
end

function TH:StartTour()
	local ui = self.UI
	if not ui.built then ui:Build() end
	if not ui:IsShown() then ui:Show() end
	ui:SetView("top")
	if not tour then Build() end
	self:TourStep(1)
end

function TH:EndTour()
	if tour then tour:Hide() end
	if self.db then self.db.tourDone = true end
end

function TH:IsTourShown()
	return tour ~= nil and tour:IsShown()
end
