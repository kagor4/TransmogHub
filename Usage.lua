local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Статистика нажатий: какие кнопки аддона нажимают и как часто — чтобы убирать
-- ненужное и переставлять важное. Считаем только «окно / кнопка» и число нажатий,
-- без образов, текстов и прочих данных. Кнопка уходит в сеть коротким кодом
-- (4 знака): раз в неделю — самые нажимаемые, не больше трёх сообщений.
-- Модератор собирает отчёты (modUsage) и расшифровку кодов (modUsageNames).
-- Отключить: /thub usage off.
---------------------------------------------------------------------------
local WEEK = 7 * 86400
local MAX_KEYS, MAX_MESSAGES, MESSAGE_BYTES = 60, 3, 160
local MOD_USAGE_MAX = 3000

-- Названия окон для ключей
local WINDOW_LABEL = {
	TransmogHubSaveDialog = "Сохранение", TransmogHubIconPicker = "Выбор иконки", TransmogHubHelp = "Справка",
	TransmogHubIdeas = "Письмо", TransmogHubReportOther = "Жалоба «Другое»", TransmogHubSuggestTag = "Предложить тег",
	TransmogHubAppeal = "Обращение", TransmogHubWarning = "Предупреждение", TransmogHubSettings = "Настройки",
}
local VIEW_LABEL = {
	top = "Образы", friends = "Друзья", guild = "Гильдия", favorites = "Избранное", mine = "Мои образы",
	profile = "Профиль", achievements = "Достижения", moderation = "Модерация", author = "Образы автора",
}

TH.usageNames = {} -- [код] = «Окно / Кнопка» — что видел этот клиент

-- Код кнопки: 4 знака base36 от названия (одинаковый у всех клиентов)
local B36 = "0123456789abcdefghijklmnopqrstuvwxyz"
function TH.UsageCode(name)
	local h = 5381
	for i = 1, #name do h = (h * 33 + name:byte(i)) % 1679609 end -- простое меньше 36^4
	local out = ""
	for _ = 1, 4 do
		local d = h % 36
		out = B36:sub(d + 1, d + 1) .. out
		h = math.floor(h / 36)
	end
	return out
end

-- Надпись кнопки без цвета, иконок и чисел: «Теги (2)» -> «Теги»
local function Label(b)
	if b.thLogKey then return b.thLogKey end
	local text = b.GetText and b:GetText()
	if type(text) ~= "string" or text == "" then text = b.thTipTitle end
	if type(text) ~= "string" then return nil end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
		:gsub("%(%d+%)", ""):gsub("%d+", "#"):gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" or #text > 60 then return nil end
	return text
end

local knownNames -- [код] = название из журнала модератора
function TH:KnownUsageName(code)
	if not knownNames then
		knownNames = {}
		for _, line in ipairs(self.db.modUsageNames) do
			local c, name = line:match("^1|(%w+)|(.*)$")
			if c then knownNames[c] = name end
		end
	end
	return knownNames[code]
end

function TH:TrackClick(name)
	if not (self.db and self.db.sendUsage) then return end
	local code = TH.UsageCode(name)
	if not self.usageNames[code] then
		self.usageNames[code] = name
		-- модератор копит расшифровку кодов: коннектор выгружает её рядом с отчётами
		if self:IsModeratorClient() and not self:KnownUsageName(code) then
			tinsert(self.db.modUsageNames, "1|" .. code .. "|" .. name)
			knownNames[code] = name
		end
	end
	self.db.clicks[code] = (self.db.clicks[code] or 0) + 1
end

local function OnClick(b)
	local label = Label(b)
	if not label then return end
	local window = b.thLogWindow
	if window == "TransmogHubFrame" then
		window = VIEW_LABEL[TH.UI and TH.UI.view] or "Главное окно"
	else
		window = WINDOW_LABEL[window] or window
	end
	TH:TrackClick(window .. " / " .. label)
end

local function Hook(frame, window)
	if type(frame) ~= "table" or not frame.GetObjectType then return end
	local ftype = frame:GetObjectType()
	if (ftype == "Button" or ftype == "CheckButton") and not frame.thLogHooked and frame.HookScript then
		frame.thLogHooked = true
		frame.thLogWindow = window
		frame:HookScript("OnClick", OnClick)
	end
	for _, child in ipairs({ frame:GetChildren() }) do Hook(child, window) end
