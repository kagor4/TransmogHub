local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Оформление в стиле EllesmereUI. Если включён EllesmereUI (или выбрано
-- /thub style eui), окна аддона перекрашиваются: плоские тёмные фоны, тонкие
-- рамки, плоские кнопки, белый текст и акцентный цвет. Рамки игры не удаляются,
-- а прячутся — /thub style blizzard и /reload возвращают обычный вид.
---------------------------------------------------------------------------
local DEFAULT_ACCENT = { 0.05, 0.82, 0.62 } -- бирюзовый, как у EllesmereUI по умолчанию
local BG, PANEL, BUTTON, EDGE = { 0.06, 0.06, 0.07, 0.96 }, { 0.09, 0.09, 0.10, 0.92 }, { 0.14, 0.14, 0.16, 1 }, { 0, 0, 0, 1 }
local GOLD = { 1, 0.82, 0 }

-- Наши окна (создаются не сразу: шкурим при показе)
local WINDOWS = { "TransmogHubFrame", "TransmogHubSaveDialog", "TransmogHubIconPicker", "TransmogHubHelp",
	"TransmogHubIdeas", "TransmogHubReportOther", "TransmogHubSuggestTag", "TransmogHubAppeal", "TransmogHubWarning", "TransmogHubSettings" }

TH.WINDOWS = WINDOWS -- их же обходит статистика нажатий (Usage.lua)

-- Рамки шаблонов игры
local FRAME_ART = { "TopLeftCorner", "TopRightCorner", "TopBorder", "BotLeftCorner", "BotRightCorner", "BottomBorder",
	"LeftBorder", "RightBorder", "Bg", "TitleBg", "TopTileStreaks", "InsetBg", "InsetBorderTopLeft", "InsetBorderTopRight",
	"InsetBorderBottomLeft", "InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom", "InsetBorderLeft", "InsetBorderRight" }
local BUTTON_ART = { "Left", "Middle", "Right" }
local EDIT_ART = { "Left", "Middle", "Right", "TopLeftTex", "TopRightTex", "TopTex", "BottomLeftTex", "BottomRightTex",
	"BottomTex", "LeftTex", "RightTex", "MiddleTex" }

function TH:IsEllesmereLoaded()
	local loaded = C_AddOns and C_AddOns.IsAddOnLoaded
	return loaded and (loaded("EllesmereUI") or loaded("EllesmereUI_Core")) or false
end

-- Включено ли оформление: auto — если стоит EllesmereUI
function TH:IsSkinned()
	local mode = self.db and self.db.style or "auto"
	if mode == "eui" then return true end
	if mode == "blizzard" then return false end
	return self:IsEllesmereLoaded()
end

-- Акцентный цвет: ищем в настройках EllesmereUI ключ с «accent» (r, g, b),
-- не нашли — бирюзовый
local function FindAccent(t, depth, seen)
	if type(t) ~= "table" or depth > 4 or seen[t] then return end
	seen[t] = true
	for k, v in pairs(t) do
		if type(k) == "string" and k:lower():find("accent") and type(v) == "table" then
			local r, g, b = v.r or v[1], v.g or v[2], v.b or v[3]
			if type(r) == "number" and type(g) == "number" and type(b) == "number" and r <= 1 and g <= 1 and b <= 1 then
				return { r, g, b }
			end
		end
	end
	for _, v in pairs(t) do
		local found = FindAccent(v, depth + 1, seen)
		if found then return found end
	end
end

function TH:GetAccent()
	if self.accent then return self.accent end
	local found
	for _, name in ipairs({ "EllesmereUIDB", "EllesmereUI_DB", "EllesmereUI" }) do
		local ok, res = pcall(FindAccent, _G[name], 1, {})
		if ok and res then found = res break end
	end
	self.accent = found or DEFAULT_ACCENT
	return self.accent
end

-- Плоский фон с рамкой в 1 пиксель (свои текстуры, поверх ничего не рисуют)
local function Flat(frame, color, edge)
	if frame.thFlat then
		frame.thFlat:SetColorTexture(unpack(color))
		return
	end
	local bg = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
	bg:SetAllPoints()
	bg:SetColorTexture(unpack(color))
	frame.thFlat = bg
	edge = edge or EDGE
	for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
		local t = frame:CreateTexture(nil, "BORDER", nil, 7)
		t:SetColorTexture(unpack(edge))
		if side == "TOP" or side == "BOTTOM" then
			t:SetPoint(side .. "LEFT")
			t:SetPoint(side .. "RIGHT")
			t:SetHeight(1)
		else
			t:SetPoint("TOP" .. side)
			t:SetPoint("BOTTOM" .. side)
			t:SetWidth(1)
		end
	end
end

local function HideArt(frame, keys)
	local hid = false
	for _, key in ipairs(keys) do
		local r = frame[key]
		if type(r) == "table" and r.Hide and r.GetObjectType and r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
			hid = true
		end
	end
	return hid
end

local function IsGold(fs)
	local r, g, b = fs:GetTextColor()
	return r and math.abs(r - GOLD[1]) < 0.05 and math.abs(g - GOLD[2]) < 0.05 and b < 0.1
end

