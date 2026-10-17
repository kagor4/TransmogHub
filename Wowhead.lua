local _, ns = ...
local L = ns.L
local TH = ns.TH

-- Передача образа в примерочную Wowhead через официальную строку игры
-- «/customset v1 …» — ту же, что даёт штатная примерочная («Отправить ссылку →
-- Скопировать»). Wowhead принимает её: Импортировать → Загрузить через
-- внутриигровую ссылку. Раса и пол выбираются уже на Wowhead.
-- Формат повторяет TransmogUtil.CreateCustomSetSlashCommand (Blizzard_TransmogShared).

-- Раздел Wowhead на языке клиента
local WOWHEAD_LANG = {
	ruRU = "ru", deDE = "de", frFR = "fr", esES = "es", esMX = "es",
	ptBR = "pt", itIT = "it", koKR = "ko", zhCN = "cn", zhTW = "tw",
}

function TH:WowheadURL(path)
	local lang = WOWHEAD_LANG[GetLocale()]
	return "https://www.wowhead.com/" .. (lang and (lang .. "/") or "") .. path
end
local MAINHAND_INDIVIDUAL = -1 -- Constants.Transmog.MainHandTransmogIsIndividualWeapon

local SLOT_ORDER = { 1, 3, 15, 5, 4, 19, 9, 10, 6, 7, 8, 16, 17 } -- TransmogSlotOrder

function TH:BuildCustomSetCommand(set)
	local values = {}
	for _, slotID in ipairs(SLOT_ORDER) do
		local it = set.items and set.items[slotID] or {}
		values[#values + 1] = it[1] or 0
		if slotID == 3 then
			values[#values + 1] = it[2] or it[1] or 0          -- левый наплечник (как у игры: без разделения — тот же)
		elseif slotID == 16 then
			values[#values + 1] = it[2] or MAINHAND_INDIVIDUAL -- не парное оружие
			values[#values + 1] = it[3] or 0                   -- иллюзия
		elseif slotID == 17 then
			values[#values + 1] = it[3] or 0                   -- иллюзия
		end
	end
	return "/customset v1 " .. table.concat(values, ",")
end

---------------------------------------------------------------------------
-- Окно с адресом примерочной и строкой для импорта
---------------------------------------------------------------------------
local dlg

-- Поле только для чтения: любое изменение возвращает исходный текст
local function ReadOnlyBox(parent, y)
	local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	eb:SetSize(440, 20)
	eb:SetPoint("TOPLEFT", 22, y)
	eb:SetAutoFocus(false)
	eb:SetScript("OnEscapePressed", function() parent:Hide() end)
	eb:SetScript("OnTextChanged", function(self, userInput)
		if userInput then
			self:SetText(self.value)
			self:HighlightText()
		end
	end)
	eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
	eb:SetScript("OnMouseUp", function(self)
		self:SetFocus()
		self:HighlightText()
	end)
	return eb
end

local function Label(parent, text, y, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
	fs:SetPoint("TOPLEFT", 16, y)
	fs:SetWidth(448)
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

local function Build()
	dlg = CreateFrame("Frame", "TransmogHubLinkDialog", UIParent, "BasicFrameTemplateWithInset")
	dlg:SetSize(480, 236)
	dlg:SetPoint("CENTER", 0, 120)
	dlg:SetFrameStrata("DIALOG")
	dlg:SetToplevel(true)
	dlg:EnableMouse(true)
	tinsert(UISpecialFrames, dlg:GetName())

	local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText(L["Примерочная Wowhead"])

	Label(dlg, L["1. Откройте в браузере примерочную Wowhead:"], -32)
	dlg.url = ReadOnlyBox(dlg, -50)

	Label(dlg, L["2. Нажмите «Импортировать» > «Загрузить через внутриигровую ссылку» и вставьте строку:"], -80)
	dlg.command = ReadOnlyBox(dlg, -112)

	dlg.hint = Label(dlg, "", -142, "GameFontHighlightSmall")

	local close = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(close)
	close:SetSize(100, 22)
	close:SetPoint("BOTTOM", 0, 12)
	close:SetText(CLOSE)
	close:SetScript("OnClick", function() dlg:Hide() end)
end

function TH:ShowWowheadLink(set)
	if not set then return end
	self:TrackCount("wowhead")
	if not dlg then Build() end
	dlg.url.value = self:WowheadURL("dressing-room")
	dlg.url:SetText(dlg.url.value)
	dlg.command.value = self:BuildCustomSetCommand(set)
	dlg.command:SetText(dlg.command.value)
	dlg.hint:SetText(string.format(
		L["Копирование: щёлкните по полю и нажмите Ctrl+C.\nРасу и пол выберите на Wowhead — автор собирал образ на модели «%s, %s».\n|cff999999Эту же строку можно вставить в чат игры — откроется штатная примерочная.|r"],
		self:GetRaceName(set.race), self:SexLabel(set.sex)))
	dlg:Show()
	TH:SkinNow(dlg)
	dlg.command:SetFocus()
end

---------------------------------------------------------------------------
-- Ссылка на страницу вещи
---------------------------------------------------------------------------
local itemDlg

local function BuildItemDialog()
	itemDlg = CreateFrame("Frame", "TransmogHubItemLinkDialog", UIParent, "BasicFrameTemplateWithInset")
	itemDlg:SetSize(480, 130)
	itemDlg:SetPoint("CENTER", 0, 120)
	itemDlg:SetFrameStrata("DIALOG")
	itemDlg:SetToplevel(true)
	itemDlg:EnableMouse(true)
	tinsert(UISpecialFrames, itemDlg:GetName())

	local title = itemDlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText("Wowhead")

	itemDlg.name = Label(itemDlg, "", -32)
	itemDlg.url = ReadOnlyBox(itemDlg, -54)
	Label(itemDlg, L["Щёлкните по полю и нажмите Ctrl+C, затем вставьте в браузер."], -82, "GameFontHighlightSmall")

	local close = CreateFrame("Button", nil, itemDlg, "UIPanelButtonTemplate")
	TH.PadButton(close)
	close:SetSize(100, 22)
	close:SetPoint("BOTTOM", 0, 10)
	close:SetText(CLOSE)
	close:SetScript("OnClick", function() itemDlg:Hide() end)
end

function TH:ShowItemLink(itemID, name)
	if not itemID then return end
	self:TrackCount("wowhead")
	if not itemDlg then BuildItemDialog() end
	itemDlg.name:SetText(name or (L["Предмет "] .. itemID))
	itemDlg.url.value = self:WowheadURL("item=" .. itemID)
	itemDlg.url:SetText(itemDlg.url.value)
	itemDlg:Show()
	TH:SkinNow(itemDlg)
	itemDlg.url:SetFocus()
end
