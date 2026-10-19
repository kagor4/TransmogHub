local _, ns = ...
local L = ns.L
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

---------------------------------------------------------------------------
-- Позы: анимации модели (номера — из AnimationData игры). freeze — остановить на кадре
-- (пауза), sheathe — оружие в ножнах. once — анимация не зацикленная (эмоция, заклинание):
-- сама она замирает на последнем кадре, поэтому играем её снова после короткой стойки. Часть эмоций у некоторых рас не проигрывается:
-- тогда модель просто стоит.
---------------------------------------------------------------------------
TH.POSES = {
	{ key = "stand", anim = 0, name = L["Стойка"] },
	{ key = "ready", anim = 25, name = L["Боевая стойка"] },
	{ key = "ready2h", anim = 27, name = L["Боевая стойка с оружием"], arms = true },
	{ key = "roar", anim = 55, once = 2, name = L["Боевой клич"], arms = true },
	{ key = "cast", anim = 52, name = L["Подготовка заклинания"] },
	{ key = "spell", anim = 54, once = 2, name = L["Заклинание"] },
	{ key = "bow", anim = 66, once = 2.5, name = L["Поклон"] },
	{ key = "wave", anim = 67, once = 2.5, name = L["Приветствие"] },
	{ key = "salute", anim = 113, once = 2.5, name = L["Салют"] },
	{ key = "cheer", anim = 68, once = 2.5, name = L["Ликование"] },
	{ key = "dance", anim = 69, name = L["Танец"] },
	{ key = "laugh", anim = 70, once = 3, name = L["Смех"] },
	{ key = "flex", anim = 82, once = 2.5, name = L["Напрячь мышцы"] },
	{ key = "point", anim = 84, once = 2, name = L["Указать"] },
	{ key = "kneel", anim = 75, name = L["На колене"] },
	{ key = "sit", anim = 97, name = L["Сидя"] },
}
TH.POSE_BY_KEY = {}
for _, p in ipairs(TH.POSES) do TH.POSE_BY_KEY[p.key] = p end

-- Классовое появление в фотостудии: анимация и эффекты класса (номера эффектов — по
-- фото-аддону Narcissus), через пару секунд модель переходит в выбранную позу
TH.CLASS_INTROS = {
	WARRIOR = { anim = 39, kits = { 77753, 113504 } },
	PALADIN = { anim = 142, kits = { 109802, 105334 } },
	HUNTER = { anim = 113, kits = { 11212 } },
	ROGUE = { anim = 0, kits = { 105866 } },
	PRIEST = { anim = 54, kits = { 41593, 44806 } },
	DEATHKNIGHT = { anim = 142, kits = { 57627, 57287 } },
	SHAMAN = { anim = 115, kits = { 100019 } },
	MAGE = { anim = 54, kits = { 68828, 68661 } },
	WARLOCK = { anim = 55, kits = { 71357, 86545 } },
	MONK = { anim = 116, kits = { 6095, 65638 } },
	DRUID = { anim = 142, kits = { 82209, 81597 } },
	DEMONHUNTER = { anim = 39, kits = { 79517 } },
}
local INTRO_TIME = 2.5

-- Поза по ключу; «anim:N» — анимация по номеру (подбор позы в фотостудии)
local function PoseByKey(key)
	local n = key and tonumber(key:match("^anim:(%d+)$"))
	if n then return { key = key, anim = n } end
	return TH.POSE_BY_KEY[key or "stand"] or TH.POSES[1]
end
TH.PoseByKey = PoseByKey

-- pose — ключ из TH.POSES (nil — обычная стойка), freeze — замереть, sheathe — оружие убрать
function Preview:SetPose(key, freeze, sheathe)
	self.poseKey, self.freeze, self.sheathe = key, freeze, sheathe
	self.intro = nil
	self.poseStart = GetTime()
	self.frozenAt = nil
	self:ApplyPose()
end

-- Пауза: замереть на текущем кадре (или продолжить)
function Preview:SetFrozen(freeze)
	self.intro = nil
	if freeze and not self.freeze then
		self.frozenAt = GetTime() - (self.poseStart or GetTime())
	elseif not freeze then
		self.poseStart = GetTime() - (self.frozenAt or 0)
		self.frozenAt = nil
	end
	self.freeze = freeze
	self:ApplyPose()
