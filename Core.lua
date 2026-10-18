local ADDON_NAME, ns = ...
local L = ns.L

local TH = CreateFrame("Frame")
ns.TH = TH
TransmogHub = TH

-- WoW Forever (проект CAMELOT, интерфейс 16xxx): своя сеть, имена «Имя Фамилия» без сервера,
-- свои расы, теги и чарт. Определяем по проекту, а на случай переименования константы — по TOC.
do
	local toc = GetBuildInfo and select(4, GetBuildInfo())
	TH.FOREVER = (WOW_PROJECT_CAMELOT ~= nil and WOW_PROJECT_ID == WOW_PROJECT_CAMELOT)
		or (type(toc) == "number" and toc >= 16000 and toc < 20000)
end

-- Тайны Forever (свои условия и тексты, свой ключ) заменяют тайны основной игры
if TH.FOREVER and type(TransmogHub_SecretsForever) == "table" then
	TransmogHub_Secrets = TransmogHub_Secrets or {}
	for id, e in pairs(TransmogHub_SecretsForever) do TransmogHub_Secrets[id] = e end
end

-- Похоже ли на полное имя персонажа: «Имя-Сервер», а в Forever «Имя Фамилия»
function TH:IsCharName(name)
	if type(name) ~= "string" or #name > 64 or name:find(",", 1, true) then return false end
	if self.FOREVER then return name:find("^[^%s%-]+ [^%s%-]+$") ~= nil end
	return name:find("^[^%-]+%-[^%-]+$") ~= nil
end

-- Кнопки с текстом: не меньше заданной ширины, но всегда с отступом 12 по бокам от текста
-- (длинная надпись или другой язык не вылезет за края)
-- Ползунок полосы прокрутки ровно по её ширине (стандартная текстура шире и наезжает)
function TH.SetSliderThumb(slider)
	local w = slider.GetWidth and slider:GetWidth()
	if type(w) ~= "number" or w <= 0 then w = 12 end
	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetColorTexture(0.85, 0.68, 0.25, 0.9)
	thumb:SetSize(w, 26)
	slider:SetThumbTexture(thumb)
	slider.thumb = thumb
end

-- Ширины ползунка и стрелок в целых пикселях экрана: иначе игра округляет доли
-- пикселя по-разному в разных местах окна и ползунок «гуляет» влево-вправо от стрелок.
-- Рисунок стрелки на полпикселя левее середины кнопки, поэтому ползунок нечётной
-- ширины, кнопка чётной, и кнопка стоит так, чтобы середины совпали.
local function SnapScrollBar(bar)
	local factor = PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()
	local scale = bar.GetEffectiveScale and bar:GetEffectiveScale()
	if type(factor) ~= "number" or type(scale) ~= "number" or factor <= 0 or scale <= 0 then return end
	local upp = factor / scale -- единиц интерфейса в одном пикселе
	if bar.thUpp == upp then return end
	bar.thUpp = upp
	local w = math.max(5, math.floor(12 / upp + 0.5))
	if w % 2 == 0 then w = w + 1 end
	local aw = math.max(8, math.floor(18 / upp + 0.5))
	if aw % 2 == 1 then aw = aw + 1 end
	bar:SetWidth(w * upp)
	if bar.thumb then bar.thumb:SetWidth(w * upp) end
	local dx = (w - aw + 1) / 2 * upp
	bar.up:SetWidth(aw * upp)
	bar.up:ClearAllPoints()
	bar.up:SetPoint("BOTTOMLEFT", bar, "TOPLEFT", dx, upp)
	bar.down:SetWidth(aw * upp)
	bar.down:ClearAllPoints()
	bar.down:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", dx, -upp)
end

-- Полоса прокрутки со стрелками: стрелка над полосой и под ней, по центру.
-- Полосу ставят с запасом 18 сверху и снизу — там стрелки. Тянуть ползунок, жать
-- стрелки — onChange(новое смещение); после любой прокрутки — bar:Sync(смещение, максимум).
function TH.CreateScrollBar(parent, onChange)
	local bar = CreateFrame("Slider", nil, parent)
	bar:SetOrientation("VERTICAL")
	bar:SetWidth(12)
	TH.SetSliderThumb(bar)
	local track = bar:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints()
	track:SetColorTexture(0, 0, 0, 0.4)
	bar:SetValueStep(1)
	bar:SetObeyStepOnDrag(true)
	bar.offset, bar.max = 0, 0
	bar:SetScript("OnValueChanged", function(self, value)
		if self.updating then return end
		onChange(math.floor(value + 0.5))
	end)
	bar.up = CreateFrame("Button", nil, parent, "UIPanelScrollUpButtonTemplate")
	bar.up:SetPoint("BOTTOM", bar, "TOP", 0, 1)
	bar.step = 1 -- на сколько сдвигают стрелки (в единицах смещения: строки или пиксели)
	bar.up:SetScript("OnClick", function() onChange(math.max(0, bar.offset - bar.step)) end)
	bar.down = CreateFrame("Button", nil, parent, "UIPanelScrollDownButtonTemplate")
	bar.down:SetPoint("TOP", bar, "BOTTOM", 0, -1)
	bar.down:SetScript("OnClick", function() onChange(math.min(bar.max, bar.offset + bar.step)) end)
	function bar:Sync(offset, maxOffset)
		maxOffset = math.max(0, maxOffset or 0)
		offset = math.min(math.max(offset or 0, 0), maxOffset)
		self.offset, self.max = offset, maxOffset
		self:SetMinMaxValues(0, maxOffset)
		self.updating = true
		self:SetValue(offset)
		self.updating = nil
		local need = maxOffset > 0
		if need then SnapScrollBar(self) end
		self:SetShown(need)
		-- стрелок нет: прокрутка колесом мыши и ползунком (кнопки остаются для оформления)
		self.up:Hide()
		self.down:Hide()
	end
	bar:SetScript("OnShow", SnapScrollBar)
	return bar
end

-- Заметное подтверждение: строка посреди экрана (как сообщения игры) и в чат
-- Благодарность за обращение (жалоба, письмо, предложение): крупно на экране и в чат
TH.THANKS = L["Спасибо, что помогаете нам становиться лучше!"]
function TH:Thanks(detail)
	if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(self.THANKS, 0.4, 1, 0.6, 1) end
	self:Print(self.THANKS .. (detail and (" " .. detail) or ""))
end

function TH:Notify(text)
	if UIErrorsFrame and UIErrorsFrame.AddMessage then UIErrorsFrame:AddMessage(text, 0.4, 1, 0.6, 1) end
	self:Print(text)
end

-- Цвет выделения: золото, а в оформлении EllesmereUI — его акцентный цвет
function TH:SelColor(alpha)
	if self.IsSkinned and self:IsSkinned() then
		local a = self:GetAccent()
		return a[1], a[2], a[3], alpha
	end
	return 1, 0.82, 0, alpha
end

function TH.PadButton(b)
	if not (b and hooksecurefunc) or b.thPadded then return end
	b.thPadded = true
	local function Fit(self)
		local fs = self.GetFontString and self:GetFontString()
		local w = fs and fs.GetStringWidth and fs:GetStringWidth()
		if type(w) ~= "number" or w <= 0 then return end
		self:SetWidth(math.max(self.thMinW or 0, w + 24 + (self.thExtra or 0)))
	end
	hooksecurefunc(b, "SetSize", function(self, w) self.thMinW = w; Fit(self) end)
	hooksecurefunc(b, "SetText", Fit)
	b.thMinW = b:GetWidth()
end

TH.SCHEMA = 1
TH.LOCAL_PREFIX = "local:"
TH.TEST_PREFIX = "test:"

