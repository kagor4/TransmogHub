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
	{ key = "chroma", name = L["Хромакей"], color = { 0, 0.85, 0 } }, -- зелёный фон для монтажа
	{ key = "race", name = L["Примерочная расы"] },
	{ key = "world", name = L["Локация персонажа"], world = true }, -- за моделью — то место, где стоит персонаж
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
local EnterWorld, LeaveWorld
local uiWasShown

---------------------------------------------------------------------------
-- Фон «Локация персонажа» (как фото-режим Narcissus): за моделью — мир, где стоит
-- персонаж. Своего персонажа в мире прячем (консольная команда showPlayer
-- переключает его видимость), камеру опускаем на уровень глаз и приближаем,
-- имена над головами на время выключаем. При выходе всё возвращаем.
---------------------------------------------------------------------------
local NAME_CVARS = { "UnitNameOwn", "UnitNameNPC", "UnitNameFriendlyPlayerName", "UnitNameEnemyPlayerName",
	"UnitNameFriendlyPetName", "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
	"UnitNameNonCombatCreatureName", "UnitNameFriendlySpecialNPCName", "UnitNameHostleNPC",
	"UnitNameInteractiveNPC" }
local WORLD_ZOOM = 4
local world -- что поменяли в мире (nil — ничего)

local function GetCV(name) return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name) end
local function SetCV(name, value) if C_CVar and C_CVar.SetCVar then pcall(C_CVar.SetCVar, name, value) end end

local function ZoomTo(goal)
	if not (GetCameraZoom and CameraZoomIn and CameraZoomOut) then return end
	local cur = GetCameraZoom()
	if not cur then return end
	if cur > goal then CameraZoomIn(cur - goal) else CameraZoomOut(goal - cur) end
end

-- имена — вернуть как были (и после перезагрузки интерфейса, если выйти не успели)
local function RestoreNames(saved)
	for name, value in pairs(saved or {}) do SetCV(name, value) end
end

EnterWorld = function()
	if world then return end
	world = { zoom = GetCameraZoom and GetCameraZoom(), names = {} }
	for _, name in ipairs(NAME_CVARS) do
		local v = GetCV(name)
		if v ~= nil then
			world.names[name] = v
			SetCV(name, "0")
		end
	end
	TH.db.photoNames = world.names
	if ConsoleExec then
		pcall(ConsoleExec, "showPlayer") -- спрятать своего персонажа: на его месте — модель образа
		world.hidPlayer = true
		-- камера на уровень глаз: ненадолго ограничиваем наклон, потом возвращаем предел
		pcall(ConsoleExec, "pitchlimit 1")
		C_Timer.After(0.1, function() pcall(ConsoleExec, "pitchlimit 88") end)
	end
	ZoomTo(WORLD_ZOOM)
end

LeaveWorld = function()
	if not world then return end
	RestoreNames(world.names)
	TH.db.photoNames = nil
	if world.hidPlayer and ConsoleExec then pcall(ConsoleExec, "showPlayer") end
	if world.zoom then ZoomTo(world.zoom) end
	world = nil
end

do
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:RegisterEvent("PLAYER_LOGOUT")
	f:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_LOGOUT" then
			LeaveWorld()
		elseif TH.db and TH.db.photoNames then
			RestoreNames(TH.db.photoNames)
			TH.db.photoNames = nil
		end
	end)
end

local function SetBackground(key)
	local bg = photo.bg
	local b
	for _, x in ipairs(BACKGROUNDS) do if x.key == key then b = x end end
	b = b or BACKGROUNDS[1]
	photo.bgKey = b.key
	TH.db.photoBg = b.key
	bg:SetShown(not b.world)
	if b.world then EnterWorld() else LeaveWorld() end
	if bg.SetGradient and CreateColor then bg:SetGradient("VERTICAL", CreateColor(1, 1, 1, 1), CreateColor(1, 1, 1, 1)) end
	photo.title:SetTextColor(1, 0.82, 0)
	photo.author:SetTextColor(0.9, 0.9, 0.9)
	if b.world then return end
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

local function OpenBackgroundMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		for _, b in ipairs(BACKGROUNDS) do
			root:CreateRadio(b.name, function() return photo.bgKey == b.key end, function() SetBackground(b.key) end)
		end
	end)
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
	LeaveWorld()
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
	scene:SetPoint("CENTER", 0, 10)

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
	bar:SetFrameLevel((photo:GetFrameLevel() or 1) + 100) -- выше сцены, она ловит мышь
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
	local poseBtn = Add(L["Поза"], function() TH.UI:TogglePosePanel(photo.posePanel, photo.preview) end)
	photo.posePanel = TH.UI:CreatePosePanel(bar)
	photo.posePanel:SetPoint("TOPLEFT", poseBtn, "BOTTOMLEFT", 0, -26) -- под подсказкой
	photo.pauseBtn = TH.UI:CreatePauseButton(bar, photo.preview)
	photo.pauseBtn:SetSize(24, 24)
	photo.pauseBtn:SetPoint("LEFT", x, 0)
	x = x + 24 + 6
	Add(L["Фон"], OpenBackgroundMenu)
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
	boxLabel:SetText(L["Номер анимации"])
	x = x + 8 + 56
	bar:SetWidth(x)
	photo.hint = photo:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	photo.hint:SetPoint("TOP", bar, "BOTTOM", 0, -6)
	photo.hint:SetText(L["ЛКМ — вращать, колесо — приблизить, Esc — выйти"])
	bar:HookScript("OnHide", function() photo.hint:Hide() end) -- панель поз — дочерняя, тоже прячется
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
	-- после появления — обычная стойка, а не поза из окна аддона
	preview.poseKey, preview.freeze, preview.sheathe, preview.frozenAt = nil, false, main.sheathe, nil
	preview.poseStart = GetTime()
	-- появление в стиле класса образа (или своего), потом — выбранная поза
	local set = TH:GetSet(self.UI.selectedId)
	local class = (set and set.class or select(2, UnitClass("player")) or ""):upper()
	preview.intro = TH.CLASS_INTROS[class]
	if UIParent and UIParent:IsShown() then
		uiWasShown = true
		UIParent:Hide()
	end
	photo:Show()
	-- сцена во всю высоту экрана (без панели сверху и подписи снизу), ширина — 0.8 высоты
	local h = math.max(200, (photo:GetHeight() or 768) - 150)
	preview.scene:SetSize(h * 0.8, h)
	TH.UI:UpdatePauseButton(photo.pauseBtn, preview)
	photo.posePanel:Hide()
	preview:SetItems(main.items)
	preview:Reload()
	RememberLight(preview.scene)
	SetBackground(photo.bgKey or TH.db.photoBg or "world")
	SetLight(photo.lightKey or "normal")
	SetVignette(photo.vignetteOn ~= false)
	UpdateCaption()
end
