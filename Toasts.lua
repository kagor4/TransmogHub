local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Всплывашки: достижения («ach») и уведомления подписок («note»). У каждого вида
-- свой стиль (пресет), место (в стопке оповещений игры или своё, перетаскиванием),
-- размер и время показа — настраиваются в окне настроек.
-- Вид по умолчанию разный, чтобы уведомление не путалось с достижением.
---------------------------------------------------------------------------
TH.TOAST_STYLES = {
	{ key = "classic", name = "Классика", hint = "Рамка подсказки игры, цвет рамки — редкость или тип события" },
	{ key = "dark", name = "Тёмный", hint = "Плоский тёмный фон и цветная полоса слева" },
	{ key = "compact", name = "Компактный", hint = "Одна строка, маленькая иконка" },
}
TH.TOAST_PLACES = {
	{ key = "alerts", name = "В стопке оповещений игры", hint = "Там же, где достижения и добыча игры (и куда их сдвинули другие аддоны)" },
	{ key = "custom", name = "Своё место", hint = "Куда перетащите кнопкой «Переместить»" },
}
TH.TOAST_KINDS = {
	ach = { name = "Достижения", sample = { icon = "Interface\\Icons\\Achievement_Quests_Completed_06",
		header = "Достижение Transmog Hub", title = "|cff0070ddПример достижения|r", text = "Редкое, |cff40ff40+25|r очков стиля",
		color = { 0, 0.44, 0.87 } } },
	note = { name = "Уведомления", sample = { icon = "Interface\\Icons\\INV_Letter_15",
		header = "Transmog Hub · подписки", title = "Новый образ от Автора", text = "«Пример образа»",
		color = { 0.2, 0.75, 0.95 } } },
}

local DEFAULT_POINT = { ach = { "TOP", "UIParent", "TOP", 0, -150 }, note = { "RIGHT", "UIParent", "RIGHT", -60, 140 } }
local frames, queues, showing = {}, { ach = {}, note = {} }, {}
local ShowNext
local NormalClick

local function Settings(kind)
	return TH.db.toasts[kind]
end

