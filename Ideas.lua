local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Предложения разработчику: идея, ошибка или что-то ещё. Уходят скрыто,
-- у модератора попадают в журнал, коннектор выгружает их, а ежедневная
-- проверка присылает разработчику сводку.
---------------------------------------------------------------------------
local LETTERS = 140
local PER_DAY = 3
local KINDS = {
	{ key = "i", text = L["Идея"] },
	{ key = "b", text = L["Ошибка"] },
	{ key = "o", text = L["Другое"] },
}
local dlg

function TH:SendIdea(kind, text)
	text = strtrim(text or "")
	if #text:gsub("[\128-\191]", "") < 10 then return L["Напишите чуть подробнее — хотя бы одно предложение."] end
	local now, today = self.Net.Now(), 0
	for i = #self.db.myIdeas, 1, -1 do
		if now - self.db.myIdeas[i] < 86400 then today = today + 1 else tremove(self.db.myIdeas, i) end
	end
	if today >= PER_DAY then return L["Не больше "] .. PER_DAY .. L[" писем в день — грифоны устали."] end
	tinsert(self.db.myIdeas, now)
	self.Net:SendIdea(kind, text)
	self:TrackCount("letters")
	self:Thanks(L["Письмо отправлено. Лучшие идеи появятся в обновлениях аддона."])
end

local function Send()
	local err = TH:SendIdea(dlg.kind, dlg.edit:GetText())
	if err then dlg.error:SetText(err) else dlg:Hide() end
end

