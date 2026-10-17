local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Профиль автора: его образы, статистика, достижения и место в рейтинге.
-- Достижения других игроков известны из рейтинга очков стиля (маска).
---------------------------------------------------------------------------
local SET_ROWS, SET_ROW_H = 11, 32
local ICON, ICON_GAP, ICON_COLS = 34, 4, 8
local LIST_X, LIST_W = 10, 300          -- образы слева
local VIEW_X, VIEW_W = 318, 310         -- примерка в центре
local ACH_X = 640                        -- достижения справа
local BODY_Y = -92

-- Портрет расы для «аватарки» (файлы иконок сверены со списком файлов игры).
-- Настоящие портреты есть только у старых рас; у союзных рас, драктиров и
-- земельников вместо портрета — иконка класса.
local RACE_PORTRAIT = {
	[1] = "achievement_character_human_%s", [2] = "achievement_character_orc_%s",
	[3] = "achievement_character_dwarf_%s", [4] = "achievement_character_nightelf_%s",
	[5] = "achievement_character_undead_%s", [6] = "achievement_character_tauren_%s",
	[7] = "achievement_character_gnome_%s", [8] = "achievement_character_troll_%s",
	[9] = { "achievement_goblinhead", "achievement_femalegoblinhead" },
	[10] = "achievement_character_bloodelf_%s", [11] = "achievement_character_draenei_%s",
	[22] = "achievement_worganhead",
	[24] = "achievement_character_pandaren_female", [25] = "achievement_character_pandaren_female",
	[26] = "achievement_character_pandaren_female",
}

-- Эмблемы союзных рас были аватарами раньше: выбранные сбрасываем
local OLD_EMBLEMS = { [1786421] = true, [1786419] = true, [1786422] = true, [1786420] = true, [1851465] = true,
	[2447785] = true, [1851464] = true, [3208033] = true, [1989713] = true, [3208032] = true, [4528811] = true,
	[5930319] = true }

-- Раса, пол и класс автора — по его последнему образу
function TH:GetAuthorLook(sets)
	local latest
	for _, set in ipairs(sets) do
		if set.race and (not latest or (set.created or 0) > (latest.created or 0)) then latest = set end
	end
	return latest
end

---------------------------------------------------------------------------
-- Аватары. Обычные: портреты рас, иконки своих образов и полученных достижений.
-- Наградные — портреты героев, открываются достижениями. Чужой аватар каждый
-- клиент проверяет по списку достижений игрока (маске из рейтинга).
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Титулы за достижения: m — для мужского персонажа, f — для женского
---------------------------------------------------------------------------
TH.TITLES = {
	{ ach = "publish_1", m = L["Дебютант"], f = L["Дебютантка"] },
	{ ach = "night", m = L["Ночной дозорный"], f = L["Ночная дозорная"] },
	{ ach = "vote_100", m = L["Член жюри"], f = L["Член жюри"] },
	{ ach = "ratings_100", m = L["Любимец публики"], f = L["Любимица публики"] },
	{ ach = "found_100", m = L["Собиратель Азерота"], f = L["Собирательница Азерота"] },
	{ ach = "colors_all", m = L["Призматический"], f = L["Призматическая"] },
	{ ach = "publish_20", m = L["Кутюрье"], f = L["Кутюрье"] },
	{ ach = "complete_10", m = L["Двойник"], f = L["Двойник"] },
	{ ach = "trend_1", m = L["Законодатель моды"], f = L["Законодательница моды"] },
	{ ach = "liked_1000", m = L["Кумир Азерота"], f = L["Муза Азерота"] },
	{ ach = "tag_first5", m = L["Многогранный талант"], f = L["Многогранный талант"] },
	{ ach = "board_1", m = L["Первый среди равных"], f = L["Первая среди равных"] },
	{ ach = "top_1", m = L["Легенда подиума"], f = L["Легенда подиума"] },
	{ ach = "pct_top_01", m = L["Сезонная легенда"], f = L["Сезонная легенда"] },
	{ ach = "first_find_1", m = L["Первооткрыватель"], f = L["Первооткрывательница"] },
	{ ach = "first_find_3", m = L["Картограф тайн"], f = L["Картограф тайн"] },
	{ ach = "pct_board_01", m = L["Легенда ключей"], f = L["Легенда ключей"] },
	{ ach = "raid_aotc", m = L["Герой рейдовой моды"], f = L["Героиня рейдовой моды"] },
	{ ach = "raid_ce", m = L["На кромке лезвия"], f = L["На кромке лезвия"] },
	{ ach = "publish_100", m = L["Владелец дома моды"], f = L["Владелица дома моды"] },
	{ ach = "all", m = L["Повелитель гардероба"], f = L["Повелительница гардероба"] },
	{ ach = "hid_lichking", m = L["Наследник Ледяного трона"], f = L["Наследница Ледяного трона"] },
	{ ach = "hid_illidan", m = L["Иллидари"], f = L["Иллидари"] },
	{ ach = "hid_bloodsail", m = L["Капитан Кровавого Паруса"], f = L["Капитан Кровавого Паруса"] },
	{ ach = "hid_chen", m = L["Хмельной мастер"], f = L["Хмельная мастерица"] },
	{ ach = "hid_gnome", m = L["Гномреганский модник"], f = L["Гномреганская модница"] },
	{ ach = "hid_murloc", m = L["Почётный мурлок"], f = L["Почётная мурлочиха"] },
	{ ach = "hid_plan", m = L["Тот, кто бежит первым"], f = L["Та, кто бежит первой"] },
	{ ach = "hid_medivh", m = L["Гость Каражана"], f = L["Гостья Каражана"] },
	{ ach = "hid_neighbours", m = L["Беглец из Гилнеаса"], f = L["Беглянка из Гилнеаса"] },
}

local function MySex()
	return (UnitSex("player") or 2) == 3 and 1 or 0 -- 1 — женский
end

-- Код титула для сети: номер достижения * 2 + пол (0 муж., 1 жен.)
function TH:GetMyTitleCode()
	local id = self.db.leader.title
	local a = id and self.db.achievements[id] and self.ACHIEVEMENT_BY_ID[id]
	if not a then return nil end
	return a.num * 2 + MySex()
end

local function TitleText(achId, sex)
	for _, t in ipairs(TH.TITLES) do
		if t.ach == achId then return sex == 1 and t.f or t.m end
	end
end

-- Титул игрока: свой — из настроек, чужой — из рейтинга, если достижение у него есть
function TH:GetPlayerTitle(name)
	if self.db.myChars[name] then
		local id = self.db.leader.title
		return id and self.db.achievements[id] and TitleText(id, MySex()) or nil
	end
	local s = self.db.net.scores[name]
	if not (s and not s.removed and s.title and s.mask) then return nil end
	local a = self.ACHIEVEMENT_BY_NUM[math.floor(s.title / 2)]
	if not a or not self.MaskHas(s.mask, a.num) then return nil end
	return TitleText(a.id, s.title % 2)
end

function TH:SetMyTitle(achId)
	self.db.leader.title = achId
	self:PublishScore(true)
	self:NotifyChanged()
end