end

local ONCE_GAP = 1.5 -- стойка между повторами эмоции

function Preview:ApplyPose()
	local actor = self.scene:GetPlayerActor()
	if not actor or not actor:IsLoaded() then return end
	self.introToken = (self.introToken or 0) + 1
	local token = self.introToken
	local pose = PoseByKey(self.poseKey)
	local sheathe = self.sheathe
	if sheathe == nil then sheathe = not pose.arms end
	if actor.SetSheathed then pcall(actor.SetSheathed, actor, sheathe and true or false) end
	if not actor.SetAnimation then return end
	local elapsed = self.freeze and (self.frozenAt or 0.5) or (GetTime() - (self.poseStart or GetTime()))
	local anim, offset, left = pose.anim, elapsed, nil
	if pose.once then
		-- цикл: эмоция once секунд, потом стойка ONCE_GAP секунд
		local t = elapsed % (pose.once + ONCE_GAP)
		if t < pose.once then
			offset, left = t, pose.once - t
		else
			anim, offset, left = 0, t - pose.once, pose.once + ONCE_GAP - t
		end
	end
	if self.freeze then
		pcall(actor.SetAnimation, actor, anim, 0, 0, offset)
		return
	end
	pcall(actor.SetAnimation, actor, anim, 0, 1, pose.once and offset or 0)
	if left then
		C_Timer.After(left + 0.01, function() if token == self.introToken then self:ApplyPose() end end)
	end
end

-- Классовое появление: играется, когда модель показалась (в одежде); загрузка модели
-- сбрасывает анимацию, поэтому раньше нельзя. Потом — выбранная поза.
function Preview:PlayIntro()
	local intro = self.intro
	local actor = self.scene:GetPlayerActor()
	if not intro or self.freeze or not actor then return end
	self.intro = nil
	if actor.SetSpellVisualKit then
		for _, kit in ipairs(intro.kits) do pcall(actor.SetSpellVisualKit, actor, kit, true) end
	end
	if actor.SetSheathed then pcall(actor.SetSheathed, actor, false) end
	if actor.SetAnimation then pcall(actor.SetAnimation, actor, intro.anim, 0, 1, 0) end
	self.introToken = (self.introToken or 0) + 1
	local token = self.introToken
	C_Timer.After(INTRO_TIME, function()
		-- за это время не выбрали другую позу и не перезагрузили модель
		if token == self.introToken then
			self.poseStart = GetTime()
			self:ApplyPose()
		end
	end)
end

-- Камера сцены — в исходное положение (приближение, поворот). Модель и вещи остаются:
-- сцена переиспользует актёра с тем же тегом.
function Preview:ResetCamera()
	self.scene:TransitionToModelSceneID(SCENE_ID, CAMERA_TRANSITION_TYPE_IMMEDIATE, CAMERA_MODIFICATION_TYPE_DISCARD, true)
	self:ApplyWideView()
end

-- Угол обзора камеры игра считает по ширине окна: в широком окне модель крупнее.
-- wide = во сколько раз окно шире обычного (0.8 высоты) — во столько же расширяем
-- угол, чтобы модель была того же размера, что в узком окне.
function Preview:ApplyWideView()
	local scene = self.scene
	if not (self.wide and scene.GetCameraFieldOfView and scene.SetCameraFieldOfView) then return end
	self.baseFov = self.baseFov or scene:GetCameraFieldOfView()
	if not self.baseFov then return end
	local deg = self.baseFov > 3.2 -- на случай, если угол в градусах, а не в радианах
	local base = deg and math.rad(self.baseFov) or self.baseFov
	local fov = math.min(2 * math.atan(math.tan(base / 2) * self.wide), 2.8)
	pcall(scene.SetCameraFieldOfView, scene, deg and math.deg(fov) or fov)
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
		if self.poseKey or self.sheathe ~= nil then self:ApplyPose() end
		C_Timer.After(0.3, function()
			if token ~= self.loadToken then return end
			self:SetHidden(false, true)
			if self.intro then self:PlayIntro() end
		end)
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
