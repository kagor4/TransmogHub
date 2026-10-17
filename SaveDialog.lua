local _, ns = ...
local L = ns.L
local TH = ns.TH

local MAX_TAGS = 5
local dlg

local function EditBox(parent, y, maxLetters)
	local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	eb:SetSize(595, 20)
	eb:SetPoint("TOPLEFT", 24, y)
	eb:SetAutoFocus(false)
	eb:SetMaxLetters(maxLetters)
	eb:SetScript("OnEscapePressed", eb.ClearFocus)
	return eb
end

local function Label(parent, text, x, y, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontNormal")
	fs:SetPoint("TOPLEFT", x, y)
	fs:SetText(text)
	return fs
end

local function SelectedTags()
	return dlg.tags:GetSelectedList()
end

local ShowNoTagsWarning, ShowArmorWarning, ShowNoIconWarning, UseSource

-- Теги брони, которым нет ни одной вещи в образе: { ключ, … }.
-- Тип брони знает игра; плащ, рубашка, гербовая накидка и оружие не в счёт.
local ARMOR_TAGS = { a_cloth = 1, a_leather = 2, a_mail = 3, a_plate = 4 }
local ARMOR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10 }
function TH:CheckArmorTags(tags, items)
	local have, known = {}, false
	for _, slot in ipairs(ARMOR_SLOTS) do
		local it = items and items[slot]
		local det = it and self:GetSourceDetails(it[1])
		if det and det.itemID and not det.hidden and C_Item.GetItemInfoInstant then
			local classID, subclassID = select(6, C_Item.GetItemInfoInstant(det.itemID))
			if classID == 4 and subclassID then -- броня
				have[subclassID], known = true, true
			end
		end
	end
	local wrong = {}
	if not known then return wrong end -- всё скрыто или игра ещё не знает вещи
	for _, tag in ipairs(tags or {}) do
		local sub = ARMOR_TAGS[tag]
		if sub and not have[sub] then wrong[#wrong + 1] = tag end
	end
	return wrong
end

-- withoutTags — игрок подтвердил, что сохраняет образ без тегов;
-- armorChecked — теги брони уже сверены с вещами образа
---------------------------------------------------------------------------
-- Рейдовые теги: хотя бы половина видимых вещей образа должна быть из рейдов
-- этого дополнения. Источник вещи знает игра: в каком подземелье или рейде и
-- какого дополнения она падает (тиры журнала 1–12 = наши 12 рейдовых тегов).
-- Классовые комплекты (из жетонов и Катализатора) засчитываются по дополнению.
---------------------------------------------------------------------------
local RAID_TAG_TIER = { raid_classic = 1, raid_bc = 2, raid_wotlk = 3, raid_cata = 4, raid_mop = 5, raid_wod = 6,
	raid_legion = 7, raid_bfa = 8, raid_sl = 9, raid_df = 10, raid_tww = 11, raid_midnight = 12 }
local SKIP_SLOTS = { [4] = true, [19] = true } -- рубашка и гербовая накидка
local RAID = INSTANCE_TYPE_RAID or 2

function TH:IsRaidSource(sourceID, tier)
	local tierName = EJ_GetTierInfo and EJ_GetTierInfo(tier)
	local drops = C_TransmogCollection.GetAppearanceSourceDrops and C_TransmogCollection.GetAppearanceSourceDrops(sourceID)
	for _, drop in ipairs(drops or {}) do
		if drop.instanceType == RAID then
			for _, t in ipairs(drop.tiers or {}) do
				if t == tierName then return true end
			end
		end
	end
	local det = self:GetSourceDetails(sourceID)
	if det and det.itemID and C_Item.GetItemInfo then
		local expansionID, setID = select(15, C_Item.GetItemInfo(det.itemID))
		if setID and expansionID == tier - 1 then return true end
	end
	return false
end

-- ok, причина (если нельзя), сколько из рейда, сколько видимых
function TH:CheckRaidTag(tag, items)
	local tier = RAID_TAG_TIER[tag]
	if not tier then return true end
	if not items then return false, L["Проверяю вещи образа, подождите секунду."] end
	local have, total = 0, 0
	for slot, it in pairs(items) do
		local det = not SKIP_SLOTS[slot] and it[1] and self:GetSourceDetails(it[1])
		if det and not det.hidden then
			total = total + 1
			if self:IsRaidSource(it[1], tier) then have = have + 1 end
		end
	end
	if total > 0 and have * 2 >= total then return true, nil, have, total end
	return false, string.format(L["Нельзя выбрать: хотя бы половина видимых вещей должна быть из рейдов этого дополнения. Сейчас — %d из %d."],
		have, total), have, total
end

-- Подгрузились данные вещей — перепроверить теги в открытом окне
function TH:RefreshSaveDialogTags()
	if dlg and dlg:IsShown() then dlg.tags:Refresh(true) end
end

-- Иконка по умолчанию: облик вещи на груди (как у образа без своей иконки)
local function DefaultIcon()
	if dlg.items then return TH:GetSetIcon({ items = dlg.items }) end
	return (GetInventoryItemTexture and GetInventoryItemTexture("player", 5)) or 134400
end

local function DoSave(publish, withoutTags, armorChecked, iconChecked)
	local name = strtrim(dlg.name:GetText() or "")
	local desc, tags = strtrim(dlg.desc:GetText() or ""), SelectedTags()
	local err = TH:ValidateSetText(name, desc)
	if err then
		dlg.error:SetText(err)
		dlg.name:SetFocus()
		return
	end
	dlg.error:SetText("")
	if #tags == 0 and not withoutTags then
		ShowNoTagsWarning(publish)
		return
	end
	-- у опубликованного иконку уже не сменить — спросим, если её не выбрали
	if publish and not dlg.iconValue and not iconChecked then
		ShowNoIconWarning(withoutTags)
		return
	end
	dlg.saveBtn:Disable()
	dlg.publishBtn:Disable()

	-- образ из сохранённого комплекта — вещи уже есть, снимать ничего не нужно
	local capture = dlg.fixedItems and function(cb) cb(dlg.fixedItems, "customset") end
		or function(cb) TH:CaptureCurrent(cb) end
	capture(function(items, method)
		dlg.saveBtn:Enable()
		dlg.publishBtn:Enable()
		if not items then
			TH:Print(L["Не удалось запомнить образ. Наденьте хотя бы одну вещь."])
			return
		end
		if method == "equipment" then
			TH:Print(L["Трансмог не считался — сохранён вид надетых вещей без трансмога. Сообщите автору аддона."])
		end
		-- рейдовые теги — по вещам, которые сохраняются прямо сейчас
		for _, tag in ipairs(tags) do
			local ok, why = TH:CheckRaidTag(tag, items)
			if not ok then
				dlg.error:SetText("«" .. (TH.TAG_LABEL[tag] or tag) .. "»: " .. why)
				dlg.items = items
				dlg.tags:Refresh(true)
				return
			end
		end
		local wrong = not armorChecked and TH:CheckArmorTags(tags, items) or {}
		if #wrong > 0 then
			ShowArmorWarning(publish, wrong)
			return
		end

		local set = TH:CreateMySet(name, desc, tags, items, dlg.iconValue)
		dlg:Hide()

		local ui = TH.UI
		if not ui:IsShown() then ui:Toggle() end
		if publish then TH:Publish(set.id) end
		-- новый образ — сразу в своём профиле
		ui:OpenProfile(TH.Net.Me())
		TH:ProfileSelect(ui.profilePanel, set.id)
	end)
end

-- Предупреждение «у образа нет тегов» поверх окна публикации
ShowNoTagsWarning = function(publish)
	local w = dlg.noTags
	if not w then
		w = CreateFrame("Frame", nil, dlg, "BasicFrameTemplateWithInset")
		dlg.noTags = w
		w:SetSize(400, 150)
		w:SetPoint("CENTER")
		w:SetFrameStrata("FULLSCREEN_DIALOG")
		w:SetToplevel(true)
		w:EnableMouse(true)
		local title = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText(L["Образ без тегов"])
		local text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", 16, -36)
		text:SetWidth(368)
		text:SetJustifyH("LEFT")
		text:SetText(L["У образа нет ни одного тега. Его будет труднее найти: игроки часто ищут образы по тегам. Добавить теги потом нельзя."])

		w.choose = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
		TH.PadButton(w.choose)
		w.choose:SetSize(150, 24)
		w.choose:SetPoint("BOTTOMLEFT", 14, 12)
		w.choose:SetText(L["Выбрать теги"])
		w.choose:SetScript("OnClick", function()
			w:Hide()
			dlg.tags.search:SetFocus()
		end)
		w.anyway = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
		TH.PadButton(w.anyway)
		w.anyway:SetSize(190, 24)
		w.anyway:SetPoint("BOTTOMRIGHT", -14, 12)
		w.anyway:SetScript("OnClick", function()
			w:Hide()
			DoSave(w.publish, true)
		end)
	end
	w.publish = publish
	w.anyway:SetText(publish and L["Опубликовать без тегов"] or L["Сохранить без тегов"])
	w:Show()
end

-- Предупреждение «тег брони не совпадает с вещами»
ShowArmorWarning = function(publish, wrong)
	local w = dlg.armorWarn
	if not w then
		w = CreateFrame("Frame", nil, dlg, "BasicFrameTemplateWithInset")
		dlg.armorWarn = w
		w:SetSize(420, 160)
		w:SetPoint("CENTER")
		w:SetFrameStrata("FULLSCREEN_DIALOG")
		w:SetToplevel(true)
		w:EnableMouse(true)
		local title = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText(L["Тег брони не совпадает с вещами"])
		w.text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		w.text:SetPoint("TOPLEFT", 16, -36)
		w.text:SetWidth(388)
		w.text:SetJustifyH("LEFT")
		w.remove = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
		TH.PadButton(w.remove)
		w.remove:SetSize(190, 24)
		w.remove:SetPoint("BOTTOMLEFT", 14, 12)
		w.remove:SetText(L["Убрать тег и продолжить"])
		w.remove:SetScript("OnClick", function()
			w:Hide()
			for _, tag in ipairs(w.wrong) do dlg.tags:Toggle(tag) end
			DoSave(w.publish, true, true, true)
		end)
		if TH.StylePrimaryButton then TH.StylePrimaryButton(w.remove) end
		w.keep = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
		TH.PadButton(w.keep)
		w.keep:SetSize(170, 24)
		w.keep:SetPoint("BOTTOMRIGHT", -14, 12)
		w.keep:SetText(L["Оставить как есть"])
		w.keep:SetScript("OnClick", function()
			w:Hide()
			DoSave(w.publish, true, true, true)
		end)
	end
	local labels = {}
	for _, tag in ipairs(wrong) do labels[#labels + 1] = "«" .. (TH.TAG_LABEL[tag] or tag) .. "»" end
	w.publish, w.wrong = publish, wrong
	w.text:SetText(L["В образе нет вещей с типом брони "] .. table.concat(labels, ", ")
		.. L[". Если тег не подходит, игроки могут его оспорить, и он погаснет. Убрать его сейчас?"])
	w:Show()
end

-- Предупреждение «иконка не выбрана» перед публикацией
ShowNoIconWarning = function(withoutTags)
	local w = dlg.noIcon
	if not w then
		w = CreateFrame("Frame", nil, dlg, "BasicFrameTemplateWithInset")
		dlg.noIcon = w
		w:SetSize(420, 160)
		w:SetPoint("CENTER")
		w:SetFrameStrata("FULLSCREEN_DIALOG")
		w:SetToplevel(true)
		w:EnableMouse(true)
		local title = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		title:SetPoint("TOP", 0, -6)
		title:SetText(L["Иконка не выбрана"])
		w.icon = w:CreateTexture(nil, "ARTWORK")
		w.icon:SetSize(44, 44)
		w.icon:SetPoint("TOPLEFT", 16, -36)
		local text = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:SetPoint("TOPLEFT", w.icon, "TOPRIGHT", 12, 0)
		text:SetWidth(332)
		text:SetJustifyH("LEFT")
		text:SetText(L["У образа будет иконка по умолчанию — облик вещи на груди (слева). После публикации иконку сменить нельзя."])

		w.choose = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
		TH.PadButton(w.choose)
		w.choose:SetSize(160, 24)
		w.choose:SetPoint("BOTTOMLEFT", 14, 12)
		w.choose:SetText(L["Выбрать иконку"])
		w.choose:SetScript("OnClick", function()
			w:Hide()
			dlg.iconBtn:Click()
		end)
		if TH.StylePrimaryButton then TH.StylePrimaryButton(w.choose) end
		w.anyway = CreateFrame("Button", nil, w, "UIPanelButtonTemplate")
		TH.PadButton(w.anyway)
		w.anyway:SetSize(190, 24)
		w.anyway:SetPoint("BOTTOMRIGHT", -14, 12)
		w.anyway:SetText(L["Опубликовать с этой"])
		w.anyway:SetScript("OnClick", function()
			w:Hide()
			DoSave(true, w.withoutTags, false, true)
		end)
	end
	w.withoutTags = withoutTags
	w.icon:SetTexture(DefaultIcon())
	w:Show()
end

local function Build()
	dlg = CreateFrame("Frame", "TransmogHubSaveDialog", UIParent, "BasicFrameTemplateWithInset")
	dlg:SetSize(701, 470)
	dlg:SetPoint("CENTER")
	dlg:SetFrameStrata("DIALOG")
	dlg:SetToplevel(true)
	dlg:SetMovable(true)
	dlg:EnableMouse(true)
	dlg:RegisterForDrag("LeftButton")
	dlg:SetScript("OnDragStart", dlg.StartMoving)
	dlg:SetScript("OnDragStop", dlg.StopMovingOrSizing)
	tinsert(UISpecialFrames, dlg:GetName())

	local title = dlg:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	title:SetPoint("TOP", 0, -6)
	title:SetText(L["Новый образ"])

	Label(dlg, L["1. Название"], 18, -36)
	dlg.name = EditBox(dlg, -54, 48)

	Label(dlg, L["Описание (необязательно)"], 18, -82)
	dlg.desc = EditBox(dlg, -100, 200)

	-- Ошибка фильтра — справа от заголовка «Название»
	dlg.error = dlg:CreateFontString(nil, "OVERLAY", "GameFontRedSmall")
	dlg.error:SetPoint("TOPRIGHT", -84, -38)
	dlg.error:SetWidth(500)
	dlg.error:SetJustifyH("RIGHT")

	-- иконка образа: справа от названия и описания
	local iconBtn = CreateFrame("Button", nil, dlg)
	dlg.iconBtn = iconBtn
	iconBtn:SetSize(52, 52)
	iconBtn:SetPoint("TOPRIGHT", -20, -52)
	iconBtn.tex = iconBtn:CreateTexture(nil, "ARTWORK")
	iconBtn.tex:SetAllPoints()
	iconBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	local iconLabel = dlg:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	iconLabel:SetPoint("BOTTOM", iconBtn, "TOP", 0, 3)
	iconLabel:SetText(L["3. Иконка"])
	iconBtn:SetScript("OnClick", function()
		local tags = SelectedTags()
		TH:OpenIconPicker({
			current = dlg.iconValue,
			tags = tags,
			-- вещи образа уже сняты при открытии окна — рекомендации сразу, без ожидания
			items = dlg.items,
			getItems = not dlg.items and function(cb) TH:CaptureCurrent(function(items) cb(items) end) end or nil,
			recLabel = #tags == 0 and L["Рекомендуемые: вещи образа. Выберите теги — добавятся иконки к ним"] or nil,
			onPick = function(fileID)
				dlg.iconValue = fileID
				dlg:UpdateIcon()
			end,
		})
	end)
	iconBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:SetText(L["Иконка образа"])
		GameTooltip:AddLine(dlg.iconValue and L["Выбрана вами. Нажмите, чтобы сменить."] or
			L["По умолчанию — вещь на груди. Выбирайте после тегов: к ним появятся подходящие иконки."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	iconBtn:SetScript("OnLeave", GameTooltip_Hide)
	function dlg:UpdateIcon()
		-- без выбора показываем, какой будет иконка по умолчанию
		self.iconBtn.tex:SetTexture(self.iconValue or DefaultIcon())
		self.iconBtn.tex:SetDesaturated(self.iconValue == nil)
		self.iconBtn.tex:SetAlpha(self.iconValue and 1 or 0.6)
	end

	dlg.name:SetScript("OnEnterPressed", function() dlg.desc:SetFocus() end)
	dlg.desc:SetScript("OnEnterPressed", function() DoSave(true) end)

	Label(dlg, L["2. Теги (до "] .. MAX_TAGS .. L[") — по ним образ ищут, к ним же подберём иконки"], 18, -130)
	dlg.tags = TH:CreateTagPicker(dlg, { cols = 3, rows = 10, colW = 165, max = MAX_TAGS,
		canSelect = function(key) return TH:CheckRaidTag(key, dlg.items) end })
	dlg.tags:SetPoint("TOPLEFT", 14, -150)

	-- Главное действие — опубликовать; черновик остаётся только у вас
	local publish = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(publish)
	publish:SetSize(150, 24)
	publish:SetPoint("BOTTOMLEFT", 16, 14)
	publish:SetText(L["Опубликовать"])
	if TH.StylePrimaryButton then TH.StylePrimaryButton(publish) end
	publish:SetScript("OnClick", function() DoSave(true) end)
	dlg.publishBtn = publish

	local save = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(save)
	save:SetSize(170, 24)
	save:SetPoint("LEFT", publish, "RIGHT", 8, 0)
	save:SetText(L["Сохранить черновик"])
	save:SetScript("OnClick", function() DoSave(false) end)
	save:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Сохранить только у себя"])
		GameTooltip:AddLine(L["Опубликовать можно позже во вкладке «Мои»."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	save:SetScript("OnLeave", GameTooltip_Hide)
	dlg.saveBtn = save

	local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(cancel)
	cancel:SetSize(80, 24)
	cancel:SetPoint("BOTTOMRIGHT", -16, 14)

	-- откуда образ: надетое сейчас или сохранённый комплект (без переодевания)
	dlg.sourceBtn = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	TH.PadButton(dlg.sourceBtn)
	dlg.sourceBtn:SetSize(230, 24)
	dlg.sourceBtn:SetPoint("RIGHT", cancel, "LEFT", -8, 0)
	dlg.sourceBtn:SetText(L["Образ: надето сейчас"])
	dlg.sourceBtn:SetScript("OnClick", function(btn)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		local choices = TH:GetCustomSetChoices()
		MenuUtil.CreateContextMenu(btn, function(_, root)
			root:CreateTitle(L["Откуда взять образ"])
			root:CreateRadio(L["Надето сейчас"], function() return dlg.fixedItems == nil end, function() UseSource(nil) end)
			if #choices == 0 then
				root:CreateTitle(L["|cff999999Своих комплектов нет|r"])
			else
				root:CreateTitle(L["Свои комплекты"])
				for _, c in ipairs(choices) do
					local r = root:CreateRadio(c.name, function() return dlg.fixedItems == c.items end, function() UseSource(c) end)
					if r and r.SetTooltip then
						r:SetTooltip(function(tip) GameTooltip_SetTitle(tip, c.name); GameTooltip_AddNormalLine(tip, L["Выберите — комплект откроется в примерочной"]) end)
					end
				end
			end
		end)
	end)
	dlg.sourceBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Откуда взять образ"])
		GameTooltip:AddLine(L["То, что надето сейчас, или любой из «Своих комплектов» окна трансмогрификации — переодеваться не нужно."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	dlg.sourceBtn:SetScript("OnLeave", GameTooltip_Hide)
	cancel:SetText(CANCEL)
	cancel:SetScript("OnClick", function() dlg:Hide() end)
end

-- Сохранённые комплекты («Свои комплекты» в окне трансмогрификации): { id, name, icon, items }
function TH:GetCustomSetChoices()
	local out = {}
	local api = C_TransmogCollection
	if not (api and api.GetCustomSets and api.GetCustomSetItemTransmogInfoList) then return out end
	for _, id in ipairs(api.GetCustomSets() or {}) do
		local name, icon = api.GetCustomSetInfo(id)
		local items = self:ItemsFromTransmogInfoList(api.GetCustomSetItemTransmogInfoList(id))
		if items then out[#out + 1] = { id = id, name = name or (L["Комплект "] .. id), icon = icon, items = items } end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

-- Показать выбранный комплект в примерочной игры: видно, что именно уйдёт в публикацию
function TH:PreviewCustomSet(choice)
	local api = C_TransmogCollection
	if choice.id and api and api.GetCustomSetItemTransmogInfoList and type(DressUpItemTransmogInfoList) == "function" then
		local list = api.GetCustomSetItemTransmogInfoList(choice.id)
		if list and pcall(DressUpItemTransmogInfoList, list) then return end
	end
	-- нет примерочной (или это наряд не из комплектов) — на модели окна аддона
	if self.UI and self.UI.model and self.UI:IsShown() then self.UI.model:SetItems(choice.items) end
end

-- Откуда берём вещи: nil — то, что надето сейчас; иначе выбранный комплект
UseSource = function(choice)
	dlg.fixedItems = choice and choice.items or nil
	local short = choice and choice.name or ""
	if #short:gsub("[\128-\191]", "") > 16 then
		local n, cut = 0, #short
		for pos in short:gmatch("()[%z\1-\127\194-\244]") do
			n = n + 1
			if n > 15 then cut = pos - 1 break end
		end
		short = short:sub(1, cut) .. "..."
	end
	dlg.sourceBtn:SetText(choice and ((choice.prefix or L["Из комплекта: "]) .. short) or L["Образ: надето сейчас"])
	if choice then
		dlg.items = choice.items
		if choice.id then TH:PreviewCustomSet(choice) end -- свой комплект: сразу видно, что публикуем
		if strtrim(dlg.name:GetText() or "") == "" then dlg.name:SetText(TH.FormatSetName(choice.name)) end
		dlg.tags:Refresh(true)
		dlg:UpdateIcon()
	else
		dlg.items = nil
		TH:CaptureCurrent(function(items)
			if dlg.fixedItems then return end
			dlg.items = items
			if dlg:IsShown() then dlg.tags:Refresh(true); dlg:UpdateIcon() end
		end)
	end
end

-- preset = { name, items, prefix } — образ не с персонажа, а готовый (наряд у NPC)
function TH:OpenSaveDialog(preset)
	if not dlg then Build() end
	dlg.fixedItems = nil
	if dlg.sourceBtn then dlg.sourceBtn:SetText(L["Образ: надето сейчас"]) end
	dlg.name:SetText("")
	dlg.desc:SetText("")
	dlg.error:SetText("")
	dlg.tags.search:SetText("")
	dlg.tags.theme = "all"
	dlg.tags.sort = "popular" -- каждый раз — сначала популярные
	dlg.tags:SetSelected({})
	if dlg.noTags then dlg.noTags:Hide() end
	if dlg.armorWarn then dlg.armorWarn:Hide() end
	if dlg.noIcon then dlg.noIcon:Hide() end
	dlg.iconValue = nil
	dlg:UpdateIcon()
	TH:ApplyScale()
	dlg:Show()
	dlg.name:SetFocus()
	-- вещи текущего облика — для проверки рейдовых тегов
	dlg.items = nil
	if preset and preset.items then
		UseSource(preset)
		return
	end
	TH:CaptureCurrent(function(items)
		if dlg.fixedItems then return end
		dlg.items = items
		if dlg:IsShown() then
			dlg.tags:Refresh(true)
			dlg:UpdateIcon() -- иконка по умолчанию — по снятому облику
		end
	end)
end

---------------------------------------------------------------------------
-- Наряды Midnight (список слева в окне трансмогрификации у NPC). Их вещи игра
-- отдаёт только для наряда, который сейчас открыт в этом окне, — поэтому кнопка
-- «В Transmog Hub» живёт прямо там и берёт вещи с модели окна.
---------------------------------------------------------------------------
function TH:GetViewedOutfit()
	local frame = _G.TransmogFrame
	local preview = frame and frame.CharacterPreview
	if not (preview and preview.GetItemTransmogInfoList) then return end
	local ok, list = pcall(preview.GetItemTransmogInfoList, preview)
	local items = ok and self:ItemsFromTransmogInfoList(list)
	if not items then return end
	local name
	local api = C_TransmogOutfitInfo
	if api and api.GetCurrentlyViewedOutfitID and api.GetOutfitInfo then
		local okId, id = pcall(api.GetCurrentlyViewedOutfitID)
		local okInfo, info = pcall(api.GetOutfitInfo, okId and id or 0)
		name = okInfo and info and info.name
	end
	return { name = (name and name ~= "") and name or L["Наряд"], items = items, prefix = L["Из наряда: "] }
end

local outfitButton
function TH:AttachOutfitButton()
	local frame = _G.TransmogFrame
	local preview = frame and frame.CharacterPreview
	if outfitButton or not preview then return end
	-- кнопка — на самом окне и выше модели: модель занимает весь центр и иначе перехватывает мышь
	outfitButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	TH.PadButton(outfitButton)
	outfitButton:SetSize(190, 24)
	outfitButton:SetPoint("TOPRIGHT", preview, "TOPRIGHT", -12, -12)
	outfitButton:SetFrameStrata(frame:GetFrameStrata())
	outfitButton:SetFrameLevel((preview:GetFrameLevel() or 1) + 100)
	outfitButton:SetNormalFontObject("GameFontHighlight")
	outfitButton:SetHighlightFontObject("GameFontHighlight")
	outfitButton:SetText(L["В Transmog Hub"])
	if TH.StylePrimaryButton then TH.StylePrimaryButton(outfitButton) end
	outfitButton:SetScript("OnClick", function()
		local outfit = TH:GetViewedOutfit()
		if not outfit then
			TH:Notify(L["Не удалось прочитать вещи наряда. Выберите наряд в списке слева и попробуйте ещё раз."])
			return
		end
		TH:OpenSaveDialog(outfit)
	end)
	outfitButton:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_BOTTOM")
		GameTooltip:SetText(L["Опубликовать в Transmog Hub"])
		GameTooltip:AddLine(L["Откроет окно нового образа с вещами наряда, который сейчас на модели, — переодеваться не нужно."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	outfitButton:SetScript("OnLeave", GameTooltip_Hide)
	frame:HookScript("OnShow", function()
		outfitButton:SetFrameLevel((preview:GetFrameLevel() or 1) + 100)
		outfitButton:Enable()
	end)
	-- пока окно открыто — следим, не легло ли оно на нашу модель (окна двигают мышью)
	local watch = CreateFrame("Frame", nil, frame)
	local elapsed = 0
	watch:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.2 then return end
		elapsed = 0
		TH:UpdateModelOverlap()
	end)
	frame:HookScript("OnHide", function() TH:UpdateModelOverlap() end)
end

-- окно трансмогрификации грузится по требованию: цепляемся, когда оно загружено
local outfitWatcher = CreateFrame("Frame")
outfitWatcher:RegisterEvent("ADDON_LOADED")
outfitWatcher:RegisterEvent("PLAYER_LOGIN")
outfitWatcher:SetScript("OnEvent", function(_, event, name)
	if event == "PLAYER_LOGIN" or name == "Blizzard_Transmog" then pcall(TH.AttachOutfitButton, TH) end
end)