function TH:OpenTitleMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local sex = MySex()
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L["Титул"])
		root:CreateRadio(L["Без титула"], function() return not self.db.leader.title end, function() self:SetMyTitle(nil) end)
		local locked = 0
		for _, t in ipairs(self.TITLES) do
			if self.db.achievements[t.ach] then
				root:CreateRadio(sex == 1 and t.f or t.m,
					function() return self.db.leader.title == t.ach end,
					function() self:SetMyTitle(t.ach) end)
			else
				locked = locked + 1
			end
		end
		if locked > 0 then
			root:CreateDivider()
			root:CreateTitle(string.format(L["Ещё %d — за достижения"], locked))
		end
	end)
end

TH.AVATAR_REWARDS = {
	{ ach = "hid_lichking", icon = "achievement_boss_lichking", name = L["Король-лич"] },
	{ ach = "hid_illidan", icon = "achievement_boss_illidan", name = L["Иллидан Ярость Бури"] },
	{ ach = "hid_bloodsail", icon = "ability_rogue_ghostpirate", name = L["Призрачный пират"] },
	{ ach = "hid_murloc", icon = "inv_misc_head_murloc_01", name = L["Мурлок"] },
	{ ach = "hid_gnome", icon = "achievement_boss_zuldazar_mekkatorque", name = L["Гелбин Меггакрут"] },
	{ ach = "hid_medivh", icon = "inv_staff_medivh", name = L["Посох Медива"] },
	{ ach = "colors_all", icon = "achievement_dungeon_blackwingdescent_raid_nefarian", name = L["Нефариан"] },
	{ ach = "races_all", icon = "achievement_raid_revendrethraid_siredenathrius", name = L["Сир Денатрий"] },
	{ ach = "vote_500", icon = "achievement_leader_genngraymane", name = L["Генн Седогрив"] },
	{ ach = "publish_20", icon = "achievement_boss_ladyvashj", name = L["Леди Вайш"] },
	{ ach = "ratings_1000", icon = "achievement_leader_tyrande_whisperwind", name = L["Тиранда Шелест Ветра"] },
	{ ach = "liked_100", icon = "achievement_leader_prophet_velen", name = L["Пророк Велен"] },
	{ ach = "liked_1000", icon = "achievement_boss_azshara", name = L["Королева Азшара"] },
	{ ach = "complete_10", icon = "achievement_boss_algalon_01", name = L["Алгалон Наблюдатель"] },
	{ ach = "complete_50", icon = "achievement_boss_yoggsaron_01", name = L["Йогг-Сарон"] },
	{ ach = "found_500", icon = "achievement_boss_zuldazar_jaina", name = L["Джайна Праудмур"] },
	{ ach = "trend_1", icon = "achievement_leader_sylvanas", name = L["Сильвана Ветрокрылая"] },
	{ ach = "board_10", icon = "achievement_leader_king_magni_bronzebeard", name = L["Король Магни Бронзобород"] },
	{ ach = "board_1", icon = "achievement_boss_ragnaros", name = L["Рагнарос"] },
	{ ach = "publish_100", icon = "achievement_boss_onyxia", name = L["Ониксия"] },
	{ ach = "tag_first5", icon = "achievement_boss_kael'thassunstrider_01", name = L["Кель'тас Солнечный Скиталец"] },
	{ ach = "top_1", icon = "achievement_leader_king_varian_wrynn", name = L["Вариан Ринн"] },
	{ ach = "all", icon = "achievement_boss_kiljaeden2", name = L["Кил'джеден"] },
	{ ach = "vote_100", icon = "inv_achievement_raid_progenitorraid_jailer", name = L["Тюремщик"] },
	{ ach = "network_500", icon = "quest_khadgar", name = L["Кадгар"] },
	{ ach = "holiday_all", icon = "inv_111_raid_achievement_chromekinggallywix", name = L["Галливикс"] },
	{ ach = "five_100", icon = "inv_120_raid_marchonqueldanas_lura", name = L["Л'ура"] },
	{ ach = "trend_10", icon = "inv_achievement_raidemeralddream_fyrakk", name = L["Фиракк"] },
	{ ach = "top_10", icon = "achievement_thenighthold_guldan", name = L["Гул'дан"] },
	{ ach = "tag_top1", icon = "achievement_boss_hellfire_archimonde", name = L["Архимонд"] },
	{ ach = "first_find_1", icon = "inv_120_raid_voidspire_alleria", name = L["Аллерия Ветрокрылая"] },
	{ ach = "first_find_3", icon = "achievement_nzothraid_nzoth", name = L["Н'Зот"] },
	{ ach = "pct_board_1", icon = "achievement_nzothraid_wrathion", name = L["Гневион"] },
	{ ach = "pct_board_01", icon = "achievement_boss_garrosh", name = L["Гаррош Адский Крик"] },
	{ ach = "pct_top_1", icon = "achievement_boss_kelthuzad_01", name = L["Кел'Тузад"] },
	{ ach = "pct_top_01", icon = "inv_achievement_raid_progenitorraid_anduin", name = L["Андуин Ринн"] },
	{ ach = "raid_aotc", icon = "achievement_raidprimalist_raszageth", name = L["Рашагет"] },
	{ ach = "raid_ce", icon = "inv_achievement_raidnerubian_queenansurek", name = L["Королева Ансурек"] },
	{ ach = "hidden_8", icon = "inv_112_achievement_raid_salhadaar", name = L["Нексус-король Сал'хадаар"] },
}

-- WoW Forever: титулы под новые названия достижений (mH/fH — для Орды)
if TH.FOREVER then
	local FOREVER = {
		pct_top_01 = { m = L["Драконий избранник"], f = L["Драконья избранница"] },
		pct_board_01 = { m = L["Главнокомандующий"], f = L["Главнокомандующая"], mH = L["Верховный вождь"], fH = L["Верховный вождь"] },
		raid_aotc = { m = L["Убийца драконов"], f = L["Убийца драконов"] },
		raid_ce = { m = L["Первый в мире"], f = L["Первая в мире"] },
	}
	for _, t in ipairs(TH.TITLES) do
		for k, v in pairs(FOREVER[t.ach] or {}) do t[k] = v end
	end
end

-- WoW Forever: портреты героев своего времени вместо героев дополнений
if TH.FOREVER then
	local FOREVER = {
		races_all = { icon = "inv_misc_head_dragon_bronze", name = L["Ноздорму"] },
		vote_100 = { icon = "achievement_boss_emperordagranthaurissan", name = L["Император Дагран Тауриссан"] },
		liked_100 = { icon = "inv_misc_head_dragon_green", name = L["Изера"] },
		complete_10 = { icon = "achievement_boss_mekgineer_thermaplugg", name = L["Механик Термоштепсель"] },
		complete_50 = { icon = "achievement_boss_edwinvancleef", name = L["Эдвин ван Клиф"] },
		holiday_all = { icon = "inv_holiday_christmas_present_01", name = L["Дедушка Зима"] },
		five_100 = { icon = "spell_holy_elunesgrace", name = L["Элуна"] },
		trend_10 = { icon = "inv_misc_head_dragon_blue", name = L["Азурегос"] },
		first_find_3 = { icon = "achievement_boss_cthun", name = L["К'Тун"] },
		pct_board_1 = { icon = "achievement_boss_generaldrakkisath", name = L["Генерал Драккисат"] },
		pct_board_01 = { icon = "achievement_leader_cairne bloodhoof", name = L["Кэрн Кровавое Копыто"] },
		pct_top_01 = { icon = "achievement_boss_nefarion", name = L["Лорд Виктор Нефарий"] },
		raid_aotc = { icon = "achievement_boss_onyxia", name = L["Ониксия"] },
		raid_ce = { icon = "achievement_boss_hellfire_archimonde", name = L["Архимонд"] },
		publish_100 = { icon = "inv_misc_head_dragon_black", name = L["Леди Престор"] },
		tag_top1 = { icon = "achievement_leader_thrall", name = L["Тралл"] },
		hidden_8 = { icon = "achievement_boss_hakkar", name = L["Хаккар"] },
	}
	for _, r in ipairs(TH.AVATAR_REWARDS) do
		for k, v in pairs(FOREVER[r.ach] or {}) do r[k] = v end
	end