local function SkinButton(b, accent)
	if b.thSkinned then return end
	b.thSkinned = true
	HideArt(b, BUTTON_ART)
	Flat(b, b.thPrimary and { accent[1] * 0.55, accent[2] * 0.55, accent[3] * 0.55, 1 } or BUTTON)
	local hl = b.GetHighlightTexture and b:GetHighlightTexture()
	if hl then
		-- подсветка внутри рамки: рамка остаётся, соседние кнопки не сливаются
		hl:SetColorTexture(accent[1], accent[2], accent[3], 0.18)
		hl:ClearAllPoints()
		hl:SetPoint("TOPLEFT", 1, -1)
		hl:SetPoint("BOTTOMRIGHT", -1, 1)
	end
	local fs = b.GetFontString and b:GetFontString()
	if fs then fs:SetTextColor(1, 1, 1) end
	if b.HookScript then
		b:HookScript("OnDisable", function(self) local f = self:GetFontString() if f then f:SetTextColor(0.55, 0.55, 0.55) end end)
		b:HookScript("OnEnable", function(self) local f = self:GetFontString() if f then f:SetTextColor(1, 1, 1) end end)
		if b.IsEnabled and not b:IsEnabled() and fs then fs:SetTextColor(0.55, 0.55, 0.55) end
	end
end

local function T(v) return type(v) == "table" and v or nil end

-- Перекрасить рисунок кнопки игры (обесцветить и окрасить)
local function Tint(button, color)
	if not button or button.thTinted then return end
	button.thTinted = true
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local tex = button[getter] and button[getter](button)
		if type(tex) == "table" and tex.SetDesaturated then
			tex:SetDesaturated(true)
			tex:SetVertexColor(color[1], color[2], color[3])
		end
	end
end

local function SkinFrame(frame, accent, top)
	if not frame or frame.thSkinWalked then return end
	frame.thSkinWalked = true
	local ftype = frame.GetObjectType and frame:GetObjectType()
	-- окно или панель из шаблона игры
	if HideArt(frame, FRAME_ART) then Flat(frame, top and BG or PANEL) end
	if T(frame.NineSlice) and frame.NineSlice.Hide then
		frame.NineSlice:Hide()
		if T(frame.Bg) and frame.Bg.SetAlpha then frame.Bg:SetAlpha(0) end
		Flat(frame, PANEL)
	end
	-- крестик закрытия — красным, как привычно в игре
	if T(frame.CloseButton) then Tint(frame.CloseButton, { 0.95, 0.25, 0.22 }) end
	if T(frame.TitleText) and frame.TitleText.SetTextColor then frame.TitleText:SetTextColor(1, 1, 1) end
	if frame.SetBackdropColor and frame.GetBackdrop and frame:GetBackdrop() then
		frame:SetBackdropColor(unpack(BG))
		if frame.SetBackdropBorderColor and not frame.thKeepBorder then frame:SetBackdropBorderColor(0, 0, 0, 1) end
	end
	-- кнопки и поля ввода
	if ftype == "Button" and T(frame.Left) and T(frame.Middle) and T(frame.Right) then
		SkinButton(frame, accent)
	elseif ftype == "EditBox" then
		if HideArt(frame, EDIT_ART) then Flat(frame, { 0.03, 0.03, 0.04, 1 }, { 0.25, 0.25, 0.28, 1 }) end
	elseif ftype == "Slider" and T(frame.thumb) then
		frame.thumb:SetColorTexture(accent[1], accent[2], accent[3], 0.9)
		-- стрелки полосы — рисунок игры, перекрашенный в акцент
		for _, arrow in ipairs({ T(frame.up), T(frame.down) }) do Tint(arrow, accent) end
	end
	-- подчёркивание выбранной вкладки — акцентом
	if T(frame.underline) and frame.underline.SetColorTexture then frame.underline:SetColorTexture(accent[1], accent[2], accent[3], 1) end
	-- золотой текст — белым (как в EllesmereUI)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then
			if IsGold(region) then region:SetTextColor(1, 1, 1) end
		end
	end
	for _, child in ipairs({ frame:GetChildren() }) do SkinFrame(child, accent, false) end
end

-- Перекрасить окно, созданное позже главного (фильтр тегов и т.п.), и его новые элементы
function TH:SkinNow(frame)
	if not frame or not self:IsSkinned() then return end
	local function Reset(fr)
		fr.thSkinWalked = nil
		for _, child in ipairs({ fr:GetChildren() }) do
			if not child.thSkinned then child.thSkinWalked = nil end
			Reset(child)
		end
	end
	Reset(frame)
	SkinFrame(frame, self:GetAccent(), true)
end

-- Пройтись по всем нашим окнам (повторно — только по новым элементам)
function TH:ApplySkin()
	if not self:IsSkinned() then return end
	local accent = self:GetAccent()
	for _, name in ipairs(WINDOWS) do
		local f = _G[name]
		if f and not f.thSkinHooked then
			f.thSkinHooked = true
			-- элементы создаются и позже (строки списков, меню): при каждом показе досматриваем новые
			f:HookScript("OnShow", function(self)
				self.thSkinWalked = nil
				local function Reset(fr)
					for _, child in ipairs({ fr:GetChildren() }) do
						if not child.thSkinned then child.thSkinWalked = nil end
						Reset(child)
					end
				end
				Reset(self)
				SkinFrame(self, TH:GetAccent(), true)
			end)
		end
		if f then SkinFrame(f, accent, true) end
	end
end

-- окна строятся при первом открытии; шкурим после каждой подгонки масштаба (её зовут все окна)
if hooksecurefunc then
	hooksecurefunc(TH, "ApplyScale", function() TH:ApplySkin() end)
end
