local _, ns = ...
local TH = ns.TH

local ICON = "Interface\\Icons\\INV_Chest_Cloth_17"
local button

local function UpdatePosition()
	local angle = math.rad(TH.db.minimap.angle)
	local radius = Minimap:GetWidth() / 2 + 10
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function DragUpdate()
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	TH.db.minimap.angle = math.deg(math.atan2(py / scale - my, px / scale - mx))
	UpdatePosition()
end

local function ShowTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Transmog Hub")
	GameTooltip:AddLine("ЛКМ — открыть окно", 1, 1, 1)
	GameTooltip:AddLine("ПКМ — сохранить текущий облик", 1, 1, 1)
	local earned, total, points = TH:GetAchievementTotals()
	GameTooltip:AddLine(string.format("Достижения: %d из %d · очки стиля: %d", earned, total, points), 1, 0.82, 0)
	GameTooltip:AddLine("Перетащите, чтобы сдвинуть", 0.6, 0.6, 0.6)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine(TH:NetworkStatusText(), 1, 1, 1, true)
	GameTooltip:Show()
end

local function Create()
	button = CreateFrame("Button", "TransmogHubMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local bg = button:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(24, 24)
	bg:SetPoint("CENTER", 0, 1)

	local icon = button:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON)
	icon:SetSize(18, 18)
	icon:SetPoint("CENTER", 0, 1)
	icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(50, 50)
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function(_, mouse)
		if mouse == "RightButton" then
			TH:OpenSaveDialog()
		else
			TH:Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self)
		GameTooltip:Hide()
		self:SetScript("OnUpdate", DragUpdate)
	end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", ShowTooltip)
	button:SetScript("OnLeave", GameTooltip_Hide)

	UpdatePosition()
end

function TH:UpdateMinimapButton()
	if self.db.minimap.hide then
		if button then button:Hide() end
		return
	end
	if not button then Create() end
	button:Show()
end

function TH:ToggleMinimapButton()
	self.db.minimap.hide = not self.db.minimap.hide
	self:UpdateMinimapButton()
	self:Print(self.db.minimap.hide and "Кнопка у миникарты скрыта. Вернуть: /thub minimap" or "Кнопка у миникарты показана.")
end