local function Build()
	dlg = CreateFrame("Frame", "TransmogHubIdeas", UIParent, "BasicFrameTemplateWithInset")
	dlg:SetSize(440, 290)
	dlg:SetPoint("CENTER", 0, 80)
	dlg:SetFrameStrata("FULLSCREEN_DIALOG")
	dlg:SetToplevel(true)
	dlg:EnableMouse(true)
	tinsert(UISpecialFrames, dlg:GetName())

	local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText(L["Письмо разработчику"])

	local info = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	info:SetPoint("TOPLEFT", 16, -32)
	info:SetWidth(408)
	info:SetJustifyH("LEFT")
	info:SetText(L["Есть идея, нашли ошибку или чего-то не хватает? Напишите — письмо доставит самый быстрый грифон Даларана. Каждое письмо прочитают."])

	-- вид письма
	dlg.kindButtons = {}
	for i, k in ipairs(KINDS) do
		local b = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
		TH.PadButton(b)
		b:SetSize(100, 22)
		b:SetPoint("TOPLEFT", 14 + (i - 1) * 104, -78)
		b:SetText(k.text)
		b.key = k.key
		b:SetScript("OnClick", function() TH:SetIdeaKind(k.key) end)
		dlg.kindButtons[i] = b
	end

	local box = CreateFrame("Frame", nil, dlg, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 14, -108)
	box:SetSize(412, 100)
	box:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	box:SetBackdropColor(0, 0, 0, 0.6)
	box:EnableMouse(true)
	dlg.edit = CreateFrame("EditBox", nil, box)
	dlg.edit:SetPoint("TOPLEFT", 8, -8)
	dlg.edit:SetPoint("BOTTOMRIGHT", -8, 8)
	dlg.edit:SetMultiLine(true)
	dlg.edit:SetAutoFocus(false)
	dlg.edit:SetFontObject("GameFontHighlight")
	dlg.edit:SetMaxLetters(LETTERS)
	dlg.edit:SetScript("OnEscapePressed", function() dlg:Hide() end)
	dlg.edit:HookScript("OnTextChanged", function(e)
		dlg.error:SetText("")
		dlg.count:SetText(string.format("%d / %d", e.GetNumLetters and e:GetNumLetters() or #(e:GetText() or ""), LETTERS))
	end)
	box:SetScript("OnMouseDown", function() dlg.edit:SetFocus() end)

	dlg.count = dlg:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	dlg.count:SetPoint("TOPRIGHT", box, "BOTTOMRIGHT", -2, -3)
	dlg.error = dlg:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	dlg.error:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -3)
	dlg.error:SetWidth(320)
	dlg.error:SetJustifyH("LEFT")

	local send = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(send)
	send:SetSize(140, 24)
	send:SetPoint("BOTTOMLEFT", 14, 12)
	send:SetText(L["Отправить"])
	send:SetScript("OnClick", Send)
	if TH.StylePrimaryButton then TH.StylePrimaryButton(send) end
	dlg.sendBtn = send

	local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(cancel)
	cancel:SetSize(100, 24)
	cancel:SetPoint("BOTTOMRIGHT", -14, 12)
	cancel:SetText(CANCEL)
	cancel:SetScript("OnClick", function() dlg:Hide() end)
end

function TH:SetIdeaKind(key)
	dlg.kind = key
	for _, b in ipairs(dlg.kindButtons) do
		if b.key == key then b:LockHighlight() else b:UnlockHighlight() end
	end
end

function TH:OpenIdeas(kind)
	if not dlg then Build() end
	self:SetIdeaKind(kind or "i")
	dlg.edit:SetText("")
	dlg.error:SetText("")
	dlg.count:SetText("0 / " .. LETTERS)
	dlg:SetScale(self.db.scale or 1)
	dlg:Show()
	TH:SkinNow(dlg)
	dlg.edit:SetFocus()
end

---------------------------------------------------------------------------
-- Отчёты об ошибках. Ошибки Lua в коде Transmog Hub уходят разработчику тем же
-- путём, что письма (вид «e»): модератор копит их в журнале, коннектор выгружает,
-- ежедневная проверка разбирает. Чужие ошибки (других аддонов) не трогаем.
-- Если стоит BugGrabber (BugSack) — берём ошибки у него, иначе встаём в цепочку
-- обработчика ошибок игры (предыдущий обработчик вызывается как обычно).
---------------------------------------------------------------------------
local ERRORS_PER_SESSION = 5
local sentThisSession = 0
local OUR_PATH = "[Aa]dd[Oo]ns[/\\]TransmogHub[/\\]"

-- Путь до файла аддона короче: «Interface/AddOns/TransmogHub/Core.lua:12» -> «Core.lua:12»
local function ShortPaths(s)
	return (tostring(s or ""):gsub("[^%s%[\"']*[Aa]dd[Oo]ns[/\\]TransmogHub[/\\]", ""))
end

-- Первая строка стека в нашем коде (где именно упало)
local function OurFrame(stack)
	for line in tostring(stack or ""):gmatch("[^\n]+") do
		if line:find(OUR_PATH) then return ShortPaths(line):gsub("^%s+", "") end
	end
end

function TH:ReportError(message, stack)
	if not (self.db and self.db.sendErrors) then return end
	message = tostring(message or "")
	local ours = message:find(OUR_PATH) or tostring(stack or ""):find(OUR_PATH)
	if not ours then return end
	if sentThisSession >= ERRORS_PER_SESSION then return end
	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("TransmogHub", "Version") or "?"
	local short = ShortPaths(message):gsub("%s+", " ")
	-- отпечаток: место и текст без чисел — одна и та же ошибка с разными значениями не повторяется
	local fingerprint = (short:gsub("%d+", "#")):sub(1, 120)
	if self.db.errorsSent[fingerprint] == version then return end
	self.db.errorsSent[fingerprint] = version
	sentThisSession = sentThisSession + 1
	local where = OurFrame(stack)
	local text = "v" .. version .. " " .. short
	if where and not short:find(where, 1, true) then text = text .. " @ " .. where end
	if self.Net and self.Net.SendIdea then self.Net:SendIdea("e", text) end
end

-- BugGrabber сообщает о новой ошибке событием EventRegistry «BugGrabber.BugGrabbed»
-- (аргумент — номер ошибки); сами ошибки — в BugGrabber:GetDB(), новые в конце.
-- Смотрим последние записи и берём новые. Повтор уже записанной ошибки BugGrabber
-- не добавляет заново, а увеличивает её счётчик — поэтому запоминаем и счётчик.
local grabbed = setmetatable({}, { __mode = "k" }) -- [ошибка] = её счётчик, когда смотрели
local function Fresh(err)
	if type(err) ~= "table" or not err.message then return false end
	local count = err.counter or 1
	if grabbed[err] == count then return false end
	grabbed[err] = count
	return true
end

local function FromGrabber(_, arg)
	if type(arg) == "table" then
		if Fresh(arg) then TH:ReportError(arg.message, arg.stack) end
		return
	end
	local db = BugGrabber.GetDB and BugGrabber:GetDB()
	if type(db) ~= "table" then return end
	-- самая свежая может быть и старой записью с выросшим счётчиком — смотрим все
	for i = #db, 1, -1 do
		local err = db[i]
		if Fresh(err) then TH:ReportError(err.message, err.stack) end
	end
end

local function Install()
	-- отпечатки ошибок прошлых версий больше не нужны: после обновления ошибка может вернуться
	local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata("TransmogHub", "Version")
	if version and TH.db and TH.db.errorsSent then
		for fp, v in pairs(TH.db.errorsSent) do
			if v ~= version then TH.db.errorsSent[fp] = nil end
		end
	end
	local grabber = _G.BugGrabber
	if grabber then
		-- уже записанные до входа ошибки не отправляем — только новые
		local db = grabber.GetDB and grabber:GetDB()
		if type(db) == "table" then for _, err in ipairs(db) do Fresh(err) end end
		if EventRegistry and EventRegistry.RegisterCallback then
			EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function(...) pcall(FromGrabber, ...) end, grabbed)
			return "BugGrabber"
		elseif grabber.RegisterCallback then -- старые версии BugGrabber
			grabber.RegisterCallback(TH, "BugGrabber_BugGrabbed", function(...) pcall(FromGrabber, ...) end)
			return L["BugGrabber (старый)"]
		end
	end
	if geterrorhandler and seterrorhandler then
		local previous = geterrorhandler()
		seterrorhandler(function(msg, ...)
			pcall(TH.ReportError, TH, msg, debugstack and debugstack(2) or nil)
			if previous then return previous(msg, ...) end
		end)
		return "handler"
	end