end

-- Окна строятся при первом открытии, строки — и позже: досматриваем при каждом показе
function TH:HookUsage()
	for _, name in ipairs(self.WINDOWS or {}) do
		local f = _G[name]
		if f and not f.thLogShowHooked and f.HookScript then
			f.thLogShowHooked = true
			f:HookScript("OnShow", function(self) Hook(self, name) end)
		end
		if f then Hook(f, name) end
	end
end
if hooksecurefunc then
	hooksecurefunc(TH, "ApplyScale", function() TH:HookUsage() end)
end

-- Раз в неделю: самые нажимаемые кнопки — «код=число,…», до трёх сообщений
function TH:SendUsage(force)
	local db = self.db
	if not (db and db.sendUsage and self.Net and self.Net.SendIdea) then return end
	local now = self.Net.Now()
	if not force and now - (db.usageSent or 0) < WEEK then return end
	local list = {}
	for code, n in pairs(db.clicks) do list[#list + 1] = { code, n } end
	if #list == 0 then return end
	table.sort(list, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
	local messages, cur = {}, {}
	local len = 0
	for i = 1, math.min(#list, MAX_KEYS) do
		local part = list[i][1] .. "=" .. list[i][2]
		if len + #part + 1 > MESSAGE_BYTES then
			messages[#messages + 1] = table.concat(cur, ",")
			cur, len = {}, 0
			if #messages >= MAX_MESSAGES then break end
		end
		cur[#cur + 1] = part
		len = len + #part + 1
	end
	if #cur > 0 and #messages < MAX_MESSAGES then messages[#messages + 1] = table.concat(cur, ",") end
	for i, text in ipairs(messages) do
		-- у каждого сообщения своё время: ключ записи «игрок#время» не совпадёт
		C_Timer.After(i - 1, function() self.Net:SendIdea("u", text) end)
	end
	wipe(db.clicks)
	db.usageSent = now
end

-- Модератор: отчёт в журнал коннектора, без имени игрока
function TH:LogUsage(t, text)
	if not self:IsModeratorClient() then return end
	local log = self.db.modUsage
	log[#log + 1] = table.concat({ "1", t, text }, "|")
	while #log > MOD_USAGE_MAX do tremove(log, 1) end
end

-- Сводка: { { название, нажатий }, … } по убыванию. У модератора — по всем отчётам,
-- у остальных — свои нажатия с прошлой отправки
function TH:GetUsageSummary()
	local total = {}
	if self:IsModeratorClient() then
		for _, line in ipairs(self.db.modUsage) do
			local text = line:match("^1|%d+|(.*)$")
			for code, n in (text or ""):gmatch("(%w+)=(%d+)") do total[code] = (total[code] or 0) + tonumber(n) end
		end
	end
	for code, n in pairs(self.db.clicks) do total[code] = (total[code] or 0) + n end
	local out = {}
	for code, n in pairs(total) do
		out[#out + 1] = { self.usageNames[code] or self:KnownUsageName(code) or ("код " .. code), n }
	end
	table.sort(out, function(a, b) if a[2] ~= b[2] then return a[2] > b[2] end return a[1] < b[1] end)
	return out
end

function TH:PrintUsage()
	local list = self:GetUsageSummary()
	self:Print((self:IsModeratorClient() and "Нажатия всех игроков (из отчётов):" or "Ваши нажатия с прошлой отправки:")
		.. (#list == 0 and " пока пусто." or ""))
	for i = 1, math.min(#list, 30) do print(string.format("  %d. %s — %d", i, list[i][1], list[i][2])) end
end

-- При входе: один раз рассказать о сборе и отправить недельную сводку
function TH:StartUsage()
	-- первая сводка — через неделю сбора, а не сразу после установки
	if (self.db.usageSent or 0) == 0 then self.db.usageSent = self.Net.Now() end
	if not self.db.usageNoticed then
		self.db.usageNoticed = true
		self:Print("Аддон считает, на какие его кнопки сколько раз нажимают, и раз в неделю отправляет сводку разработчику — так проще улучшать интерфейс. Только названия кнопок и числа. Отключить: /thub usage off")
	end
	C_Timer.After(90, function() self:SendUsage() end)
end