---------------------------------------------------------------------------
-- Теги: фиксированный список, чтобы не плодить «пират/пираты/pirate»
---------------------------------------------------------------------------
-- Ключи тегов уходят в сеть: существующие не переименовывать.
TH.TAG_GROUPS = {
	{ name = L["Классы"], tags = {
		{ "warrior", L["Воитель"] }, { "knight", L["Рыцарь"] }, { "paladin", L["Паладин"] },
		{ "hunter", L["Охотник"] }, { "rogue", L["Разбойник"] }, { "priest", L["Жрец"] },
		{ "deathknight", L["Рыцарь смерти"] }, { "shaman", L["Шаман"] }, { "mage", L["Маг"] },
		{ "warlock", L["Чернокнижник"] }, { "monk", L["Монах"] }, { "druid", L["Друид"] },
		{ "demonhunter", L["Охотник на демонов"] }, { "evoker", L["Пробудитель"] }, { "necro", L["Некромант"] },
	} },
	{ name = L["Образ"], tags = {
		{ "pirate", L["Пират"] }, { "assassin", L["Убийца"] }, { "tribal", L["Племенной"] },
		{ "royal", L["Королевский"] }, { "noble", L["Аристократ"] }, { "commoner", L["Крестьянин"] },
		{ "scholar", L["Учёный"] }, { "adventurer", L["Путешественник"] }, { "gladiator", L["Гладиатор"] },
	} },
	{ name = L["Стиль"], tags = {
		{ "minimal", L["Минимализм"] }, { "classic", L["Классика"] }, { "tier", L["Классовый комплект"] },
		{ "retro", L["Ретро"] }, { "elegant", L["Элегантный"] }, { "casual", L["Повседневный"] },
		{ "battle", L["Боевой"] }, { "heavy", L["Массивный"] }, { "light", L["Лёгкий"] },
		{ "robe", L["Мантия"] }, { "dress", L["Платье"] }, { "cute", L["Милый"] }, { "funny", L["Забавный"] },
		{ "scary", L["Устрашающий"] }, { "mysterious", L["Загадочный"] }, { "rp", L["Для RP"] },
		{ "gothic", L["Готика"] }, { "military", L["Военный"] }, { "wizard", L["Чародейский"] }, { "barbarian", L["Варвар"] },
		{ "victorian", L["Викторианский"] }, { "formal", L["Парадный"] }, { "battleworn", L["Потрёпанный"] },
		{ "ornate", L["Вычурный"] }, { "bridal", L["Свадебный"] }, { "cozy", L["Уютный"] }, { "heroic", L["Героический"] },
		{ "villain", L["Злодейский"] }, { "romantic", L["Романтичный"] }, { "peaceful", L["Мирный"] }, { "hooded", L["С капюшоном"] },
		{ "masked", L["В маске"] }, { "no_helm", L["Без шлема"] }, { "asymmetric", L["Асимметрия"] },
	} },
	{ name = L["Роли и занятия"], tags = {
		{ "tank", L["Танк"] }, { "healer", L["Лекарь"] }, { "mercenary", L["Наёмник"] }, { "bandit", L["Бандит"] },
		{ "guard", L["Стражник"] }, { "inquisitor", L["Инквизитор"] }, { "cultist", L["Культист"] }, { "witch", L["Ведьма"] },
		{ "vampire", L["Вампир"] }, { "bard", L["Бард"] }, { "merchant", L["Торговец"] }, { "farmer", L["Фермер"] },
		{ "innkeeper", L["Трактирщик"] }, { "sailor", L["Моряк"] }, { "ranger", L["Следопыт"] }, { "bounty", L["Охотник за головами"] },
		{ "spy", L["Шпион"] }, { "priestess", L["Жрица"] }, { "archmage", L["Архимаг"] }, { "warlord", L["Полководец"] },
	} },
	{ name = L["Профессии"], tags = {
		{ "p_alchemy", L["Алхимик"] }, { "p_blacksmith", L["Кузнец"] }, { "p_enchant", L["Зачарователь"] },
		{ "p_engineer", L["Инженер"] }, { "p_herbalism", L["Травник"] }, { "p_mining", L["Шахтёр"] }, { "p_skinning", L["Скорняк"] },
		{ "p_tailor", L["Портной"] }, { "p_leather", L["Кожевник"] }, { "p_jewel", L["Ювелир"] }, { "p_inscription", L["Начертатель"] },
		{ "p_cooking", L["Повар"] }, { "p_fishing", L["Рыболов"] }, { "p_archaeology", L["Археолог"] },
	} },
	{ name = L["Мир и фэнтези"], tags = {
		{ "dark", L["Тёмный"] }, { "holy", L["Светлый"] }, { "nature", L["Природа"] },
		{ "elf", L["Эльфийский"] }, { "undead", L["Нежить"] }, { "demon", L["Демонический"] },
		{ "fel", L["Скверна"] }, { "void", L["Бездна"] }, { "dragon", L["Драконий"] },
		{ "cosmic", L["Звёздный"] }, { "elemental", L["Стихии"] }, { "steampunk", L["Стимпанк"] },
		{ "sea", L["Морской"] }, { "oriental", L["Восточный"] }, { "desert", L["Пустынный"] },
		{ "titan", L["Титаны"] },
	} },
	{ name = L["Расы и народы"], tags = {
		{ "r_human", L["Люди"] }, { "r_orc", L["Орки"] }, { "r_dwarf", L["Дворфы"] }, { "r_nightelf", L["Ночные эльфы"] },
		{ "r_bloodelf", L["Эльфы крови"] }, { "r_draenei", L["Дренеи"] }, { "r_tauren", L["Таурены"] }, { "r_troll", L["Тролли"] },
		{ "r_gnome", L["Гномы"] }, { "r_goblin", L["Гоблины"] }, { "r_forsaken", L["Отрёкшиеся"] }, { "r_worgen", L["Воргены"] },
		{ "r_pandaren", L["Пандарены"] }, { "r_vulpera", L["Вульперы"] }, { "r_nightborne", L["Ночнорождённые"] },
		{ "r_voidelf", L["Эльфы Бездны"] }, { "r_lightforged", L["Озарённые дренеи"] }, { "r_highmountain", L["Таурены Крутогорья"] },
		{ "r_darkiron", L["Дворфы Чёрного Железа"] }, { "r_maghar", L["Маг'хары"] }, { "r_kultiran", L["Култирасцы"] },
		{ "r_zandalari", L["Зандалары"] }, { "r_mechagnome", L["Механогномы"] }, { "r_dracthyr", L["Драктиры"] },
		{ "r_earthen", L["Земельники"] }, { "r_haranir", L["Харанир"] }, { "r_naga", L["Наги"] }, { "r_centaur", L["Кентавры"] },
		{ "r_ethereal", L["Эфириалы"] }, { "r_titanforged", L["Титанорождённые"] },
	} },
	{ name = L["Фракции и ордены"], tags = {
		{ "f_argent", L["Серебряный Авангард"] }, { "f_silverhand", L["Серебряная Длань"] }, { "f_kirintor", L["Кирин-Тор"] },
		{ "f_cenarion", L["Круг Кенария"] }, { "f_scarlet", L["Алый орден"] }, { "f_ebonblade", L["Орден Чёрного Клинка"] },
		{ "f_illidari", L["Иллидари"] }, { "f_scourge", L["Плеть"] }, { "f_twilight", L["Сумеречный Молот"] },
		{ "f_sentinels", L["Часовые"] }, { "f_farstriders", L["Следопыты Кель'Таласа"] }, { "f_explorers", L["Лига исследователей"] },
		{ "f_earthenring", L["Служители Земли"] }, { "f_shadopan", L["Шадо-Пан"] }, { "f_kultiras", L["Флот Кул-Тираса"] },
		{ "f_bloodsail", L["Кровавый Парус"] }, { "f_steamwheedle", L["Картель Хитрой Шестерёнки"] },
		{ "f_dragonflights", L["Драконьи стаи"] }, { "f_kyrian", L["Кирии"] }, { "f_venthyr", L["Вентиры"] },
		{ "f_nightfae", L["Ночной народец"] }, { "f_necrolord", L["Некролорды"] }, { "f_oldgods", L["Древние боги"] },
		{ "f_naaru", L["Наару"] }, { "f_burninglegion", L["Пылающий Легион"] }, { "f_shadowlands", L["Тёмные Земли"] },
	} },
	{ name = L["Места"], tags = {
		{ "z_stormwind", L["Штормград"] }, { "z_orgrimmar", L["Оргриммар"] }, { "z_ironforge", L["Стальгорн"] },
		{ "z_darnassus", L["Дарнас"] }, { "z_silvermoon", L["Луносвет"] }, { "z_undercity", L["Подгород"] },
		{ "z_thunderbluff", L["Громовой Утёс"] }, { "z_exodar", L["Экзодар"] }, { "z_gilneas", L["Гилнеас"] },
		{ "z_dalaran", L["Даларан"] }, { "z_suramar", L["Сурамар"] }, { "z_outland", L["Запределье"] }, { "z_northrend", L["Нордскол"] },
		{ "z_pandaria", L["Пандария"] }, { "z_draenor", L["Дренор"] }, { "z_zandalar", L["Зандалар"] },
		{ "z_dragonisles", L["Драконьи острова"] }, { "z_khazalgar", L["Каз Алгар"] }, { "z_quelthalas", L["Кель'Талас"] },
		{ "z_emerald", L["Изумрудный Сон"] }, { "z_karazhan", L["Каражан"] },
	} },
	{ name = L["Праздники и сезоны"], tags = {
		{ "holiday", L["Праздник"] }, { "hallows", L["Тыквовин"] }, { "winterveil", L["Зимний Покров"] },
		{ "lovefest", L["Любовная лихорадка"] }, { "brewfest", L["Хмельной фестиваль"] }, { "winter", L["Зимний"] },
		{ "summer", L["Летний"] }, { "beach", L["Пляжный"] },
		{ "lunar", L["Лунный фестиваль"] }, { "noblegarden", L["Сад чудес"] }, { "midsummer", L["Огненный солнцеворот"] },
		{ "pilgrim", L["Пиршество странников"] }, { "deadday", L["День мёртвых"] }, { "piratesday", L["День пирата"] },
		{ "darkmoon", L["Ярмарка Новолуния"] }, { "spring", L["Весенний"] }, { "autumn", L["Осенний"] },
	} },
	{ name = L["Тип брони"], tags = {
		{ "a_cloth", L["Ткань"] }, { "a_leather", L["Кожа"] }, { "a_mail", L["Кольчуга"] }, { "a_plate", L["Латы"] },
		{ "a_any", L["Любой тип брони"] },
	} },
	{ name = L["Оружие"], tags = {
		{ "w_sword", L["Меч"] }, { "w_axe", L["Топор"] }, { "w_mace", L["Булава"] }, { "w_staff", L["Посох"] },
		{ "w_polearm", L["Древковое"] }, { "w_bow", L["Лук"] }, { "w_gun", L["Огнестрельное"] }, { "w_dagger", L["Кинжал"] },
		{ "w_glaive", L["Боевые клинки"] }, { "w_fist", L["Кистевое"] }, { "w_wand", L["Жезл"] }, { "w_shield", L["Щит"] },
		{ "w_offhand", L["В левой руке"] }, { "w_dual", L["Два оружия"] }, { "w_twohand", L["Двуручное"] },
		{ "w_none", L["Без оружия"] },
	} },
	{ name = L["Детали"], tags = {
		{ "d_wings", L["Крылья"] }, { "d_cloak", L["Плащ"] }, { "d_tabard", L["Гербовая накидка"] }, { "d_fur", L["Мех"] },
		{ "d_feathers", L["Перья"] }, { "d_bones", L["Кости"] }, { "d_skulls", L["Черепа"] }, { "d_spikes", L["Шипы"] },
		{ "d_chains", L["Цепи"] }, { "d_crystals", L["Кристаллы"] }, { "d_runes", L["Руны"] }, { "d_glow", L["Свечение"] },
		{ "d_flowers", L["Цветы"] }, { "d_leaves", L["Листья"] }, { "d_horns", L["Рога"] }, { "d_belts", L["Ремни"] },
	} },
	{ name = L["Рейды"], tags = {
		{ "raid_classic", L["Рейд: Classic"] }, { "raid_bc", L["Рейд: Burning Crusade"] }, { "raid_wotlk", L["Рейд: Wrath of the Lich King"] },
		{ "raid_cata", L["Рейд: Cataclysm"] }, { "raid_mop", L["Рейд: Mists of Pandaria"] }, { "raid_wod", L["Рейд: Warlords of Draenor"] },
		{ "raid_legion", L["Рейд: Legion"] }, { "raid_bfa", L["Рейд: Battle for Azeroth"] }, { "raid_sl", L["Рейд: Shadowlands"] },
		{ "raid_df", L["Рейд: Dragonflight"] }, { "raid_tww", L["Рейд: The War Within"] }, { "raid_midnight", L["Рейд: Midnight"] },
	} },
	{ name = "PvP", tags = {
		{ "pvp", "PvP" }, { "arena", L["Арена"] }, { "battleground", L["Поле боя"] }, { "elite", L["Элитный PvP"] },
		{ "alliance", L["Альянс"] }, { "horde", L["Орда"] },
	} },
	{ name = L["Цвет"], tags = {
		{ "c_black", L["Чёрный"] }, { "c_white", L["Белый"] }, { "c_red", L["Красный"] },
		{ "c_blue", L["Синий"] }, { "c_green", L["Зелёный"] }, { "c_purple", L["Фиолетовый"] },
		{ "c_gold", L["Золотой"] }, { "c_brown", L["Коричневый"] }, { "c_pink", L["Розовый"] },
		{ "c_orange", L["Оранжевый"] }, { "c_yellow", L["Жёлтый"] }, { "c_gray", L["Серый"] },
		{ "c_teal", L["Бирюзовый"] }, { "c_silver", L["Серебряный"] }, { "c_multi", L["Разноцветный"] },
		{ "c_navy", L["Тёмно-синий"] }, { "c_cyan", L["Голубой"] }, { "c_lime", L["Салатовый"] }, { "c_olive", L["Оливковый"] },
		{ "c_emerald", L["Изумрудный"] }, { "c_lavender", L["Лавандовый"] }, { "c_magenta", L["Пурпурный"] },
		{ "c_burgundy", L["Бордовый"] }, { "c_beige", L["Бежевый"] }, { "c_bronze", L["Бронзовый"] }, { "c_copper", L["Медный"] },
		{ "c_peach", L["Персиковый"] }, { "c_mint", L["Мятный"] }, { "c_khaki", L["Хаки"] }, { "c_mono", L["Монохром"] },
		{ "c_pastel", L["Пастельный"] }, { "c_neon", L["Кислотный"] }, { "c_duo", L["Двухцветный"] },
	} },
}

-- Цвета цветовых тегов (обводка квадратика в окне тегов)
TH.TAG_COLORS = {
	c_black = { 0.08, 0.08, 0.08 }, c_white = { 0.95, 0.95, 0.95 }, c_red = { 0.85, 0.12, 0.12 },
	c_blue = { 0.15, 0.4, 0.95 }, c_green = { 0.15, 0.75, 0.25 }, c_purple = { 0.6, 0.25, 0.85 },
	c_gold = { 1, 0.78, 0.15 }, c_brown = { 0.5, 0.32, 0.15 }, c_pink = { 1, 0.45, 0.75 },
	c_orange = { 1, 0.5, 0.1 }, c_yellow = { 1, 0.95, 0.2 }, c_gray = { 0.5, 0.5, 0.5 },
	c_teal = { 0.1, 0.75, 0.7 }, c_silver = { 0.78, 0.8, 0.85 }, c_multi = { 0.95, 0.3, 0.9 },
	c_navy = { 0.1, 0.15, 0.45 },
	c_cyan = { 0.45, 0.8, 1 },
	c_lime = { 0.6, 0.95, 0.25 },
	c_olive = { 0.45, 0.5, 0.15 },
	c_emerald = { 0.05, 0.6, 0.35 },
	c_lavender = { 0.75, 0.65, 0.95 },
	c_magenta = { 0.8, 0.1, 0.6 },
	c_burgundy = { 0.5, 0.05, 0.15 },
	c_beige = { 0.85, 0.75, 0.6 },
	c_bronze = { 0.7, 0.45, 0.2 },
	c_copper = { 0.75, 0.4, 0.25 },
	c_peach = { 1, 0.7, 0.55 },
	c_mint = { 0.6, 0.95, 0.8 },
	c_khaki = { 0.65, 0.6, 0.4 },
	c_mono = { 0.6, 0.6, 0.6 },
	c_pastel = { 1, 0.8, 0.9 },
	c_neon = { 0.5, 1, 0.1 },
	c_duo = { 0.9, 0.6, 0.2 },
}