-- Плоские края в 1 px (для тёмного и компактного стиля)
local function Edges(f)
	if f.edges then return f.edges end
	f.edges = {}
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = f:CreateTexture(nil, "BORDER")
		if side == "TOP" or side == "BOTTOM" then
			t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(1)
		else
			t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(1)
		end
		f.edges[#f.edges + 1] = t
	end
	return f.edges
end

local function Build(kind)
	local f = CreateFrame("Frame", kind == "ach" and "TransmogHubAchievementToast" or "TransmogHubNoteToast", UIParent, "BackdropTemplate")
	f.kind = kind
	f:SetFrameStrata("DIALOG")
	f:SetClampedToScreen(true)
	f:Hide()
	f.flat = f:CreateTexture(nil, "BACKGROUND")
	f.flat:SetAllPoints()
	f.stripe = f:CreateTexture(nil, "ARTWORK")
	f.stripe:SetPoint("TOPLEFT")
	f.stripe:SetPoint("BOTTOMLEFT")
	f.stripe:SetWidth(4)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.header = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	f.title:SetJustifyH("LEFT")
	f.title:SetWordWrap(false)
	f.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	f.text:SetJustifyH("LEFT")
	f.text:SetWordWrap(false)
	f:EnableMouse(true)
	f:SetScript("OnMouseUp", function(self, button) if not self.moving then NormalClick(self, button) end end)

	-- в стопке оповещений игры: встаём над предыдущим оповещением
	if AlertFrame and AlertFrame.AddAlertFrameSubSystem and AlertFrame.UpdateAnchors then
		AlertFrame:AddAlertFrameSubSystem({
			AdjustAnchors = function(_, relative)
				if not f:IsShown() or f.moving or Settings(kind).place ~= "alerts" then return relative end
				f:ClearAllPoints()
				f:SetPoint("BOTTOM", relative, "TOP", 0, 10)
				return f
			end,
			CheckQueuedAlerts = function() end,
		})
		f.inAlerts = true
		f:HookScript("OnHide", function() AlertFrame:UpdateAnchors() end)
	end
	-- закрыли (по таймеру или кликом) — следующая из очереди
	f:HookScript("OnHide", function(self)
		if self.moving then return end
		showing[kind] = false
		self.token = nil
		C_Timer.After(0.3, function() ShowNext(kind) end)
	end)
	frames[kind] = f
	return f
end

-- Стиль: размеры и фон; color — цвет рамки или полосы
local function ApplyStyle(f, style, color)
	local r, g, b = color[1], color[2], color[3]
	local compact = style == "compact"
	f:SetSize(compact and 300 or (style == "dark" and 320 or 340), compact and 36 or (style == "dark" and 64 or 72))
	local iconSize = compact and 26 or (style == "dark" and 42 or 48)
	f.icon:ClearAllPoints()
	f.icon:SetSize(iconSize, iconSize)
	f.icon:SetPoint("LEFT", style == "classic" and 12 or 12, 0)
	if style == "classic" then
		f:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
		f:SetBackdropColor(0, 0, 0, 0.9)
		f:SetBackdropBorderColor(r, g, b)
		f.flat:Hide(); f.stripe:Hide()
		for _, e in ipairs(Edges(f)) do e:Hide() end
	else
		f:SetBackdrop(nil)
		f.flat:SetColorTexture(0.05, 0.05, 0.06, 0.94)
		f.flat:Show()
		f.stripe:SetColorTexture(r, g, b, 1)
		f.stripe:Show()
		for _, e in ipairs(Edges(f)) do e:SetColorTexture(0, 0, 0, 1); e:Show() end
	end
	f.header:ClearAllPoints(); f.title:ClearAllPoints(); f.text:ClearAllPoints()
	if compact then
		f.header:Hide()
		f.title:SetFontObject(GameFontNormal)
		f.title:SetPoint("LEFT", f.icon, "RIGHT", 8, 0)
		f.title:SetPoint("RIGHT", f, "RIGHT", -8, 0)
		f.text:Hide()
	else
		f.header:Show(); f.text:Show()
		f.title:SetFontObject(style == "dark" and GameFontNormal or GameFontNormalLarge)
		f.header:SetPoint("TOPLEFT", f.icon, "TOPRIGHT", 10, style == "dark" and 0 or -2)
		f.title:SetPoint("TOPLEFT", f.header, "BOTTOMLEFT", 0, -3)
		f.title:SetPoint("RIGHT", f, "RIGHT", -10, 0)
		f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
		f.text:SetPoint("RIGHT", f, "RIGHT", -10, 0)
	end
end

local function Place(f)
	local s = Settings(f.kind)
	f:SetScale(s.scale or 1)
	if s.place == "alerts" and f.inAlerts then
		AlertFrame:UpdateAnchors()
		return
	end
	local p = s.point or DEFAULT_POINT[f.kind]
	f:ClearAllPoints()
	f:SetPoint(p[1], UIParent, p[3], p[4], p[5])
end

local function Fill(f, data)
	f.data = data
	local s = Settings(f.kind)
	ApplyStyle(f, s.style, data.color or { 1, 0.82, 0 })
	f.icon:SetTexture(data.icon or 134400)
	f.header:SetText(data.header or "")
	if s.style == "compact" then
		f.title:SetText((data.title or "") .. (data.text and data.text ~= "" and ("  |cffcccccc" .. data.text .. "|r") or ""))
		-- одна строка: ширина — по тексту (от 240 до 460), чтобы не обрезалось
		local w = f.title.GetUnboundedStringWidth and f.title:GetUnboundedStringWidth() or f.title:GetStringWidth()
		if type(w) == "number" and w > 0 then f:SetWidth(math.max(240, math.min(460, math.ceil(w) + 26 + 12 + 16))) end
	else
		f.title:SetText(data.title or "")
		f.text:SetText(data.text or "")
	end
end

function ShowNext(kind)
	local f = frames[kind] or Build(kind)
	if showing[kind] or f.moving or #queues[kind] == 0 then return end
	local data = tremove(queues[kind], 1)
	showing[kind] = true
	Fill(f, data)
	f:SetAlpha(1)
	f:Show()
	Place(f)
	if data.sound and Settings(kind).sound ~= false then PlaySound(data.sound) end
	local token = {}
	f.token = token
	C_Timer.After(Settings(kind).duration or 5, function()
		if f.token ~= token then return end
		UIFrameFadeOut(f, 1, 1, 0)
		C_Timer.After(1, function()
			if f.token == token then f:Hide() end
		end)
	end)
end

-- data: icon, header, title, text, color {r,g,b}, sound, onClick
function TH:ShowToast(kind, data)
	tinsert(queues[kind], data)
	ShowNext(kind)
end

-- Пример — чтобы посмотреть стиль и место
function TH:ShowToastSample(kind)
	self:ShowToast(kind, TH.TOAST_KINDS[kind].sample)
end

-- Перемещение: всплывашка встаёт на место и тянется мышью, отпустили — запомнили
-- Разблокировать: всплывашка стоит на экране, пока её не заблокируют, и тянется мышью.
-- Заблокировать: место запомнено, всплывашка убирается.
function NormalClick(self, button)
	if self.moving then return end
	local onClick = self.data and self.data.onClick
	self:Hide()
	if button == "LeftButton" and onClick then onClick() end
end

function TH:IsToastUnlocked(kind)
	return frames[kind] ~= nil and frames[kind].moving == true
end

function TH:SetToastUnlocked(kind, unlocked)
	local f = frames[kind] or Build(kind)
	local s = Settings(kind)
	if unlocked then
		f.token = nil -- таймер текущей всплывашки её не уберёт
		showing[kind] = true
		f.moving = true
		local sample = CopyTable(TH.TOAST_KINDS[kind].sample)
		sample.title = "Перетащите в удобное место"
		sample.text = "Потом — «Заблокировать» в настройках"
		Fill(f, sample)
		s.place = "custom"
		Place(f)
		f:SetAlpha(1)
		f:Show()
		f:SetMovable(true)
		f:RegisterForDrag("LeftButton")
		f:SetScript("OnDragStart", f.StartMoving)
		f:SetScript("OnDragStop", function(self)
			self:StopMovingOrSizing()
			local point, _, rel, x, y = self:GetPoint()
			s.point = { point, "UIParent", rel, math.floor(x + 0.5), math.floor(y + 0.5) }
		end)
	elseif f.moving then
		f.moving = false
		f:SetMovable(false)
		f:SetScript("OnDragStart", nil)
		f:SetScript("OnDragStop", nil)
		f:Hide() -- OnHide покажет следующую из очереди
	end
end

-- Окно настроек закрыли — всё блокируем
function TH:LockAllToasts()
	for kind in pairs(TH.TOAST_KINDS) do self:SetToastUnlocked(kind, false) end
end

function TH:ResetToastPosition(kind)
	local s = Settings(kind)
	s.point = nil
	s.place = kind == "ach" and "alerts" or "custom"
end
