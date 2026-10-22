local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Шрифт окон аддона. Выбирается в настройках: шрифты игры, шрифты других аддонов
-- (LibSharedMedia, в том числе EllesmereUI) и свой файл. В список попадают только
-- шрифты, в которых есть ВСЕ нужные аддону буквы и знаки: каждый знак меряется
-- в самом шрифте и сравнивается с «пустым» знаком (квадратиком) — совпал, значит
-- знака в шрифте нет. Размер и обводка текста остаются как были.
---------------------------------------------------------------------------

-- Шрифты игры (есть в каждом клиенте)
TH.GAME_FONTS = {
	{ key = "friz", name = L["Friz Quadrata (как в игре)"], path = "Fonts\\FRIZQT___CYR.TTF" },
	{ key = "arialn", name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ key = "morpheus", name = "Morpheus", path = "Fonts\\MORPHEUS_CYR.TTF" },
	{ key = "skurri", name = "Skurri", path = "Fonts\\SKURRI_CYR.TTF" },
	{ key = "2002", name = "2002", path = "Fonts\\2002.TTF" },
	{ key = "arhei", name = "AR Hei", path = "Fonts\\ARHei.ttf" },
	{ key = "arkai", name = "AR Kai", path = "Fonts\\ARKai_T.ttf" },
	{ key = "pagetext", name = "K Pagetext", path = "Fonts\\K_Pagetext.TTF" },
}

-- Свой шрифт: файл кладут сюда (папку создать самому), игру перезапустить целиком
TH.CUSTOM_FONT_DIR = "Interface\\Fonts\\"
TH.CUSTOM_FONT_HINT = L["Свой шрифт: положите файл .ttf или .otf в папку World of Warcraft\\_retail_\\Interface\\Fonts "]
	.. L["(папки Fonts нет — создайте), полностью перезапустите игру (/reload не хватит: новые файлы игра видит только "]
	.. L["после запуска) и выберите «Свой шрифт...», вписав имя файла, например MyFont.ttf. "]
	.. L["Аддон проверит, есть ли в шрифте русские и латинские буквы."]

