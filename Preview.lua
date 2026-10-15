local _, ns = ...
local TH = ns.TH

-- Та же сцена, что у штатной примерочной (DressUpFrame)
local SCENE_ID = 596

-- Играбельные расы для примерки. Повторы (союз/орда) отсеиваются по имени.
-- TODO: добавить харанир (Midnight), когда будет известен raceID.
local RACE_IDS = { 1, 3, 4, 7, 11, 22, 25, 29, 30, 32, 34, 37, 52, 85,
	2, 5, 6, 8, 9, 10, 26, 27, 28, 31, 35, 36, 70, 84 }

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

function TH:CreatePreview(parent)
	local scene = CreateFrame("ModelScene", nil, parent, "PanningModelSceneMixinTemplate")
	scene:TransitionToModelSceneID(SCENE_ID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
	return setmetatable({ scene = scene }, Preview)
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

function Preview:Reload()
	self.loadToken = (self.loadToken or 0) + 1
	local token = self.loadToken
	local autoDress = self.items == nil
	self:LoadPlayer(self.raceID, autoDress, function() self:ApplyWithRetry(token) end)
	-- Запасной путь, если колбэк загрузки не придёт
	C_Timer.After(0.2, function() self:ApplyWithRetry(token) end)
end

-- Модель другой расы и вещи грузятся не сразу: пока игра отвечает
-- DataPending, повторяем попытку (до ~3 секунд).
function Preview:ApplyWithRetry(token, attempt)
	if token ~= self.loadToken then return end -- уже загружается другая модель
	attempt = attempt or 1
	local actor = self.scene:GetPlayerActor()
	if not actor then return end
	local done = actor:IsLoaded() and self:ApplyItems(actor)
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
	self.loadToken = (self.loadToken or 0) + 1 -- останавливает повторы надевания старого набора

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
	-- ещё надет набор, который был в примерке.
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