-- Темы в окне тегов. Один тег может быть в нескольких темах.
TH.TAG_THEMES = {
	-- первая тема — классы (по ней считается достижение «классы»)
	{ name = L["Классы"], tags = { "warrior", "paladin", "hunter", "rogue", "priest", "deathknight", "shaman",
		"mage", "warlock", "monk", "druid", "demonhunter", "evoker", "tier" } },
	{ name = L["Образы и роли"], tags = { "pirate", "knight", "warrior", "assassin", "necro", "tribal", "royal", "noble",
		"commoner", "scholar", "adventurer", "gladiator", "tank", "healer", "mercenary", "bandit", "guard", "inquisitor",
		"cultist", "witch", "vampire", "bard", "merchant", "farmer", "innkeeper", "sailor", "ranger", "bounty", "spy",
		"priestess", "archmage", "warlord", "barbarian", "wizard" } },
	{ name = L["Стиль"], tags = { "minimal", "classic", "tier", "retro", "elegant", "casual", "battle", "heavy",
		"light", "robe", "dress", "cute", "funny", "scary", "mysterious", "gothic", "military", "victorian", "formal",
		"battleworn", "ornate", "bridal", "cozy", "heroic", "villain", "romantic", "peaceful", "hooded", "masked",
		"no_helm", "asymmetric" } },
	{ name = L["Магия и силы"], tags = { "holy", "dark", "fel", "void", "nature", "elemental", "cosmic", "necro",
		"mage", "warlock", "shaman", "druid", "evoker", "archmage", "wizard", "d_runes", "d_glow", "d_crystals" } },
	{ name = L["Расы и народы"], tags = { "elf", "undead", "demon", "dragon", "titan", "r_human", "r_orc", "r_dwarf",
		"r_nightelf", "r_bloodelf", "r_draenei", "r_tauren", "r_troll", "r_gnome", "r_goblin", "r_forsaken", "r_worgen",
		"r_pandaren", "r_vulpera", "r_nightborne", "r_voidelf", "r_lightforged", "r_highmountain", "r_darkiron", "r_maghar",
		"r_kultiran", "r_zandalari", "r_mechagnome", "r_dracthyr", "r_earthen", "r_haranir", "r_naga", "r_centaur",
		"r_ethereal", "r_titanforged" } },
	{ name = L["Фракции и лор"], tags = { "f_argent", "f_silverhand", "f_kirintor", "f_cenarion", "f_scarlet", "f_ebonblade",
		"f_illidari", "f_scourge", "f_twilight", "f_sentinels", "f_farstriders", "f_explorers", "f_earthenring", "f_shadopan",
		"f_kultiras", "f_bloodsail", "f_steamwheedle", "f_dragonflights", "f_kyrian", "f_venthyr", "f_nightfae",
		"f_necrolord", "f_oldgods", "f_naaru", "f_burninglegion", "f_shadowlands", "alliance", "horde" } },
	{ name = L["Места"], tags = { "z_stormwind", "z_orgrimmar", "z_ironforge", "z_darnassus", "z_silvermoon", "z_undercity",
		"z_thunderbluff", "z_exodar", "z_gilneas", "z_dalaran", "z_suramar", "z_outland", "z_northrend", "z_pandaria",
		"z_draenor", "z_zandalar", "z_dragonisles", "z_khazalgar", "z_quelthalas", "z_emerald", "z_karazhan",
		"steampunk", "oriental", "desert", "sea" } },
	{ name = L["Тёмное и жуткое"], tags = { "dark", "undead", "scary", "demon", "void", "fel", "necro",
		"assassin", "deathknight", "warlock", "hallows", "gothic", "villain", "cultist", "vampire", "witch",
		"d_bones", "d_skulls", "d_spikes", "d_chains", "f_scourge", "f_oldgods" } },
	{ name = L["Рейды"], tags = { "raid_classic", "raid_bc", "raid_wotlk", "raid_cata", "raid_mop", "raid_wod",
		"raid_legion", "raid_bfa", "raid_sl", "raid_df", "raid_tww", "raid_midnight", "tier" } },
	{ name = "PvP", tags = { "pvp", "arena", "battleground", "elite", "gladiator", "alliance", "horde" } },
	{ name = L["Праздники и сезоны"], tags = { "holiday", "hallows", "winterveil", "lovefest", "brewfest", "lunar",
		"noblegarden", "midsummer", "pilgrim", "deadday", "piratesday", "darkmoon", "winter", "summer", "spring",
		"autumn", "beach", "sea", "casual" } },
	{ name = L["Броня и оружие"], tags = { "a_cloth", "a_leather", "a_mail", "a_plate", "a_any", "robe", "dress", "heavy",
		"light", "w_sword", "w_axe", "w_mace", "w_staff", "w_polearm", "w_bow", "w_gun", "w_dagger", "w_glaive",
		"w_fist", "w_wand", "w_shield", "w_offhand", "w_dual", "w_twohand", "w_none" } },
	{ name = L["Детали"], tags = { "d_wings", "d_cloak", "d_tabard", "d_fur", "d_feathers", "d_bones", "d_skulls",
		"d_spikes", "d_chains", "d_crystals", "d_runes", "d_glow", "d_flowers", "d_leaves", "d_horns", "d_belts",
		"hooded", "masked", "no_helm" } },
	{ name = L["Профессии"], tags = { "p_alchemy", "p_blacksmith", "p_enchant", "p_engineer", "p_herbalism", "p_mining",
		"p_skinning", "p_tailor", "p_leather", "p_jewel", "p_inscription", "p_cooking", "p_fishing", "p_archaeology",
		"merchant", "farmer", "innkeeper", "scholar" } },
	{ name = L["Цвета"], tags = { "c_black", "c_white", "c_red", "c_blue", "c_green", "c_purple", "c_gold",
		"c_brown", "c_pink", "c_orange", "c_yellow", "c_gray", "c_teal", "c_silver", "c_multi", "c_navy", "c_cyan",
		"c_lime", "c_olive", "c_emerald", "c_lavender", "c_magenta", "c_burgundy", "c_beige", "c_bronze", "c_copper",
		"c_peach", "c_mint", "c_khaki", "c_mono", "c_pastel", "c_neon", "c_duo" } },
	{ name = L["Для RP"], tags = { "rp", "commoner", "noble", "royal", "scholar", "adventurer", "casual",
		"elegant", "dress", "pirate", "mysterious", "funny", "bard", "innkeeper", "merchant", "farmer", "guard",
		"sailor", "priestess", "cozy", "romantic" } },
}

-- Дата добавления тегов, добавленных после выхода аддона: [ключ] = "ГГГГ-ММ-ДД".
-- По ней сортировка «Новые теги» и возраст тега при чистке неиспользуемых.
TH.TAG_ADDED = {
	raid_classic = "2026-10-16", raid_bc = "2026-10-16", raid_wotlk = "2026-10-16", raid_cata = "2026-10-16",
	raid_mop = "2026-10-16", raid_wod = "2026-10-16", raid_legion = "2026-10-16", raid_bfa = "2026-10-16",
	raid_sl = "2026-10-16", raid_df = "2026-10-16", raid_tww = "2026-10-16", raid_midnight = "2026-10-16",
	pvp = "2026-10-16", arena = "2026-10-16", battleground = "2026-10-16", elite = "2026-10-16",
	alliance = "2026-10-16", horde = "2026-10-16", dress = "2026-10-17", a_any = "2026-10-17",
	-- большое пополнение тегов (неиспользуемые потом уберём)
	gothic = "2026-10-17", military = "2026-10-17", wizard = "2026-10-17", barbarian = "2026-10-17",
	victorian = "2026-10-17", formal = "2026-10-17", battleworn = "2026-10-17", ornate = "2026-10-17",
	bridal = "2026-10-17", cozy = "2026-10-17", heroic = "2026-10-17", villain = "2026-10-17", romantic = "2026-10-17",
	peaceful = "2026-10-17", hooded = "2026-10-17", masked = "2026-10-17", no_helm = "2026-10-17",
	asymmetric = "2026-10-17", tank = "2026-10-17", healer = "2026-10-17", mercenary = "2026-10-17",
	bandit = "2026-10-17", guard = "2026-10-17", inquisitor = "2026-10-17", cultist = "2026-10-17", witch = "2026-10-17",
	vampire = "2026-10-17", bard = "2026-10-17", merchant = "2026-10-17", farmer = "2026-10-17", innkeeper = "2026-10-17",
	sailor = "2026-10-17", ranger = "2026-10-17", bounty = "2026-10-17", spy = "2026-10-17", priestess = "2026-10-17",
	archmage = "2026-10-17", warlord = "2026-10-17", p_alchemy = "2026-10-17", p_blacksmith = "2026-10-17",
	p_enchant = "2026-10-17", p_engineer = "2026-10-17", p_herbalism = "2026-10-17", p_mining = "2026-10-17",
	p_skinning = "2026-10-17", p_tailor = "2026-10-17", p_leather = "2026-10-17", p_jewel = "2026-10-17",
	p_inscription = "2026-10-17", p_cooking = "2026-10-17", p_fishing = "2026-10-17", p_archaeology = "2026-10-17",
	r_human = "2026-10-17", r_orc = "2026-10-17", r_dwarf = "2026-10-17", r_nightelf = "2026-10-17",
	r_bloodelf = "2026-10-17", r_draenei = "2026-10-17", r_tauren = "2026-10-17", r_troll = "2026-10-17",
	r_gnome = "2026-10-17", r_goblin = "2026-10-17", r_forsaken = "2026-10-17", r_worgen = "2026-10-17",
	r_pandaren = "2026-10-17", r_vulpera = "2026-10-17", r_nightborne = "2026-10-17", r_voidelf = "2026-10-17",
	r_lightforged = "2026-10-17", r_highmountain = "2026-10-17", r_darkiron = "2026-10-17", r_maghar = "2026-10-17",
	r_kultiran = "2026-10-17", r_zandalari = "2026-10-17", r_mechagnome = "2026-10-17", r_dracthyr = "2026-10-17",
	r_earthen = "2026-10-17", r_haranir = "2026-10-17", r_naga = "2026-10-17", r_centaur = "2026-10-17",
	r_ethereal = "2026-10-17", r_titanforged = "2026-10-17", f_argent = "2026-10-17", f_silverhand = "2026-10-17",
	f_kirintor = "2026-10-17", f_cenarion = "2026-10-17", f_scarlet = "2026-10-17", f_ebonblade = "2026-10-17",
	f_illidari = "2026-10-17", f_scourge = "2026-10-17", f_twilight = "2026-10-17", f_sentinels = "2026-10-17",
	f_farstriders = "2026-10-17", f_explorers = "2026-10-17", f_earthenring = "2026-10-17", f_shadopan = "2026-10-17",
	f_kultiras = "2026-10-17", f_bloodsail = "2026-10-17", f_steamwheedle = "2026-10-17", f_dragonflights = "2026-10-17",
	f_kyrian = "2026-10-17", f_venthyr = "2026-10-17", f_nightfae = "2026-10-17", f_necrolord = "2026-10-17",
	f_oldgods = "2026-10-17", f_naaru = "2026-10-17", f_burninglegion = "2026-10-17", f_shadowlands = "2026-10-17",
	z_stormwind = "2026-10-17", z_orgrimmar = "2026-10-17", z_ironforge = "2026-10-17", z_darnassus = "2026-10-17",
	z_silvermoon = "2026-10-17", z_undercity = "2026-10-17", z_thunderbluff = "2026-10-17", z_exodar = "2026-10-17",
	z_gilneas = "2026-10-17", z_dalaran = "2026-10-17", z_suramar = "2026-10-17", z_outland = "2026-10-17",
	z_northrend = "2026-10-17", z_pandaria = "2026-10-17", z_draenor = "2026-10-17", z_zandalar = "2026-10-17",
	z_dragonisles = "2026-10-17", z_khazalgar = "2026-10-17", z_quelthalas = "2026-10-17", z_emerald = "2026-10-17",
	z_karazhan = "2026-10-17", w_sword = "2026-10-17", w_axe = "2026-10-17", w_mace = "2026-10-17",
	w_staff = "2026-10-17", w_polearm = "2026-10-17", w_bow = "2026-10-17", w_gun = "2026-10-17", w_dagger = "2026-10-17",
	w_glaive = "2026-10-17", w_fist = "2026-10-17", w_wand = "2026-10-17", w_shield = "2026-10-17",
	w_offhand = "2026-10-17", w_dual = "2026-10-17", w_twohand = "2026-10-17", w_none = "2026-10-17",
	d_wings = "2026-10-17", d_cloak = "2026-10-17", d_tabard = "2026-10-17", d_fur = "2026-10-17",
	d_feathers = "2026-10-17", d_bones = "2026-10-17", d_skulls = "2026-10-17", d_spikes = "2026-10-17",
	d_chains = "2026-10-17", d_crystals = "2026-10-17", d_runes = "2026-10-17", d_glow = "2026-10-17",
	d_flowers = "2026-10-17", d_leaves = "2026-10-17", d_horns = "2026-10-17", d_belts = "2026-10-17",
	lunar = "2026-10-17", noblegarden = "2026-10-17", midsummer = "2026-10-17", pilgrim = "2026-10-17",
	deadday = "2026-10-17", piratesday = "2026-10-17", darkmoon = "2026-10-17", spring = "2026-10-17",
	autumn = "2026-10-17", c_navy = "2026-10-17", c_cyan = "2026-10-17", c_lime = "2026-10-17", c_olive = "2026-10-17",
	c_emerald = "2026-10-17", c_lavender = "2026-10-17", c_magenta = "2026-10-17", c_burgundy = "2026-10-17",
	c_beige = "2026-10-17", c_bronze = "2026-10-17", c_copper = "2026-10-17", c_peach = "2026-10-17",
	c_mint = "2026-10-17", c_khaki = "2026-10-17", c_mono = "2026-10-17", c_pastel = "2026-10-17", c_neon = "2026-10-17",
	c_duo = "2026-10-17",
}

-- Теги рейдов: для достижений «Слава герою подиума» и «На кромке лезвия»
TH.RAID_TAGS = {}
for _, key in ipairs({ "raid_classic", "raid_bc", "raid_wotlk", "raid_cata", "raid_mop", "raid_wod", "raid_legion",
	"raid_bfa", "raid_sl", "raid_df", "raid_tww", "raid_midnight" }) do TH.RAID_TAGS[key] = true end

-- Убранные теги (ими почти не пользовались): выбрать нельзя, но у старых
-- образов подпись остаётся. Ключ сюда, из TAG_GROUPS — убрать.
TH.TAG_RETIRED = {
}

