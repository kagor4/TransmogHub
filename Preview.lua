local _, ns = ...
local L = ns.L
local TH = ns.TH

-- Та же сцена, что у штатной примерочной (DressUpFrame)
local SCENE_ID = 596

-- Играбельные расы для примерки. Повторы (союз/орда) отсеиваются по имени.
-- 86/91 — харанир, 95/96 — небеснорождённые Forever (у союза и орды разные названия).
local RACE_IDS = TH.FOREVER and { 1, 3, 4, 7, 95, 2, 5, 6, 8, 96 }
	or { 1, 3, 4, 7, 11, 22, 25, 29, 30, 32, 34, 37, 52, 85, 91,
		2, 5, 6, 8, 9, 10, 26, 27, 28, 31, 35, 36, 70, 84, 86 }

function TH:GetPlayableRaces()
	if self.races then return self.races end
	local list, seen = {}, {}
	for _, id in ipairs(RACE_IDS) do
		local info = C_CreatureInfo.GetRaceInfo(id)
		if info and info.raceName and not seen[info.raceName] then
			seen[info.raceName] = true
			list[#list + 1] = { id = id, name = info.raceName }
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	self.races = list
	return list
end

function TH:GetRaceName(raceID)
	local info = raceID and C_CreatureInfo.GetRaceInfo(raceID)
	return info and info.raceName or "?"
end

-- ItemTransmogInfoList актёра → наш компактный формат items
function TH:ItemsFromTransmogInfoList(list)
	if not list then return end
	local items, any = {}, false
	for slotID, info in pairs(list) do
		if TH.SLOT_BY_ID[slotID] and info.appearanceID and info.appearanceID > 0 then
			local e = { info.appearanceID }
			local sec = info.secondaryAppearanceID
			if sec and sec > 0 and sec ~= info.appearanceID then e[2] = sec end
			if info.illusionID and info.illusionID > 0 then e[3] = info.illusionID end
			items[slotID] = e
			any = true
		end
	end
	return any and items or nil
end

---------------------------------------------------------------------------
-- Модель для примерки. Вращение и приближение мышью даёт сама ModelScene.
---------------------------------------------------------------------------
local Preview = {}
Preview.__index = Preview

TH.previews = {}
function TH:CreatePreview(parent)
	local scene = CreateFrame("ModelScene", nil, parent, "PanningModelSceneMixinTemplate")
	scene:TransitionToModelSceneID(SCENE_ID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
	local preview = setmetatable({ scene = scene, parent = parent }, Preview)
	self.previews[#self.previews + 1] = preview
	-- двойной клик по модели — вернуть камеру как была (если отдалили колесом)
	local lastClick = 0
	scene:HookScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" then return end
		local now = GetTime()
		if now - lastClick < 0.35 then preview:ResetCamera() end
		lastClick = now
	end)
	return preview
end

-- Камера сцены — в исходное положение (приближение, поворот). Модель и вещи остаются:
-- сцена переиспользует актёра с тем же тегом.
function Preview:ResetCamera()
	self.scene:TransitionToModelSceneID(SCENE_ID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
end

---------------------------------------------------------------------------
-- Две 3D-модели из разных окон рисуются в общем пространстве глубины и режут
-- друг друга, если окна наложить. Поэтому, пока окно трансмогрификации игры
-- перекрывает нашу модель, свою прячем и пишем, почему.
---------------------------------------------------------------------------
local function ScreenRect(f)
	local l, b, w, h = f:GetRect()
	if not l then return end
	local s = f:GetEffectiveScale()
	return l * s, b * s, (l + w) * s, (b + h) * s
end

local function Overlaps(a, b)
	local al, ab, ar, at = ScreenRect(a)
	local bl, bb, br, bt = ScreenRect(b)
	if not (al and bl) then return false end
	return al < br and bl < ar and ab < bt and bb < at
end

function TH:UpdateModelOverlap()
	local tf = _G.TransmogFrame
	local blocking = tf and tf:IsShown() and tf
	for _, preview in ipairs(self.previews) do
		local hide = blocking and preview.parent:IsVisible() and Overlaps(preview.parent, blocking) or false
		if hide ~= (preview.overlapHidden or false) then
			preview.overlapHidden = hide
			preview.scene:SetShown(not hide)
			if not preview.overlapHint then
				preview.overlapHint = preview.parent:CreateFontString(nil, "OVERLAY", "GameFontDisable")
				preview.overlapHint:SetPoint("CENTER")
				preview.overlapHint:SetWidth(220)
				preview.overlapHint:SetText(L["Окно трансмогрификации перекрывает модель — отодвиньте окна друг от друга."])
			end
			preview.overlapHint:SetShown(hide)
			if not hide then preview:Refresh() end
		end
	end
end

-- Загружает модель игрока (raceID = nil — своя раса) и вызывает onLoaded(actor).
-- Пол сменить нельзя: SetModelByUnit берёт пол персонажа.
function Preview:LoadPlayer(raceID, autoDress, onLoaded)
	local actor = self.scene:GetPlayerActor()
	if not actor then return false end
	actor:SetOnModelLoadedCallback(onLoaded)
	-- unit, sheatheWeapons, autoDress, hideWeapons, usePlayerNativeForm, holdBowString, customRaceID
	actor:SetModelByUnit("player", false, autoDress, false, true, false, raceID)
	return true
end

function Preview:SetRace(raceID)
	if self.capture then
		self.capture.raceID = raceID
		return
	end
	self.raceID = raceID
	self:Reload()
end

-- items = nil — показать персонажа в его текущем облике
function Preview:SetItems(items)
	if self.capture then
		self.capture.items = items -- применим после снимка
		return
	end
	local wasDressed = self.items == nil
	self.items = items
	local actor = self.scene:GetPlayerActor()
	if items and not wasDressed and actor and actor:IsLoaded() then
		self:ApplyWithRetry(self.loadToken)
	else
		self:Reload()
	end
end

-- Пока модель грузится, она без одежды: прячем её и показываем, когда вещи надеты
-- (или через секунду, если игра долго отдаёт вещи)
-- Прячем всю сцену, а не модель: загрузка модели сбрасывает её прозрачность.
-- Сцена остаётся показанной (alpha 0), поэтому модель в ней загружается как обычно.
function Preview:SetHidden(hidden, fade)
	if not hidden and fade and UIFrameFadeIn and self.scene:GetAlpha() < 1 then
		UIFrameFadeIn(self.scene, 0.15, self.scene:GetAlpha(), 1)
		return
	end
	if UIFrameFadeRemoveFrame then UIFrameFadeRemoveFrame(self.scene) end
	self.scene:SetAlpha(hidden and 0 or 1)
end

-- Окно снова показали: если модель уже в этом образе, заново её не собираем
-- (сборка с нуля — это персонаж без одежды, пока игра не отдаст вещи)
function Preview:Refresh()
	local actor = self.scene:GetPlayerActor()
	if actor and actor:IsLoaded() and self.items and self.shownItems == self.items and self.shownRace == self.raceID then
		-- на всякий случай надеваем вещи ещё раз, пока модель скрыта: игра могла сбросить её, пока окно было закрыто
		self.loadToken = (self.loadToken or 0) + 1
		local token = self.loadToken
		self:SetHidden(true)
		self:ApplyWithRetry(token)
		C_Timer.After(1, function() if token == self.loadToken then self:SetHidden(false) end end)
		return
	end
	self:Reload()
end

function Preview:Reload()
	self.loadToken = (self.loadToken or 0) + 1
	local token = self.loadToken
	local autoDress = self.items == nil
	if not autoDress then self:SetHidden(true) end
	self:LoadPlayer(self.raceID, autoDress, function() self:ApplyWithRetry(token) end)
	-- Запасной путь, если колбэк загрузки не придёт
	C_Timer.After(0.2, function() self:ApplyWithRetry(token) end)
	C_Timer.After(1, function() if token == self.loadToken then self:SetHidden(false) end end)
end

-- Модель другой расы и вещи грузятся не сразу: пока игра отвечает
-- DataPending, повторяем попытку (до ~3 секунд).
function Preview:ApplyWithRetry(token, attempt)
	if token ~= self.loadToken then return end -- уже загружается другая модель
	attempt = attempt or 1
	local actor = self.scene:GetPlayerActor()
	if not actor then return end
	local loaded = actor:IsLoaded()
	local done = loaded and self:ApplyItems(actor)
	-- все вещи надеты — показываем модель чуть позже, когда игра их нарисует;
	-- если часть вещей грузится долго, модель откроет таймер в Reload через секунду
	-- вещи надеты, но их модели игра дорисовывает ещё долю секунды — показываем
	-- чуть позже и плавно, иначе мелькает персонаж в белье
	if done then
		self.shownItems, self.shownRace = self.items, self.raceID
		C_Timer.After(0.3, function() if token == self.loadToken then self:SetHidden(false, true) end end)
	end
	if not done and attempt < 20 then
		C_Timer.After(0.15, function() self:ApplyWithRetry(token, attempt + 1) end)
	end
end

-- Возвращает false, если часть вещей ещё не загрузилась.
function Preview:ApplyItems(actor)
	if not self.items then return true end
	actor:Undress()
	local complete = true
	for slotID, it in pairs(self.items) do
		local secondary = it[2]
		if slotID == INVSLOT_MAINHAND and not secondary then
			secondary = Constants.Transmog.MainHandTransmogIsIndividualWeapon -- обычное, не парное оружие
		end
		local info = ItemUtil.CreateItemTransmogInfo(it[1], secondary, it[3])
		local result = actor:SetItemTransmogInfo(info, slotID, slotID ~= INVSLOT_MAINHAND)
		if result == Enum.ItemTryOnReason.DataPending then complete = false end
	end
	return complete
end

---------------------------------------------------------------------------
-- Снимок облика: загружаем на модель игрока «как есть» и читаем её список
-- трансмога — так же делает штатная примерочная. Модель должна быть видна
-- на экране, иначе она не загружается.
---------------------------------------------------------------------------
function Preview:CaptureDisplayed(callback)
	if self.capture then return callback(nil) end
	-- Пока идёт снимок, SetItems/SetRace только запоминают новое состояние
	self.capture = { items = self.items, raceID = self.raceID }
	self.items, self.raceID = nil, nil
	self.loadToken = (self.loadToken or 0) + 1 -- останавливает повторы надевания старого образа
	self:SetHidden(false) -- снимок — на видимой модели в своей одежде

	local done, loaded = false, false
	local function finish(items)
		if done then return end
		done = true
		self.items, self.raceID = self.capture.items, self.capture.raceID
		self.capture = nil
		self:Reload()
		callback(items)
	end
	-- Читаем только после загрузки новой модели: до этого на актёре
	-- ещё надет образ, который был в примерке.
	local function try(attempt)
		if done or not loaded then return end
		local actor = self.scene:GetPlayerActor()
		local items = actor and TH:ItemsFromTransmogInfoList(actor:GetItemTransmogInfoList())
		if items then
			finish(items)
		elseif attempt < 10 then
			C_Timer.After(0.15, function() try(attempt + 1) end)
		else
			finish(nil)
		end
	end

	local ok = self:LoadPlayer(nil, true, function()
		loaded = true
		C_Timer.After(0.05, function() try(1) end)
	end)
	if not ok then return finish(nil) end
	C_Timer.After(4, function() finish(nil) end)
end

function TH:CaptureViaModel(callback)
	local ui = self.UI
	if not ui:IsShown() then ui:Toggle() end
	ui.model:CaptureDisplayed(callback)
end
