local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Фотостудия: образ во весь экран на фоне, интерфейс игры скрыт. Поза, фон, ракурс,
-- подпись (название, автор, «Transmog Hub») и кнопка снимка экрана (файл — в папке
-- Screenshots игры). Панель с кнопками на снимок не попадает. Esc — выйти.
---------------------------------------------------------------------------
local BACKGROUNDS = {
	{ key = "dark", name = L["Тёмный"], color = { 0.05, 0.05, 0.07 } },
	{ key = "gradient", name = L["Градиент"], top = { 0.22, 0.12, 0.32 }, bottom = { 0.02, 0.02, 0.04 } },
	{ key = "light", name = L["Светлый"], color = { 0.82, 0.82, 0.86 } },
	{ key = "race", name = L["Примерочная расы"] },
}

local photo -- окно (создаётся при первом открытии)
local uiWasShown

local function SetBackground(key)
	local bg = photo.bg
	local b
	for _, x in ipairs(BACKGROUNDS) do if x.key == key then b = x end end
	b = b or BACKGROUNDS[1]
	photo.bgKey = b.key
	if b.key == "race" then
		-- фон штатной примерочной для расы модели; нет такого — тёмный
		local info = C_CreatureInfo.GetRaceInfo(photo.preview.raceID or select(3, UnitRace("player")))
		local file = info and info.clientFileString and info.clientFileString:lower()
		local atlas = file and ("dressingroom-background-" .. file)
		if atlas and C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(atlas) then
			bg:SetAtlas(atlas)
			return
		end
		b = BACKGROUNDS[1]
	end
	if b.top then
		bg:SetColorTexture(1, 1, 1)
		if bg.SetGradient and CreateColor then
			bg:SetGradient("VERTICAL", CreateColor(b.bottom[1], b.bottom[2], b.bottom[3], 1), CreateColor(b.top[1], b.top[2], b.top[3], 1))
		end
	else
		bg:SetColorTexture(b.color[1], b.color[2], b.color[3])
	end
	-- подпись читается и на светлом фоне
	local dark = b.key ~= "light"
	photo.title:SetTextColor(dark and 1 or 0.1, dark and 0.82 or 0.1, dark and 0 or 0.1)
	photo.author:SetTextColor(dark and 0.9 or 0.15, dark and 0.9 or 0.15, dark and 0.9 or 0.15)
end