-- WoW Forever: теги того, что есть в игре. Ключи основной игры не трогаем: лишние скрыты,
-- новые — со своими ключами (сети раздельные, в основной игре этих тегов нет).
if TH.FOREVER then
	local HIDE = {}
	for _, key in ipairs({
		-- классы и оружие, которых нет
		"deathknight", "monk", "demonhunter", "evoker", "w_glaive",
		-- профессии, появившиеся позже
		"p_jewel", "p_inscription", "p_archaeology",
		-- расы и народы из дополнений
		"r_bloodelf", "r_draenei", "r_pandaren", "r_vulpera", "r_nightborne", "r_voidelf", "r_lightforged",
		"r_highmountain", "r_maghar", "r_kultiran", "r_mechagnome", "r_dracthyr", "r_earthen", "r_haranir",
		"r_ethereal", "r_titanforged",
		-- фракции и места из дополнений
		"f_argent", "f_ebonblade", "f_illidari", "f_earthenring", "f_shadopan", "f_kultiras", "f_kyrian", "f_venthyr",
		"f_nightfae", "f_necrolord", "f_naaru", "f_shadowlands",
		"z_silvermoon", "z_exodar", "z_suramar", "z_outland", "z_northrend", "z_pandaria", "z_draenor", "z_zandalar",
		"z_dragonisles", "z_khazalgar", "z_gilneas",
		-- праздники из дополнений, арены, рейды основной игры
		"brewfest", "pilgrim", "deadday", "piratesday", "arena",
		"raid_classic", "raid_bc", "raid_wotlk", "raid_cata", "raid_mop", "raid_wod", "raid_legion", "raid_bfa",
		"raid_sl", "raid_df", "raid_tww", "raid_midnight",
	}) do HIDE[key] = true end

	local RAIDS = { { "raid_onyxia", L["Рейд: Логово Ониксии"] }, { "raid_hyjal", L["Рейд: Вершина Хиджала"] },
		{ "raid_barrow", L["Рейд: Barrow Deeps"] } }
	local NEW_DUNGEONS = {
		{ "dg_thanes", L["Чертог танов"] }, { "dg_lordaeron", L["Руины Лордерона"] }, { "dg_excavation", L["Место раскопок"] },
		{ "dg_dalaran", L["Город Даларан"] }, { "dg_drowned", L["Затонувший город"] }, { "dg_kroldok", L["Крепость Крол'док"] },
		{ "dg_alcaz", L["Тюрьма острова Алькац"] }, { "dg_blackmaw", L["Логово Черной Пасти"] },
		{ "dg_shapers", L["Терраса Творцов"] },
	}
	local DUNGEONS = {
		{ "dg_ragefire", L["Огненная Пропасть"] }, { "dg_deadmines", L["Мертвые копи"] }, { "dg_wailing", L["Пещеры Стенаний"] },
		{ "dg_shadowfang", L["Крепость Темного Клыка"] }, { "dg_bfd", L["Непроглядная Пучина"] },
		{ "dg_stockade", L["Тюрьма Штормграда"] }, { "dg_gnomeregan", L["Гномреган"] },
		{ "dg_kraul", L["Лабиринты Иглошкурых"] }, { "dg_scarlet", L["Монастырь Алого ордена"] },
		{ "dg_uldaman", L["Ульдаман"] }, { "dg_downs", L["Курганы Иглошкурых"] }, { "dg_zulfarrak", L["Зул'Фаррак"] },
		{ "dg_maraudon", L["Мародон"] }, { "dg_sunken", L["Храм Атал'Хаккара"] }, { "dg_brd", L["Глубины Черной горы"] },
		{ "dg_blackrock", L["Пик Черной горы"] }, { "dg_diremaul", L["Забытый город"] },
		{ "dg_strat", L["Стратхольм"] }, { "dg_scholo", L["Некроситет"] },
	}
	local EXTRA = { -- [группа] = новые теги в конец
		[L["Расы и народы"]] = { { "r_skyborne", L["Небеснорождённые"] } },
		[L["Фракции и ордены"]] = { { "f_argentdawn", L["Серебряный Рассвет"] } },
		[L["Места"]] = { { "z_zephras", L["Остров Зефрас"] }, { "z_riverglades", L["Лесоречье"] } },
	}
	local function Keys(list) local out = {} for _, t in ipairs(list) do out[#out + 1] = t[1] end return out end

	for _, group in ipairs(TH.TAG_GROUPS) do
		local kept = {}
		for _, tag in ipairs(group.tags) do if not HIDE[tag[1]] then kept[#kept + 1] = tag end end
		for _, tag in ipairs(EXTRA[group.name] or {}) do kept[#kept + 1] = tag end
		if group.name == L["Рейды"] then kept = RAIDS end
		group.tags = kept
	end
	for i, group in ipairs(TH.TAG_GROUPS) do
		if group.name == L["Рейды"] then
			table.insert(TH.TAG_GROUPS, i + 1, { name = L["Подземелья Forever"], tags = NEW_DUNGEONS })
			table.insert(TH.TAG_GROUPS, i + 2, { name = L["Подземелья"], tags = DUNGEONS })
			break
		end
	end

	local themeExtra = {
		[L["Расы и народы"]] = { "r_skyborne" }, [L["Фракции и лор"]] = { "f_argentdawn" },
		[L["Места"]] = { "z_zephras", "z_riverglades" },
	}
	for i, theme in ipairs(TH.TAG_THEMES) do
		local kept = {}
		for _, key in ipairs(theme.tags) do if not HIDE[key] then kept[#kept + 1] = key end end
		for _, key in ipairs(themeExtra[theme.name] or {}) do kept[#kept + 1] = key end
		if theme.name == L["Рейды"] then
			kept = Keys(RAIDS)
			kept[#kept + 1] = "tier"
			local dungeons = Keys(NEW_DUNGEONS)
			for _, key in ipairs(Keys(DUNGEONS)) do dungeons[#dungeons + 1] = key end
			table.insert(TH.TAG_THEMES, i + 1, { name = L["Подземелья"], tags = dungeons })
		end
		theme.tags = kept
	end

	TH.RAID_TAGS = {}
	for _, tag in ipairs(RAIDS) do TH.RAID_TAGS[tag[1]] = true end
	for _, list in ipairs({ RAIDS, NEW_DUNGEONS, DUNGEONS, { { "r_skyborne" }, { "f_argentdawn" }, { "z_zephras" }, { "z_riverglades" } } }) do
		for _, tag in ipairs(list) do TH.TAG_ADDED[tag[1]] = TH.TAG_ADDED[tag[1]] or "2026-10-17" end
	end
end

-- Короткие подписи для сетки тегов (полное название — в подсказке и карточке)
TH.TAG_SHORT = { raid_wotlk = L["Рейд: WotLK"], raid_wod = L["Рейд: WoD"], raid_bfa = L["Рейд: BfA"] }

TH.TAG_LABEL = {}
TH.TAG_GROUP = {}
TH.TAG_ORDER = {}
for key, label in pairs(TH.TAG_RETIRED) do TH.TAG_LABEL[key] = label end
for _, group in ipairs(TH.TAG_GROUPS) do
	for _, tag in ipairs(group.tags) do
		TH.TAG_LABEL[tag[1]] = tag[2]
		TH.TAG_GROUP[tag[1]] = group.name
		TH.TAG_ORDER[#TH.TAG_ORDER + 1] = tag[1]
	end
end

-- Сколько образов в ленте с каждым тегом (since — только образы новее этого времени)
-- Оспоренные теги. Тег у образа гаснет, если его отметили «не подходит»
-- 3+ игрока и это не меньше трети оценивших образ, или если автор убрал его сам.
-- Погасший тег не ищется, не участвует в списках тегов и не даёт достижений.
TH.TAG_DISPUTE_MIN = 3

function TH:GetTagFlags(set)
	local id = set and (set.serverId or set.id)
	return id and self.db.net.tagFlags[id], id
end

-- [тег] = число отметок (у погасших); пустая таблица — спорных нет
function TH:GetDisputedTags(set)
	local out = {}
	local flags, id = self:GetTagFlags(set)
	if not flags then return out end
	local raters = 0
	for _ in pairs(self.db.net.votes[id] or {}) do raters = raters + 1 end
	local author = set.author
	for tag, list in pairs(flags) do
		local n, byAuthor = 0, false
		for name, f in pairs(list) do
			if f[1] == 1 then
				if name == author then byAuthor = true else n = n + 1 end
			end
		end
		if byAuthor or (n >= self.TAG_DISPUTE_MIN and n * 3 >= raters) then out[tag] = n end
	end
	return out
end

-- Теги образа без погасших
function TH:GetActiveTags(set)
	local tags = set and set.tags or {}
	local disputed = self:GetDisputedTags(set)
	if not next(disputed) then return tags end
	local out = {}
	for _, tag in ipairs(tags) do
		if not disputed[tag] then out[#out + 1] = tag end
	end
	return out
end

-- Своя отметка «не подходит» у тега
function TH:IsTagFlaggedByMe(set, tag)
	local flags = self:GetTagFlags(set)
	local f = flags and flags[tag] and flags[tag][self.Net.Me()]
	return f ~= nil and f[1] == 1
end

function TH:ToggleTagFlag(set, tag)
	if self:IsExiled() then return self:ExileNotice() end
	local id = set.serverId or set.id
	if self:IsTestId(id) or self:IsLocalId(id) then return end
	local on = self:IsTagFlaggedByMe(set, tag) and 0 or 1
	self.Net:SendTagFlag(id, tag, on)
	self:LoadFeed()
	self:NotifyChanged()
	local label = self.TAG_LABEL[tag] or tag
	if on == 1 then
		if self:IsMine(set) then
			self:Notify(L["Тег «"] .. label .. L["» убран из вашего образа."])
		else
			self:Thanks(L["Отметка принята: тег «"] .. label .. L["» не подходит. Если так отметят и другие, он погаснет у этого образа."])
		end
	else
		self:Notify(L["Отметка снята: тег «"] .. label .. L["» снова считается подходящим."])
	end
end

function TH:GetTagCounts(since)
	local counts = {}
	for _, set in ipairs(self.feed and self.feed.sets or {}) do
		if not since or (set.created or 0) >= since then
			for _, key in ipairs(self:GetActiveTags(set)) do counts[key] = (counts[key] or 0) + 1 end
		end
	end
	return counts
end

TH.TAG_SORTS = {
	{ key = "popular", text = L["Популярные"] },
	{ key = "trending", text = L["В тренде"], hint = L["Чаще всего в образах за последние 14 дней"] },
	{ key = "rare", text = L["Редкие"] },
	{ key = "new", text = L["Новые теги"], hint = L["Недавно добавленные в аддон"] },
	{ key = "alpha", text = L["По алфавиту"] },
	{ key = "theme", text = L["По темам"] },
}

-- Теги под поиск (и из списка keys, если задан), отсортированные способом mode.
-- Возвращает список и число образов с каждым тегом.
function TH:GetTagsSorted(query, mode, keys)
	query = query and self.Lower(strtrim(query)) or ""
	mode = mode or "popular"
	local counts = self:GetTagCounts()
	local trend = mode == "trending" and self:GetTagCounts(self.Net.Now() - 14 * 86400) or nil
	local order, list = {}, {}
	for i, key in ipairs(self.TAG_ORDER) do order[key] = i end
	for _, key in ipairs(keys or self.TAG_ORDER) do
		if order[key] then
			local hay = self.Lower(self.TAG_LABEL[key] .. " " .. self.TAG_GROUP[key])
			if query == "" or hay:find(query, 1, true) then list[#list + 1] = key end
		end
	end
	-- при равной популярности выше те, что ставите вы сами
	local mine = {}
	for _, set in pairs(self.db and self.db.mySets or {}) do
		for _, tag in ipairs(set.tags or {}) do mine[tag] = (mine[tag] or 0) + 1 end
	end
	local function byCount(c, desc)
		return function(a, b)
			local ca, cb = c[a] or 0, c[b] or 0
			if ca ~= cb then if desc then return ca > cb end return ca < cb end
			local ma, mb = mine[a] or 0, mine[b] or 0
			if ma ~= mb then return ma > mb end
			return order[a] < order[b]
		end
	end
	if mode == "popular" then
		table.sort(list, byCount(counts, true))
	elseif mode == "trending" then
		table.sort(list, function(a, b)
			local ta, tb = trend[a] or 0, trend[b] or 0
			if ta ~= tb then return ta > tb end
			return byCount(counts, true)(a, b)
		end)
	elseif mode == "rare" then
		table.sort(list, byCount(counts, false))
	elseif mode == "new" then
		table.sort(list, function(a, b)
			local da, db = self.TAG_ADDED[a] or "", self.TAG_ADDED[b] or ""
			if da ~= db then return da > db end
			return order[a] > order[b]
		end)
	elseif mode == "alpha" then
		table.sort(list, function(a, b) return self.Lower(self.TAG_LABEL[a]) < self.Lower(self.TAG_LABEL[b]) end)
	end
	return list, counts, trend
end

-- Теги образа для карточки: погасшие — серым с пометкой
function TH:FormatSetTags(set)
	local disputed = self:GetDisputedTags(set)
	local out = {}
	for _, key in ipairs(set.tags or {}) do
		if self.TAG_LABEL[key] then
			out[#out + 1] = disputed[key] and ("|cff808080" .. self.TAG_LABEL[key] .. L[" (оспорен)|r"]) or self.TAG_LABEL[key]
		end
	end
	return table.concat(out, ", ")
end

-- Автору: какие теги его образов погасли по отметкам игроков (раз на тег)
function TH:CheckDisputedOwnTags()
	for _, mine in pairs(self.db.mySets) do
		local set = mine.serverId and self.byId[mine.serverId]
		if set then
			for tag, n in pairs(self:GetDisputedTags(set)) do
				local key = set.id .. ":" .. tag
				if n > 0 and not self.db.warnedTags[key] then
					self.db.warnedTags[key] = self.Net.Now()
					self:Print(string.format(L["Игроки (%d) отметили, что тег «%s» не подходит вашему образу «%s». Тег погас: по нему образ не ищется."],
						n, self.TAG_LABEL[tag] or tag, mine.name or ""))
				end
			end
		end
	end
end

-- Меню «какой тег не подходит»
function TH:OpenTagFlagMenu(owner, set)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local mine = self:IsMine(set)
	local disputed = self:GetDisputedTags(set)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(mine and L["Убрать тег из своего образа"] or L["Какой тег не подходит образу?"])
		for _, key in ipairs(set.tags or {}) do
			local label = self.TAG_LABEL[key]
			if label then
				if disputed[key] and not self:IsTagFlaggedByMe(set, key) then label = label .. L[" (уже погас)"] end
				root:CreateCheckbox(label, function() return self:IsTagFlaggedByMe(set, key) end,
					function() self:ToggleTagFlag(set, key) end)
			end
		end
	end)
end

function TH:FormatTags(tags)
	if not tags or #tags == 0 then return "" end
	local out = {}
	for _, key in ipairs(tags) do
		-- теги из более новой версии аддона не показываем
		if self.TAG_LABEL[key] then out[#out + 1] = self.TAG_LABEL[key] end
	end
	return table.concat(out, ", ")
end

---------------------------------------------------------------------------
-- Утилиты
---------------------------------------------------------------------------

-- string.lower не трогает кириллицу в UTF-8, поэтому дополняем вручную.
local CYR_LOWER = {}
do
	local upper = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
	local lower = "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
	local ups, lows = {}, {}
	for ch in upper:gmatch("[\192-\255][\128-\191]*") do ups[#ups + 1] = ch end
	for ch in lower:gmatch("[\192-\255][\128-\191]*") do lows[#lows + 1] = ch end
	for i = 1, #ups do CYR_LOWER[ups[i]] = lows[i] end
end
local CYR_UPPER = {}
for up, low in pairs(CYR_LOWER) do CYR_UPPER[low] = up end

function TH.Lower(s)
	return (s:lower():gsub("[\208\209][\128-\191]", CYR_LOWER))
end

local function IsLetter(ch)
	return ch:match("^%a$") or #ch > 1 -- латиница или любая не-ASCII буква
end

-- Название образа: лишние пробелы убраны; первая буква названия заглавная;
-- первая буква остальных слов — как написал игрок («Король Лич»);
-- все прочие буквы строчные, чтобы нельзя было писать КАПСОМ.
function TH.FormatSetName(s)
	s = strtrim(tostring(s or "")):gsub("%s+", " ")
	local out, firstDone, wordStart = {}, false, true
	for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if IsLetter(ch) then
			local lower = TH.Lower(ch)
			if not firstDone then
				ch = CYR_UPPER[lower] or lower:upper() -- название начинается с буквы
			elseif not wordStart then
				ch = lower
			end
			wordStart = false
		else
			wordStart = true -- пробел, дефис, цифра и т.п. начинают новое слово
		end
		firstDone = true
		out[#out + 1] = ch
	end
	return table.concat(out)
end

local uidCounter = 0
function TH:NewUid()
	uidCounter = uidCounter + 1
	return string.format("%08x%04x%04x%03x", time(), math.random(0, 0xffff), math.random(0, 0xffff), uidCounter % 0x1000)
end

function TH:Print(...)
	print("|cffd4a017Transmog Hub:|r", ...)
end

function TH:SexLabel(sex)
	return sex == 1 and L["жен."] or L["муж."]
end

function TH:PlayerSex()
	return (UnitSex("player") or 2) - 2
end

function TH:IsLocalId(id)
	return type(id) == "string" and id:sub(1, #self.LOCAL_PREFIX) == self.LOCAL_PREFIX
end

function TH:IsTestId(id)
	return type(id) == "string" and id:sub(1, #self.TEST_PREFIX) == self.TEST_PREFIX
end

---------------------------------------------------------------------------
-- SavedVariables
---------------------------------------------------------------------------
local DEFAULTS = {
	schema = 2,
	mySets = {},     -- [localId] = set; у опубликованных serverId = id в сети
	net = {          -- копия сетевой базы (см. Network.lua)
		sets = {},       -- [id] = set
		votes = {},      -- [setId] = { [игрок] = { звёзды, время } }
		favs = {},       -- [setId] = { [игрок] = { 1 или 0, время } } — кто добавил образ в избранное
		follows = {},    -- [автор] = { [игрок] = { 1 или 0, время } } — подписки на авторов
		voteRetracts = {}, -- [setId] = { [игрок] = время } — снятые голоса (наказание за занижение)
		tombstones = {}, -- [id] = время снятия с публикации
		lastSync = 0,
		peerSync = {},   -- [Имя-Сервер друга или "group"] = время синхронизации
		reports = {},    -- [setId] = { [игрок] = { причина, время } } — игрокам не показываются
		modBlocks = { sets = {}, authors = {}, players = {}, verified = {}, names = {}, banned = {}, warned = {} }, -- решения модератора, полученные напрямую
		-- names[образ] = "e" (шуточное название: переименовать) или "o" (оскорбление); banned[автор] — бан за рекламу;
		-- warned[автор] = id образа — автора уже просили переименовать (пометка Стражей)
		modRoles = {},   -- [Имя-Сервер] = { 1 или 0, время } — модераторы, назначенные админом (напрямую от него)
		tagSuggest = {}, -- [текст] = { [игрок] = время } — предложенные теги, игрокам не показываются
		scores = {},     -- [игрок] = { очки, получено, лучшее, время } или { removed = true, время } — рейтинг
		appeals = {},    -- [игрок] = { время, текст } — оспаривание решений модераторов (скрыто)
		ideas = {},      -- ["игрок#время"] = { игрок, время, вид, текст } — предложения разработчику (скрыто)
		usage = {},      -- то же для статистики нажатий (вид u), отдельно, чтобы не вытеснять письма
		tagFlags = {},   -- [образ][тег][игрок] = { 1 или 0, время } — «тег не подходит»
	},
	mySuggest = {},    -- [текст] = время — свои предложения тегов
	friendChars = {},  -- [Имя-Сервер] = время — персонажи друзей Battle.net, которых мы видели
	myVoteChar = {},   -- [setId] = каким персонажем аккаунта поставлена оценка
	myFavChar = {},    -- [setId] = каким персонажем отправлена отметка «в избранном»
	myReports = {},    -- [setId] = время — на что жаловались вы (только у вас)
	falseReports = {}, -- [setId] = время — ваши жалобы, признанные ложными
	confirmedReports = {}, -- [setId] = true — ваши жалобы, по которым модератор убрал образ
	warned = {},       -- [предупреждение] = время показа
	myAppeal = 0,      -- когда вы последний раз оспаривали решение
	modAppeals = {},   -- обращения для коннектора (только у модератора)
	modIdeas = {},     -- предложения для коннектора (только у модератора)
	modUsage = {},     -- статистика нажатий для коннектора, без имён (только у модератора)
	modUsageNames = {}, -- «1|код|Окно / Кнопка» — расшифровка кодов для коннектора (только у модератора)
	myIdeas = {},      -- времена своих предложений (не больше 3 в день)
	leader = { char = nil, optOut = false, sent = {}, last = "" }, -- участие в рейтинге очков стиля
	moderator = false, -- на аккаунте есть персонаж-модератор: копим журнал жалоб
	modLog = {},       -- журнал жалоб для коннектора (только у модератора)
	modDecisions = {}, -- решения модератора для коннектора
	modDismissed = {}, -- [setId] = true — жалобы разобраны, из списка модерации убраны
	modTags = {},      -- предложенные теги для коннектора
	modTagStats = {},  -- снимки популярности тегов для коннектора (раз в день)
	modStats = {},     -- журнал рейтингов, оценок и достижений для коннектора (раз в день)
	warnedTags = {},   -- ["образ:тег"] = время — автору уже сказали, что тег оспорен
	secretKeys = {},   -- [id скрытого] = ключ — открытые тайны (тексты полученных скрытых достижений)
	myChars = {},    -- [Имя-Сервер] = true — все свои персонажи (для «свой образ»)
	charClass = {},  -- [Имя-Сервер] = CLASS — классы своих персонажей (для рекомендаций)
	hidden = {},     -- [setId] = true — образы, скрытые игроком
	myVotes = {},    -- [setId] = 1..5 (локальная копия для интерфейса)
	favorites = {},  -- [setId] = true
	testSets = {},   -- тестовая лента (/thub test)
	minimap = { angle = 200, hide = false },
	scale = 1,         -- масштаб окон аддона
	achievements = {}, -- [id] = время получения
	achView = { show = "all", sort = "rarity", cat = "all", collapsed = {} }, -- вид списка достижений
	style = "auto",      -- оформление: auto (как EllesmereUI, если он стоит), eui, blizzard
	font = "auto",       -- шрифт окон аддона (Fonts.lua): auto (как в EllesmereUI, если он стоит), default, ключ шрифта игры, lsm:Имя, custom
	customFont = nil,    -- свой шрифт: имя файла в Interface\Fonts
	sendErrors = true,   -- отправлять разработчику отчёты об ошибках аддона (/thub errors)
	sendUsage = true,    -- отправлять раз в неделю, на какие кнопки сколько нажимали (/thub usage)
	usageNoticed = false, -- о сборе статистики уже сказали
	clicks = {},         -- [код кнопки] = нажатий с прошлой отправки
	usageSent = 0,       -- когда статистику отправили в последний раз
	errorsSent = {},     -- [отпечаток ошибки] = версия — уже отправлено
	seenAch = {},      -- [id] = true — полученное достижение уже посмотрели (рамка в профиле тусклее)
	following = {},    -- [Имя-Сервер] = время — авторы, на которых подписан аккаунт
	followMuted = {},  -- [Имя-Сервер] = true — подписка есть, уведомлений от автора не надо
	notified = {},     -- [ключ события] = время — о чём уже уведомили
	notify = {         -- уведомления подписок (окно настроек)
		sets = true,       -- новые образы авторов, на которых подписан
		follows = true,    -- на вас подписались
		votes = true,      -- ваши образы оценили
		voteLimit = 5,     -- только о первых N оценках каждого образа (0 — обо всех)
		mutualOnly = false, -- об образах и оценках — только от взаимных подписок
		chat = true,       -- дублировать в чат
	},
	toasts = {         -- всплывашки: стиль, место, размер, время показа, звук
		ach = { style = "classic", place = "alerts", scale = 1, duration = 5, sound = true },
		note = { style = "dark", place = "custom", scale = 1, duration = 5, sound = true },
	},
	avatars = {},        -- [Имя-Сервер] = иконка — аватар у каждого своего персонажа свой
	charOrder = {},      -- порядок своих персонажей в профиле (перетаскиванием)
	collapsedChars = {}, -- [Имя-Сервер] = true — образы персонажа в профиле свёрнуты
	stats = { saved = 0, published = 0, races = {}, colors = {}, maxHidden = 0,
		tags = {}, viewed = {}, counts = {}, bnet = false, night = false, maxNetwork = 0,
		midnight = false, tagFirsts = {},
		wanted = {}, gotFromHub = {}, watchSets = {}, setsCompleted = {} },
}

-- Чистый старт с выпуском: красные (позорные) достижения и наказания, полученные за время
-- проверки, снимаются у каждого один раз. Обычные достижения, статистика и рейтинг остаются.
-- Ключ меняют, когда нужен новый сброс; nil — сброса нет.
TH.FRESH_START = "1.0.0"
function TH:ResetForRelease()
	local key = rawget(self, "FRESH_START")
	if not key or self.db.freshStart == key then return false end
	self.db.freshStart = key
	for _, a in ipairs(self.ACHIEVEMENTS or {}) do
		if a.shame then self.db.achievements[a.id] = nil end
	end
	self.db.penalty, self.db.nameStrikes = nil, nil
	wipe(self.db.myReports)
	wipe(self.db.falseReports)
	wipe(self.db.warned)
	self.db.net.modBlocks = CopyTable(DEFAULTS.net.modBlocks)
	wipe(self.db.net.modRoles)
	for _, mine in pairs(self.db.mySets) do mine.renameRequired = nil end
	return true
end

local function ApplyDefaults(t, d)
	for k, v in pairs(d) do
		if t[k] == nil then
			t[k] = type(v) == "table" and CopyTable(v) or v
		elseif type(v) == "table" and type(t[k]) == "table" then
			ApplyDefaults(t[k], v)
		end
	end
end

---------------------------------------------------------------------------
-- Лента образов
---------------------------------------------------------------------------
local PRIOR_MEAN, PRIOR_WEIGHT = 3.5, 10
local TREND_WINDOW = 7 * 86400
TH.NEW_WINDOW = 14 * 86400 -- столько образ висит в «Новых» (и «Рекомендуемых») ленты

---------------------------------------------------------------------------
-- Порог чарта растёт вместе с аудиторией. Берём 7 прошлых дней (по UTC) и в каждом
-- считаем, сколько разных игроков ставили оценки; медиана этих чисел — «игроков
-- в день» (один необычный день её не сдвигает). Порог — 5% от неё, но не меньше 5.
-- Сегодняшний день не учитывается, поэтому в течение дня число не меняется.
-- Официальный чарт пишет своё число (minVotes) — клиент со свежим чартом берёт
-- его, так порог у всех одинаковый.
---------------------------------------------------------------------------
TH.MIN_CHART_VOTES = 5     -- меньше не бывает
TH.CHART_VOTES_SHARE = 0.05
local THRESHOLD_DAYS = 7

-- Порог по своей базе: порог, медиана игроков в день
function TH:ComputeChartThreshold(now)
	now = now or self.Net.Now()
	local today = math.floor(now / 86400)
	local first = today - THRESHOLD_DAYS
	local voters = {} -- [день] = { [имя] = true }
	for _, votes in pairs(self.db.net.votes) do
		for name, v in pairs(votes) do
			local day = v[2] and math.floor(v[2] / 86400)
			if day and day >= first and day < today then
				local d = voters[day]
				if not d then d = {} voters[day] = d end
				d[name] = true
			end
		end
	end
	local counts = {}
	for day = first, today - 1 do
		local n = 0
		for _ in pairs(voters[day] or {}) do n = n + 1 end
		counts[#counts + 1] = n
	end
	table.sort(counts)
	local median = counts[math.floor(#counts / 2) + 1] or 0
	return math.max(self.MIN_CHART_VOTES, math.ceil(median * self.CHART_VOTES_SHARE - 1e-9)), median
end

-- Сколько оценок нужно для чарта сегодня; второе — игроков с оценками в день
function TH:GetMinChartVotes()
	local c = self.GetCharts and self:GetCharts()
	if c and tonumber(c.minVotes) and not self:IsChartsStale() then
		return tonumber(c.minVotes), tonumber(c.activeVoters)
	end
	-- своя оценка: раз в день или если прошло 10 минут (база могла дополниться из сети)
	local now = self.Net.Now()
	local cache = self.chartThreshold
	if not cache or cache.day ~= math.floor(now / 86400) or now - cache.at > 600 then
		local value, median = self:ComputeChartThreshold(now)
		cache = { day = math.floor(now / 86400), at = now, value = value, median = median }
		self.chartThreshold = cache
	end
	return cache.value, cache.median
end

-- Байесовское среднее: один голос 5★ не обгоняет сотню голосов 4.8★.
function TH:GetScore(set)
	local r = set.rating
	if not r or not r.n or r.n == 0 then return 0 end
	return (r.avg * r.n + PRIOR_MEAN * PRIOR_WEIGHT) / (r.n + PRIOR_WEIGHT)
end

-- В чарте («Лучшие», «В тренде», места для достижений) только образы
-- с достаточным числом оценок и без подозрений на накрутку
function TH:IsCharted(set)
	local r = set.rating
	return r ~= nil and (r.n or 0) >= self:GetMinChartVotes() and not self:GetSuspicion(set)
end

-- Рейтинг и «в тренде» по голосам из сети. «В тренде» — сумма звёзд
-- за последние 7 дней. У образов из подборок без голосов в сети
-- остаётся рейтинг из подборки.
local function ApplyVotes(set, votes, now)
	if not votes or not next(votes) then return end
	local n, sum, trend, dist = 0, 0, 0, { 0, 0, 0, 0, 0 }
	for _, v in pairs(votes) do
		n, sum = n + 1, sum + v[1]
		dist[v[1]] = (dist[v[1]] or 0) + 1
		if now - v[2] < TREND_WINDOW then trend = trend + v[1] end
	end
	-- образ из каталога: пока своих голосов меньше, чем в официальном итоге, верим итогу
	local base = set.baseRating
	if base and (base.n or 0) > n then
		set.rating = base
	else
		set.rating = { avg = sum / n, n = n, dist = dist }
	end
	set.trend = trend
end

-- Рейтинг пересчитываем только у образов, где голоса изменились (или раз в час —
-- «в тренде» зависит от времени): при тысячах образов полный пересчёт заметно тормозит
local voteCache = {}  -- [setId] = { stamp, at, rating, trend }
local formatted = setmetatable({}, { __mode = "k" }) -- названия, уже приведённые к виду
local VOTE_CACHE_TTL = 3600

-- Лента = подборки из обновления аддона + сетевая база
function TH:LoadFeed()
	local now = self.Net.Now()
	local net = self.db.net
	local stamps = self.Net.voteStamp or {}
	local sets, changed = {}, {}
	self.byId = {}
	local function add(set)
		if self.byId[set.id] or self.db.hidden[set.id] or net.tombstones[set.id] then return end
		if not self:IsSetTextAllowed(set) or self:IsBlocked(set) or self:IsAutoHidden(set) then return end
		local votes = net.votes[set.id]
		local c, stamp = voteCache[set.id], stamps[set.id] or 0
		if c and c.stamp == stamp and c.votes == votes and now - c.at < VOTE_CACHE_TTL then
			if c.rating then set.rating, set.trend = c.rating, c.trend end
		else
			ApplyVotes(set, votes, now)
			changed[#changed + 1] = set.id
			voteCache[set.id] = { stamp = stamp, at = now, votes = votes,
				rating = votes and next(votes) and set.rating or nil, trend = set.trend }
		end
		sets[#sets + 1] = set
		self.byId[set.id] = set
	end
	for _, set in pairs(net.sets) do
		if not formatted[set] then
			set.name = TH.FormatSetName(set.name)
			formatted[set] = true
		end
		add(set)
	end
	-- каталог из обновления: оценка в нём — итог чарта, свои голоса из сети его дополняют
	for _, set in ipairs(TransmogHub_Bundled and TransmogHub_Bundled.sets or {}) do
		if set.rating and not set.baseRating then set.baseRating = set.rating end
		add(set)
	end
	self.feed = { sets = sets }

	for _, set in ipairs(self.db.testSets) do
		self.byId[set.id] = set
	end
	if self.RefreshSuspicion then self:RefreshSuspicion(changed) end
	self.feedGen = (self.feedGen or 0) + 1 -- по нему сбрасываются расчёты, зависящие от ленты
	self.Net.dirty = false
end

function TH:GetSet(id)
	if not id then return end
	-- образ из сети может быть скрыт из ленты, но нужен модератору
	return self.byId[id] or self.db.mySets[id] or self.db.net.sets[id]
end

function TH:IsMine(set)
	if not set then return false end
	if self.db.mySets[set.id] or (set.author and self.db.myChars[set.author]) then return true end
	for _, mine in pairs(self.db.mySets) do
		if mine.serverId and mine.serverId == set.id then return true end
	end
	return false
end

-- Названия вещей образа строчными (для поиска по вещам); кэш на облик
local itemNames = {}
local function ItemsText(set)
	local parts = {}
	for _, it in pairs(set.items or {}) do
		local id = it[1]
		if id then
			local name = itemNames[id]
			if not name then
				local d = TH.GetSourceDetails and TH:GetSourceDetails(id)
				name = d and not d.pending and d.name and TH.Lower(d.name) or nil
				if name then itemNames[id] = name end
			end
			parts[#parts + 1] = name or ""
		end
	end
	return table.concat(parts, " ")
end

local function MatchesFilter(set, filter)
	if filter.text and filter.text ~= "" then
		local hay = TH.Lower((set.name or "") .. " " .. (set.author or "") .. " " .. TH:FormatTags(set.tags))
		-- не нашли в названии, авторе и тегах — ищем по названиям вещей (от 3 букв)
		if not hay:find(filter.text, 1, true)
			and not (#filter.text >= 3 and ItemsText(set):find(filter.text, 1, true)) then
			return false
		end
	end
	if filter.tags then
		local active = TH:GetActiveTags(set)
		for key in pairs(filter.tags) do
			if not tContains(active, key) then return false end
		end
	end
	return true
end

-- Персонажи друзей: список друзей игры и все замеченные персонажи друзей Battle.net
function TH:GetFriendNames()
	local names = {}
	for name in pairs(self.db.friendChars) do names[name] = true end
	if C_FriendList and C_FriendList.GetNumFriends then
		for i = 1, C_FriendList.GetNumFriends() or 0 do
			local info = C_FriendList.GetFriendInfoByIndex(i)
			if info and info.name then names[self.Net.FullName(info.name)] = true end
		end
	end
	return names
end

-- Согильдийцы (без своих персонажей); nil — не в гильдии
function TH:GetGuildNames()
	if not (IsInGuild and IsInGuild()) or not GetNumGuildMembers then return nil end
	local names = {}
	for i = 1, GetNumGuildMembers() or 0 do
		local name = GetGuildRosterInfo(i)
		if name then
			name = self.Net.FullName(name)
			if not self.db.myChars[name] then names[name] = true end
		end
	end
	return names
end

-- Модератор убрал образ из списка («ложные» или «без решения»); новая жалоба после
-- этого возвращает его в список. true — старая запись без времени: убран насовсем.
function TH:IsModDismissed(setId)
	local at = self.db.modDismissed[setId]
	if not at then return false end
	if at == true then return true end
	for _, r in pairs(self.db.net.reports[setId] or {}) do
		if r[1] ~= "u" and (r[2] or 0) > at then return false end
	end
	return true
end

-- view: top | trending | new | friends | guild | favorites | mine
-- Вкладки, которые показывают ту же ленту, что «Образы», только отобранную (друзья,
-- гильдия, подписки): при той же сортировке в них ровно те же образы — свежие в «Новых»
-- и «Рекомендуемых», только чарт в «Лучших» и «В тренде»
local FEED_VIEWS = { top = true, friends = true, guild = true, subs = true }

function TH:QuerySets(view, filter)
	local list = {}
	if view == "mine" then
		for _, set in pairs(self.db.mySets) do list[#list + 1] = set end
	elseif view == "moderation" then
		-- все образы с жалобами, включая скрытые (разобранные убираем),
		-- и образы с подозрением на накрутку оценок
		local seen = {}
		for setId in pairs(self.db.net.reports) do
			local set = self.db.net.sets[setId]
			if set and not self:IsModDismissed(setId) and self:GetReportStats(setId) > 0 then list[#list + 1] = set; seen[setId] = true end
		end
		for _, set in ipairs(self.feed.sets) do
			if not seen[set.id] and self:GetSuspicion(set) then list[#list + 1] = set; seen[set.id] = true end
		end
		-- отметки «тег не подходит» — модератор видит их, даже пока тег не погас
		for setId, tags in pairs(self.db.net.tagFlags) do
			local set = not seen[setId] and not self:IsModDismissed(setId) and self.db.net.sets[setId]
			if set then
				local flagged = false
				for _, list2 in pairs(tags) do
					for _, f in pairs(list2) do if f[1] == 1 then flagged = true end end
				end
				if flagged then list[#list + 1] = set; seen[setId] = true end
			end
		end
	elseif view == "author" then
		for _, set in ipairs(self.feed.sets) do
			if set.author == filter.author then list[#list + 1] = set end
		end
		for _, set in ipairs(self.db.testSets) do
			if set.author == filter.author then list[#list + 1] = set end
		end
	elseif view == "friends" then
		local friends = self:GetFriendNames()
		for _, set in ipairs(self.feed.sets) do
			if set.author and friends[set.author] then list[#list + 1] = set end
		end
	elseif view == "guild" then
		local guild = self:GetGuildNames() or {}
		for _, set in ipairs(self.feed.sets) do
			if set.author and guild[set.author] then list[#list + 1] = set end
		end
	elseif view == "hall" then
		for _, set in ipairs(self.feed.sets) do
			if self:GetHallDate(set.id) then list[#list + 1] = set end
		end
	elseif view == "subs" then
		for _, set in ipairs(self.feed.sets) do
			if set.author and self.db.following[set.author] then list[#list + 1] = set end
		end
	elseif view == "favorites" then
		for id in pairs(self.db.favorites) do
			local set = self:GetSet(id)
			if set then list[#list + 1] = set end
		end
	else
		for _, set in ipairs(self.feed.sets) do list[#list + 1] = set end
		for _, set in ipairs(self.db.testSets) do list[#list + 1] = set end
	end

	filter = filter or {}
	if filter.text then filter.text = self.Lower(filter.text) end
	local out = {}
	for _, set in ipairs(list) do
		if MatchesFilter(set, filter) then out[#out + 1] = set end
	end

	-- порядок: явный (filter.sort) или по умолчанию для раздела
	local order = filter.sort
	if not order then
		order = (view == "top" or view == "favorites" or view == "author") and "top"
			or (view == "trending" and "trending") or "new"
	end
	if view == "mine" then order = "new" end
	if view == "hall" then
		local out2 = {}
		for _, set in ipairs(out) do out2[#out2 + 1] = set end
		table.sort(out2, function(a, b) return self:GetHallDate(a.id) > self:GetHallDate(b.id) end)
		return out2
	end
	-- в общей ленте «Новые» и «Рекомендуемые» — только свежие образы: кто за это
	-- время не набрал оценок для чарта, тот просто не зашёл
	if FEED_VIEWS[view] and (order == "new" or order == "recommended") then
		local since, fresh = self.Net.Now() - self.NEW_WINDOW, {}
		for _, set in ipairs(out) do
			if (set.created or 0) >= since then fresh[#fresh + 1] = set end
		end
		out = fresh
	end
	if view == "moderation" then
		table.sort(out, function(a, b)
			local ra, rb = self:GetReportStats(a.id), self:GetReportStats(b.id)
			if ra ~= rb then return ra > rb end
			return (a.rating and a.rating.n or 0) > (b.rating and b.rating.n or 0)
		end)
	elseif order == "top" or order == "trending" then
		-- сначала чарт, ниже образы, которым не хватает оценок (новые выше).
		-- В общей ленте «Лучшие» и «В тренде» — только чарт: остальные ищите в «Новых».
		-- оценку считаем один раз на образ, а не в каждом сравнении сортировки
		local charted, score = {}, {}
		for _, set in ipairs(out) do
			charted[set] = self:IsCharted(set)
			score[set] = self:GetScore(set)
		end
		if FEED_VIEWS[view] then
			-- только чарт и без Зала славы: те образы уже вне конкурса
			local only = {}
			for _, set in ipairs(out) do
				if charted[set] and not self:GetHallDate(set.id) then only[#only + 1] = set end
			end
			out = only
		end
		table.sort(out, function(a, b)
			if charted[a] ~= charted[b] then return charted[a] end
			if not charted[a] then return (a.created or 0) > (b.created or 0) end
			if order == "trending" then
				local ta, tb = a.trend or 0, b.trend or 0
				if ta ~= tb then return ta > tb end
			end
			if score[a] ~= score[b] then return score[a] > score[b] end
			return a.id < b.id
		end)
	elseif order == "recommended" then
		local key = self:RecommendKeys(out)
		table.sort(out, function(a, b)
			if key[a] ~= key[b] then return key[a] > key[b] end
			return a.id < b.id
		end)
	else
		table.sort(out, function(a, b) return (a.created or 0) > (b.created or 0) end)
	end
	return out
end

---------------------------------------------------------------------------
-- «Рекомендуемые»: новые образы в случайном порядке, но с весами интереса.
-- Вес 1 у всех; больше — у образов классов своих персонажей (главного — ещё
-- больше) и с тегами, которые игрок сам ставит своим образам, держит в избранном
-- и оценивает на 4–5. Уже оценённые и свои — реже. Вес только повышает шанс
-- оказаться выше: остальные образы тоже выпадают.
---------------------------------------------------------------------------
TH.shuffleSeed = tostring(math.random(1, 1000000000))

function TH:Reshuffle()
	self.shuffleSeed = tostring(math.random(1, 1000000000))
end

-- Число 0..1 из строки: одинаковое при каждой перерисовке, пока не перемешали
local function Unit(str)
	local h = 5381
	for i = 1, #str do h = (h * 33 + str:byte(i)) % 4294967291 end
	return (h + 0.5) / 4294967291
end

-- Интересы игрока: классы, главный класс, веса тегов 0..1
function TH:GetInterests()
	local classes = {}
	for name, class in pairs(self.db.charClass) do
		if self.db.myChars[name] then classes[class:lower()] = true end
	end
	-- персонажи, на которых аддон давно не запускали: класс из их образов
	for _, set in pairs(self.db.mySets) do
		if set.class then classes[set.class:lower()] = true end
	end
	local main = self.db.leader.char and self.db.charClass[self.db.leader.char]
		or select(2, UnitClass("player"))
	local tags = {}
	local function Add(set, k)
		for _, tag in ipairs(set and set.tags or {}) do tags[tag] = (tags[tag] or 0) + k end
	end
	for _, set in pairs(self.db.mySets) do Add(set, 1) end
	for id in pairs(self.db.favorites) do Add(self:GetSet(id), 1) end
	for id, stars in pairs(self.db.myVotes) do
		if stars >= 4 then Add(self:GetSet(id), stars == 5 and 0.75 or 0.5) end
	end
	local max = 0
	for _, k in pairs(tags) do max = math.max(max, k) end
	if max > 0 then
		for tag, k in pairs(tags) do tags[tag] = k / max end
	end
	return { classes = classes, main = main and main:lower(), tags = tags }
end

function TH:GetRecommendWeight(set, it)
	local w = 1
	local class = set.class and set.class:lower()
	local mine, isMain = class and it.classes[class], class and class == it.main
	local tagScore = 0
	for _, tag in ipairs(set.tags or {}) do
		if it.classes[tag] then mine = true end
		if tag == it.main then isMain = true end
		tagScore = tagScore + (it.tags[tag] or 0)
	end
	if mine then w = w + 0.75 end
	if isMain then w = w + 0.75 end
	w = w + math.min(tagScore, 2) * 0.75
	if self.db.myVotes[set.id] then w = w * 0.35 end -- уже видел и оценил
	if self:IsMine(set) then w = w * 0.3 end
	return w
end

-- Ключи сортировки: u^(1/вес) — чем больше вес, тем вероятнее образ выше
function TH:RecommendKeys(list)
	local it, key = self:GetInterests(), {}
	for _, set in ipairs(list) do
		key[set] = Unit(self.shuffleSeed .. set.id) ^ (1 / self:GetRecommendWeight(set, it))
	end
	return key
end

---------------------------------------------------------------------------
-- Свои образы, публикация, голоса
---------------------------------------------------------------------------
-- Иконка образа: выбранная автором или иконка вещи на груди (иначе первой попавшейся)
function TH:GetSetIcon(set)
	if set.icon then return set.icon end
	local items = set.items or {}
	local main = items[5] or items[1] or select(2, next(items))
	local det = main and self:GetSourceDetails(main[1])
	return det and det.icon or 134400
end

function TH:CreateMySet(name, desc, tags, items, icon)
	local _, classFile = UnitClass("player")
	local _, _, raceID = UnitRace("player")
	local id = self.LOCAL_PREFIX .. self:NewUid()
	local set = {
		id = id,
		name = TH.FormatSetName(name),
		desc = desc,
		tags = tags,
		items = items,
		icon = icon,
		author = self.Net.Me(),
		race = raceID,
		sex = (UnitSex("player") or 2) - 2, -- 0 муж., 1 жен.
		class = classFile,
		created = self.Net.Now(),
		status = "draft",
	}
	self.db.mySets[id] = set
	self:TrackSavedSet(set)
	self:NotifyChanged()
	self:CheckAchievements()
	return set
end

local EXPORT_FIELDS = { "name", "desc", "tags", "items", "author", "race", "sex", "class", "icon" }

-- Публикация: образ сразу уходит в сеть, перезагрузка не нужна
function TH:Publish(localId)
	if self:IsExiled() then return self:ExileNotice() end
	local set = self.db.mySets[localId]
	if not set or set.status == "published" then return end
	local restricted = self:PublishRestrictionText()
	if restricted then return self:Notify(restricted) end
	local err = self:ValidateSetText(set.name, set.desc)
	if err then
		self:Print(err .. L[" Удалите образ и сохраните заново с другим названием."])
		return
	end
	local payload = { id = "n" .. self:NewUid(), created = self.Net.Now() }
	for _, k in ipairs(EXPORT_FIELDS) do
		payload[k] = type(set[k]) == "table" and CopyTable(set[k]) or set[k]
	end
	self.Net:PublishSet(payload)
	set.serverId = payload.id
	set.status = "published"
	if not set.everPublished then
		set.everPublished = true
		self.db.stats.published = self.db.stats.published + 1
	end
	if tonumber(date("%H")) < 5 then self.db.stats.night = true end
	self:LoadFeed()
	self:NotifyChanged()
	self:CheckAchievements()
	if not self.Net:IsConnected() then
		self:Print(L["Сеть ещё подключается — образ уйдёт другим игрокам автоматически."])
	end
end

function TH:DeleteMySet(localId)
	local set = self.db.mySets[localId]
	if not set then return end
	if set.serverId then
		self.Net:Unpublish(set.serverId)
		self.db.favorites[set.serverId] = nil
	end
	self.db.mySets[localId] = nil
	self.db.favorites[localId] = nil
	self:LoadFeed()
	self:NotifyChanged()
end

-- Каким персонажем аккаунта уже оценён образ (nil — ещё никаким)
function TH:GetVoteChar(setId)
	local who = self.db.myVoteChar[setId]
	if who or not self.db.myVotes[setId] then return who end
	-- оценки, поставленные до этой проверки: ищем своего персонажа среди голосов
	for voter in pairs(self.db.net.votes[setId] or {}) do
		if self.db.myChars[voter] then
			self.db.myVoteChar[setId] = voter
			return voter
		end
	end
end

function TH:CanVote(set)
	if not set then return false, L["Образ не найден"] end
	if self:IsMine(set) then return false, L["Свой образ оценивать нельзя"] end
	local restricted = self.VoteRestrictionText and self:VoteRestrictionText()
	if restricted then return false, restricted end
	if self:IsLocalId(set.id) then return false, L["Образ ещё не опубликован"] end
	-- одна оценка на аккаунт: изменить её можно только тем же персонажем
	local who = self:GetVoteChar(set.id)
	if who and who ~= self.Net.Me() then
		return false, L["Вы уже оценили этот образ персонажем "] .. who:gsub("%-.*", "")
	end
	return true
end

-- Скрыть образ только у себя (например, неприличное название)
-- Строка состояния сети для окна и кнопки у миникарты
function TH:NetworkStatusText()
	local Net = self.Net
	local base = string.format(L["образов в базе: %d"], Net:SetCount())
	if not Net:IsConnected() then
		return L["|cff999999Сеть: подключение...|r, "] .. base
	end
	local text = string.format(L["|cff40ff40Сеть подключена|r, игроков с аддоном: %d, друзей с других серверов: %d, %s"],
		Net:PeerCount(), Net:BNetPeerCount(), base)
	if Net:IsLocked() and Net:QueueLength() > 0 then
		text = text .. L[", |cffffd100отправка на паузе (бой или подземелье)|r"]
	elseif Net:QueueLength() > 0 then
		text = text .. string.format(L[", |cffffd100отправляется: %d|r"], Net:QueueLength())
		local stall = Net:SendStallReason()
		if stall then text = text .. L[" |cffff9020(игра не даёт отправить: "] .. stall .. ")|r" end
	end
	return text
end

function TH:HideSet(setId)
	self.db.hidden[setId] = true
	self.db.favorites[setId] = nil
	self:LoadFeed()
	self:NotifyChanged()
end

function TH:Vote(setId, stars)
	if self:IsExiled() then return self:ExileNotice() end
	local set = self:GetSet(setId)
	local ok, err = self:CanVote(set)
	if not ok then
		self:Print(err)
		return
	end
	self.db.myVotes[setId] = stars
	self.db.myVoteChar[setId] = self.Net.Me()
	if not self:IsTestId(setId) then
		self.Net:SendVote(setId, stars)
		self:LoadFeed()
	end
	self:NotifyChanged()
	self:CheckAchievements()
end

-- Избранное, добавленное до того, как оно стало расходиться по сети, — разослать
function TH:SendOldFavorites()
	local n = 0
	for setId in pairs(self.db.favorites) do
		local set = self:GetSet(setId)
		if n < 100 and set and not self.db.myFavChar[setId] and not self:IsTestId(setId)
			and not self:IsLocalId(setId) and not self:IsMine(set) then
			self.Net:SendFav(setId, 1)
			self.db.myFavChar[setId] = self.Net.Me()
			n = n + 1
		end
	end
end

-- Сколько игроков добавили образ в избранное (по сети)
function TH:GetFavoriteCount(setId)
	local n = 0
	for _, f in pairs(self.db.net.favs[setId] or {}) do
		if f[1] == 1 then n = n + 1 end
	end
	return n
end

-- Избранное общее на аккаунт; в сеть отметку шлёт один персонаж — тот, кто её поставил
function TH:ToggleFavorite(setId)
	local on = not self.db.favorites[setId]
	self.db.favorites[setId] = on or nil
	local set = self:GetSet(setId)
	local who = self.db.myFavChar[setId]
	if set and not self:IsTestId(setId) and not self:IsLocalId(setId) and not self:IsMine(set)
		and (not who or who == self.Net.Me()) then
		self.Net:SendFav(setId, on and 1 or 0)
		self.db.myFavChar[setId] = on and self.Net.Me() or nil
	end
	self:NotifyChanged()
	self:CheckAchievements()
end

---------------------------------------------------------------------------
-- Уведомления интерфейса
---------------------------------------------------------------------------
function TH:NotifyChanged()
	if self.UI and self.UI.Refresh then self.UI:Refresh() end
end

local refreshPending = false
function TH:RequestRefresh()
	if refreshPending then return end
	refreshPending = true
	C_Timer.After(0.5, function()
		refreshPending = false
		if TH.Net.dirty then TH:LoadFeed() end
		TH:NotifyChanged()
		TH:CheckAchievementsSoon()
	end)
end

-- Проверка достижений после изменений из сети: не чаще раза в 20 секунд
-- (при большой базе она заметна, а сеть шлёт изменения пачками). Свои действия
-- вызывают CheckAchievements сразу.
local ACH_CHECK_EVERY = 20
local lastAchCheck, achCheckPending = -math.huge, false
function TH:CheckAchievementsSoon()
	local wait = lastAchCheck + ACH_CHECK_EVERY - GetTime()
	if wait <= 0 then
		lastAchCheck = GetTime()
		self:CheckAchievements()
	elseif not achCheckPending then
		achCheckPending = true
		C_Timer.After(wait, function()
			achCheckPending = false
			lastAchCheck = GetTime()
			TH:CheckAchievements()
		end)
	end
end

---------------------------------------------------------------------------
-- Тестовая лента: копии своих образов со случайным рейтингом
---------------------------------------------------------------------------
local FAKE_AUTHORS = { L["Ксарн-Гордунни"], L["Лиара-Свежеватель Душ"], "Thrall-Draenor", L["Мирабель-Ревущий фьорд"], L["Огрим-Галакронд"] }

function TH:MakeTestFeed()
	local sources = {}
	for _, set in pairs(self.db.mySets) do sources[#sources + 1] = set end
	if #sources > 0 then
		self:FillTestFeed(sources)
		return
	end
	self:CaptureCurrent(function(items)
		if not items then
			self:Print(L["Не удалось запомнить, во что одет персонаж."])
			return
		end
		self:FillTestFeed({ { items = items, race = select(3, UnitRace("player")), sex = UnitSex("player") - 2 } })
	end)
end

function TH:FillTestFeed(sources)
	wipe(self.db.testSets)
	for i = 1, 25 do
		local src = sources[(i - 1) % #sources + 1]
		local n = math.random(0, 300)
		local tags = {}
		for _ = 1, math.random(1, 3) do
			local key = self.TAG_ORDER[math.random(1, #self.TAG_ORDER)]
			if not tContains(tags, key) then tags[#tags + 1] = key end
		end
		tinsert(self.db.testSets, {
			id = self.TEST_PREFIX .. i,
			name = L["Тестовый образ "] .. i,
			desc = L["Сгенерировано командой /thub test"],
			author = FAKE_AUTHORS[math.random(1, #FAKE_AUTHORS)],
			tags = tags,
			items = CopyTable(src.items),
			race = src.race,
			sex = src.sex,
			created = time() - math.random(0, 30 * 86400),
			rating = { avg = n > 0 and (math.random(250, 500) / 100) or 0, n = n },
			trend = math.random(0, 100),
		})
	end
	self:LoadFeed()
	self:NotifyChanged()
	self:Print(L["Создано 25 тестовых образов."])
end

---------------------------------------------------------------------------
-- События и команды
---------------------------------------------------------------------------
TH:SetScript("OnEvent", function(self, event, ...)
	if self[event] then self[event](self, ...) end
end)
TH:RegisterEvent("ADDON_LOADED")
TH:RegisterEvent("PLAYER_LOGIN")

function TH:ADDON_LOADED(name)
	if name ~= ADDON_NAME then return end
	TransmogHubDB = TransmogHubDB or {}
	ApplyDefaults(TransmogHubDB, DEFAULTS)
	self.db = TransmogHubDB
	-- Версии до сети отправляли образы через компаньон: очередь больше не нужна,
	-- а «отправляющиеся» образы становятся черновиками — их можно опубликовать в сеть.
	if self.db.outbox then
		self.db.outbox = nil
		for _, set in pairs(self.db.mySets) do
			if set.status ~= "published" then set.status = "draft" end
		end
	end
	self.db.schema = DEFAULTS.schema
	self:UnregisterEvent("ADDON_LOADED")
end

function TH:PLAYER_LOGIN()
	self.db.myChars[self.Net.Me()] = true
	self.db.charClass[self.Net.Me()] = select(2, UnitClass("player"))
	-- аватар был общий на аккаунт: оставляем его персонажу из рейтинга
	if self.db.leader.avatar then
		local owner = self.db.leader.char or self.Net.Me()
		self.db.avatars[owner] = self.db.avatars[owner] or self.db.leader.avatar
		self.db.leader.avatar = nil
	end
	self:CleanAvatars()
	if self:ResetForRelease() then
		self:Print(L["Transmog Hub вышел! Позорные достижения и наказания, полученные во время проверки, сняты — удачи на подиуме."])
	end
	-- 0.21.0 сохраняла «как в игре» без выбора игрока: теперь по умолчанию — как в EllesmereUI
	if self.db.font == "default" and not self.db.fontChosen then self.db.font = "auto" end
	self:PruneNotified()
	-- уведомления — только о том, что пришло после входа (иначе — всё, что лежит в базе)
	C_Timer.After(5, function()
		self.loggedIn = true
		self:ReconcileFollows()
		self:CheckNameViolations(true) -- решения Стражей по названиям (и напоминание переименовать)
	end)
	if self.StartUsage then self:StartUsage() end
	if self.RegisterBlizzardSettings then pcall(self.RegisterBlizzardSettings, self) end
	for _, set in pairs(self.db.mySets) do set.name = TH.FormatSetName(set.name) end
	if self:IsModerator(self.Net.Me()) then
		self.db.moderator = true
	elseif self.db.net.modRoles[self.Net.Me()] then
		self.db.moderator = nil -- админ снял с модераторов
	end
	self.Net:Prune()
	self:LoadFeed()
	self:ApplyFactionNames()
	self:ApplySecrets()
	self.Net:Start()
	self:UpdateMinimapButton()
	C_Timer.After(5, function()
		self:RebuildStatsFromSets()
		self:CheckAchievements()
	end)
	C_Timer.After(180, function() -- после синхронизации
		self:SnapshotTagStats()
		self:SnapshotStats()
	end)
	C_Timer.After(30, function() self:PublishScore() end)
	C_Timer.After(15, function() self:CheckChartsFreshness() end)
	C_Timer.After(90, function() self:CheckDisputedOwnTags() end) -- после синхронизации
	C_Timer.After(40, function() self:SendOldFavorites() end)
	C_Timer.After(20, function() self:CheckCollectedFromHub() end) -- собранное без аддона
	self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	self:RegisterEvent("TRANSMOG_COLLECTION_UPDATED")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")
end

function TH:GUILD_ROSTER_UPDATE()
	if self.UI and self.UI:IsShown() and self.UI.view == "guild" then self:RequestRefresh() end
end

function TH:GET_ITEM_INFO_RECEIVED()
	if self.UI and self.UI:IsShown() then self:RequestRefresh() end
	if self.RefreshSaveDialogTags then self:RefreshSaveDialogTags() end
end

function TH:TRANSMOG_COLLECTION_UPDATED()
	if self.WipeSourceCache then self:WipeSourceCache() end
	-- событие приходит пачками: проверяем коллекцию один раз через пару секунд
	if not self.collectionCheckPending then
		self.collectionCheckPending = true
		C_Timer.After(2, function()
			self.collectionCheckPending = false
			self:CheckCollectedFromHub()
		end)
	end
	if self.UI and self.UI:IsShown() then self:RequestRefresh() end
end

-- Масштаб окон аддона: 60–150 %, шаг 5 %
TH.SCALE_MIN, TH.SCALE_MAX, TH.SCALE_STEP = 0.6, 1.5, 0.05

function TH:ApplyScale()
	local scale = self.db and self.db.scale or 1
	for _, name in ipairs({ "TransmogHubFrame", "TransmogHubSaveDialog", "TransmogHubSuggestTag" }) do
		local f = _G[name]
		if f then f:SetScale(scale) end
	end
end

-- exact — без округления до шага (при растягивании окна за угол)
function TH:SetScale(value, exact)
	value = tonumber(value)
	if not value then return end
	if not exact then value = math.floor(value / self.SCALE_STEP + 0.5) * self.SCALE_STEP end
	value = math.min(math.max(value, self.SCALE_MIN), self.SCALE_MAX)
	self.db.scale = value
	self:ApplyScale()
	if self.UI and self.UI.UpdateScaleSlider then self.UI:UpdateScaleSlider() end
end

function TH:Toggle()
	if self.UI then self.UI:Toggle() end
end

function TransmogHub_OnAddonCompartmentClick()
	TH:Toggle()
end

SLASH_TRANSMOGHUB1 = "/thub"
SLASH_TRANSMOGHUB2 = "/transmoghub"
SlashCmdList.TRANSMOGHUB = function(msg)
	msg = strtrim(msg or ""):lower()
	if msg == "help" or msg == "справка" then
		TH:OpenHelp(1)
	elseif msg == "idea" or msg == "идея" then
		TH:OpenIdeas()
	elseif msg == "appeal" or msg == "оспорить" then
		TH:OpenAppeal()
	elseif msg == "tour" or msg == "обучение" then
		TH:StartTour()
	elseif msg == "minimap" then
		TH:ToggleMinimapButton()
	elseif msg == "test" then
		TH:MakeTestFeed()
	elseif msg == "test clear" then
		wipe(TH.db.testSets)
		TH:LoadFeed()
		TH:NotifyChanged()
		TH:Print(L["Тестовые образы удалены."])
	elseif msg == "sync" then
		TH.Net:RequestSync()
		TH:Print(L["Запрос синхронизации отправлен."])
	elseif msg == "net" then
		local Net = TH.Net
		TH:Print(string.format(L["Сеть: %s, канал %d (участников: %s), игроков с аддоном: %d, образов в базе: %d, в очереди: %d%s. Вы: %s"],
			Net:IsConnected() and L["подключено"] or L["нет подключения"], Net.channelId, tostring(Net:ChannelMemberCount() or "?"),
			Net:PeerCount(), Net:SetCount(), Net:QueueLength(),
			Net:IsLocked() and L[", отправка на паузе (бой или подземелье)"] or "", Net.Me()))
		local friends = {}
		for _, peer in pairs(Net.bnPeers) do friends[#friends + 1] = peer.name end
		TH:Print(L["Друзья Battle.net с аддоном: "] .. (#friends > 0 and table.concat(friends, ", ") or L["никого"]))
	elseif msg:match("^scale") then
		local pct = tonumber(msg:match("^scale%s+(%d+)"))
		if pct then TH:SetScale(pct / 100) end
		TH:Print(string.format(L["Масштаб окна: %d%%. Изменить: /thub scale 60—150"], math.floor(TH.db.scale * 100 + 0.5)))
	elseif msg == "style" or msg == "style auto" or msg == "style eui" or msg == "style blizzard" then
		if msg ~= "style" then TH.db.style = msg:sub(7) end
		local names = { auto = L["авто (как EllesmereUI, если он стоит)"], eui = L["в стиле EllesmereUI"], blizzard = L["обычное, как в игре"] }
		TH:Print(L["Оформление окон: "] .. (names[TH.db.style] or TH.db.style) .. ". /thub style auto|eui|blizzard"
			.. (msg ~= "style" and L[" — изменится после /reload."] or ""))
	elseif msg == "usage" or msg == "usage on" or msg == "usage off" then
		if msg ~= "usage" then TH.db.sendUsage = msg == "usage on" end
		if not TH.db.sendUsage then wipe(TH.db.clicks) end
		TH:Print(L["Статистика нажатий на кнопки: "] .. (TH.db.sendUsage and L["|cff40ff40собирается|r"] or L["|cffff4040выключена|r"])
			.. L[". Раз в неделю разработчику уходят только названия кнопок аддона и число нажатий. /thub usage on|off, /thub clicks — сводка"])
	elseif msg == "settings" or msg == "config" or msg == "options" then
		TH:OpenSettings()
	elseif msg == "fonts" then
		TH:PrintFontCheck()
	elseif msg == "clicks" then
		TH:PrintUsage()
	elseif msg == "errors" or msg == "errors on" or msg == "errors off" then
		if msg ~= "errors" then TH.db.sendErrors = msg == "errors on" end
		TH:Print(L["Отчёты об ошибках аддона: "] .. (TH.db.sendErrors and L["|cff40ff40отправляются|r"] or L["|cffff4040выключены|r"])
			.. L[" (ловит: "] .. (TH.errorReportsVia or "—") .. ")"
			.. L[". Уходят только ошибки Transmog Hub: текст ошибки и место в коде, без ваших данных. /thub errors on|off"])
	elseif msg == "unhide" then
		wipe(TH.db.hidden)
		TH:LoadFeed()
		TH:NotifyChanged()
		TH:Print(L["Скрытые образы снова показываются."])
	elseif msg == "capture" then
		TH:CaptureCurrent(function(items, method)
			if not items then
				TH:Print(L["Не удалось запомнить, во что одет персонаж."])
				return
			end
			TH:Print(L["Облик снят способом:"], method)
			for slotID, it in pairs(items) do
				print(slotID, it[1], it[2] or "-", it[3] or "-")
			end
		end)
	else
		TH:Toggle()
	end
end