-- Знаки, которые аддон пишет: все русские и латинские буквы, цифры и знаки
local REQUIRED = {}
do
	local function Add(s)
		for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
			if ch ~= " " then REQUIRED[#REQUIRED + 1] = ch end
		end
	end
	Add("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя")
	Add("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
	Add(".,:;!?()[]-+/%'\"*#&=_<>«»—·")
	-- испанский клиент: буквы с диакритикой и перевёрнутые знаки
	-- (кодами: в коде остальных языков этих знаков нет)
	if ns.ClientLocale and ns.ClientLocale() == "esES" then
		for _, cp in ipairs({ 0xC1, 0xC9, 0xCD, 0xD3, 0xDA, 0xDC, 0xD1, 0xE1, 0xE9, 0xED, 0xF3, 0xFA, 0xFC, 0xF1, 0xBF, 0xA1 }) do
			REQUIRED[#REQUIRED + 1] = cp < 0xC0 and ("\194" .. string.char(cp)) or ("\195" .. string.char(cp - 0x40))
		end
	end
	-- немецкий клиент: умлауты и ß
	if ns.ClientLocale and ns.ClientLocale() == "deDE" then
		for _, cp in ipairs({ 0xC4, 0xD6, 0xDC, 0xE4, 0xF6, 0xFC, 0xDF }) do
			REQUIRED[#REQUIRED + 1] = "\195" .. string.char(cp - 0x40)
		end
	end
	-- французский клиент: буквы с диакритикой и œ
	if ns.ClientLocale and ns.ClientLocale() == "frFR" then
		for _, cp in ipairs({ 0xC0, 0xC2, 0xC7, 0xC9, 0xC8, 0xCA, 0xCE, 0xD4, 0xE0, 0xE2, 0xE7, 0xE9, 0xE8, 0xEA, 0xEB, 0xEE, 0xEF, 0xF4, 0xFB, 0xF9 }) do
			REQUIRED[#REQUIRED + 1] = "\195" .. string.char(cp - 0x40)
		end
		REQUIRED[#REQUIRED + 1] = "\197\147" -- œ
	end
end
TH.FONT_REQUIRED = REQUIRED

local NOTDEF = "\238\128\128" -- U+E000: этого знака нет ни в одном шрифте — так выглядит квадратик
local probe, checked = nil, {}

-- Есть ли в шрифте все нужные знаки: ok, список отсутствующих
function TH:CheckFont(path)
	if not path or path == "" then return false, { L["файл не найден"] } end
	if checked[path] then return checked[path][1], checked[path][2] end
	probe = TH.fontProbe or probe or UIParent:CreateFontString(nil, "OVERLAY") -- fontProbe — для тестов
	probe:Hide()
	if not probe:SetFont(path, 16, "") then
		checked[path] = { false, { L["файл не найден или не шрифт"] } }
		return false, checked[path][2]
	end
	probe:SetText(NOTDEF)
	local empty = probe:GetStringWidth()
	local missing = {}
	if type(empty) ~= "number" or empty <= 0 then
		-- не смогли измерить: не рискуем
		checked[path] = { false, { L["не удалось проверить"] } }
		return false, checked[path][2]
	end
	for _, ch in ipairs(REQUIRED) do
		probe:SetText(ch)
		local w = probe:GetStringWidth()
		if type(w) ~= "number" or w <= 0 or math.abs(w - empty) < 0.01 then missing[#missing + 1] = ch end
	end
	-- если ширина знака случайно совпала с квадратиком, шрифт отбрасывается: лучше не
	-- предложить хороший шрифт, чем показать квадратики
	local ok = #missing == 0
	checked[path] = { ok, missing }
	return ok, missing
end

-- Шрифт, выбранный в EllesmereUI (его общий шрифт интерфейса): путь, название; nil — нет EllesmereUI
function TH:GetEllesmereFont()
	local E = _G.EllesmereUI
	if type(E) ~= "table" or type(E.GetFontPath) ~= "function" then return nil end
	local ok, path = pcall(E.GetFontPath)
	if not ok or type(path) ~= "string" or path == "" then return nil end
	local name
	if type(E.GetFontName) == "function" then
		local ok2, n = pcall(E.GetFontName)
		if ok2 and type(n) == "string" then name = n:gsub("^%c+", "") end
	end
	return path, name
end

-- Все шрифты, в которых есть нужные знаки: { key, name, path }
function TH:GetFontChoices()
	local list = { { key = "auto", name = L["Авто (как в EllesmereUI)"], hint = L["Шрифт, выбранный в EllesmereUI; без него — как в игре."] },
		{ key = "default", name = L["Как в игре"] } }
	local euiPath, euiName = self:GetEllesmereFont()
	if euiPath and self:CheckFont(euiPath) then
		list[#list + 1] = { key = "eui", name = L["Как в EllesmereUI"] .. (euiName and (" (" .. euiName .. ")") or ""), path = euiPath }
	end
	for _, f in ipairs(self.GAME_FONTS) do
		if self:CheckFont(f.path) then list[#list + 1] = f end
	end
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and LSM.HashTable then
		local names = {}
		for name in pairs(LSM:HashTable("font") or {}) do names[#names + 1] = name end
		table.sort(names)
		for _, name in ipairs(names) do
			local path = LSM:Fetch("font", name, true)
			local dup = false
			for _, f in ipairs(list) do if f.path and path and f.path:lower() == path:lower() then dup = true end end
			if path and not dup and self:CheckFont(path) then
				list[#list + 1] = { key = "lsm:" .. name, name = name .. L[" (аддоны)"], path = path }
			end
		end
	end
	if self.db.customFont and self.db.customFont ~= "" then
		local path = self.CUSTOM_FONT_DIR .. self.db.customFont
		if self:CheckFont(path) then list[#list + 1] = { key = "custom", name = L["Свой: "] .. self.db.customFont, path = path } end
	end
	return list
end

-- Путь выбранного шрифта (nil — шрифты игры как есть)
function TH:GetFontPath()
	local key = self.db.font or "auto"
	if key == "default" then return nil end
	-- авто и «как в EllesmereUI»: его шрифт, если EllesmereUI стоит и в шрифте есть все буквы
	if key == "auto" or key == "eui" then
		local path = self:GetEllesmereFont()
		return path and self:CheckFont(path) and path or nil
	end
	if key == "custom" then
		local path = self.db.customFont and (self.CUSTOM_FONT_DIR .. self.db.customFont)
		return path and self:CheckFont(path) and path or nil
	end
	if key:sub(1, 4) == "lsm:" then
		local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
		local path = LSM and LSM:Fetch("font", key:sub(5), true)
		return path and self:CheckFont(path) and path or nil
	end
	for _, f in ipairs(self.GAME_FONTS) do
		if f.key == key then return self:CheckFont(f.path) and f.path or nil end
	end
end

-- Поставить шрифт тексту, сохранив размер и обводку; «по умолчанию» — вернуть родной
local function ApplyTo(fs, path)
	if not fs.GetFont then return end
	if not fs.thFontOrig then
		local file, size, flags = fs:GetFont()
		if not file or not size then return end
		fs.thFontOrig = { file, size, flags or "" }
	end
	local orig = fs.thFontOrig
	local target = path or orig[1]
	if fs.thFontNow == target then return end
	if fs:SetFont(target, orig[2], orig[3]) then
		fs.thFontNow = target
	else
		fs:SetFont(orig[1], orig[2], orig[3])
		fs.thFontNow = orig[1]
	end
end

local function Walk(frame, path)
	if type(frame) ~= "table" or not frame.GetRegions then return end
	for _, region in ipairs({ frame:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "FontString" then ApplyTo(region, path) end
	end
	if frame.GetObjectType and frame:GetObjectType() == "EditBox" then ApplyTo(frame, path) end
	for _, child in ipairs({ frame:GetChildren() }) do Walk(child, path) end
end

-- Пройтись по всем окнам аддона (и всплывашкам) и поставить выбранный шрифт
function TH:ApplyFont()
	if not self.db then return end
	local path = self:GetFontPath()
	local names = {}
	for _, n in ipairs(self.WINDOWS or {}) do names[#names + 1] = n end
	names[#names + 1] = "TransmogHubAchievementToast"
	names[#names + 1] = "TransmogHubNoteToast"
	for _, name in ipairs(names) do
		local f = _G[name]
		if f then
			Walk(f, path)
			if not f.thFontHooked and f.HookScript then
				f.thFontHooked = true
				f:HookScript("OnShow", function(self) Walk(self, TH:GetFontPath()) end) -- новые строки списков
			end
		end
	end
end

function TH:SetFont(key)
	self.db.font = key
	self:ApplyFont()
end

-- /thub fonts — проверка всех шрифтов: какие подходят, чего не хватает
function TH:PrintFontCheck()
	local function Line(name, path)
		local ok, missing = self:CheckFont(path)
		self:Print(name .. ": " .. (ok and L["|cff40ff40все знаки есть|r"]
			or (L["|cffff4040нет: "] .. table.concat(missing, " ", 1, math.min(#missing, 20)) .. (#missing > 20 and " ..." or "") .. "|r")))
	end
	self:Print(string.format(L["Проверка шрифтов (%d знаков: русские и латинские буквы, цифры, знаки):"], #REQUIRED))
	local euiPath, euiName = self:GetEllesmereFont()
	if euiPath then Line("EllesmereUI: " .. (euiName or euiPath), euiPath) end
	for _, f in ipairs(self.GAME_FONTS) do Line(f.name, f.path) end
	local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
	if LSM and LSM.HashTable then
		for name in pairs(LSM:HashTable("font") or {}) do Line(name .. L[" (аддоны)"], LSM:Fetch("font", name, true)) end
	end
	if self.db.customFont then Line(L["Свой: "] .. self.db.customFont, self.CUSTOM_FONT_DIR .. self.db.customFont) end
end

if hooksecurefunc then
	hooksecurefunc(TH, "ApplyScale", function() TH:ApplyFont() end)
end