local function NextBackground()
	for i, b in ipairs(BACKGROUNDS) do
		if b.key == photo.bgKey then
			SetBackground(BACKGROUNDS[i % #BACKGROUNDS + 1].key)
			return
		end
	end
	SetBackground(BACKGROUNDS[1].key)
end

-- Ракурсы: во весь рост (как в примерочной), по пояс, портрет
local function SetFraming(kind)
	local preview = photo.preview
	preview:ResetCamera()
	if kind == "full" then return end
	local camera = preview.scene.GetActiveCamera and preview.scene:GetActiveCamera()
	if not (camera and camera.SetZoomDistance and camera.GetMinZoomDistance and camera.GetMaxZoomDistance) then return end
	local lo, hi = camera:GetMinZoomDistance(), camera:GetMaxZoomDistance()
	if not (lo and hi) then return end
	pcall(camera.SetZoomDistance, camera, kind == "waist" and (lo + (hi - lo) * 0.35) or lo)
end

local function UpdateCaption()
	local set = TH:GetSet(TH.UI.selectedId)
	local show = photo.caption and set ~= nil
	photo.title:SetText(set and (TH:SetName(set) or "") or "")
	photo.author:SetText(set and set.author and (L["Автор: "] .. set.author:gsub("%-.*", "")) or "")
	photo.title:SetShown(show)
	photo.author:SetShown(show)
	photo.brand:SetShown(photo.caption)
end

function TH:ClosePhotoMode()
	if not photo or not photo:IsShown() then return end
	photo:Hide()
	if uiWasShown and UIParent and not UIParent:IsShown() then UIParent:Show() end
	uiWasShown = nil
end

local function Build()
	photo = CreateFrame("Frame", "TransmogHubPhoto", nil)
	photo:SetFrameStrata("FULLSCREEN_DIALOG")
	if UIParent and UIParent.GetScale then photo:SetScale(UIParent:GetScale() or 1) end -- кнопки того же размера, что в игре
	photo:SetAllPoints(WorldFrame)
	photo:EnableMouse(true)
	photo:EnableKeyboard(true)
	photo:SetScript("OnKeyDown", function(f, key)
		if key == "ESCAPE" then
			if f.SetPropagateKeyboardInput then f:SetPropagateKeyboardInput(false) end
			TH:ClosePhotoMode()
		elseif f.SetPropagateKeyboardInput then
			f:SetPropagateKeyboardInput(true) -- снимок экрана клавишей игры и прочее — как обычно
		end
	end)
	photo:Hide()

	photo.bg = photo:CreateTexture(nil, "BACKGROUND")
	photo.bg:SetAllPoints()

	photo.preview = TH:CreatePreview(photo)
	local scene = photo.preview.scene
	scene:SetPoint("TOP", 0, -50)
	scene:SetPoint("BOTTOM", 0, 90)
	scene:SetScript("OnSizeChanged", function(s, _, h) s:SetWidth((h or 600) * 0.8) end)

	photo.title = photo:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	photo.title:SetPoint("BOTTOM", 0, 48)
	photo.author = photo:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	photo.author:SetPoint("TOP", photo.title, "BOTTOM", 0, -6)
	photo.brand = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	photo.brand:SetPoint("BOTTOMRIGHT", -16, 12)
	photo.brand:SetText("Transmog Hub")
	photo.caption = true

	-- Панель кнопок (на снимок не попадает)
	local bar = CreateFrame("Frame", nil, photo)
	bar:SetPoint("TOP", 0, -10)
	bar:SetSize(10, 26)
	photo.bar = bar
	local buttons, x = {}, 0
	local function Add(text, onClick)
		local b = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
		b:SetText(text)
		local w = math.max(80, (b:GetTextWidth() or 60) + 24)
		b:SetSize(w, 24)
		b:SetPoint("LEFT", x, 0)
		x = x + w + 6
		b:SetScript("OnClick", onClick)
		buttons[#buttons + 1] = b
		return b
	end
	Add(L["Поза"], function(b) TH.UI:OpenPoseMenu(b, photo.preview) end)
	Add(L["Фон"], NextBackground)
	Add(L["Ракурс"], function(b)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		MenuUtil.CreateContextMenu(b, function(_, root)
			root:CreateButton(L["Во весь рост"], function() SetFraming("full") end)
			root:CreateButton(L["По пояс"], function() SetFraming("waist") end)
			root:CreateButton(L["Портрет"], function() SetFraming("portrait") end)
		end)
	end)
	Add(L["Подпись"], function()
		photo.caption = not photo.caption
		UpdateCaption()
	end)
	Add(L["Снимок"], function()
		bar:Hide()
		C_Timer.After(0.05, function() if Screenshot then Screenshot() end end)
		C_Timer.After(0.8, function() bar:Show() end)
	end)
	Add(L["Закрыть"], function() TH:ClosePhotoMode() end)
	bar:SetWidth(x)
	photo.hint = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	photo.hint:SetPoint("TOP", bar, "BOTTOM", 0, -6)
	photo.hint:SetText(L["ЛКМ — вращать, колесо — приблизить, Esc — выйти"])
	bar:HookScript("OnHide", function() photo.hint:Hide() end)
	bar:HookScript("OnShow", function() photo.hint:Show() end)
end

function TH:OpenPhotoMode()
	if InCombatLockdown and InCombatLockdown() then
		self:Print(L["Фотостудия недоступна в бою."])
		return
	end
	if not photo then Build() end
	local main = self.UI.model
	local preview = photo.preview
	preview.raceID = main.raceID
	preview.poseKey, preview.freeze, preview.sheathe, preview.frozenAt = main.poseKey, main.freeze, main.sheathe, main.frozenAt
	preview.poseStart = GetTime()
	if UIParent and UIParent:IsShown() then
		uiWasShown = true
		UIParent:Hide()
	end
	photo:Show()
	preview:SetItems(main.items)
	preview:Reload()
	SetBackground(photo.bgKey or "gradient")
	UpdateCaption()
end