end
TH.InstallErrorReports = Install

-- запрещённые действия (taint) по вине аддона — тоже ошибка
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:SetScript("OnEvent", function(_, event, addon, func)
	if event == "PLAYER_LOGIN" then
		TH.errorReportsVia = Install()
	elseif addon == "TransmogHub" then
		pcall(TH.ReportError, TH, "Interface/AddOns/TransmogHub/: " .. event .. " " .. tostring(func), nil)
	end
end)

---------------------------------------------------------------------------
-- Жалоба «Другое»: игрок пишет, что не так. Жалоба уходит как обычно, а пояснение —
-- тем же путём, что письма (вид «r», текст «[id образа] пояснение»).
---------------------------------------------------------------------------
local REPORT_LETTERS = 140
local other

function TH:SendReportOther(setId, text)
	text = strtrim(text or "")
	if #text:gsub("[\128-\191]", "") < 5 then return L["Напишите хотя бы пару слов: что не так с образом."] end
	self:Report(setId, "x")
	self.Net:SendIdea("r", "[" .. setId .. "] " .. text)
end

function TH:OpenReportOther(set)
	if not other then
		other = CreateFrame("Frame", "TransmogHubReportOther", UIParent, "BasicFrameTemplateWithInset")
		other:SetSize(420, 170)
		other:SetPoint("CENTER", 0, 80)
		other:SetFrameStrata("FULLSCREEN_DIALOG")
		other:SetToplevel(true)
		other:EnableMouse(true)
		tinsert(UISpecialFrames, other:GetName())
		local title = other:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText(L["Жалоба: что не так?"])
		other.info = other:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		other.info:SetPoint("TOPLEFT", 16, -34)
		other.info:SetWidth(388)
		other.info:SetJustifyH("LEFT")
		other.edit = CreateFrame("EditBox", nil, other, "InputBoxTemplate")
		other.edit:SetSize(380, 22)
		other.edit:SetPoint("TOPLEFT", 22, -74)
		other.edit:SetAutoFocus(true)
		other.edit:SetMaxLetters(REPORT_LETTERS)
		other.error = other:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
		other.error:SetPoint("TOPLEFT", 18, -102)
		other.error:SetWidth(388)
		other.error:SetJustifyH("LEFT")
		local function Send()
			local err = TH:SendReportOther(other.setId, other.edit:GetText())
			if err then other.error:SetText(err) else other:Hide() end
		end
		other.edit:SetScript("OnEnterPressed", Send)
		other.edit:SetScript("OnEscapePressed", function() other:Hide() end)
		local send = CreateFrame("Button", nil, other, "UIPanelButtonTemplate")
		TH.PadButton(send)
		send:SetSize(140, 24)
		send:SetPoint("BOTTOMLEFT", 14, 12)
		send:SetText(L["Отправить"])
		send:SetScript("OnClick", Send)
		if TH.StylePrimaryButton then TH.StylePrimaryButton(send) end
		local cancel = CreateFrame("Button", nil, other, "UIPanelButtonTemplate")
		TH.PadButton(cancel)
		cancel:SetSize(100, 24)
		cancel:SetPoint("BOTTOMRIGHT", -14, 12)
		cancel:SetText(CANCEL or L["Отмена"])
		cancel:SetScript("OnClick", function() other:Hide() end)
		other.sendBtn = send
	end
	other.setId = set.id
	other.info:SetText(L["Образ «"] .. (set.name or "?") .. L["». Коротко опишите, что не так (до "] .. REPORT_LETTERS
		.. L[" букв) — модератор прочитает. Для рекламы и оскорблений есть отдельные пункты."])
	other.edit:SetText("")
	other.error:SetText("")
	self:ApplyScale()
	other:SetScale(self.db.scale or 1)
	other:Show()
	TH:SkinNow(other)
end