end

local iconIDs = {} -- кэш: имя или путь иконки -> номер файла
local function IconID(name)
	if type(name) == "number" then return name end
	if type(name) ~= "string" then return nil end
	if iconIDs[name] == nil then iconIDs[name] = TH.IconToFileID and TH.IconToFileID(name) or false end
	return iconIDs[name] or nil
end

-- Иконки классов и их специализаций: { fileID, название } по порядку классов
local classIcons
local function ClassIcons()
	if classIcons then return classIcons end
	classIcons = {}
	local numSpecs = C_SpecializationInfo and C_SpecializationInfo.GetNumSpecializationsForClassID
		or GetNumSpecializationsForClassID
	for i = 1, (GetNumClasses and GetNumClasses() or 0) do
		local className, classFile, classID = GetClassInfo(i)
		if classFile then
			local id = IconID("classicon_" .. classFile:lower())
			if id then classIcons[#classIcons + 1] = { id, className } end
			for j = 1, (numSpecs and classID and numSpecs(classID) or 0) do
				local _, specName, _, icon = GetSpecializationInfoForClassID(classID, j)
				if type(icon) == "number" then classIcons[#classIcons + 1] = { icon, specName .. " (" .. className .. ")" } end
			end
		end
	end
	return classIcons
end

-- Обычные аватары (портреты рас обоих полов, классы и специализации): [fileID] = true
local standardIDs
local function StandardIDs()
	if standardIDs then return standardIDs end
	standardIDs = {}
	for raceID in pairs(RACE_PORTRAIT) do
		for sex = 0, 1 do
			local id = IconID(TH:GetRacePortrait(raceID, sex))
			if id then standardIDs[id] = true end
		end
	end
	for _, c in ipairs(ClassIcons()) do standardIDs[c[1]] = true end
	return standardIDs
end

-- Наградной аватар по номеру файла: запись AVATAR_REWARDS и достижение
function TH:GetAvatarReward(fileID)
	if not fileID then return nil end
	for _, r in ipairs(self.AVATAR_REWARDS) do
		if IconID(r.icon) == fileID then return r, self.ACHIEVEMENT_BY_ID[r.ach] end
	end
end

-- Рамка аватара: у наградного — цвет редкости достижения (приглушённо), у обычного нет
function TH:PaintAvatarBorder(border, fileID)
	local _, a = self:GetAvatarReward(type(fileID) == "number" and fileID or IconID(fileID))
	if a then
		local r, g, b = self:RarityRGB(a.rarity)
		border:SetColorTexture(r, g, b, 0.6)
		border:Show()
	else
		border:Hide()
	end
end

-- Можно ли игроку name такой аватар: обычный или открытый его достижениями
function TH:IsAvatarAllowed(name, fileID, mask)
	if not fileID then return false end
	if StandardIDs()[fileID] then return true end
	local function Has(id)
		local a = self.ACHIEVEMENT_BY_ID[id]
		return a and mask and self.MaskHas(mask, a.num)
	end
	for _, r in ipairs(self.AVATAR_REWARDS) do
		if IconID(r.icon) == fileID then return Has(r.ach) end
	end
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if not a.shame and IconID(a.texture) == fileID and Has(a.id) then return true end
	end
	for _, set in ipairs(self.feed.sets) do
		if set.author == name and self:GetSetIcon(set) == fileID then return true end
	end
	return false
end

-- Аватар игрока: выбранный им (свой — из настроек; чужой — из рейтинга, если он ему
-- доступен) или портрет расы (у союзных рас — иконка класса)
function TH:GetAvatar(name, raceID, sex, class)
	local avatar
	if self.db.myChars[name] then
		avatar = self.db.avatars[name]
	else
		local s = self.db.net.scores[name]
		if s and not s.removed and s.avatar and self:IsAvatarAllowed(name, s.avatar, s.mask) then avatar = s.avatar end
	end
	return avatar or self:GetRacePortrait(raceID, sex, class)
end

-- Выбранные раньше эмблемы союзных рас больше не аватары
function TH:CleanAvatars()
	for name, id in pairs(self.db.avatars) do
		if OLD_EMBLEMS[id] then self.db.avatars[name] = nil end
	end
end

function TH:OpenAvatarPicker()
	local _, _, myRace = UnitRace("player")
	local mySex = (UnitSex("player") or 2) - 2
	local myClass = select(2, UnitClass("player"))
	local rewards, locked, tips, borders, opened = {}, {}, {}, {}, 0
	-- по редкости достижения: от обычных к легендарным, внутри — в порядке списка
	local order = {}
	for i, r in ipairs(self.AVATAR_REWARDS) do order[i] = { r = r, i = i } end
	local function Rarity(r) local a = self.ACHIEVEMENT_BY_ID[r.ach] return a and a.rarity or 0 end
	table.sort(order, function(x, y)
		local rx, ry = Rarity(x.r), Rarity(y.r)
		if rx ~= ry then return rx < ry end
		return x.i < y.i
	end)
	for _, o in ipairs(order) do
		local r = o.r
		local id, a = IconID(r.icon), self.ACHIEVEMENT_BY_ID[r.ach]
		if id and a then
			rewards[#rewards + 1] = id
			borders[id] = { self:RarityRGB(a.rarity) }
			local has = self.db.achievements[a.id] ~= nil
			if has then opened = opened + 1 else locked[id] = true end
			-- условие скрытого достижения не раскрываем, пока оно не получено
			local how = (a.hidden and not has) and (L["Скрытое достижение. Подсказка: "] .. a.hint)
				or (L["Достижение «"] .. a.name .. "»: " .. a.desc)
			tips[id] = { r.name, how }
		end
	end
	-- обычные: свой портрет первым, остальные расы, классы и специализации,
	-- свои образы, полученные достижения
	local list, seen = {}, {}
	local function Add(icon, title, text)
		local id = IconID(icon)
		if id and not seen[id] then
			seen[id] = true
			list[#list + 1] = id
			tips[id] = tips[id] or { title, text }
		end
	end
	Add(self:GetRacePortrait(myRace, mySex, myClass), RACE_PORTRAIT[myRace] and L["Портрет вашей расы"] or L["Иконка вашего класса"])
	for _, race in ipairs(self:GetPlayableRaces()) do
		if RACE_PORTRAIT[race.id] then
			for sex = 0, 1 do Add(self:GetRacePortrait(race.id, sex), race.name) end
		end
	end
	for _, c in ipairs(ClassIcons()) do Add(c[1], c[2]) end
	for _, set in pairs(self.db.mySets) do Add(self:GetSetIcon(set), L["Иконка образа"], set.name) end
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if self.db.achievements[a.id] and not a.shame then Add(a.texture, a.name, L["Полученное достижение"]) end
	end
	self:OpenIconPicker({
		title = L["Аватар"],
		recLabel = string.format(L["Наградные аватары — открываются достижениями (открыто %d из %d)"], opened, #rewards),
		recommended = rewards,
		recRows = math.min(4, math.max(2, math.ceil(#rewards / 12))),
		list = list,
		allLabel = L["Обычные: портреты рас, классы и специализации, ваши образы и достижения"],
		locked = locked,
		tooltips = tips,
		borders = borders,
		defaultHint = L["Портрет расы этого персонажа (у союзных рас — иконка класса). Аватар у каждого персонажа свой."],
		current = self.db.avatars[self.Net.Me()],
		onPick = function(fileID)
			self.db.avatars[self.Net.Me()] = fileID -- у каждого персонажа свой
			self:PublishScore(true) -- аватар уходит в сеть вместе с очками рейтинга
			self:NotifyChanged()
		end,
	})
end

function TH:GetRacePortrait(raceID, sex, class)
	local file = raceID and RACE_PORTRAIT[raceID]
	if type(file) == "table" then file = file[sex == 1 and 2 or 1] end
	if not file then
		if type(class) == "string" then return self:GetClassPortrait(class) end
		return "Interface\\Icons\\INV_Misc_QuestionMark"
	end
	return "Interface\\Icons\\" .. file:format(sex == 1 and "female" or "male")
end

function TH:GetClassPortrait(class)
	return "Interface\\Icons\\classicon_" .. class:lower()
end

-- Образы автора в ленте и сводка по ним
-- Рейтинг образа: у своего опубликованного он хранится у сетевой копии
function TH:GetSetRating(set)
	if set.rating then return set.rating end
	local net = set.serverId and self:GetSet(set.serverId)
	return net and net.rating
end

function TH:GetAuthorStats(name)
	local sets, votes, weighted = {}, 0, 0
	-- свой профиль: все свои образы, включая черновики, новые сверху
	if name == self.Net.Me() then
		for _, set in pairs(self.db.mySets) do
			sets[#sets + 1] = set
			local r = self:GetSetRating(set)
			if r and (r.n or 0) > 0 then
				votes = votes + r.n
				weighted = weighted + r.avg * r.n
			end
		end
		table.sort(sets, function(a, b) return (a.created or 0) > (b.created or 0) end)
		return { sets = sets, votes = votes, avg = votes > 0 and weighted / votes or nil, own = true }
	end
	local function Add(set)
		if set.author == name then
			sets[#sets + 1] = set
			local r = set.rating
			if r and (r.n or 0) > 0 then
				votes = votes + r.n
				weighted = weighted + r.avg * r.n
			end
		end
	end
	for _, set in ipairs(self.feed.sets) do Add(set) end
	for _, set in ipairs(self.db.testSets) do Add(set) end -- тестовая лента /thub test
	table.sort(sets, function(a, b) return self:GetScore(a) > self:GetScore(b) end)
	return { sets = sets, votes = votes, avg = votes > 0 and weighted / votes or nil }
end

-- Запись рейтинга очков: место, очки, маска (nil — автор не участвует)
function TH:GetAuthorBoardEntry(name)
	local board, total = self:GetLeaderboard(false, "")
	for _, e in ipairs(board) do
		if e.name == name then return e, total end
	end
	return nil, total
end

local function SplitName(name)
	local char, realm = (name or "?"):match("^([^-]+)%-(.+)$")
	return char or name or "?", realm
end

-- Рамка значка: новое своё — яркая, просмотренное и чужое — приглушённая
local function PaintIconBorder(icon)
	local a = icon.achievement
	local r, g, b = TH:RarityRGB(a.rarity)
	local fresh = icon.has and icon.own and not TH.db.seenAch[a.id]
	icon.border:SetColorTexture(r, g, b, fresh and 0.95 or (icon.has and 0.35 or 0.15))
end

local function ShowIconTooltip(icon)
	local a, p = icon.achievement, icon.profile
	-- навели на новое — оно больше не новое
	if icon.has and icon.own and not TH.db.seenAch[a.id] then
		TH.db.seenAch[a.id] = true
		PaintIconBorder(icon)
	end
	local mineToo = TH.db.achievements[a.id] ~= nil
	-- скрытое раскрываем, только если оно есть и у вас
	local secret = a.hidden and not mineToo
	GameTooltip:SetOwner(icon, "ANCHOR_RIGHT")
	GameTooltip:SetText(TH:RarityHex(a.rarity) .. (secret and L["Скрытое достижение"] or a.name) .. "|r")
	GameTooltip:AddLine(TH:FormatAchievementPoints(a, not icon.own), 0.8, 0.8, 0.8, true)
	GameTooltip:AddLine(secret and a.hint or a.desc, 1, 1, 1, true)
	if icon.own then
		-- свой профиль: одна строка, без «есть у меня» и «есть и у вас»
		local at = TH.db.achievements[a.id]
		if at then
			GameTooltip:AddLine(L["Получено "] .. date("%d.%m.%Y", at), 0.25, 1, 0.25)
		else
			GameTooltip:AddLine(L["Ещё не получено"], 0.6, 0.6, 0.6)
		end
	else
		if icon.has then
			GameTooltip:AddLine(L["Есть у "] .. SplitName(p.name), 0.25, 1, 0.25)
		else
			GameTooltip:AddLine(L["Нет у "] .. SplitName(p.name), 0.6, 0.6, 0.6)
		end
		GameTooltip:AddLine(mineToo and L["Есть и у вас"] or L["У вас нет"], 0.6, 0.8, 1)
	end
	GameTooltip:Show()
end

function TH:BuildProfilePanel(p)
	p.offset = 0

	-- аватар: портрет расы и значок класса
	p.avatar = p:CreateTexture(nil, "ARTWORK")
	p.avatar:SetSize(64, 64)
	p.avatar:SetPoint("TOPLEFT", 14, -12)
	p.avatarBorder = p:CreateTexture(nil, "BORDER")
	p.avatarBorder:SetPoint("TOPLEFT", p.avatar, -2, 2)
	p.avatarBorder:SetPoint("BOTTOMRIGHT", p.avatar, 2, -2)
	p.avatarBorder:Hide() -- рамка только у наградных аватаров
	-- свой профиль: клик по портрету — сменить аватар
	p.avatarBtn = CreateFrame("Button", nil, p)
	p.avatarBtn:SetAllPoints(p.avatar)
	p.avatarBtn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
	p.avatarBtn:SetScript("OnClick", function() TH:OpenAvatarPicker() end)
	p.avatarBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
		GameTooltip:SetText(L["Сменить аватар"])
		GameTooltip:AddLine(L["Его видят другие игроки в вашем профиле и в рейтинге, если вы участвуете в рейтинге очков стиля."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	p.avatarBtn:SetScript("OnLeave", GameTooltip_Hide)

	p.classIcon = p:CreateTexture(nil, "OVERLAY")
	p.classIcon:SetSize(24, 24)
	p.classIcon:SetPoint("BOTTOMRIGHT", p.avatar, 6, -6)

	p.title = p:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	p.title:SetPoint("TOPLEFT", p.avatar, "TOPRIGHT", 14, -4)
	p.realm = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	p.realm:SetPoint("BOTTOMLEFT", p.title, "BOTTOMRIGHT", 8, 2)

	-- титул под именем
	p.titleText = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	p.titleText:SetPoint("TOPLEFT", p.title, "BOTTOMLEFT", 0, -6)
	p.titleText:SetTextColor(0.9, 0.8, 0.5)

	-- подписчики: под титулом
	p.followInfo = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.followInfo:SetPoint("TOPLEFT", p.titleText, "BOTTOMLEFT", 0, -4)
	-- по клику — список подписчиков (подписаться в ответ), в своём профиле и подписки
	p.followInfoBtn = CreateFrame("Button", nil, p)
	p.followInfoBtn:SetPoint("TOPLEFT", p.followInfo, "TOPLEFT", -2, 2)
	p.followInfoBtn:SetPoint("BOTTOMRIGHT", p.followInfo, "BOTTOMRIGHT", 2, -2)
	p.followInfoBtn:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	p.followInfoBtn:SetScript("OnClick", function(b) TH:OpenFollowersMenu(b, p.name) end)
	p.followInfoBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Подписчики"])
		GameTooltip:AddLine(L["Нажмите: кто подписан — можно подписаться в ответ."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	p.followInfoBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- справа: «Назад» в чужом профиле; в своём — аватар и титул
	p.back = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.back)
	p.back:SetSize(130, 22)
	p.back:SetPoint("TOPRIGHT", -10, -10)
	p.back:SetText(L["Назад"])
	p.back:SetScript("OnClick", function() TH.UI:CloseProfile() end)

	p.changeAvatar = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.changeAvatar)
	p.changeAvatar:SetSize(130, 22)
	p.changeAvatar:SetPoint("TOPRIGHT", -10, -10)
	p.changeAvatar:SetText(L["Сменить аватар"])
	p.changeAvatar:SetScript("OnClick", function() TH:OpenAvatarPicker() end)

	p.changeTitle = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.changeTitle)
	p.changeTitle:SetSize(130, 22)
	p.changeTitle:SetPoint("TOPRIGHT", -10, -36)
	p.changeTitle:SetText(L["Титул"])
	p.changeTitle:SetScript("OnClick", function(b) TH:OpenTitleMenu(b) end)

	-- чужой профиль: подписаться (под «Назад»)
	p.followBtn = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.followBtn)
	p.followBtn:SetSize(130, 22)
	p.followBtn:SetPoint("TOPRIGHT", -10, -36)
	p.followBtn:SetScript("OnClick", function() TH:ToggleFollow(p.name) end)
	p.followBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_LEFT")
		GameTooltip:SetText(L["Подписка"])
		GameTooltip:AddLine(L["Новые образы автора — во вкладке «Подписки» и уведомлением. Что присылать — в настройках (шестерёнка вверху)."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	p.followBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- статистика плитками: подпись и крупное число
	p.tiles = {}
	for i, label in ipairs({ L["Образов"], L["Средняя оценка"], L["Оценок получено"], L["Очки стиля"], L["Место в рейтинге"] }) do
		-- плитки между именем и кнопками справа (кнопки занимают ~140 px)
		local x = 340 + (i - 1) * 96
		local cap = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		cap:SetPoint("TOP", p, "TOPLEFT", x + 47, -18)
		cap:SetWidth(94)
		cap:SetWordWrap(false)
		cap:SetText(label)
		local value = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
		value:SetPoint("TOP", cap, "BOTTOM", 0, -6)
		value:SetWidth(94)
		p.tiles[i] = value
	end

	-- образы автора
	p.setsLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	p.setsLabel:SetPoint("TOPLEFT", LIST_X + 4, BODY_Y)

	p.rows = {}
	for i = 1, SET_ROWS do
		local row = CreateFrame("Button", nil, p)
		row:SetSize(LIST_W - 16, SET_ROW_H - 2) -- справа — полоса прокрутки
		row:SetPoint("TOPLEFT", LIST_X, BODY_Y - 20 - (i - 1) * SET_ROW_H)
		row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		row.icon = row:CreateTexture(nil, "ARTWORK")
		row.icon:SetSize(24, 24)
		row.icon:SetPoint("LEFT", 4, 0)
		row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
		row.name:SetWidth(190)
		row.name:SetJustifyH("LEFT")
		row.name:SetWordWrap(false)
		row.rating = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		row.rating:SetPoint("RIGHT", -6, 0)
		row.arrow = row:CreateTexture(nil, "ARTWORK")
		row.arrow:SetSize(14, 14)
		row.arrow:SetPoint("LEFT", 6, 0)
		row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		row:SetScript("OnClick", function(r, mouse)
			if r.char then
				-- заголовок персонажа: ЛКМ — свернуть/развернуть, ПКМ — порядок
				if mouse == "RightButton" then TH:OpenProfileCharMenu(p, r, r.char)
				else TH:ToggleProfileChar(p, r.char) end
				return
			end
			if not r.set then return end
			TH:ProfileSelect(p, r.set.id)
			-- ПКМ: то же меню, что в списке (у своих — опубликовать, удалить, сменить иконку)
			if mouse == "RightButton" then TH.UI:OpenSetMenu(r, r.set.id) end
		end)
		-- персонажей можно перетаскивать за заголовок
		row:RegisterForDrag("LeftButton")
		row:SetScript("OnDragStart", function(r) if r.char then TH:StartProfileCharDrag(p, r.char) end end)
		row:SetScript("OnDragStop", function() TH:StopProfileCharDrag(p) end)
		row:SetScript("OnEnter", function(r)
			if not r.char then return end
			GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
			GameTooltip:SetText(r.char)
			GameTooltip:AddLine(L["ЛКМ — свернуть или развернуть образы персонажа."], 1, 1, 1, true)
			GameTooltip:AddLine(L["Перетащите заголовок, чтобы поднять персонажа выше или опустить ниже. ПКМ — то же через меню."], 1, 1, 1, true)
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:EnableMouseWheel(true)
		row:SetScript("OnMouseWheel", function(_, delta) TH:ScrollProfileSets(p, delta) end)
		p.rows[i] = row
	end
	p.noSets = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	p.noSets:SetPoint("TOPLEFT", LIST_X + 6, BODY_Y - 26)
	p.noSets:SetText(L["Опубликованных образов в вашей базе нет."])


	-- примерка выбранного образа прямо в профиле
	p.view = CreateFrame("Frame", nil, p, "InsetFrameTemplate")
	p.view:SetPoint("TOPLEFT", VIEW_X, BODY_Y)
	p.view:SetSize(VIEW_W, 330) -- под ним название и оценка, ниже кнопка
	p.model = self:CreatePreview(p.view)
	p.model.scene:SetPoint("TOPLEFT", 3, -3)
	p.model.scene:SetPoint("BOTTOMRIGHT", -3, 3)
	p:SetScript("OnShow", function() if p.model.items then p.model:Refresh() end end)

	p.viewName = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	p.viewName:SetPoint("TOP", p.view, "BOTTOM", 0, -8)
	p.viewName:SetWidth(VIEW_W - 8)
	p.viewName:SetJustifyH("CENTER")
	p.viewName:SetWordWrap(false)
	p.viewInfo = p:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	p.viewInfo:SetPoint("TOP", p.viewName, "BOTTOM", 0, -4)
	p.viewInfo:SetWidth(VIEW_W - 8)
	p.viewInfo:SetJustifyH("CENTER")

	p.details = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
	TH.PadButton(p.details)
	p.details:SetSize(VIEW_W, 22)
	p.details:SetPoint("BOTTOMLEFT", VIEW_X, 10)
	p.details:SetText(L["Вещи, оценка и примерка на другой расе"])
	p.details:SetScript("OnClick", function() TH:ProfileOpenList(p) end)

	-- достижения
	p.achLabel = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	p.achLabel:SetPoint("TOPLEFT", ACH_X, BODY_Y)
	p.achLabel:SetWidth(330)
	p.achLabel:SetJustifyH("LEFT")
	p.achMore = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	p.achMore:SetPoint("TOPRIGHT", p, "TOPLEFT", ACH_X + ICON_COLS * (ICON + ICON_GAP), BODY_Y - 2)
	if p.HookScript then p:HookScript("OnSizeChanged", function() TH:LayoutProfileAch(p) end) end

	p.icons = {}
	for i, a in ipairs(self.ACHIEVEMENTS) do
		local col, row = (i - 1) % ICON_COLS, math.floor((i - 1) / ICON_COLS)
		local icon = CreateFrame("Frame", nil, p)
		icon:SetSize(ICON, ICON)
		icon:SetPoint("TOPLEFT", ACH_X + 2 + col * (ICON + ICON_GAP), BODY_Y - 22 - row * (ICON + ICON_GAP))
		icon:EnableMouse(true)
		icon.achievement, icon.profile = a, p
		-- рамка на 1 px за край: между соседними значками остаётся зазор
		icon.border = icon:CreateTexture(nil, "BACKGROUND")
		icon.border:SetPoint("TOPLEFT", -1, 1)
		icon.border:SetPoint("BOTTOMRIGHT", 1, -1)
		icon.tex = icon:CreateTexture(nil, "ARTWORK")
		icon.tex:SetAllPoints()
		icon:SetScript("OnEnter", ShowIconTooltip)
		icon:SetScript("OnLeave", GameTooltip_Hide)
		icon:EnableMouseWheel(true)
		icon:SetScript("OnMouseWheel", function(_, delta) TH:ProfileScrollAch(p, delta) end)
		p.icons[i] = icon
	end
	p.noAch = p:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	p.noAch:SetPoint("TOPLEFT", ACH_X, BODY_Y - 24)
	p.noAch:SetWidth(330)
	p.noAch:SetJustifyH("LEFT")
	p.noAch:SetText(L["Достижения автора неизвестны: он не участвует в рейтинге очков стиля или ещё не заходил в игру с новой версией аддона."])
end

-- Переход к образам в обычном списке (свои — в список «Мои образы» с черновиками)
function TH:ProfileOpenList(p)
	local ui = self.UI
	if p.own then
		ui:SetView("mine")
		if p.selectedId then ui:Select(p.selectedId) end
	else
		ui:ShowAuthorSets(p.name, p.selectedId)
	end
end

function TH:ScrollProfileSets(p, delta)
	p.offset = math.min(math.max(p.offset - delta, 0), math.max(0, #(p.entries or p.sets) - SET_ROWS))
	self:RefreshProfileSets(p)
end

-- Показать образ в примерке профиля: на расе автора
function TH:ProfileSelect(p, setId)
	local set = setId and self:GetSet(setId)
	p.selectedId = set and set.id
	if set then
		local r = self:GetSetRating(set)
		p.viewName:SetText(set.name or L["Без названия"])
		local info = r and (r.n or 0) > 0 and string.format(L["|cffffd100%.1f|r из 5, оценок: %d"], r.avg, r.n) or L["|cff999999нет оценок|r"]
		local tags = self:FormatTags(set.tags)
		if tags ~= "" then info = info .. "  —  " .. tags end
		p.viewInfo:SetText(info)
		local myRace = select(3, UnitRace("player"))
		p.model.raceID = set.race ~= myRace and set.race or nil
		p.model.items = set.items
		p.model:Reload()
	else
		p.viewName:SetText("")
		p.viewInfo:SetText("")
	end
	p.details:SetEnabled(set ~= nil)
	self:RefreshProfileSets(p)
end

---------------------------------------------------------------------------
-- Свой профиль: образы по персонажам (заголовок, сворачивание, порядок)
---------------------------------------------------------------------------
local function ShortName(name)
	local char, realm = SplitName(name)
	local _, myRealm = SplitName(TH.Net.Me())
	if realm and realm ~= myRealm then return char .. " |cff999999- " .. realm .. "|r" end
	return char
end

-- Свои персонажи с образами в сохранённом порядке; новых — в конец (свежие выше),
-- без сохранённого порядка текущий персонаж первый
function TH:GetProfileCharOrder(sets)
	local newest, present = {}, {}
	for _, set in ipairs(sets) do
		local name = set.author or self.Net.Me()
		newest[name] = math.max(newest[name] or 0, set.created or 0)
		present[name] = true
	end
	local order, seen = {}, {}
	for _, name in ipairs(self.db.charOrder) do
		if present[name] and not seen[name] then
			order[#order + 1] = name
			seen[name] = true
		end
	end
	local rest = {}
	for name in pairs(present) do
		if not seen[name] then rest[#rest + 1] = name end
	end
	local me = self.Net.Me()
	table.sort(rest, function(a, b)
		if (a == me) ~= (b == me) then return a == me end
		if newest[a] ~= newest[b] then return newest[a] > newest[b] end
		return a < b
	end)
	for _, name in ipairs(rest) do order[#order + 1] = name end
	return order
end

-- Строки списка: у своего профиля с несколькими персонажами — заголовки и их образы
function TH:BuildProfileEntries(p)
	local entries = {}
	if not p.own then
		for _, set in ipairs(p.sets) do entries[#entries + 1] = { set = set } end
		p.entries, p.grouped = entries, false
		return
	end
	local byChar = {}
	for _, set in ipairs(p.sets) do
		local name = set.author or self.Net.Me()
		byChar[name] = byChar[name] or {}
		table.insert(byChar[name], set)
	end
	p.charOrder = self:GetProfileCharOrder(p.sets)
	p.grouped = #p.charOrder > 1
	for _, name in ipairs(p.charOrder) do
		if p.grouped then entries[#entries + 1] = { char = name, count = #byChar[name], class = byChar[name][1].class } end
		if not p.grouped or not self.db.collapsedChars[name] then
			for _, set in ipairs(byChar[name]) do entries[#entries + 1] = { set = set, indent = p.grouped } end
		end
	end
	p.entries = entries
end

function TH:ToggleProfileChar(p, name)
	self.db.collapsedChars[name] = not self.db.collapsedChars[name] or nil
	self:BuildProfileEntries(p)
	p.offset = math.min(p.offset, math.max(0, #p.entries - SET_ROWS))
	self:RefreshProfileSets(p)
end

-- Поставить персонажа на место index (1 — самый верх)
function TH:MoveProfileChar(p, name, index)
	local order = {}
	for _, n in ipairs(p.charOrder or {}) do
		if n ~= name then order[#order + 1] = n end
	end
	index = math.min(math.max(index, 1), #order + 1)
	table.insert(order, index, name)
	-- сохраняем весь порядок, включая персонажей без образов сейчас (они в конце)
	local saved, seen = {}, {}
	for _, n in ipairs(order) do saved[#saved + 1] = n; seen[n] = true end
	for _, n in ipairs(self.db.charOrder) do
		if not seen[n] then saved[#saved + 1] = n; seen[n] = true end
	end
	self.db.charOrder = saved
	self:BuildProfileEntries(p)
	self:RefreshProfileSets(p)
end

local function CharIndex(p, name)
	for i, n in ipairs(p.charOrder or {}) do
		if n == name then return i end
	end
end

function TH:OpenProfileCharMenu(p, owner, name)
	if not MenuUtil then return end
	local index, count = CharIndex(p, name) or 1, #(p.charOrder or {})
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(name)
		local function Item(text, enabled, to)
			local b = root:CreateButton(text, function() TH:MoveProfileChar(p, name, to) end)
			if not enabled then b:SetEnabled(false) end
		end
		Item(L["В самый верх"], index > 1, 1)
		Item(L["Выше"], index > 1, index - 1)
		Item(L["Ниже"], index < count, index + 1)
		Item(L["В самый низ"], index < count, count)
		root:CreateButton(self.db.collapsedChars[name] and L["Развернуть"] or L["Свернуть"], function() TH:ToggleProfileChar(p, name) end)
	end)
end

-- Перетаскивание: под курсором — строка; персонаж этой строки и есть цель.
-- Тянем вверх — встаём перед ним, вниз — после него. Линия показывает, куда встанем.
local function DragTarget(p)
	if not p.dragChar then return end
	for i, row in ipairs(p.rows) do
		if row:IsShown() and row:IsMouseOver() then
			local e = p.entries[p.offset + i]
			local target = e and (e.char or (e.set and (e.set.author or TH.Net.Me())))
			if target then return target, i end
		end
	end
end

function TH:StartProfileCharDrag(p, name)
	if not p.grouped then return end
	p.dragChar = name
	if not p.dragLine then
		p.dragLine = p:CreateTexture(nil, "OVERLAY")
		p.dragLine:SetColorTexture(1, 0.82, 0, 1)
		p.dragLine:SetHeight(2)
		p.dragWatch = CreateFrame("Frame", nil, p)
	end
	p.dragWatch:SetScript("OnUpdate", function()
		local target = DragTarget(p)
		local from, to = CharIndex(p, p.dragChar), target and CharIndex(p, target)
		p.dragLine:Hide()
		if not (from and to) or from == to then return end
		-- линия: над заголовком цели (вверх) или под последней видимой строкой цели (вниз)
		local anchorRow, below
		for i, row in ipairs(p.rows) do
			local e = p.entries[p.offset + i]
			local owner = e and (e.char or (e.set and (e.set.author or TH.Net.Me())))
			if row:IsShown() and owner == target then
				if to < from then anchorRow = anchorRow or row else anchorRow, below = row, true end
			end
		end
		if not anchorRow then return end
		p.dragLine:ClearAllPoints()
		p.dragLine:SetPoint("LEFT", anchorRow, below and "BOTTOMLEFT" or "TOPLEFT", 0, below and -1 or 1)
		p.dragLine:SetPoint("RIGHT", anchorRow, below and "BOTTOMRIGHT" or "TOPRIGHT", 0, below and -1 or 1)
		p.dragLine:Show()
	end)
end

function TH:StopProfileCharDrag(p)
	local name = p.dragChar
	if not name then return end
	local target = DragTarget(p)
	p.dragChar = nil
	if p.dragWatch then p.dragWatch:SetScript("OnUpdate", nil) end
	if p.dragLine then p.dragLine:Hide() end
	local from, to = CharIndex(p, name), target and CharIndex(p, target)
	if from and to and from ~= to then self:MoveProfileChar(p, name, to) end
end

function TH:RefreshProfileSets(p)
	if not p.entries then self:BuildProfileEntries(p) end
	for i, row in ipairs(p.rows) do
		local e = p.entries[p.offset + i]
		local set = e and e.set
		row.set, row.char = set, e and e.char
		row.arrow:SetShown(row.char ~= nil)
		row.icon:ClearAllPoints()
		row.icon:SetPoint("LEFT", e and e.indent and 16 or 4, 0)
		row.name:SetWidth(e and e.indent and 178 or 190)
		if row.char then
			local collapsed = self.db.collapsedChars[row.char]
			row.arrow:SetTexture(collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
			row.icon:SetTexture(nil)
			local color = e.class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[e.class]
			local text = ShortName(row.char)
			if color and color.WrapTextInColorCode then text = color:WrapTextInColorCode(text) end
			if row.char == self.Net.Me() then text = text .. L[" |cff999999(этот персонаж)|r"] end
			row.name:ClearAllPoints()
			row.name:SetPoint("LEFT", row.arrow, "RIGHT", 6, 0)
			row.name:SetWidth(200)
			row.name:SetText(text)
			row.rating:SetText(string.format("|cff999999%d|r", e.count))
			row.bg:SetColorTexture(1, 1, 1, 0.09)
			row:Show()
		elseif set then
			row.name:ClearAllPoints()
			row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
			local r = self:GetSetRating(set)
			row.icon:SetTexture(self:GetSetIcon(set))
			row.name:SetText(set.name or L["Без названия"])
			if p.own and set.status ~= "published" then
				row.rating:SetText(L["|cff999999черновик|r"])
			else
				row.rating:SetText(r and (r.n or 0) > 0 and string.format("|cffffd100%.1f|r (%d)", r.avg, r.n) or L["|cff999999нет оценок|r"])
			end
			if set.id == p.selectedId then
				row.bg:SetColorTexture(TH:SelColor(0.18))
			else
				row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0.02)
			end
			row:Show()
		else
			row:Hide()
		end
	end
	p.noSets:SetShown(#p.sets == 0)
	if not p.setsBar then
		p.setsBar = TH.CreateScrollBar(p, function(value)
			p.offset = value
			TH:RefreshProfileSets(p)
		end)
		p.setsBar:SetPoint("TOPLEFT", LIST_X + LIST_W - 12, BODY_Y - 20 - 18)
		p.setsBar:SetHeight(SET_ROWS * SET_ROW_H - 2 - 36)
	end
	p.setsBar:Sync(p.offset, #p.entries - SET_ROWS)
end

function TH:RefreshProfile(p, name)
	local changed = p.name ~= name
	if changed then p.offset, p.selectedId = 0, nil end
	p.name = name
	local char, realm = SplitName(name)
	p.title:SetText(char)
	p.realm:SetText(realm or "")

	local stats = self:GetAuthorStats(name)
	p.sets, p.own = stats.sets, stats.own
	self:BuildProfileEntries(p)
	p.offset = math.min(p.offset or 0, math.max(0, #p.entries - SET_ROWS))
	p.setsLabel:SetText(p.own and (p.grouped and L["Мои образы по персонажам (ПКМ — действия)"]
		or L["Мои образы (новые сверху, ПКМ — действия)"]) or L["Образы (лучшие сверху)"])
	p.noSets:SetText(p.own and L["Образов пока нет. Наденьте трансмог и нажмите «Новый образ»."]
		or L["Опубликованных образов в вашей базе нет."])
	p.details:SetText(p.own and L["Вещи, статус и публикация"] or L["Вещи, оценка и примерка на другой расе"])

	-- аватар: раса и пол из последнего образа автора, для себя — свой персонаж
	local look = self:GetAuthorLook(stats.sets)
	local raceID, sex, class = look and look.race, look and look.sex, look and look.class
	if self.db.myChars[name] and name == self.Net.Me() then
		raceID, sex, class = select(3, UnitRace("player")), (UnitSex("player") or 2) - 2, select(2, UnitClass("player"))
	end
	local avatar = self:GetAvatar(name, raceID, sex, class)
	p.avatar:SetTexture(avatar)
	self:PaintAvatarBorder(p.avatarBorder, avatar)
	local isMe = name == self.Net.Me()
	p.avatarBtn:SetShown(isMe)
	p.changeAvatar:SetShown(isMe)
	p.changeTitle:SetShown(isMe)
	p.back:SetShown(not isMe)
	p.name = name
	local canFollow = not self.db.myChars[name]
	p.followBtn:SetShown(canFollow)
	if canFollow then
		p.followBtn:SetText(self:IsFollowing(name) and L["Отписаться"] or L["Подписаться"])
	end
	local followers = self:GetFollowerCount(name)
	local info = L["|cff69ccf0Подписчиков: "] .. followers .. "|r"
	if not canFollow then info = info .. L["  ·  |cff69ccf0подписок: "] .. #self:GetFollowingList() .. "|r" end
	if canFollow and self:FollowsMe(name) then
		info = info .. (self:IsFollowing(name) and L["  ·  |cff40ff40подписка взаимная|r"] or L["  ·  |cff40ff40подписан на вас|r"])
	end
	p.followInfo:SetText(info)
	local classAtlas = class and GetClassAtlas and GetClassAtlas(class:lower())
	-- значок класса не нужен, если аватар и есть иконка класса
	if classAtlas and C_Texture.GetAtlasInfo(classAtlas) and avatar ~= self:GetClassPortrait(class) then
		p.classIcon:SetAtlas(classAtlas)
		p.classIcon:Show()
	else
		p.classIcon:Hide()
	end

	local entry, total = self:GetAuthorBoardEntry(name)
	local dash = "|cff666666—|r"
	p.tiles[1]:SetText(#stats.sets)
	p.tiles[2]:SetText(stats.avg and string.format("|cffffd100%.1f|r", stats.avg) or dash)
	p.tiles[3]:SetText(stats.avg and stats.votes or dash)
	p.tiles[4]:SetText(entry and ("|cffffd100" .. entry.points .. "|r") or dash)
	p.tiles[5]:SetText(entry and string.format(L["%d |cff999999из %d|r"], entry.place, total) or dash)
	p.titleText:SetText(self:GetPlayerTitle(name) or "")

	-- сразу показываем лучший образ
	if changed or not (p.selectedId and self:GetSet(p.selectedId)) then
		self:ProfileSelect(p, stats.sets[1] and stats.sets[1].id)
	else
		self:RefreshProfileSets(p)
	end

	-- достижения: свои — из сохранённых, чужие — по маске из рейтинга
	local mine = self.db.myChars[name]
	local mask = entry and entry.mask
	local known = mine or mask ~= nil
	local has, count, normal = {}, 0, 0
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if mine then has[a.id] = self.db.achievements[a.id] ~= nil else has[a.id] = mask and self.MaskHas(mask, a.num) end
		if not a.shame then
			normal = normal + 1
			if has[a.id] then count = count + 1 end
		end
	end
	p.achLabel:SetText(known and string.format(L["Достижения: %d из %d"], count, normal) or L["Достижения"])

	-- порядок: полученные (редкие впереди), полученные позорные, остальные по редкости,
	-- неполученные скрытые и позорные — в конце
	local function Group(a)
		if has[a.id] then return a.shame and 2 or 1 end
		if a.shame then return 5 end
		if a.hidden then return 4 end
		return 3
	end
	local order = {}
	for i, icon in ipairs(p.icons) do order[i] = icon end
	table.sort(order, function(x, y)
		local a, b = x.achievement, y.achievement
		local ga, gb = Group(a), Group(b)
		if ga ~= gb then return ga < gb end
		if a.rarity ~= b.rarity then
			if ga == 1 then return a.rarity > b.rarity end
			return a.rarity < b.rarity
		end
		return a.num < b.num
	end)
	p.achOrder, p.achKnown = order, known
	if p.achName ~= p.name then p.achOffset, p.achName = 0, p.name end
	for _, icon in ipairs(p.icons) do
		local a = icon.achievement
		icon.has = has[a.id]
		local secret = a.hidden and not self.db.achievements[a.id]
		icon.tex:SetTexture(secret and "Interface\\Icons\\INV_Misc_QuestionMark" or a.texture)
		icon.tex:SetDesaturated(not icon.has)
		local shade = icon.has and 1 or 0.4 -- затемняем, а не делаем прозрачным: рамка не просвечивает
		icon.tex:SetVertexColor(shade, shade, shade)
		icon.own = self.db.myChars[p.name] or p.name == self.Net.Me()
		PaintIconBorder(icon)
	end
	p.noAch:SetShown(not known)
	self:LayoutProfileAch(p)
end

-- Сколько рядов значков помещается в профиле по высоте окна
local function VisibleRows(p)
	local h = p.GetHeight and p:GetHeight()
	if type(h) ~= "number" or h <= 0 then return 9 end
	return math.max(3, math.floor((h + BODY_Y - 22 - 10) / (ICON + ICON_GAP)))
end

-- Значки достижений по рядам; лишние — прокруткой колесом мыши
function TH:LayoutProfileAch(p)
	local order = p.achOrder or {}
	local rows, visible = math.ceil(#order / ICON_COLS), VisibleRows(p)
	p.achOffset = math.min(math.max(p.achOffset or 0, 0), math.max(0, rows - visible))
	for i, icon in ipairs(order) do
		local col, row = (i - 1) % ICON_COLS, math.floor((i - 1) / ICON_COLS) - p.achOffset
		icon:ClearAllPoints()
		icon:SetPoint("TOPLEFT", ACH_X + 2 + col * (ICON + ICON_GAP), BODY_Y - 22 - row * (ICON + ICON_GAP))
		icon:SetShown(p.achKnown and row >= 0 and row < visible)
	end
	if not p.achBar then
		p.achBar = TH.CreateScrollBar(p, function(value)
			p.achOffset = value
			TH:LayoutProfileAch(p)
		end)
		p.achBar:SetPoint("TOPLEFT", ACH_X + 6 + ICON_COLS * (ICON + ICON_GAP), BODY_Y - 22 - 18) -- правее рамок значков
	end
	p.achBar:SetHeight(visible * (ICON + ICON_GAP) - ICON_GAP - 36)
	p.achBar:Sync(p.achOffset, p.achKnown and rows - visible or 0)
	if p.achMore then
		p.achMore:SetText(rows > visible and string.format(L["колесо мыши: ещё рядов — %d"], rows - visible - p.achOffset) or "")
		p.achMore:SetShown(rows > visible and p.achOffset < rows - visible)
	end
end

function TH:ProfileScrollAch(p, delta)
	p.achOffset = (p.achOffset or 0) - delta
	self:LayoutProfileAch(p)
end
