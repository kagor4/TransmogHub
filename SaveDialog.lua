local _, ns = ...
local TH = ns.TH

local MAX_TAGS = 5
local dlg

local function EditBox(parent, y, maxLetters)
	local eb = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	eb:SetSize(414, 20)
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
	local tags = {}
	for _, cb in ipairs(dlg.checks) do
		if cb:GetChecked() then tags[#tags + 1] = cb.key end
	end
	return tags
end

local function DoSave(publish)
	local name = strtrim(dlg.name:GetText() or "")
	if name == "" then
		TH:Print("Введите название набора.")
		dlg.name:SetFocus()
		return
	end

	local desc, tags = strtrim(dlg.desc:GetText() or ""), SelectedTags()
	dlg.saveBtn:Disable()
	dlg.publishBtn:Disable()

	TH:CaptureCurrent(function(items, method)
		dlg.saveBtn:Enable()
		dlg.publishBtn:Enable()
		if not items then
			TH:Print("Не удалось снять облик. Наденьте хотя бы одну вещь.")
			return
		end
		if method == "equipment" then
			TH:Print("Трансмог не считался — сохранён облик надетых вещей. Сообщите автору аддона.")
		end

		local set = TH:CreateMySet(name, desc, tags, items)
		dlg:Hide()

		local ui = TH.UI
		if not ui:IsShown() then ui:Toggle() end
		ui:SetView("mine")
		ui:Select(set.id)

		if publish then TH:Publish(set.id) end
	end)
end

local function Build()
	dlg = CreateFrame("Frame", "TransmogHubSaveDialog", UIParent, "BasicFrameTemplateWithInset")
	dlg:SetSize(460, 456)
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
	title:SetText("Сохранить текущий облик")

	Label(dlg, "Название", 18, -36)
	dlg.name = EditBox(dlg, -54, 48)

	Label(dlg, "Описание (необязательно)", 18, -82)
	dlg.desc = EditBox(dlg, -100, 200)

	dlg.name:SetScript("OnEnterPressed", function() dlg.desc:SetFocus() end)
	dlg.desc:SetScript("OnEnterPressed", function() DoSave(false) end)

	Label(dlg, "Теги (до " .. MAX_TAGS .. ")", 18, -130)

	dlg.checks = {}
	local y = -150
	for _, group in ipairs(TH.TAG_GROUPS) do
		Label(dlg, group.name, 22, y, "GameFontHighlightSmall")
		y = y - 16
		for i, tag in ipairs(group.tags) do
			local col = (i - 1) % 3
			local rowY = y - math.floor((i - 1) / 3) * 22
			local cb = CreateFrame("CheckButton", nil, dlg, "UICheckButtonTemplate")
			cb:SetSize(22, 22)
			cb:SetPoint("TOPLEFT", 18 + col * 142, rowY)
			cb.key = tag[1]
			local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
			text:SetText(tag[2])
			cb:SetScript("OnClick", function(self)
				if self:GetChecked() and #SelectedTags() > MAX_TAGS then
					self:SetChecked(false)
					TH:Print("Можно выбрать не больше " .. MAX_TAGS .. " тегов.")
				end
			end)
			dlg.checks[#dlg.checks + 1] = cb
		end
		y = y - math.ceil(#group.tags / 3) * 22 - 6
	end

	local save = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	save:SetSize(130, 24)
	save:SetPoint("BOTTOMLEFT", 16, 14)
	save:SetText("Сохранить")
	save:SetScript("OnClick", function() DoSave(false) end)
	dlg.saveBtn = save

	local publish = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	publish:SetSize(200, 24)
	publish:SetPoint("LEFT", save, "RIGHT", 8, 0)
	publish:SetText("Сохранить и опубликовать")
	publish:SetScript("OnClick", function() DoSave(true) end)
	dlg.publishBtn = publish

	local cancel = CreateFrame("Button", nil, dlg, "UIPanelButtonTemplate")
	cancel:SetSize(80, 24)
	cancel:SetPoint("BOTTOMRIGHT", -16, 14)
	cancel:SetText(CANCEL)
	cancel:SetScript("OnClick", function() dlg:Hide() end)
end

function TH:OpenSaveDialog()
	if not dlg then Build() end
	dlg.name:SetText("")
	dlg.desc:SetText("")
	for _, cb in ipairs(dlg.checks) do cb:SetChecked(false) end
	dlg:Show()
	dlg.name:SetFocus()
end
