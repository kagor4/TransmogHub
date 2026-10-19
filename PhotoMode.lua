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
	{ key = "chroma", name = L["Хромакей"], color = { 0, 0.85, 0 } }, -- зелёный фон для монтажа
}

-- Свет сцены: направление и цвета (как в Narcissus — пресеты вместо ручного круга)
local LIGHTS = {
	{ key = "normal", name = L["Обычный"] },
	{ key = "warm", name = L["Тёплый"], dir = { -0.4, 0.8, -0.4 }, amb = { 0.55, 0.42, 0.32 }, dif = { 1, 0.82, 0.6 } },
	{ key = "cold", name = L["Холодный"], dir = { -0.4, 0.8, -0.4 }, amb = { 0.32, 0.4, 0.55 }, dif = { 0.65, 0.8, 1 } },
	{ key = "side", name = L["Сбоку"], dir = { 1, 0.3, -0.2 }, amb = { 0.15, 0.15, 0.18 }, dif = { 1, 1, 1 } },
	{ key = "silhouette", name = L["Силуэт"], dir = { 0, -1, 0 }, amb = { 0, 0, 0 }, dif = { 0, 0, 0 } },
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

local function SetLight(key)
	local scene = photo.preview.scene
	local l
	for _, x in ipairs(LIGHTS) do if x.key == key then l = x end end
	photo.lightKey = key
	if not l or not l.dir then
		-- обычный свет — тот, что задаёт сцена примерочной
		if photo.defaultLight then l = photo.defaultLight else return end
	end
	if scene.SetLightDirection then pcall(scene.SetLightDirection, scene, l.dir[1], l.dir[2], l.dir[3]) end
	if scene.SetLightAmbientColor then pcall(scene.SetLightAmbientColor, scene, l.amb[1], l.amb[2], l.amb[3]) end
	if scene.SetLightDiffuseColor then pcall(scene.SetLightDiffuseColor, scene, l.dif[1], l.dif[2], l.dif[3]) end
end

-- Свет сцены как есть (чтобы вернуть «обычный»)
local function RememberLight(scene)
	if photo.defaultLight or not (scene.GetLightDirection and scene.GetLightAmbientColor and scene.GetLightDiffuseColor) then return end
	local ok1, x, y, z = pcall(scene.GetLightDirection, scene)
	local ok2, ar, ag, ab = pcall(scene.GetLightAmbientColor, scene)
	local ok3, dr, dg, db = pcall(scene.GetLightDiffuseColor, scene)
	if ok1 and ok2 and ok3 and x and ar and dr then
		photo.defaultLight = { dir = { x, y, z }, amb = { ar, ag, ab }, dif = { dr, dg, db } }
	end
end

-- Виньетка: затемнение по краям кадра
local function BuildVignette()
	photo.vignette = {}
	local function Edge(p1, p2, horizontal, from, to)
		local t = photo:CreateTexture(nil, "BORDER")
		t:SetColorTexture(1, 1, 1)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if horizontal then t:SetWidth(260) else t:SetHeight(200) end
		if t.SetGradient and CreateColor then
			t:SetGradient(horizontal and "HORIZONTAL" or "VERTICAL", CreateColor(0, 0, 0, from), CreateColor(0, 0, 0, to))
		end
		photo.vignette[#photo.vignette + 1] = t
	end
	Edge("TOPLEFT", "BOTTOMLEFT", true, 0.75, 0)
	Edge("TOPRIGHT", "BOTTOMRIGHT", true, 0, 0.75)
	Edge("TOPLEFT", "TOPRIGHT", false, 0, 0.7)
	Edge("BOTTOMLEFT", "BOTTOMRIGHT", false, 0.7, 0)
end

local function SetVignette(on)
	photo.vignetteOn = on
	for _, t in ipairs(photo.vignette) do t:SetShown(on) end
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
	BuildVignette()

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
	Add(L["Свет"], function(b)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		MenuUtil.CreateContextMenu(b, function(_, root)
			for _, l in ipairs(LIGHTS) do
				root:CreateRadio(l.name, function() return (photo.lightKey or "normal") == l.key end, function() SetLight(l.key) end)
			end
			root:CreateDivider()
			root:CreateCheckbox(L["Виньетка"], function() return photo.vignetteOn end, function() SetVignette(not photo.vignetteOn) end)
		end)
	end)
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
	-- подбор позы по номеру анимации: колесо мыши — следующая/предыдущая
	local box = CreateFrame("EditBox", nil, bar, "InputBoxTemplate")
	box:SetSize(56, 22)
	box:SetPoint("LEFT", x + 8, 0)
	box:SetAutoFocus(false)
	box:SetNumeric(true)
	box:SetMaxLetters(5)
	local function Play(n)
		n = math.max(0, math.min(99999, n or 0))
		box:SetText(tostring(n))
		photo.preview:SetPose("anim:" .. n, false, photo.preview.sheathe)
	end
	box:SetScript("OnEnterPressed", function(b) Play(tonumber(b:GetText())); b:ClearFocus() end)
	box:SetScript("OnEscapePressed", function(b) b:ClearFocus() end)
	box:EnableMouseWheel(true)
	box:SetScript("OnMouseWheel", function(b, delta) Play((tonumber(b:GetText()) or 0) + (delta > 0 and 1 or -1)) end)
	photo.animBox = box
	local boxLabel = bar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	boxLabel:SetPoint("BOTTOM", box, "TOP", 0, 1)
	boxLabel:SetText(L["Анимация №"])
	x = x + 8 + 56
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
	RememberLight(preview.scene)
	SetBackground(photo.bgKey or "gradient")
	SetLight(photo.lightKey or "normal")
	SetVignette(photo.vignetteOn ~= false)
	UpdateCaption()
end
