local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Редкость — как у предметов: 0 серое … 5 легендарное
---------------------------------------------------------------------------
TH.RARITY = {
	[-1] = { name = L["Позорное"], points = -50 },
	[0] = { name = L["Низкое"], points = 5 },
	[1] = { name = L["Обычное"], points = 10 },
	[2] = { name = L["Необычное"], points = 15 },
	[3] = { name = L["Редкое"], points = 25 },
	[4] = { name = L["Эпическое"], points = 50 },
	[5] = { name = L["Легендарное"], points = 100 },
	[6] = { name = L["Скрытое"], points = 50 },
}

local FALLBACK_COLORS = {
	[-1] = "|cffff3030", [0] = "|cff9d9d9d", [1] = "|cffffffff", [2] = "|cff1eff00",
	[3] = "|cff0070dd", [4] = "|cffa335ee", [5] = "|cffff8000", [6] = "|cffe6cc80",
}

function TH:RarityHex(q)
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	return c and c.hex or FALLBACK_COLORS[q]
end

function TH:RarityRGB(q)
	if q < 0 then return 1, 0.19, 0.19 end
	local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

---------------------------------------------------------------------------
-- Список достижений
-- stat — откуда брать прогресс (см. GetAchievementStat)
-- rank = true — «место в рейтинге»: выполнено, если место <= goal
-- goal = "races" — число играбельных рас (считается в игре)
-- flavor — шуточная подпись в подсказке
-- num — постоянный номер для передачи по сети: не менять, новым давать следующий
-- shame = true — «позорное»: отнимает очки, снимается, когда условие перестаёт выполняться
-- hidden = true — скрытое: до получения видна только подсказка hint
-- stat = "secret" — скрытое: условие и тексты зашифрованы в Data/Secrets.lua (см. Secret.lua)
-- ref — отсылка к реальному человеку (стример, блогер), см. «Отсылки и языки» ниже:
--   "universal" — его знают все игроки, текст на всех языках про него же;
--   "local" — известен в своей языковой аудитории: здесь нейтральный текст, а в
--   ACH_LOCALE[язык] — своя персона под то же условие
---------------------------------------------------------------------------
TH.ACHIEVEMENTS = {
	-- Серые
	{ id = "save_1", num = 1, rarity = 0, stat = "saved", goal = 1, icon = "INV_Shirt_White_01",
		name = L["Первый выход в свет"], desc = L["Сохраните свой первый образ."],
		flavor = L["Даже Вариан когда-то впервые примерял наплечники. Правда, сразу с волками."] },
	{ id = "race_1", num = 2, rarity = 0, stat = "races", goal = 1, icon = "spell_magic_polymorphrabbit",
		name = L["Свет мой, зеркальце"], desc = L["Примерьте образ на другую расу."],
		flavor = L["Маги Даларана клянутся, что это не превращение. Почти."] },
	{ id = "view_10", num = 3, rarity = 0, stat = "viewed", goal = 10, icon = "INV_Misc_Spyglass_02",
		name = L["Витринный зевака"], desc = L["Посмотрите 10 чужих образов."],
		flavor = L["Ремулос тоже часами разглядывает лес. Ему простительно, он полубог."] },
	{ id = "wowhead_1", num = 4, rarity = 0, stat = "wowhead", goal = 1, icon = "INV_Misc_Book_09",
		name = L["Свериться с летописью"], desc = L["Откройте ссылку на Wowhead."],
		flavor = L["Комментарии под предметом читаются дольше, чем идёт сам рейд."] },
	{ id = "suggest_1", num = 5, rarity = 0, stat = "suggested", goal = 1, icon = "INV_Inscription_Scroll",
		name = L["Глас народа"], desc = L["Предложите новый тег."],
		flavor = L["Уважаемый Совет Тирисфаля, предлагаю тег Кальмар. Аргументы прилагаю."] },
	{ id = "letter_1", num = 98, rarity = 0, stat = "letters", goal = 1, icon = "INV_Letter_15",
		name = L["Письмо в Совет"], desc = L["Отправьте разработчику письмо: идею, ошибку или отзыв."],
		flavor = L["Грифон с конвертом улетел. Ответ придёт с обновлением — грифоны медленные, но честные."] },
	{ id = "report_ok_1", num = 99, rarity = 2, stat = "confirmedReports", goal = 1, icon = "Ability_Hunter_EagleEye",
		name = L["Зоркий глаз"], desc = L["Пожалуйтесь на образ, который модератор затем уберёт."],
		flavor = L["Стражи подиума проверили. Вы были правы. Вы почти всегда правы, но тут — официально."] },
	{ id = "hall_1", num = 103, rarity = 5, stat = "hallOfFame", goal = 1, icon = "INV_Misc_Trophy_Argent",
		name = L["Зал славы"], desc = L["Ваш образ попал в Зал славы: трижды первый в «Лучших» за неделю или 8 недель в топ-10."],
		flavor = L["Статую уже заказали у дворфов Стальгорна. Обещают сходство. Примерно."] },
	{ id = "report_ok_5", num = 100, rarity = 3, stat = "confirmedReports", goal = 5, icon = "INV_Misc_Spyglass_02",
		name = L["Страж порядка"], desc = L["5 ваших жалоб подтверждены: модератор убрал образы."],
		flavor = L["Ложные жалобы отнимают очки, верные — дают. Справедливость любит точность."] },

	-- Белые
	{ id = "save_5", num = 6, rarity = 1, stat = "saved", goal = 5, icon = "Inv_misc_bag_08",
		name = L["Своя гардеробная"], desc = L["Сохраните 5 образов."],
		flavor = L["Мурлоки хранят всё в одной куче. Вы выше этого. Мргл."] },
	{ id = "publish_1", num = 7, rarity = 1, stat = "published", goal = 1, icon = "INV_BannerPVP_01",
		name = L["Дебют на подиуме"], desc = L["Опубликуйте первый образ."],
		flavor = L["Чэнь Буйный Портер поднимает за вас кружку. И ещё одну. И ещё..."] },
	{ id = "vote_10", num = 8, rarity = 1, stat = "votesCast", goal = 10, icon = "INV_Misc_Note_02",
		name = L["Строгий критик"], desc = L["Оцените 10 чужих образов."],
		flavor = L["Вы не готовы! — говорите вы. Но звёзды всё-таки ставите."] },
	{ id = "fav_5", num = 9, rarity = 1, stat = "favorites", goal = 5, icon = "Item_Shop_GiftBox01",
		name = L["Копилка вдохновения"], desc = L["Добавьте 5 образов в избранное."],
		flavor = L["Внутренний гоблин потирает руки: время — деньги, а мода бесценна."] },
	{ id = "tags_10", num = 10, rarity = 1, stat = "tagsUsed", goal = 10, icon = "INV_Misc_Gear_01",
		name = L["Ярлык на всё"], desc = L["Используйте 10 разных тегов в своих образах."],
		flavor = L["Гномы-механики подписывают даже гайки. Вы на верном пути."] },
	{ id = "bnet_1", num = 11, rarity = 1, stat = "bnet", goal = 1, icon = "Spell_Arcane_PortalDalaran",
		name = L["Дальняя связь"], desc = L["Найдите друга Battle.net с аддоном."],
		flavor = L["Камень встреч не нужен: мода путешествует между мирами сама."] },

	-- Зелёные
	{ id = "ratings_10", num = 12, rarity = 2, stat = "ratingsReceived", goal = 10, icon = "achievement_guildperk_honorablemention",
		name = L["Первые аплодисменты"], desc = L["Получите 10 оценок на свои образы."],
		flavor = L["Публика арены Гурубаши аплодирует. Пока что руками, а не камнями."] },
	{ id = "publish_5", num = 13, rarity = 2, stat = "published", goal = 5, icon = "inv_misc_tournaments_banner_human",
		name = L["Завсегдатай подиума"], desc = L["Опубликуйте 5 образов."],
		flavor = L["Вас уже узнают в Штормграде. Стража тоже, но это другая история."] },
	{ id = "race_10", num = 14, rarity = 2, stat = "races", goal = 10, icon = "Spell_Shaman_SpectralTransformation",
		name = L["Тысяча лиц"], desc = L["Примерьте образы на 10 разных рас."],
		flavor = L["Безликие бы позавидовали. Если бы у них было лицо."] },
	{ id = "colors_5", num = 15, rarity = 2, stat = "colors", goal = 5, icon = "UI_LemixGem_White",
		name = L["Все цвета радуги"], desc = L["Используйте 5 разных цветовых тегов."],
		flavor = L["Гномы Гномрегана одобряют. Особенно розовый."] },
	{ id = "hidden_5", num = 16, rarity = 2, stat = "hidden", goal = 5, icon = "Ability_Stealth",
		name = L["Меньше — значит больше"], desc = L["Скройте 5 слотов в одном образе."],
		flavor = L["Друиды называют это единением с природой. Стража Штормграда называет иначе."] },
	{ id = "trend_50", num = 17, rarity = 2, stat = "trendRank", rank = true, goal = 50, icon = "achievement_bg_wineos_underxminutes",
		name = L["Ветер перемен"], desc = L["Попадите в топ-50 «В тренде»."],
		flavor = L["Ветра Пандарии шепчут ваше имя. Ну или это опять Чэнь."] },
	{ id = "view_100", num = 18, rarity = 2, stat = "viewed", goal = 100, icon = "INV_Misc_Spyglass_03",
		name = L["Завсегдатай примерочной"], desc = L["Посмотрите 100 чужих образов."],
		flavor = L["Эфириалы-трансмогрификаторы уже держат для вас отдельное кресло."] },
	{ id = "fav_25", num = 19, rarity = 2, stat = "favorites", goal = 25, icon = "INV_Misc_Book_11",
		name = L["Альбом вдохновения"], desc = L["Добавьте 25 образов в избранное."],
		flavor = L["Хранители Ульдуара записывали всё. Вы — только самое красивое."] },
	{ id = "armor_all", num = 20, rarity = 2, stat = "armorTags", goal = 4, icon = "INV_Chest_Plate06",
		name = L["Ткань, кожа, кольчуга, латы"], desc = L["Используйте все 4 тега типа брони."],
		flavor = L["Паладин в мантии — не ошибка, а заявление."] },
	{ id = "night", num = 21, rarity = 2, stat = "night", goal = 1, icon = "Spell_Nature_Starfall",
		name = L["Ночной дозор"], desc = L["Опубликуйте образ с 0:00 до 5:00."],
		flavor = L["Ночные эльфы называют это время ранним утром."] },

	-- Синие
	{ id = "ratings_100", num = 22, rarity = 3, stat = "ratingsReceived", goal = 100, icon = "achievement_guildperk_everybodysfriend",
		name = L["Народная любовь"], desc = L["Получите 100 оценок на свои образы."],
		flavor = L["Барды Даларана уже сочиняют балладу. Рифму к слову наплечники пока не нашли."] },
	{ id = "five_25", num = 23, rarity = 3, stat = "fiveStars", goal = 25, icon = "spell_holy_surgeoflight",
		name = L["Безупречный вкус"], desc = L["Получите 25 оценок «5 звёзд»."],
		flavor = L["Сильвана одобрительно кивнула. Наверное. Под капюшоном не разобрать."] },
	{ id = "trend_10", num = 24, rarity = 3, stat = "trendRank", rank = true, goal = 10, icon = "Achievement_Quests_Completed_06",
		name = L["На гребне волны"], desc = L["Попадите в топ-10 «В тренде»."],
		flavor = L["Наги завидуют: вы на гребне, а они всё ещё под ним."] },
	{ id = "vote_100", num = 25, rarity = 3, stat = "votesCast", goal = 100, icon = "inv_misc_scrollunrolled01",
		name = L["Член жюри"], desc = L["Оцените 100 чужих образов."],
		flavor = L["Совет Трёх Молотов признал вас экспертом. Единогласно, что для него редкость."] },
	{ id = "save_25", num = 26, rarity = 3, stat = "saved", goal = 25, icon = "inv_chest_cloth_17",
		name = L["Модный дом"], desc = L["Сохраните 25 образов."],
		flavor = L["Отдельная сумка под трансмог? Берите выше: отдельное крыло Каражана."] },
	{ id = "holiday_all", num = 27, rarity = 3, stat = "holidayTags", goal = 4, icon = "INV_Misc_Bag_28_Halloween",
		name = L["Круглый год праздник"], desc = L["Используйте теги всех четырёх праздников."],
		flavor = L["Дедушка Зима, Всадник без головы и Корен Худовар за одним столом. Ненадолго."] },
	{ id = "class_5", num = 28, rarity = 3, stat = "classTags", goal = 5, icon = "Achievement_General_StayClassy",
		name = L["Мастер на все классы"], desc = L["Используйте 5 разных классовых тегов."],
		flavor = L["Рыцарь смерти в мантии жреца? Тралл видел вещи и постраннее."] },
	{ id = "network_500", num = 29, rarity = 3, stat = "network", goal = 500, icon = "INV_Misc_Book_17",
		name = L["Библиотекарь Даларана"], desc = L["Наберите 500 образов в своей базе."],
		flavor = L["Кадгар бы позавидовал такому каталогу. И попросил бы не трогать его полки."] },
	{ id = "hidden_8", num = 30, rarity = 3, stat = "hidden", goal = 8, icon = "Spell_Shadow_Charm",
		name = L["Новое платье короля"], desc = L["Скройте 8 слотов в одном образе."],
		flavor = L["Гаррош тоже считал, что наплечников вполне достаточно."] },

	-- Фиолетовые
	{ id = "ratings_1000", num = 31, rarity = 4, stat = "ratingsReceived", goal = 1000, icon = "Achievement_General_StayClassy",
		name = L["Икона стиля"], desc = L["Получите 1000 оценок на свои образы."],
		flavor = L["Мойра Тауриссан просит автограф. Для Даграна, конечно."] },
	{ id = "top_10", num = 32, rarity = 4, stat = "topRank", rank = true, goal = 10, icon = "achievement_legionpvp2tier3",
		name = L["Галерея героев"], desc = L["Попадите в топ-10 «Лучшие»."],
		flavor = L["Ваш портрет повесили в Зале героев. Рядом с Артасом, но его, кажется, скоро снимут."] },
	{ id = "publish_20", num = 33, rarity = 4, stat = "published", goal = 20, icon = "INV_Helmet_08",
		name = L["Кутюрье Азерота"], desc = L["Опубликуйте 20 образов."],
		flavor = L["Портные Сурамара втайне конспектируют ваши наряды."] },
	{ id = "trend_1", num = 34, rarity = 4, stat = "trendRank", rank = true, goal = 1, icon = "Achievement_LegionPVPTier4",
		name = L["Законодатель моды"], desc = L["Займите 1-е место «В тренде»."],
		flavor = L["Весь Вальдраккен вдруг оделся как вы. Драконы для этого даже приняли облик смертных."] },
	{ id = "colors_all", num = 35, rarity = 4, stat = "colors", goal = 15, icon = "INV_Misc_Gem_Variety_01",
		name = L["Призматическая душа"], desc = L["Используйте все 15 цветовых тегов."],
		flavor = L["Хроматические драконы Нефариана смотрят на вас с уважением. И с подозрением."] },
	{ id = "races_all", num = 36, rarity = 4, stat = "races", goal = "races", icon = "Achievement_Character_Human_Male",
		name = L["Каждой твари по паре"], desc = L["Примерьте образы на все играбельные расы."],
		flavor = L["Даже Ноздорму не видел столько версий одного камзола."] },
	{ id = "five_100", num = 37, rarity = 4, stat = "fiveStars", goal = 100, icon = "Spell_Holy_HolyGuidance",
		name = L["Сияние наару"], desc = L["Получите 100 оценок «5 звёзд»."],
		flavor = L["К'ара светится от восторга. Или это её обычное состояние."] },
	{ id = "vote_500", num = 38, rarity = 4, stat = "votesCast", goal = 500, icon = "INV_Scroll_11",
		name = L["Совет ткачей"], desc = L["Оцените 500 чужих образов."],
		flavor = L["Вы видели больше нарядов, чем аукционист Прибамбасска видел ставок."] },

	-- Оранжевые
	{ id = "top_1", num = 39, rarity = 5, stat = "topRank", rank = true, goal = 1, icon = "spell_holy_guardianspirit",
		name = L["Легенда подиума"], desc = L["Займите 1-е место среди лучших."],
		flavor = L["Говорят, сам Король-лич снял перед вами шлем. А это, между прочим, Шлем Господства."] },
	{ id = "publish_100", num = 40, rarity = 5, stat = "published", goal = 100, icon = "INV_Crown_02",
		name = L["Дом моды Азерота"], desc = L["Опубликуйте 100 образов."],
		flavor = L["Леди Престор заказала у вас платье. Подозрительно большого размера."] },
	{ id = "all", num = 41, rarity = 5, stat = "earned", goal = 0, icon = "achievement_reputation_01",
		name = L["Повелитель гардероба"], desc = L["Получите все остальные достижения."],
		flavor = L["Вы собрали всё. Теперь можно наконец что-нибудь надеть и пойти в рейд."] },

	-- За места в рейтинге
	{ id = "tag_top3", num = 46, rarity = 3, stat = "tagRank", rank = true, goal = 3, icon = "Achievement_BG_topDPS",
		name = L["Призёр"], desc = L["Попадите в тройку лучших по любому тегу."],
		flavor = L["Бронза, серебро или золото — турнир Серебряного союза принимает всех."] },
	{ id = "tag_top1", num = 47, rarity = 4, stat = "tagRank", rank = true, goal = 1, icon = "Achievement_Arena_2v2_7",
		name = L["Чемпион темы"], desc = L["Займите 1-е место по любому тегу."],
		flavor = L["Тралл, бывший гладиатор, аплодирует. Ему ли не знать, каково побеждать на арене."] },
	{ id = "tag_first5", num = 48, rarity = 5, stat = "tagFirsts", goal = 5, icon = "Achievement_Arena_5v5_7",
		name = L["Многогранный талант"], desc = L["Займите 1-е место по 5 разным тегам."],
		flavor = L["Кадгар, Джайна и Кель'тас в одном лице. Только с лучшим вкусом."] },
	{ id = "board_10", num = 49, rarity = 4, stat = "boardRank", rank = true, goal = 10, icon = "Achievement_PVP_A_A",
		name = L["Звёздный состав"], desc = L["Попадите в топ-10 рейтинга очков стиля."],
		flavor = L["Вас пригласили в Совет Шести. Пока что подавать чай."] },
	{ id = "board_1", num = 50, rarity = 5, stat = "boardRank", rank = true, goal = 1, icon = "INV_Crown_01",
		name = L["Первый среди равных"], desc = L["Займите 1-е место в рейтинге очков стиля."],
		flavor = L["Андуин одолжил вам корону. Просил вернуть, когда наиграетесь."] },

	-- Доля лучших — как ключи эпохальных+: реальны и в большой сети, где топ-10 почти недостижим.
	-- goal — процент, minPool — сколько соперников нужно, чтобы процент что-то значил.
	{ id = "pct_top_25", num = 74, rarity = 1, stat = "topPct", goal = 25, minPool = 30, icon = "achievement_challengemode_bronze",
		name = L["Ключ +2"], desc = L["Войдите в топ-25% «Лучших»."],
		flavor = L["Аффиксов почти нет, таймер щедрый. Но это уже не обычный режим."] },
	{ id = "pct_top_10", num = 75, rarity = 2, stat = "topPct", goal = 10, minPool = 50, icon = "achievement_challengemode_silver",
		name = L["Ключ +10"], desc = L["Войдите в топ-10% «Лучших»."],
		flavor = L["Тиранический, Укреплённый — а ваш образ всё равно укладывается в таймер."] },
	{ id = "pct_top_1", num = 76, rarity = 3, stat = "topPct", goal = 1, minPool = 300, icon = "achievement_challengemode_gold",
		name = L["Ключ +20"], desc = L["Войдите в топ-1% «Лучших»."],
		flavor = L["Сундук на три улучшения. Рейтинг Рио смотрит на вас с уважением."] },
	{ id = "pct_top_01", num = 77, rarity = 4, stat = "topPct", goal = 0.1, minPool = 3000, icon = "achievement_challengemode_platinum",
		name = L["Звание сезона"], desc = L["Войдите в топ-0,1% «Лучших»."],
		flavor = L["Как в эпохальном+: звание достаётся лишь 0,1% лучших. Портал в подземелье — по жизни."] },
	{ id = "pct_board_25", num = 78, rarity = 1, stat = "boardPct", goal = 25, minPool = 20, icon = "inv_misc_key_14",
		name = L["Покоритель ключей"], desc = L["Войдите в топ-25% рейтинга очков стиля."],
		flavor = L["Первый сундук сезона. Отсюда начинаются все легенды."] },
	{ id = "pct_board_10", num = 79, rarity = 2, stat = "boardPct", goal = 10, minPool = 50, icon = "inv_misc_key_15",
		name = L["Мастер ключей"], desc = L["Войдите в топ-10% рейтинга очков стиля."],
		flavor = L["Транспорт за ключи получен. Теперь можно и покрасоваться у почтового ящика."] },
	{ id = "pct_board_1", num = 80, rarity = 3, stat = "boardPct", goal = 1, minPool = 300, icon = "inv_relics_hourglass",
		name = L["Герой ключей"], desc = L["Войдите в топ-1% рейтинга очков стиля."],
		flavor = L["Телепорты во все подземелья сезона открыты. Куда идём красоваться?"] },
	{ id = "pct_board_01", num = 81, rarity = 4, stat = "boardPct", goal = 0.1, minPool = 3000, icon = "achievement_featsofstrength_gladiator_08",
		name = L["Легенда ключей"], desc = L["Войдите в топ-0,1% рейтинга очков стиля."],
		flavor = L["О вас пишут в гайдах, а в групповом поиске принимают без вопросов."] },

	-- Рейды: образ с тегом рейда побеждает в своём теге
	{ id = "raid_aotc", num = 82, rarity = 3, stat = "raidTagRank", rank = true, goal = 3, icon = "achievement_boss_lichking",
		name = L["Слава герою подиума"], desc = L["Ваш образ с тегом рейда попал в тройку лучших по этому тегу."],
		flavor = L["Как «Слава герою» за героический рейд: не первые, зато в гильдии есть чем хвастаться."] },
	{ id = "raid_ce", num = 83, rarity = 5, stat = "raidTagRank", rank = true, goal = 1, icon = "inv_120_raid_voidspire_salhadaar",
		name = L["На кромке лезвия"], desc = L["Займите 1-е место по тегу рейда."],
		flavor = L["Как за эпохальный рейд до выхода следующего: успевают только самые быстрые. И самые нарядные."] },

	-- Первооткрыватели: нашли скрытое достижение раньше всех в сети. Таких игроков на всю сеть
	-- единицы (по одному на каждое скрытое), поэтому очков больше, чем у обычных той же редкости.
	{ id = "first_find_1", num = 96, rarity = 4, points = 150, stat = "firstFinds", goal = 1, icon = "INV_Misc_Spyglass_03",
		name = L["Первооткрыватель"], desc = L["Найдите скрытое достижение первым среди всех игроков."],
		flavor = L["Бранн Бронзобород записал ваше имя в дневник. Между «нашёл древний артефакт» и «потерял шляпу»."] },
	{ id = "first_find_3", num = 97, rarity = 5, points = 300, stat = "firstFinds", goal = 3, icon = "INV_Misc_Map02",
		name = L["Картограф тайн"], desc = L["Найдите первым 3 скрытых достижения."],
		flavor = L["Лига исследователей предлагает вам место в совете. И просит не рассказывать, где лежат остальные."] },

	-- Отсылки к стримерам и блогерам — как будто они сами живут в Азероте
	{ id = "hid_asmon", num = 84, rarity = 6, hidden = true, ref = "universal", stat = "secret", goal = 1,
		hint = L["Простой, смешной и цвета старого дивана. Как логово одного великого коллекционера: беспорядок, зато всё под рукой."] },
	{ id = "hid_rwf", num = 85, rarity = 6, hidden = true, ref = "universal", stat = "secret", goal = 1,
		hint = L["Великие гильдии в боевом настрое штурмуют рейд Полночи. Кто-то должен одеть их для победной фотографии."] },
	{ id = "hid_paladin_live", num = 86, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Паладин, Свет и золото: один рыцарь так любит Свет, что ведёт о нём трансляции."] },
	{ id = "hid_blink", num = 87, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Маг, синий лёд и зимний ветер: ледяная стрела, скачок — и вы уже на вершине."] },
	{ id = "hid_lore", num = 88, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Учёный, титаны и звёзды: есть те, кто знает историю Азерота лучше самих титанов."] },

	-- Русскоязычные авторы (ref = "local": в других языках — нейтральный текст)
	{ id = "hid_shout", num = 89, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Страшно, по-боевому и красный от злости: некоторые герои говорят только криком. Зато честно."] },
	{ id = "hid_goldfarm", num = 90, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Золото, манеры аристократа и гоблинские шестерёнки: настоящий наряд стоит очень много золота."] },
	{ id = "hid_tierlist", num = 91, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Классовый комплект, боевая стойка и фиолетовый цвет эпиков: так выглядит первая строчка тир-листа."] },
	{ id = "hid_million", num = 92, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Королевское золото, да потяжелее: наряд, в котором не стыдно пойти в купленный рейд."] },
	{ id = "hid_evergreen", num = 93, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Племенной, зелёный и по-домашнему уютный: самый зелёный голос Оргриммара всегда в эфире."] },

	{ id = "hid_bloodtank", num = 94, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Рыцарь смерти, тяжёлая броня и цвет крови: кто-то должен стоять впереди, когда таймер горит."] },

	{ id = "hid_raidguide", num = 95, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Учёный в рейде Полночи: прежде чем идти на босса, кто-то должен разобрать его по фазам."] },
	{ id = "hid_lunar", num = 101, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Монах, эльф и фиолетовый цвет ночи: кто-то медитирует под луной и знает все тайны Азерота."] },
	{ id = "hid_casualcore", num = 102, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Повседневный, но боевой: в таком не стыдно и в рейд, и за хлебом. Спор казуалов и хардкорщиков вечен."] },
	{ id = "hid_translate", num = 104, rarity = 6, hidden = true, ref = "local", stat = "secret", goal = 1,
		hint = L["Учёный, начертатель и руны: кто-то переводит древние надписи, а кто-то — целые аддоны."] },

	-- Собрано благодаря аддону: облики, которых не было, когда вы увидели их в образе
	{ id = "found_1", num = 61, rarity = 1, stat = "gotFromHub", goal = 1, icon = "INV_Misc_Bag_10",
		name = L["Находка"], desc = L["Соберите облик, который увидели в чужом образе."],
		flavor = L["Увидел, захотел, добыл. Как гоблин на аукционе, только честно."] },
	{ id = "found_25", num = 62, rarity = 2, stat = "gotFromHub", goal = 25, icon = "INV_Misc_Bag_08",
		name = L["Охотник за обликами"], desc = L["Соберите 25 обликов, увиденных в чужих образах."],
		flavor = L["Рексар выслеживает зверей, вы — наплечники. Методы похожи."] },
	{ id = "found_100", num = 63, rarity = 3, stat = "gotFromHub", goal = 100, icon = "INV_Misc_Map_01",
		name = L["Собиратель Азерота"], desc = L["Соберите 100 обликов, увиденных в чужих образах."],
		flavor = L["Брэнн Бронзобород ищет артефакты, вы — штаны. Обоим нравится процесс."] },
	{ id = "found_500", num = 64, rarity = 4, stat = "gotFromHub", goal = 500, icon = "INV_Misc_Book_11",
		name = L["Хранитель гардероба"], desc = L["Соберите 500 обликов, увиденных в чужих образах."],
		flavor = L["Хранители Ульдуара завели бы на вас отдельный архив."] },
	{ id = "complete_1", num = 65, rarity = 2, stat = "setsCompleted", goal = 1, icon = "INV_Chest_Cloth_17",
		name = L["Как на картинке"], desc = L["Соберите целиком образ, найденный в аддоне."],
		flavor = L["Теперь вы выглядите точь-в-точь как автор. Неловко вышло."] },
	{ id = "complete_10", num = 66, rarity = 4, stat = "setsCompleted", goal = 10, icon = "INV_Chest_Plate06",
		name = L["Точная копия"], desc = L["Соберите целиком 10 найденных образов."],
		flavor = L["Бесконечные драконы подозревают, что вы украли облик из другой временной линии."] },
	{ id = "complete_50", num = 67, rarity = 5, stat = "setsCompleted", goal = 50, icon = "INV_Helmet_96",
		name = L["Ходячий каталог"], desc = L["Соберите целиком 50 найденных образов."],
		flavor = L["Любой образ из Transmog Hub — у вас в шкафу. Шкаф размером с Ульдуар."] },

	-- Ваши образы в чужом избранном (разные игроки, по всем образам)
	{ id = "liked_1", num = 68, rarity = 1, stat = "favsReceived", goal = 1, icon = "INV_ValentinePinkRocket",
		name = L["Кому-то понравилось"], desc = L["Ваш образ добавили в избранное."],
		flavor = L["Где-то в Азероте один искатель приключений тихо сказал: хочу так же."] },
	{ id = "liked_10", num = 69, rarity = 2, stat = "favsReceived", goal = 10, icon = "INV_ValentinesBoxOfChocolates02",
		name = L["Поклонники"], desc = L["Ваши образы 10 раз добавили в избранное."],
		flavor = L["У вас появился фан-клуб. Пока он собирается в таверне Златоземья."] },
	{ id = "liked_100", num = 70, rarity = 3, stat = "favsReceived", goal = 100, icon = "INV_Jewelry_Necklace_27",
		name = L["Любимец публики"], desc = L["Ваши образы 100 раз добавили в избранное."],
		flavor = L["Ваши образы обсуждают даже в очереди на аукцион в Оргриммаре."] },
	{ id = "liked_1000", num = 71, rarity = 4, stat = "favsReceived", goal = 1000, icon = "Achievement_General_StayClassy",
		name = L["Муза Азерота"], desc = L["Ваши образы 1000 раз добавили в избранное."],
		flavor = L["Художники Сурамара просят вас попозировать. Платят звёздами и восхищением."] },

	-- Скрытые: условие держится в тайне, видна только подсказка
	{ id = "hid_lichking", num = 51, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Трон в Ледяной Короне пустует. Кто наденет его цвета?"] },
	{ id = "hid_illidan", num = 52, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Повязка на глаза, крылья и пламя цвета весенней травы."] },
	{ id = "hid_bloodsail", num = 53, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["В Пиратской Бухте любят алые паруса и тех, кто под ними ходит."] },
	{ id = "hid_chen", num = 54, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Где-то в Пандарии один мастер ищет идеальный напиток и идеальный наряд к нему."] },
	{ id = "hid_gnome", num = 55, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Шестерёнки, пар и любимый цвет одной невысокой расы."] },
	{ id = "hid_murloc", num = 56, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Мргл мргл мрргл? Мргл."] },
	{ id = "hid_plan", num = 57, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["План был отличный. Пока один паладин не вернулся от холодильника."] },
	{ id = "hid_medivh", num = 58, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["В башне Медива самое интересное начинается, когда часы бьют двенадцать."] },
	{ id = "hid_neighbours", num = 59, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Два народа однажды потеряли дом в один и тот же год. Примерьте на обоих."] },
	{ id = "hid_naked", num = 60, rarity = 6, hidden = true, stat = "secret", goal = 1,
		hint = L["Иногда лучший наряд — тот, которого не видно."] },

	-- Позорные: отнимают очки, пока условие выполняется
	{ id = "shame_troll", num = 42, rarity = -1, shame = true, sticky = true, points = -50, stat = "troll", goal = 1, icon = "Ability_Rogue_Disguise",
		name = L["Тролль под мостом"], desc = L["Из 20+ ваших оценок за 90 дней не меньше 70% — единицы."],
		flavor = L["Даже тролли Зул'Амана ставят хотя бы двойки. Из вежливости."] },
	{ id = "shame_troll_100", num = 43, rarity = -1, shame = true, sticky = true, points = -150, stat = "troll100", goal = 1, icon = "Spell_Shadow_UnholyFrenzy",
		name = L["Повелитель единиц"], desc = L["Из 100+ ваших оценок за 90 дней не меньше 80% — единицы."],
		flavor = L["Дэтвинг тоже был недоволен всем вокруг. Помните, чем кончилось?"] },
	{ id = "shame_blocked", num = 44, rarity = -1, shame = true, points = -50, stat = "blockedSets", goal = 1, icon = "archaeology_5_0_manaclesofrebellion",
		name = L["Под надзором стражи"], desc = L["Ваш образ заблокирован модератором или скрыт из-за жалоб."],
		flavor = L["Стража Штормграда записала вас в журнал. Карандашом, но всё же."] },
	{ id = "shame_cry", num = 72, rarity = -1, shame = true, points = -50, stat = "falseReports", goal = 3, icon = "INV_Misc_Horn_01",
		name = L["Мальчик, который кричал «Мурлок!»"], desc = L["3 ваши жалобы за 90 дней признаны ложными."],
		flavor = L["Стража трижды прибегала в Златоземье. Мурлоков там не было. Были вполне приличные наряды."] },
	{ id = "shame_cry_10", num = 73, rarity = -1, shame = true, points = -150, stat = "falseReports", goal = 10, icon = "Spell_Shadow_SoulLeech_3",
		name = L["Ложный глашатай"], desc = L["10 ваших жалоб за 90 дней признаны ложными."],
		flavor = L["Глашатаи Культа Проклятых и те были честнее."] },
	{ id = "shame_blocked_3", num = 45, rarity = -1, shame = true, points = -150, stat = "blockedSets", goal = 3, icon = "Spell_Shadow_ShadowWordPain",
		name = L["Разыскивается"], desc = L["Заблокировано или скрыто 3 ваших образа."],
		flavor = L["Ваш портрет висит в Штормграде. На доске объявлений, рядом с ворготом-воришкой."] },
}

---------------------------------------------------------------------------
-- Отсылки и языки. Условия достижений одинаковы на всех языках (номер num
-- уходит в сеть), меняется только текст. У «local»-отсылок в каждом языке своя
-- персона: англоязычным — англоязычный стример, русскоязычным — русскоязычный
-- (когда добавим), остальным — нейтральный текст из списка выше. Перевод
-- «universal» — просто перевод, персона та же.
-- ACH_LOCALE[язык][id] = { hint, … } — только то, что отличается. Название и подпись
-- скрытых достижений для каждого языка зашифрованы вместе с ними (Secret.lua).
---------------------------------------------------------------------------
local ACH_LOCALE = {
	enUS = {
		hid_paladin_live = { hint = "Paladin, Light and gold: one knight loves the Light so much he streams it." },
		hid_blink = { hint = "Mage, blue ice and winter wind: frostbolt, blink, and you are already at the top." },
		hid_lore = { hint = "Scholar, titans and stars: some know the history of Azeroth better than the titans themselves." },
		hid_asmon = { hint = "Simple, funny and the color of an old couch, just like Asmongold's den: a mess, but everything is within reach." },
	},
	ruRU = {
		hid_shout = { hint = "Страшно, по-боевому и красный от злости: так один ветеран-блогер спорил с директором игры. Слышно было в Оргриммаре." },
		hid_goldfarm = { hint = "Золото, манеры аристократа и гоблинские шестерёнки: любимое сочетание одного барона аукциона." },
		hid_tierlist = { hint = "Классовый комплект, боевая стойка и фиолетовый цвет эпиков. Как быстро одеться? Смотрите таймовички." },
		hid_million = { hint = "Королевское золото, да потяжелее: наряд для того, кто однажды купил рейд за миллион." },
		hid_lore = { hint = "Учёный, титаны и звёзды: сюжет, который озвучил бы голос тысячи NPC." },
		hid_bloodtank = { hint = "Рыцарь смерти, тяжёлая броня и цвет крови: так одевается один танк, который пушит ключи." },
		hid_raidguide = { hint = "Учёный в рейде Полночи: один знаток уже разобрал этого босса по фазам. И, кажется, ваш наряд тоже." },
		hid_asmon = { hint = "Простой, смешной и цвета старого дивана — как логово Асмонголда: беспорядок, зато всё под рукой." },
		hid_lunar = { hint = "Монах, эльф и фиолетовый цвет ночи: один фиолетовый эльф присматривает за Азеротом и рассказывает его тайны." },
		hid_casualcore = { hint = "Повседневный, но боевой: казуал это или хардкорщик? Один блогер с орком-подкастером так и не договорились." },
		hid_translate = { hint = "Учёный, начертатель и руны: один стример перевёл уже больше трёхсот аддонов — прочитает и ваш образ." },
	},
}
ACH_LOCALE.enGB = ACH_LOCALE.enUS
TH.ACH_LOCALE = ACH_LOCALE

do
	local over = ACH_LOCALE[GetLocale and GetLocale() or ""] or {}
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		for k, v in pairs(over[a.id] or {}) do a[k] = v end
	end
end

-- WoW Forever: тексты без лора дополнений и механик основной игры (ключи, «Слава герою»).
-- nameH — название для Орды (PvP-звания), подставляет TH:ApplyFactionNames().
if TH.FOREVER then
	local FOREVER = {
		save_1 = { flavor = L["Даже юный король Андуин когда-то впервые примерял корону. Болвар помогал застегнуть плащ."] },
		race_10 = { flavor = L["Даже Ониксия меняет облики реже. Хотя ей есть что скрывать."] },
		trend_50 = { flavor = L["Ветра Степей шепчут ваше имя. Ну или это опять кентавры."] },
		view_100 = { flavor = L["Портные Штормграда уже держат для вас отдельный стул."] },
		fav_25 = { flavor = L["Каменные хранители Ульдамана записывали всё. Вы — только самое красивое."] },
		vote_100 = { flavor = L["Король Магни признал вас экспертом. Даже не дожидаясь второй кружки."] },
		holiday_all = { flavor = L["Дедушка Зима, Всадник без головы и хранитель костра солнцеворота за одним столом. Ненадолго."] },
		class_5 = { flavor = L["Воин в мантии жреца? Тралл видел вещи и постраннее."] },
		hidden_8 = { flavor = L["Варвары Альтерака тоже считали, что наплечников вполне достаточно."] },
		publish_20 = { flavor = L["Портные Даларана втайне конспектируют ваши наряды."] },
		trend_1 = { flavor = L["Весь Оргриммар вдруг оделся как вы. Даже Тралл задумался о новом доспехе."] },
		five_100 = { name = L["Благословение Элуны"], flavor = L["Жрицы Луны светятся от восторга. Или это обычный лунный свет."] },
		tag_top3 = { flavor = L["Бронза, серебро или золото — в Пиратской бухте ставки принимают на всё."] },
		complete_10 = { flavor = L["Бронзовые драконы подозревают, что вы украли облик из другой временной линии."] },
		complete_50 = { flavor = L["Любой образ из Transmog Hub — у вас в шкафу. Шкаф размером с Ульдаман."] },
		found_500 = { flavor = L["Хранители Ульдамана завели бы на вас отдельный архив."] },
		liked_1000 = { flavor = L["Скульпторы Стальгорна просят вас попозировать. Платят звёздами и восхищением."] },
		shame_troll = { flavor = L["Даже тролли Зул'Гуруба ставят хотя бы двойки. Из вежливости."] },
		shame_troll_100 = { flavor = L["Дэтвинг тоже был недоволен всем вокруг. Его дети — тоже. Особенно Ониксия."] },
		pct_top_25 = { name = L["Скелетный ключ"], flavor = L["Двери Некроситета открыты. Учёба начинается."] },
		pct_top_10 = { name = L["Ключ от города"], flavor = L["Ворота Стратхольма поддаются. Живые и мёртвые смотрят на ваш наряд."] },
		pct_top_1 = { name = L["Печать Восхождения"], flavor = L["Верхний Пик Черной горы открыт для вас. Драккисат уже поправляет доспех."] },
		pct_top_01 = { name = L["Амулет драконьего огня"], flavor = L["С этим амулетом пускают к самой Ониксии. Говорят, она тоже следит за модой."] },
		pct_board_25 = { name = L["Сержант"], flavor = L["Первые нашивки за честь. Отсюда начинаются все легенды поля боя."] },
		pct_board_10 = { name = L["Рыцарь-капитан"], nameH = L["Легионер"], flavor = L["Звание получено. Теперь можно и покрасоваться у почтового ящика."] },
		pct_board_1 = { name = L["Командор"], nameH = L["Генерал-лейтенант"], flavor = L["Казармы офицеров открыты. Куда идём красоваться?"] },
		pct_board_01 = { name = L["Главнокомандующий"], nameH = L["Верховный вождь"], flavor = L["Высшее звание. О вас поют у костров, а в рейд берут без вопросов."] },
		raid_aotc = { name = L["Голова на воротах"], flavor = L["Как голова Ониксии над воротами столицы: весь город видит, что вы сделали."] },
		raid_ce = { name = L["Первые в мире"], flavor = L["Первыми прошли — первыми и нарядились. Летописцы уже пишут."] },
	}
	-- Подсказки тайн: hint — общая (переводится), hintRU — русская с намёком на блогера
	local HINTS = {
		hid_rwf = { hint = L["Великие гильдии в боевом настрое штурмуют Вершину Хиджала. Кто-то должен одеть их для победной фотографии."] },
		hid_bloodtank = { hint = L["Танк, мех и цвет медвежьей шкуры: кто-то должен стоять впереди, когда босс злится."],
			hintRU = "Танк, мех и цвет медвежьей шкуры: так одевается один медведь, который держит боссов на себе." },
		hid_raidguide = { hint = L["Учёный в Логове Ониксии: прежде чем идти на дракона, кто-то должен разобрать его по фазам."],
			hintRU = "Учёный в Логове Ониксии: прежде чем идти на дракона, кто-то должен разобрать его по фазам." },
		hid_lunar = { hint = L["Ночной эльф, свет и фиолетовый цвет ночи: кто-то смотрит на луну и знает все тайны Азерота."],
			hintRU = "Ночной эльф, свет и фиолетовый цвет ночи: один фиолетовый эльф присматривает за Азеротом и рассказывает его тайны." },
		hid_casualcore = { hintRU = "Повседневный, но боевой: казуал это или хардкорщик? Один блогер поиграл за вас и так и не решил." },
		hid_paladin_live = { hintRU = "Паладин, Свет и золото: один паладин проходит подземелья в одиночку — и ещё успевает красиво выглядеть." },
		hid_shout = { hintRU = "Страшно, по-боевому и красный от злости: так один ветеран-блогер орёт на группу. Слышно было в Оргриммаре." },
		hid_lichking = { hint = L["Король-лич ждёт на Ледяном троне. Кто наденет его цвета?"] },
		hid_chen = { hint = L["Где-то в Азероте один странствующий мастер ищет идеальный напиток и идеальный наряд к нему."] },
		hid_neighbours = { hint = L["Один народ потерял королевство, другой — жизнь, но столица у них одна. Примерьте на обоих."] },
		hid_translate = { hint = L["Учёный, руны и Даларан: кто-то переводит древние надписи, а кто-то — целые аддоны."],
			hintRU = "Учёный, руны и Даларан: один стример перевёл уже больше трёхсот аддонов — прочитает и ваш образ." },
	}
	local ru = GetLocale and GetLocale() == "ruRU"
	for _, a in ipairs(TH.ACHIEVEMENTS) do
		for k, v in pairs(FOREVER[a.id] or {}) do a[k] = v end
		local h = HINTS[a.id]
		if h then a.hint = (ru and h.hintRU) or h.hint or a.hint end
	end
end

-- Названия по фракции игрока (в Forever у Орды свои PvP-звания): и достижения, и титулы
function TH:ApplyFactionNames()
	local horde = UnitFactionGroup and UnitFactionGroup("player") == "Horde"
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if a.nameH then
			a.nameA = a.nameA or a.name
			a.name = horde and a.nameH or a.nameA
		end
	end
	for _, t in ipairs(type(self.TITLES) == "table" and self.TITLES or {}) do
		if t.mH then
			t.mA, t.fA = t.mA or t.m, t.fA or t.f
			t.m, t.f = horde and t.mH or t.mA, horde and t.fH or t.fA
		end
	end
end

local function SetTexture(a)
	-- Если иконки нет в игре, показываем знак вопроса
	local path = "Interface\\Icons\\" .. (a.icon or "INV_Misc_QuestionMark")
	a.texture = GetFileIDFromPath and GetFileIDFromPath(path) and path or "Interface\\Icons\\INV_Misc_QuestionMark"
end

TH.ACHIEVEMENT_BY_ID = {}
for _, a in ipairs(TH.ACHIEVEMENTS) do
	TH.ACHIEVEMENT_BY_ID[a.id] = a
	a.points = a.points or TH.RARITY[a.rarity].points
	if a.stat == "secret" then
		-- пока тайна не открыта: только загадка
		a.name, a.desc, a.flavor, a.icon = L["Скрытое достижение"], a.hint, nil, nil
	end
	SetTexture(a)
end

-- Открыть тексты тайны ключом (ключ запоминается: тексты нужны и после входа)
function TH:ApplySecret(a, key)
	local entry = TransmogHub_Secrets and TransmogHub_Secrets[a.id]
	local fields = entry and key and self.Secret.Open(entry.data, key)
	if not fields then return false end
	-- текст на языке клиента; нет — английский; нет и его — русский (основной)
	local loc = ns.ClientLocale and ns.ClientLocale() or "ruRU"
	for _, k in ipairs({ "name", "desc", "flavor", "icon" }) do
		local v = fields[loc .. "." .. k]
		if (v == nil or v == "") and loc ~= "ruRU" then v = fields["enUS." .. k] end
		if v == nil or v == "" then v = fields[k] end
		if v and v ~= "" then a[k] = v end
	end
	SetTexture(a)
	if self.db then self.db.secretKeys[a.id] = key end
	return true
end

-- Попробовать открыть тайну тем, что есть у игрока; true — условие выполнено
function TH:TrySecret(a, approvedOnly)
	local entry = TransmogHub_Secrets and TransmogHub_Secrets[a.id]
	if not entry then return false end
	local sets = {}
	for _, mine in pairs(self.db.mySets) do
		if not approvedOnly or self:IsSetApproved(mine) then sets[#sets + 1] = mine end
	end
	for _, cond in ipairs(self.Secret.Candidates(entry.probe, sets)) do
		local key = self.Secret.TryCond(a.id, entry, cond)
		if key and self:ApplySecret(a, key) then return true end
	end
	return false
end

-- При входе: открыть тексты уже полученных тайн
function TH:ApplySecrets()
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if a.stat == "secret" then
			local key = self.db.secretKeys[a.id]
			if not (key and self:ApplySecret(a, key)) and self.db.achievements[a.id] then
				self:TrySecret(a, false) -- получено до шифрования: ключ ещё не запомнен
			end
		end
	end
end
-- Достижения за места — сезонные (см. «Сезоны» ниже)
for _, a in ipairs(TH.ACHIEVEMENTS) do
	if a.rank or a.stat == "tagFirsts" then a.seasonal = true end
end

-- порядок сезонных для передачи уровней по сети
TH.SEASONAL_ORDER = {}
for _, a in ipairs(TH.ACHIEVEMENTS) do
	if a.seasonal then TH.SEASONAL_ORDER[#TH.SEASONAL_ORDER + 1] = a end
end
table.sort(TH.SEASONAL_ORDER, function(x, y) return x.num < y.num end)

TH.ACHIEVEMENT_BY_NUM = {}
local normalCount = 0
for _, a in ipairs(TH.ACHIEVEMENTS) do
	TH.ACHIEVEMENT_BY_NUM[a.num] = a
	if not a.shame then normalCount = normalCount + 1 end
end
TH.ACHIEVEMENT_BY_ID.all.goal = normalCount - 1

---------------------------------------------------------------------------
-- Статистика
---------------------------------------------------------------------------
local function CountKeys(t, skipTest)
	local n = 0
	for k, v in pairs(t) do
		if v and not (skipTest and TH:IsTestId(k)) then n = n + 1 end
	end
	return n
end

-- Места в рейтинге имеют смысл только в живой сети: иначе в маленькой
-- сети единственный образ сразу «первый» и даёт легендарное достижение.
-- Соперники — только образы в чарте: с 5+ оценками и без подозрений на накрутку.
local MIN_RATED_SETS = 30 -- образов в чарте

-- Лучшее место моих опубликованных образов в реальной ленте (без тестовых)
-- Место считаем без сортировки: 1 + сколько образов строго выше лучшего своего.
-- Результат зависит только от ленты, поэтому один раз на её пересчёт.
local rankMemo = {}
local function MemoByFeed(key, fn)
	local m = rankMemo[key]
	if not (m and TH.feedGen and m.gen == TH.feedGen) then
		local r1, r2 = fn()
		m = { gen = TH.feedGen, r1, r2 }
		rankMemo[key] = m
	end
	return m[1], m[2]
end

local function RankAmong(sets, value)
	local best
	for _, set in ipairs(sets) do
		if TH:IsMine(set) then
			local v = value(set)
			if not best or v > best then best = v end
		end
	end
	if not best then return nil end
	local above = 0
	for _, set in ipairs(sets) do
		if value(set) > best then above = above + 1 end
	end
	return above + 1
end

local function BestRank(view)
	return MemoByFeed("best:" .. view, function()
		local sets, score = {}, {}
		for _, set in ipairs(TH.feed.sets) do
			if TH:IsCharted(set) then
				sets[#sets + 1] = set
				score[set] = view == "trending" and (set.trend or 0) or TH:GetScore(set)
			end
		end
		if #sets < MIN_RATED_SETS then return nil end
		local rank = RankAmong(sets, function(set) return score[set] end)
		if rank then return rank, #sets end
	end)
end

local MIN_TAG_SETS = 10    -- образов из чарта в теге, чтобы место в нём что-то значило
TH.MIN_TAG_SETS = MIN_TAG_SETS
local MIN_BOARD_PLAYERS = 20 -- игроков в рейтинге очков стиля

-- Лучшее место своего образа по каждому тегу: { [тег] = место }, { [тег] = образов в теге }
local function TagRanks()
	return MemoByFeed("tags", function()
		local byTag, score = {}, {}
		for _, set in ipairs(TH.feed.sets) do
			if TH:IsCharted(set) then
				score[set] = TH:GetScore(set)
				for _, tag in ipairs(TH:GetActiveTags(set)) do
					byTag[tag] = byTag[tag] or {}
					tinsert(byTag[tag], set)
				end
			end
		end
		local ranks, pools = {}, {}
		for tag, sets in pairs(byTag) do
			if #sets >= MIN_TAG_SETS then
				local rank = RankAmong(sets, function(set) return score[set] end)
				if rank then ranks[tag], pools[tag] = rank, #sets end
			end
		end
		return ranks, pools
	end)
end

-- Вид списка достижений: что показывать и порядок
local ACH_SHOW = {
	{ key = "all", text = L["Все"], short = L["все"] },
	{ key = "earned", text = L["Только полученные"], short = L["полученные"] },
	{ key = "missing", text = L["Только не полученные"], short = L["не полученные"] },
}
local ACH_SORT = {
	{ key = "rarity", text = L["По редкости"] },
	{ key = "earned", text = L["Сначала полученные"] },
	{ key = "recent", text = L["Сначала недавно полученные"] },
}

-- Категории достижений (порядок — как в ряду кнопок над карточками)
TH.ACH_CATEGORIES = {
	{ key = "looks", name = L["Образы"], hint = L["Сохранять и публиковать свои образы, теги, цвета, броня."] },
	{ key = "fame", name = L["Признание"], hint = L["Оценки и избранное на ваши образы."] },
	{ key = "viewer", name = L["Зритель"], hint = L["Смотреть и оценивать чужие образы, примерять, делиться."] },
	{ key = "collect", name = L["Коллекция"], hint = L["Собирать облики и целые образы, увиденные в аддоне."] },
	{ key = "rank", name = L["Викли"], hint = L["Еженедельные: места в «Лучших», «В тренде», по тегам и в рейтинге очков стиля. Итоги — раз в неделю."] },
	{ key = "secret", name = L["Тайны"], hint = L["Скрытые достижения и первооткрыватели."] },
	{ key = "shame", name = L["Позорные"], hint = L["Отнимают очки. Снимаются, когда поведение исправилось."] },
}
local STAT_CATEGORY = {
	saved = "looks", published = "looks", tagsUsed = "looks", colors = "looks", classTags = "looks",
	armorTags = "looks", holidayTags = "looks", night = "looks", hidden = "looks", suggested = "looks",
	ratingsReceived = "fame", fiveStars = "fame", favsReceived = "fame",
	viewed = "viewer", votesCast = "viewer", favorites = "viewer", races = "viewer", wowhead = "viewer",
	network = "viewer", bnet = "viewer", letters = "viewer", confirmedReports = "viewer",
	gotFromHub = "collect", setsCompleted = "collect",
	hallOfFame = "rank", topRank = "rank", trendRank = "rank", tagRank = "rank", tagFirsts = "rank", raidTagRank = "rank",
	topPct = "rank", boardPct = "rank", boardRank = "rank",
	secret = "secret", firstFinds = "secret", earned = "secret",
}
TH.STAT_CATEGORY = STAT_CATEGORY

function TH:AchievementCategory(a)
	if a.shame then return "shame" end
	return STAT_CATEGORY[a.stat] or "looks"
end

-- Категории в порядке игрока (перетаскиванием); новых — в конец, по умолчанию — как в списке
function TH:GetAchCategoryOrder()
	local saved = self.db and self.db.achView and self.db.achView.catOrder or {}
	local out, seen, byKey = {}, {}, {}
	for _, c in ipairs(self.ACH_CATEGORIES) do byKey[c.key] = c end
	for _, key in ipairs(saved) do
		if byKey[key] and not seen[key] then out[#out + 1] = byKey[key]; seen[key] = true end
	end
	for _, c in ipairs(self.ACH_CATEGORIES) do
		if not seen[c.key] then out[#out + 1] = c end
	end
	return out
end

-- Поставить категорию на место index (1 — первая после «Все»)
function TH:MoveAchCategory(key, index)
	local order = {}
	for _, c in ipairs(self:GetAchCategoryOrder()) do
		if c.key ~= key then order[#order + 1] = c.key end
	end
	index = math.min(math.max(index, 1), #order + 1)
	table.insert(order, index, key)
	self.db.achView.catOrder = order
end

local function CategoryIndex(key)
	for i, c in ipairs(TH:GetAchCategoryOrder()) do
		if c.key == key then return i end
	end
end

---------------------------------------------------------------------------
-- Сезоны и уровни. Достижения за места (топы образов, теги, рейтинг очков)
-- подводятся раз в неделю — после еженедельного сброса игры — по лучшему за
-- неделю. У каждого пять уровней: чем больше соперников было в том списке,
-- тем выше уровень (обычный, бронза, серебро, золото, бриллиант). Очки растут
-- с уровнем: обычный — четверть очков достижения, серебро — полные, бриллиант — в 4 раза больше.
---------------------------------------------------------------------------
local WEEK = 7 * 86400
local RESET_ANCHOR = 1704254400 -- среда 03.01.2024 04:00 UTC — сброс в Европе

TH.TIER_NAMES = { L["обычный"], L["бронза"], L["серебро"], L["золото"], L["бриллиант"] }
TH.TIER_COLORS = { "|cffffffff", "|cffd28c47", "|cffc0c0c8", "|cffffd100", "|cff7fe0ff" }
-- сколько соперников нужно для уровня: образы в чарте, образы в теге, игроки в рейтинге
local TIER_POOLS = {
	sets = { 30, 100, 300, 1000, 3000 },
	tag = { 10, 30, 100, 300, 1000 },
	board = { 20, 100, 500, 2000, 10000 },
}
local STAT_POOL = { trendRank = "sets", topRank = "sets", tagRank = "tag", tagFirsts = "tag", boardRank = "board",
	raidTagRank = "tag" }

-- Место должно быть заметно выше середины: «топ-50» среди 30 образов — это
-- просто попасть в чарт. Поэтому соперников нужно не меньше, чем место × множитель.
local TIER_RATIO = { 3, 5, 10, 20, 50 }

function TH:GetTierPools(a)
	local base = TIER_POOLS[STAT_POOL[a.stat] or "sets"]
	local goal = a.stat == "tagFirsts" and 1 or (a.goal or 1) -- там goal — число тегов, а не место
	local pools = {}
	for i, need in ipairs(base) do pools[i] = math.max(need, goal * TIER_RATIO[i]) end
	return pools
end

local function TierFor(pools, size)
	local tier = 0
	for i, need in ipairs(pools) do
		if size and size >= need then tier = i end
	end
	return tier
end
TH.TierFor = TierFor

-- Время прошлого и следующего еженедельного сброса
function TH:GetWeeklyReset()
	local now = self.Net.Now()
	local left = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset and C_DateAndTime.GetSecondsUntilWeeklyReset()
	local nextReset
	if left and left > 0 then
		nextReset = now + left
	else
		nextReset = now - (now - RESET_ANCHOR) % WEEK + WEEK
	end
	nextReset = math.floor(nextReset / 3600 + 0.5) * 3600 -- округляем: id сезона не должен «дрожать»
	return nextReset - WEEK, nextReset
end

function TH:GetSeasonPlayers()
	local _, total = self:GetLeaderboard(false, "")
	return total
end

-- Уровни сезонных достижений строкой цифр (по номерам num) — для сети
function TH:EncodeTiers()
	local out = {}
	for _, a in ipairs(self.SEASONAL_ORDER) do out[#out + 1] = tostring(self:GetTier(a)) end
	return (table.concat(out):gsub("0+$", ""))
end

-- Уровень достижения у вас (0 — нет); для несезонных — 1, если получено
function TH:GetTier(a)
	if not a.seasonal then return self.db.achievements[a.id] and 5 or 0 end
	return (self.db.stats.tiers or {})[a.id] or 0
end

-- Очки за уровень: от четверти очков достижения до четырёх раз. Серебро — ровно
-- очки достижения; каждый следующий уровень — в 2 раза больше соперников и очков.
TH.TIER_MULT = { 0.25, 0.5, 1, 2, 4 }

-- Очки достижения с учётом уровня
function TH:GetAchievementPoints(a, tier)
	if not a.seasonal then return a.points end
	tier = tier or self:GetTier(a)
	if tier < 1 then return 0 end
	return math.floor(a.points * self.TIER_MULT[math.min(tier, 5)] + 0.5)
end

-- Строка «редкость, очки» для подсказок: у сезонных очки зависят от уровня
-- rangeOnly — только «от … до …» (для чужого профиля: уровень там не наш)
function TH:FormatAchievementPoints(a, rangeOnly)
	local rarity = self.RARITY[a.rarity].name
	if not a.seasonal then return rarity .. ", " .. a.points .. L[" очков стиля"] end
	local tier = rangeOnly and 0 or self:GetTier(a)
	if tier >= 1 then
		return string.format(L["%s, %d очков стиля (уровень «%s»; от %d до %d)"], rarity, self:GetAchievementPoints(a),
			self.TIER_NAMES[tier], self:GetAchievementPoints(a, 1), self:GetAchievementPoints(a, 5))
	end
	return string.format(L["%s, от %d до %d очков стиля — по уровню"], rarity,
		self:GetAchievementPoints(a, 1), self:GetAchievementPoints(a, 5))
end

-- Какой уровень заработан в этой проверке: по месту и размеру списка
local function SeasonTiers(self, season)
	local results = {}
	local trendRank, trendPool = BestRank("trending")
	local topRank, topPool = BestRank("top")
	local tagRanks, tagPools = TagRanks()
	local board, total = self:GetLeaderboard(false, "")
	local boardRank
	for _, e in ipairs(board) do
		if e.name == self.db.leader.char then boardRank = e.place end
	end
	-- текущие места для достижений «доля лучших»
	self.rankNow = { top = { topRank, topPool }, board = { boardRank, total } }
	for tag, r in pairs(tagRanks) do
		if r == 1 and tagPools[tag] > (season.firsts[tag] or 0) then season.firsts[tag] = tagPools[tag] end
	end
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if a.seasonal then
			local pools, tier = self:GetTierPools(a), 0
			if a.stat == "trendRank" and trendRank and trendRank <= a.goal then
				tier = TierFor(pools, trendPool)
			elseif a.stat == "topRank" and topRank and topRank <= a.goal then
				tier = TierFor(pools, topPool)
			elseif a.stat == "boardRank" and boardRank and boardRank <= a.goal then
				tier = TierFor(pools, total)
			elseif a.stat == "tagRank" or a.stat == "raidTagRank" then
				for tag, r in pairs(tagRanks) do
					if r <= a.goal and (a.stat == "tagRank" or self.RAID_TAGS[tag]) then
						tier = math.max(tier, TierFor(pools, tagPools[tag]))
					end
				end
			elseif a.stat == "tagFirsts" then
				-- уровень — по самому слабому из 5 лучших тегов, где вы первый
				local sizes = {}
				for _, size in pairs(season.firsts) do sizes[#sizes + 1] = size end
				table.sort(sizes, function(x, y) return x > y end)
				if #sizes >= a.goal then tier = TierFor(pools, sizes[a.goal]) end
			end
			results[a.id] = tier
		end
	end
	return results
end

-- Лучшее копится за неделю; после сброса — итоги прошлой недели
function TH:UpdateRankStats()
	local s = self.db.stats
	s.tiers = s.tiers or {}
	-- есть официальный чарт — места и уровни только из него
	local charts = self.GetCharts and self:GetCharts()
	if charts then
		for _, a in ipairs(self.ACHIEVEMENTS) do
			if a.seasonal then
				local tier = self:GetOfficialAward(a)
				if tier > (s.tiers[a.id] or 0) then s.tiers[a.id] = math.min(tier, 5) end
			end
		end
		self:ApplyServerSecrets()
		local topRank, topPool = self:GetMyOfficialRank("top")
		local _, boardPlace = self:GetOfficialBoard(self.db.leader.char or self.Net.Me())
		self.rankNow = { top = { topRank, topPool }, board = { boardPlace, type(charts.board) == "table" and #charts.board or 0 } }
		return
	end
	if not s.seasonsMigrated then
		-- места, засчитанные до сезонов (в маленькой сети), не в счёт
		for _, stat in ipairs({ "trendRank", "topRank", "tagRank", "boardRank" }) do s[stat] = nil end
		s.tagFirsts = {}
		s.seasonsMigrated = true
	end

	local lastReset = self:GetWeeklyReset()
	local season = s.season
	if not season or season.id ~= lastReset or not season.tiers then
		if season and season.tiers and season.id < lastReset then
			local raised = false
			for id, tier in pairs(season.tiers) do
				if tier > (s.tiers[id] or 0) then
					s.tiers[id] = tier
					raised = true
				end
			end
			if raised then self:Print(L["Подведены итоги недели: засчитаны ваши лучшие места за прошлую неделю."]) end
		end
		season = { id = lastReset, tiers = {}, firsts = {} }
		s.season = season
	end

	for id, tier in pairs(SeasonTiers(self, season)) do
		if tier > (season.tiers[id] or 0) then season.tiers[id] = tier end
	end
end

-- «через 2 д 5 ч»
function TH:FormatSeasonLeft()
	local _, nextReset = self:GetWeeklyReset()
	local left = math.max(0, nextReset - self.Net.Now())
	local d, h = math.floor(left / 86400), math.floor(left % 86400 / 3600)
	return d > 0 and string.format(L["%d д %d ч"], d, h) or string.format(L["%d ч"], h)
end

local ARMOR_TAGS = { "a_cloth", "a_leather", "a_mail", "a_plate" }
-- В Forever нет Хмельного фестиваля (тег скрыт): вместо него Огненный солнцеворот
local HOLIDAY_TAGS = TH.FOREVER and { "hallows", "winterveil", "lovefest", "midsummer" }
	or { "hallows", "winterveil", "lovefest", "brewfest" }

local function CountListed(set, keys)
	local n = 0
	for _, k in ipairs(keys) do
		if set[k] then n = n + 1 end
	end
	return n
end

-- Цель достижения (для «всех рас» — сколько рас в игре)
function TH:GetAchievementGoal(a)
	if a.goal == "races" then return math.max(1, #self:GetPlayableRaces()) end
	return a.goal
end

-- Скрытые за теги и название засчитываются только за образ, который понравился
-- игрокам: опубликован, получил 5+ оценок со средней от 3.5 и без подозрений на
-- накрутку. Так их не получить перебором тегов в черновиках.
TH.HIDDEN_MIN_VOTES, TH.HIDDEN_MIN_AVG = 5, 3.5

function TH:IsSetApproved(mine)
	local set = mine and mine.serverId and self.byId and self.byId[mine.serverId]
	local r = set and set.rating
	return r ~= nil and (r.n or 0) >= self.HIDDEN_MIN_VOTES and (r.avg or 0) >= self.HIDDEN_MIN_AVG
		and not self:GetSuspicion(set)
end

function TH:GetAchievementStat(stat, a)
	local s = self.db.stats
	if stat == "saved" then
		return s.saved
	elseif stat == "published" then
		return s.published
	elseif stat == "votesCast" then
		return CountKeys(self.db.myVotes, true)
	elseif stat == "favorites" then
		return CountKeys(self.db.favorites, true)
	elseif stat == "races" then
		local n = 0
		for _, race in ipairs(self:GetPlayableRaces()) do
			if s.races[race.id] then n = n + 1 end
		end
		return math.max(n, CountKeys(s.races) > 0 and 1 or 0)
	elseif stat == "viewed" then
		return CountKeys(s.viewed)
	elseif stat == "confirmedReports" then
		-- жалобы, по которым модератор убрал образ (решением в сети или чёрным списком в обновлении)
		local confirmed = self.db.confirmedReports
		for setId in pairs(self.db.myReports) do
			if not confirmed[setId] and self:IsBlocked({ id = setId }) then confirmed[setId] = true end
		end
		return CountKeys(confirmed)
	elseif stat == "wowhead" or stat == "suggested" or stat == "letters" then
		return s.counts[stat] or 0
	elseif stat == "tagsUsed" then
		return CountKeys(s.tags)
	elseif stat == "armorTags" then
		return CountListed(s.tags, ARMOR_TAGS)
	elseif stat == "holidayTags" then
		return CountListed(s.tags, HOLIDAY_TAGS)
	elseif stat == "classTags" then
		return CountListed(s.tags, self.TAG_THEMES[1].tags)
	elseif stat == "bnet" then
		if self.Net and next(self.Net.bnPeers) then s.bnet = true end
		return s.bnet and 1 or 0
	elseif stat == "night" then
		return s.night and 1 or 0
	elseif stat == "secret" then
		-- за образ — только опубликованный и понравившийся игрокам (см. IsSetApproved)
		return self:TrySecret(a, true) and 1 or 0
	elseif stat == "tagRank" or stat == "boardRank" then
		return s[stat]
	elseif stat == "falseReports" then
		return self:CountFalseReports()
	elseif stat == "favsReceived" then
		local n = 0
		for setId in pairs(self.db.net.favs) do
			if self:IsMine(self.db.net.sets[setId]) then n = n + self:GetFavoriteCount(setId) end
		end
		return n
	elseif stat == "gotFromHub" then
		return CountKeys(s.gotFromHub or {})
	elseif stat == "setsCompleted" then
		return CountKeys(s.setsCompleted or {})
	elseif stat == "tagFirsts" then
		return CountKeys(s.tagFirsts or {})
	elseif stat == "hallOfFame" then
		local n = 0
		for _, set in ipairs(self.feed and self.feed.sets or {}) do
			if self:IsMine(set) and self:GetHallDate(set.id) then n = n + 1 end
		end
		return n
	elseif stat == "firstFinds" then
		local n = 0
		for _, f in pairs(self:GetFirstFinders()) do
			if self.db.myChars[f[1]] or f[1] == self.Net.Me() then n = n + 1 end
		end
		return n
	elseif stat == "network" then
		local n = self.Net and self.Net:SetCount() or 0
		if n > (s.maxNetwork or 0) then s.maxNetwork = n end
		return s.maxNetwork or 0
	elseif stat == "colors" then
		return CountKeys(s.colors)
	elseif stat == "hidden" then
		return s.maxHidden
	elseif stat == "ratingsReceived" then
		local n = 0
		for _, set in ipairs(self.feed.sets) do
			if set.rating and self:IsMine(set) then n = n + (set.rating.n or 0) end
		end
		return n
	elseif stat == "fiveStars" then
		local n = 0
		for setId, votes in pairs(self.db.net.votes) do
			if self:IsMine(self.byId[setId]) then
				for _, v in pairs(votes) do
					if v[1] == 5 then n = n + 1 end
				end
			end
		end
		return n
	elseif stat == "trendRank" or stat == "topRank" then
		return s[stat]
	elseif stat == "earned" then
		local n = 0
		for id in pairs(self.db.achievements) do
			local a = self.ACHIEVEMENT_BY_ID[id]
			if id ~= "all" and a and not a.shame then n = n + 1 end
		end
		return n
	elseif stat == "troll" or stat == "troll100" then
		local votes, ones = self:CountRecentVotes()
		local minVotes, share = 20, 0.7
		if stat == "troll100" then minVotes, share = 100, 0.8 end
		return (votes >= minVotes and ones / votes >= share) and 1 or 0
	elseif stat == "blockedSets" then
		local n = 0
		for _, mine in pairs(self.db.mySets) do
			if mine.serverId then
				local set = self.db.net.sets[mine.serverId] or { id = mine.serverId, author = mine.author }
				-- шуточное название (просят переименовать) позорным не считается
				if (self:IsBlocked(set) and self:GetNameViolation(set.id) ~= "e") or self:IsAutoHidden(set) then n = n + 1 end
			end
		end
		return n
	end
	return 0
end

-- Доля лучших: место, соперники и сколько мест входит в нужный процент
function TH:GetPercentStanding(a)
	local now = self.rankNow and self.rankNow[a.stat == "boardPct" and "board" or "top"]
	local rank, pool = now and now[1], now and now[2] or 0
	return rank, pool, math.max(1, math.floor(pool * a.goal / 100))
end

function TH:IsAchievementMet(a)
	if a.seasonal then return self:GetTier(a) >= 1 end
	if self.GetCharts and self:GetCharts() and self:IsChartAchievement(a) then
		return self:GetOfficialAward(a) > 0
	end
	if a.stat == "topPct" or a.stat == "boardPct" then
		local rank, pool, places = self:GetPercentStanding(a)
		return rank ~= nil and pool >= a.minPool and rank <= places
	end
	local value = self:GetAchievementStat(a.stat, a)
	if a.rank then return value ~= nil and value <= a.goal end
	return (value or 0) >= self:GetAchievementGoal(a)
end

-- Текст прогресса для карточки
function TH:GetAchievementProgress(a)
	if a.shame then return self:IsAchievementMet(a) and L["|cffff3030действует|r"] or L["нет"] end
	if a.hidden then return "???" end
	if a.seasonal then
		local tier = self:GetTier(a)
		if tier >= 1 then return self.TIER_COLORS[tier] .. self.TIER_NAMES[tier] .. "|r" end
		local season = self.db.stats.season
		local now = season and season.tiers and season.tiers[a.id] or 0
		if self.GetCharts and self:GetCharts() then return L["итоги — каждый день"] end
		return now >= 1 and (L["за неделю: "] .. self.TIER_NAMES[now]) or L["итоги — по средам"]
	end
	if a.stat == "topPct" or a.stat == "boardPct" then
		local rank, pool, places = self:GetPercentStanding(a)
		local unit = a.stat == "boardPct" and L["игроков"] or L["образов в чарте"]
		if pool < a.minPool then return string.format(L["%s: %d из %d"], unit, pool, a.minPool) end
		return rank and string.format(L["место %d, нужно %d или выше"], rank, places) or L["пока не в рейтинге"]
	end
	local value = self:GetAchievementStat(a.stat, a)
	if a.rank then
		return value and (L["лучшее место: "] .. value) or L["пока не в рейтинге"]
	end
	local goal = self:GetAchievementGoal(a)
	return string.format("%d / %d", math.min(value or 0, goal), goal)
end

-- Получено обычных, всего обычных, очки (позорные отнимают)
function TH:GetAchievementTotals()
	local earned, points = 0, 0
	for id, _ in pairs(self.db.achievements) do
		local a = self.ACHIEVEMENT_BY_ID[id]
		if a then
			if not a.shame then earned = earned + 1 end
			points = points + self:GetAchievementPoints(a)
		end
	end
	return earned, normalCount, points
end

-- Вызывается после любых действий; новые достижения показываются всплывашкой
function TH:CheckAchievements()
	if not self.db then return end
	self:UpdateRankStats()
	local new = {}
	-- Два прохода: «Повелитель гардероба» зависит от остальных
	local changed = false
	for _ = 1, 2 do
		for _, a in ipairs(self.ACHIEVEMENTS) do
			if not self.db.achievements[a.id] and self:IsAchievementMet(a) then
				self.db.achievements[a.id] = time()
				new[#new + 1] = a
			elseif a.shame and not a.sticky and self.db.achievements[a.id] and not self:IsAchievementMet(a) then
				-- позорное снимается, когда поведение исправилось
				self.db.achievements[a.id] = nil
				changed = true
				self:Print(L["Снято позорное достижение "] .. self:RarityHex(a.rarity) .. "[" .. a.name .. L["]|r. Так держать!"])
			end
		end
	end
	if changed then self:SchedulePublishScore() end
	if self.CheckVotePenalty then self:CheckVotePenalty() end
	if self.CheckStanding then self:CheckStanding() end
	for _, a in ipairs(new) do
		self:ShowAchievementToast(a)
	end
	if #new > 0 then self:SchedulePublishScore() end
	if #new > 0 and self.UI and self.UI.RefreshAchievements then self.UI:RefreshAchievements() end
end

-- Учёт действий для статистики
function TH:TrackSavedSet(set)
	local s = self.db.stats
	s.saved = s.saved + 1
	for _, tag in ipairs(set.tags or {}) do
		if tag:sub(1, 2) == "c_" then s.colors[tag] = true end
		s.tags[tag] = true
	end
	local hidden = 0
	for _, it in pairs(set.items or {}) do
		local d = self:GetSourceDetails(it[1])
		if d and d.hidden then hidden = hidden + 1 end
	end
	if hidden > s.maxHidden then s.maxHidden = hidden end
end

-- Пересчёт по уже сохранённым образам: они могли появиться до того,
-- как аддон начал вести статистику.
function TH:RebuildStatsFromSets()
	local s = self.db.stats
	local saved, published = 0, 0
	for _, set in pairs(self.db.mySets) do
		saved = saved + 1
		if set.serverId or set.status == "pending" or set.status == "published" then
			set.everPublished = true
		end
		if set.everPublished then published = published + 1 end
		for _, tag in ipairs(set.tags or {}) do
			if tag:sub(1, 2) == "c_" then s.colors[tag] = true end
			s.tags[tag] = true
		end
		local hidden = 0
		for _, it in pairs(set.items or {}) do
			local d = self:GetSourceDetails(it[1])
			if d and d.hidden then hidden = hidden + 1 end
		end
		if hidden > s.maxHidden then s.maxHidden = hidden end
	end
	if saved > s.saved then s.saved = saved end
	if published > s.published then s.published = published end
end

-- Счётчики действий: Wowhead, предложенные теги
function TH:TrackCount(name)
	local c = self.db.stats.counts
	c[name] = (c[name] or 0) + 1
	self:CheckAchievements()
end

-- Чего не хватает из увиденного образа: потом проверяем, собрал ли игрок это
local MAX_WANTED = 5000
function TH:TrackWanted(set)
	local s = self.db.stats
	local wanted, count = s.wanted, 0
	for _ in pairs(wanted) do count = count + 1 end
	local have, total = self:GetCollectedStats(set)
	if total == 0 or have == total then return end
	for _, it in pairs(set.items or {}) do
		for i = 1, 2 do
			local d = it[i] and self:GetSourceDetails(it[i])
			if d and not d.hidden and not d.collected and not wanted[it[i]] and not s.gotFromHub[it[i]] and count < MAX_WANTED then
				wanted[it[i]] = true
				count = count + 1
			end
		end
	end
	if not s.setsCompleted[set.id] then s.watchSets[set.id] = true end
end

-- Коллекция изменилась: что из увиденного в аддоне теперь собрано
function TH:CheckCollectedFromHub()
	local s = self.db.stats
	for sourceID in pairs(s.wanted) do
		local d = self:GetSourceDetails(sourceID)
		if d and d.collected then
			s.wanted[sourceID] = nil
			s.gotFromHub[sourceID] = true
		end
	end
	for setId in pairs(s.watchSets) do
		local set = self:GetSet(setId)
		if set then
			local have, total = self:GetCollectedStats(set)
			if total > 0 and have == total then
				s.watchSets[setId] = nil
				s.setsCompleted[setId] = true
			end
		end
	end
	self:CheckAchievements()
end

-- Просмотр чужого образа (свои и тестовые не считаем)
function TH:TrackViewed(set)
	if not set or self:IsMine(set) or self:IsTestId(set.id) then return end
	self:TrackWanted(set)
	local viewed = self.db.stats.viewed
	if viewed[set.id] then return end
	viewed[set.id] = true
	self:CheckAchievements()
end

function TH:TrackRaceTried(raceID)
	if raceID then self.db.stats.races[raceID] = true end
end

---------------------------------------------------------------------------
-- Рейтинг очков стиля. От аккаунта участвует один персонаж (достижения общие
-- на аккаунт); альтов в сети не связываем, чтобы не раскрывать, чьи они.
---------------------------------------------------------------------------
local SCORE_REFRESH = 86400 -- раз в сутки подтверждаем, что мы ещё играем

-- Самое редкое из полученных достижений (позорные не в счёт)
function TH:GetBestAchievement()
	local best
	for id in pairs(self.db.achievements) do
		local a = self.ACHIEVEMENT_BY_ID[id]
		if a and not a.shame and (not best or a.rarity > best.rarity) then best = a end
	end
	return best
end

-- Маска полученных достижений: по 5 штук на символ 0-9a-v, по постоянным номерам
local B32 = "0123456789abcdefghijklmnopqrstuv"

function TH:EncodeAchievementMask()
	local maxNum = 0
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if a.num > maxNum then maxNum = a.num end
	end
	local out = {}
	for chunk = 1, math.ceil(maxNum / 5) do
		local v = 0
		for bit = 0, 4 do
			local a = self.ACHIEVEMENT_BY_NUM[(chunk - 1) * 5 + bit + 1]
			if a and self.db.achievements[a.id] then v = v + 2 ^ bit end
		end
		out[chunk] = B32:sub(v + 1, v + 1)
	end
	return (table.concat(out):gsub("0+$", ""))
end

-- Есть ли у игрока достижение с номером num (по маске)
local function MaskHas(mask, num)
	local chunk = math.floor((num - 1) / 5) + 1
	local ch = mask and mask:sub(chunk, chunk)
	if not ch or ch == "" then return false end
	local v = (B32:find(ch, 1, true) or 1) - 1
	return math.floor(v / 2 ^ ((num - 1) % 5)) % 2 == 1
end
TH.MaskHas = MaskHas

-- У скольких игроков в рейтинге есть каждое достижение: counts[id], всего игроков
function TH:GetAchievementPrevalence()
	local counts, players = {}, 0
	for _, s in pairs(self.db.net.scores) do
		if not s.removed and s.mask then
			players = players + 1
			for _, a in ipairs(self.ACHIEVEMENTS) do
				if MaskHas(s.mask, a.num) then counts[a.id] = (counts[a.id] or 0) + 1 end
			end
		end
	end
	return counts, players
end

function TH:FormatPrevalence(a, counts, players)
	if players == 0 then return nil end
	local n = counts[a.id] or 0
	return string.format(L["есть у %d из %d (%d%%)"], n, players, math.floor(n / players * 100 + 0.5))
end

function TH:IsLeaderChar()
	local leader = self.db.leader
	return not leader.optOut and leader.char == self.Net.Me()
end

---------------------------------------------------------------------------
-- Первооткрыватели. С очками приходит, когда игрок нашёл каждое скрытое
-- достижение (с точностью до часа). Кто раньше всех — первооткрыватель: это
-- видно на карточке у всех, а сам он получает «Первооткрывателя».
---------------------------------------------------------------------------
local FOUND_EPOCH = 1767225600 -- 01.01.2026 UTC: часы считаем от него

local function Pad36(n, width)
	local digits, out = "0123456789abcdefghijklmnopqrstuvwxyz", ""
	for _ = 1, width do
		local d = n % 36
		out = digits:sub(d + 1, d + 1) .. out
		n = math.floor(n / 36)
	end
	return out
end

function TH:EncodeFound()
	local parts = {}
	for _, a in ipairs(self.ACHIEVEMENTS) do
		local at = a.hidden and self.db.achievements[a.id]
		if at then
			local hour = math.min(36 ^ 3 - 1, math.max(0, math.floor((at - FOUND_EPOCH) / 3600)))
			parts[#parts + 1] = Pad36(a.num, 2) .. Pad36(hour, 3)
		end
	end
	table.sort(parts)
	return table.concat(parts)
end

-- { [номер] = время } из строки found
function TH.DecodeFound(found)
	local out = {}
	for i = 1, #(found or "") - 4, 5 do
		local num, hour = tonumber(found:sub(i, i + 1), 36), tonumber(found:sub(i + 2, i + 4), 36)
		if num and hour then out[num] = FOUND_EPOCH + hour * 3600 end
	end
	return out
end

-- [id достижения] = { имя, время } — кто нашёл первым (по известным нам данным)
function TH:GetFirstFinders()
	local firsts = {}
	-- официальные первооткрыватели закреплены навсегда; остальные — по данным сети
	local official = self.GetOfficialFirsts and self:GetOfficialFirsts() or {}
	for id, f in pairs(official) do firsts[id] = { f[1], f[2], official = true } end
	local function Consider(name, num, t)
		local a = self.ACHIEVEMENT_BY_NUM[num]
		if not (a and a.hidden) then return end
		local cur = firsts[a.id]
		if cur and cur.official then return end
		if not cur or t < cur[2] or (t == cur[2] and name < cur[1]) then firsts[a.id] = { name, t } end
	end
	for name, s in pairs(self.db.net.scores) do
		if not s.removed and s.found and s.mask and not self:IsPlayerBlocked(name) and not self:IsBanned(name) then
			for num, t in pairs(self.DecodeFound(s.found)) do
				-- время находки не позже отправки очков и достижение есть в маске
				if t <= (s.t or 0) and self.MaskHas(s.mask, num) then Consider(name, num, t) end
			end
		end
	end
	-- свои находки — сразу, не дожидаясь отправки очков
	local me = self.db.leader.char or self.Net.Me()
	for num, t in pairs(self.DecodeFound(self:EncodeFound())) do Consider(me, num, t) end
	return firsts
end

function TH:PublishScore(force)
	local leader, me = self.db.leader, self.Net.Me()
	if not leader.char then leader.char = me end
	-- этот персонаж раньше был в рейтинге, а теперь нет — убираем его
	if not self:IsLeaderChar() then
		if leader.sent[me] then
			self.Net:SendScore(nil)
			leader.sent[me] = nil
		end
		return
	end
	local earned, _, points = self:GetAchievementTotals()
	local best = self:GetBestAchievement()
	local mask = self:EncodeAchievementMask()
	local title = self:GetMyTitleCode()
	local key = points .. ":" .. earned .. ":" .. (best and best.id or "") .. ":" .. mask .. ":" .. (self.db.avatars[leader.char or ""] or 0)
		.. ":" .. (title or 0) .. ":" .. self:EncodeTiers() .. ":" .. self:EncodeFound()
	if not force and key == leader.last and self.Net.Now() - (leader.sent[me] or 0) < SCORE_REFRESH then return end
	self.Net:SendScore({ points = points, earned = earned, best = best and best.id or "", mask = mask,
		avatar = self.db.avatars[leader.char or ""], title = title, tiers = self:EncodeTiers(), found = self:EncodeFound() })
	leader.last, leader.sent[me] = key, self.Net.Now()
end

function TH:SchedulePublishScore()
	if self.scorePending then return end
	self.scorePending = true
	C_Timer.After(10, function()
		self.scorePending = false
		self:PublishScore()
	end)
end

-- Основной персонаж для рейтинга (по умолчанию — текущий). Очки отправляет
-- только он сам: имя отправителя гарантирует игра, подделать его нельзя.
function TH:SetLeaderChar(name)
	local leader = self.db.leader
	leader.char, leader.optOut = name or self.Net.Me(), false
	self:PublishScore(true)
end

-- Свои персонажи для выбора основного
function TH:GetMyCharacters()
	local list = {}
	for name in pairs(self.db.myChars) do list[#list + 1] = name end
	table.sort(list)
	return list
end

function TH:SetLeaderOptOut(optOut)
	self.db.leader.optOut = optOut and true or false
	if optOut then self:PublishScore() else self:SetLeaderChar() end
end

-- Очки, число и самое редкое достижение — по маске, а не по присланным числам:
-- так «999 очков» без достижений не пройдёт. Неизвестные (из новых версий) не считаем.
-- Очки по маске считаются для каждого игрока таблицы при каждом её показе:
-- результат зависит только от маски и уровней, поэтому запоминаем его
local maskScores = {}
function TH:ScoreFromMask(mask, tiers)
	local key = mask .. "|" .. (tiers or "")
	local c = maskScores[key]
	if c then return c[1], c[2], c[3] end
	local points, earned, best = self:ScoreFromMaskRaw(mask, tiers)
	maskScores[key] = { points, earned, best }
	return points, earned, best
end

function TH:ScoreFromMaskRaw(mask, tiers)
	local tierOf = {}
	for i, a in ipairs(self.SEASONAL_ORDER) do
		tierOf[a.id] = tonumber((tiers or ""):sub(i, i)) or 1 -- без данных об уровне — обычный
	end
	local points, earned, best = 0, 0, nil
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if MaskHas(mask, a.num) then
			points = points + (a.seasonal and self:GetAchievementPoints(a, math.max(1, tierOf[a.id])) or a.points)
			if not a.shame then
				earned = earned + 1
				if not best or a.rarity > best.rarity then best = a end
			end
		end
	end
	return points, earned, best and best.id
end

-- Список рейтинга: { name, points, earned, best, t, place }
function TH:GetLeaderboard(friendsOnly, query)
	local leader, friends = self.db.leader, friendsOnly and self:GetFriendNames()
	query = self.Lower(strtrim(query or ""))
	local list = {}
	for name, s in pairs(self.db.net.scores) do
		-- свои прочие персонажи — старые записи, пока они не убраны из сети
		local stale = self.db.myChars[name] and name ~= leader.char
		local hidden = self.db.hidden[self.PLAYER_REPORT_PREFIX .. name] or self:IsPlayerBlocked(name)
		if not s.removed and not stale and not hidden then
			local points, earned, best = s.points, s.earned, s.best
			if s.mask then points, earned, best = self:ScoreFromMask(s.mask, s.tiers) end
			-- с официальным чартом очки — из него; кого ещё не проверили, ставим ниже
			local unverified
			if self.GetCharts and self:GetCharts() then
				local official = self:GetOfficialBoard(name)
				if official then points = official else unverified = true end
			end
			list[#list + 1] = { name = name, points = points, earned = earned, best = best, t = s.t, mask = s.mask,
				avatar = s.avatar, title = s.title, unverified = unverified }
		end
	end
	table.sort(list, function(a, b)
		if (a.unverified or false) ~= (b.unverified or false) then return not a.unverified end
		if a.points ~= b.points then return a.points > b.points end
		if a.earned ~= b.earned then return a.earned > b.earned end
		return a.t < b.t
	end)
	local out = {}
	for i, e in ipairs(list) do
		e.place = i
		local mine = self.db.myChars[e.name] or e.name == self.Net.Me()
		if (not friends or friends[e.name] or mine) and (query == "" or self.Lower(e.name):find(query, 1, true)) then
			out[#out + 1] = e
		end
	end
	return out, #list
end

---------------------------------------------------------------------------
-- Всплывающее уведомление (вид и место — Toasts.lua и настройки)
---------------------------------------------------------------------------
function TH:ShowAchievementToast(a)
	self:Print((a.shame and L["Получено позорное достижение: "] or L["Получено достижение: "])
		.. self:RarityHex(a.rarity) .. "[" .. a.name .. "]|r")
	local pts = self:GetAchievementPoints(a) -- у сезонных — за полученный уровень
	self:ShowToast("ach", {
		icon = a.texture,
		header = a.shame and L["|cffff3030Позорное достижение|r"] or L["Достижение Transmog Hub"],
		title = self:RarityHex(a.rarity) .. a.name .. "|r",
		text = self.RARITY[a.rarity].name .. ", " .. (pts > 0 and ("|cff40ff40+" .. pts .. "|r") or ("|cffff4040" .. pts .. "|r")) .. L[" очков стиля"],
		color = { self:RarityRGB(a.rarity) },
		sound = SOUNDKIT and SOUNDKIT.ACHIEVEMENT_MENU_OPEN,
		onClick = function() self.UI:OpenAchievements() end,
	})
end

---------------------------------------------------------------------------
-- Вкладка «Достижения»
---------------------------------------------------------------------------
local COLS, CARD_W, CARD_H, GAP = 3, 308, 56, 3

local function ShowCardTooltip(card)
	local a = card.achievement
	if TH.db.achievements[a.id] then TH.db.seenAch[a.id] = true end -- прочитали — в профиле уже не «новое»
	GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
	local secret = a.hidden and not TH.db.achievements[a.id]
	GameTooltip:SetText(TH:RarityHex(a.rarity) .. (secret and L["Скрытое достижение"] or a.name) .. "|r")
	GameTooltip:AddLine(TH:FormatAchievementPoints(a), 0.8, 0.8, 0.8, true)
	if secret then
		GameTooltip:AddLine(L["Условие держится в тайне. Подсказка:"], 1, 1, 1, true)
		GameTooltip:AddLine(a.hint, 0.9, 0.8, 0.5, true)
		local probe = TransmogHub_Secrets and TransmogHub_Secrets[a.id] and TransmogHub_Secrets[a.id].probe
		if probe == "server" or probe == "hidden" then
			GameTooltip:AddLine(string.format(L["Засчитывается за опубликованный образ, когда он получит %d+ оценок со средней от %.1f."],
				TH.HIDDEN_MIN_VOTES, TH.HIDDEN_MIN_AVG), 0.6, 0.8, 1, true)
		end
		if probe == "server" then
			GameTooltip:AddLine(L["Проверяют Стражи подиума раз в день: достижение придёт с обновлением аддона."], 0.6, 0.8, 1, true)
		end
	else
		GameTooltip:AddLine(a.desc, 1, 1, 1, true)
		if a.flavor then GameTooltip:AddLine(a.flavor, 0.9, 0.75, 0.45, true) end
	end
	for _, r in ipairs(TH.AVATAR_REWARDS or {}) do
		if r.ach == a.id then
			GameTooltip:AddLine(L["Награда: аватар «"] .. (secret and "???" or r.name) .. "»", 1, 0.82, 0)
		end
	end
	for _, t in ipairs(TH.TITLES or {}) do
		if t.ach == a.id then
			local female = (UnitSex("player") or 2) == 3
			GameTooltip:AddLine(L["Награда: звание «"] .. (secret and "???" or (female and t.f or t.m)) .. "»", 1, 0.82, 0)
		end
	end
	if a.seasonal then
		GameTooltip:AddLine(" ")
		local board = a.stat == "boardRank"
		local inTag = a.stat == "tagRank" or a.stat == "tagFirsts"
		if TH:GetCharts() then
			GameTooltip:AddLine(L["За место: итоги каждый день по официальному рейтингу (на "] .. TH:FormatChartsDate()
				.. L["), засчитывается лучший уровень. Рейтинг приходит с обновлением аддона."], 0.6, 0.8, 1, true)
		else
			GameTooltip:AddLine(L["Викли (еженедельное): итоги раз в неделю после еженедельного сброса (в Европе — утро среды), по лучшему месту за неделю."], 0.6, 0.8, 1, true)
		end
		GameTooltip:AddLine(board
			and L["Уровень зависит от того, сколько игроков было в рейтинге очков стиля, когда вы заняли место: чем больше соперников, тем ценнее победа."]
			or (L["Уровень зависит от того, сколько образов соревновалось "] .. (inTag and L["в этом теге"] or L["в чарте"])
				.. L[", когда вы заняли место. В чарт попадает любой образ, который получил 5+ оценок от игроков. Самому оценивать ничего не нужно: чем больше сеть, тем ценнее победа."]),
			0.6, 0.8, 1, true)
		local pools, have = TH:GetTierPools(a), TH:GetTier(a)
		local unit = board and L["соперников"] or L["образов-соперников"]
		for i, need in ipairs(pools) do
			local mark = i <= have and "|cff40ff40+|r " or "   "
			GameTooltip:AddLine(string.format(L["%s%s%s|r — если %s %d+ %s, %d очков"], mark, TH.TIER_COLORS[i], TH.TIER_NAMES[i],
				board and L["в рейтинге"] or (inTag and L["в теге"] or L["в чарте"]), need, unit, TH:GetAchievementPoints(a, i)), 1, 1, 1)
		end
		local season = TH.db.stats.season
		local week = season and season.tiers and season.tiers[a.id] or 0
		if not TH:GetCharts() then
			GameTooltip:AddLine(L["Итоги через "] .. TH:FormatSeasonLeft()
				.. (week >= 1 and (L[", на этой неделе: "] .. TH.TIER_NAMES[week]) or ""), 0.6, 0.8, 1, true)
		end
	end
	if a.minPool then
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(string.format(L["Засчитывается, когда %s не меньше %d: иначе процент ничего не значит. Получив, не потеряете."],
			a.stat == "boardPct" and L["в рейтинге очков стиля игроков"] or L["в чарте образов"], a.minPool), 0.6, 0.8, 1, true)
	end
	if a.stat == "raidTagRank" then
		GameTooltip:AddLine(L["Теги рейдов — в окне тегов, тема «Рейды». Отметьте образ тегом рейда, из которого он собран."], 0.6, 0.8, 1, true)
	end
	if a.hidden then
		local first = TH:GetFirstFinders()[a.id]
		if first then
			local mine = TH.db.myChars[first[1]] or first[1] == TH.Net.Me()
			GameTooltip:AddLine(mine and (L["Первооткрыватель — вы! Нашли "] .. date("%d.%m.%Y", first[2]))
				or (L["Первооткрыватель: "] .. first[1]:gsub("%-", " - ", 1) .. ", " .. date("%d.%m.%Y", first[2])), 1, 0.82, 0, true)
		else
			GameTooltip:AddLine(L["Ещё никто не нашёл. Станьте первооткрывателем!"], 1, 0.82, 0, true)
		end
	end
	local counts, players = TH:GetAchievementPrevalence()
	local prevalence = TH:FormatPrevalence(a, counts, players)
	if prevalence then GameTooltip:AddLine(L["Среди игроков в рейтинге: "] .. prevalence, 0.6, 0.8, 1) end
	local earnedAt = TH.db.achievements[a.id]
	if earnedAt then
		GameTooltip:AddLine(L["Получено "] .. date("%d.%m.%Y", earnedAt), 0.25, 1, 0.25)
	else
		GameTooltip:AddLine(L["Прогресс: "] .. TH:GetAchievementProgress(a), 1, 0.82, 0)
	end
	GameTooltip:Show()
end

function TH:BuildAchievementsPanel(panel)
	panel.header = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	panel.header:SetPoint("TOPLEFT", 12, -10)

	panel.cards, panel.offset = {}, 0
	local function Wheel(_, delta) TH:ScrollAchievementsPanel(panel, delta) end
	panel:EnableMouseWheel(true)
	panel:SetScript("OnMouseWheel", Wheel)
	-- карточки — в прокручиваемой области: прокрутка по пикселям, нижний ряд
	-- обрезается краем, поэтому область всегда заполнена до низа
	panel.scroll = CreateFrame("ScrollFrame", nil, panel)
	panel.scroll:SetPoint("TOPLEFT", 0, -60)
	panel.scroll:SetSize(8 + COLS * CARD_W + (COLS - 1) * 6 + 4, 508 - 60 - 6)
	panel.scroll:EnableMouseWheel(true)
	panel.scroll:SetScript("OnMouseWheel", Wheel)
	panel.scrollChild = CreateFrame("Frame", nil, panel.scroll)
	panel.scrollChild:SetSize(8 + COLS * CARD_W + (COLS - 1) * 6 + 4, 1)
	panel.scroll:SetScrollChild(panel.scrollChild)
	-- полоса прокрутки между стрелками (и для карточек, и для рейтинга)
	panel.bar = TH.CreateScrollBar(panel, function(value)
		if panel.mode == "board" then
			panel.board.offset = value
			TH:RefreshLeaderboard(panel)
		else
			panel.offset = value
			TH:LayoutAchievementsPanel(panel, true)
		end
	end)
	panel.bar:SetPoint("TOP", panel, "TOPRIGHT", -15, -60 - 18) -- ниже ряда категорий
	panel.bar:SetPoint("BOTTOM", panel, "BOTTOMRIGHT", -15, 10 + 18)
	panel.up, panel.down = panel.bar.up, panel.bar.down
	panel.bar.step = CARD_H + GAP -- стрелки — на ряд карточек
	panel.pos = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	panel.pos:SetPoint("TOPRIGHT", -12, -12)
	panel.empty = panel:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	panel.empty:SetPoint("CENTER")
	panel.empty:SetText(L["Таких достижений нет."])
	panel.empty:Hide()

	-- переключатель «Мои достижения» / «Рейтинг»
	panel.mode = "cards"
	local function ModeButton(text, mode, x)
		local b = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		TH.PadButton(b)
		b:SetSize(150, 22)
		b:SetPoint("TOPLEFT", x, -6)
		b:SetText(text)
		b:SetScript("OnClick", function()
			panel.mode = mode
			panel.offset = 0
			TH:RefreshAchievementsPanel(panel, panel.lastQuery)
		end)
		return b
	end
	-- справа, вровень с правым краем сетки карточек: [Мои достижения][Рейтинг]  [Показать]
	local GRID_RIGHT = 8 + COLS * CARD_W + (COLS - 1) * 6
	panel.cardsBtn = ModeButton(L["Мои достижения"], "cards", GRID_RIGHT - 190 - 12 - 150 - 4 - 150)
	panel.boardBtn = ModeButton(L["Рейтинг"], "board", GRID_RIGHT - 190 - 12 - 150)
	-- Зал славы — список образов (как вкладка с образами)
	panel.hallBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	TH.PadButton(panel.hallBtn)
	panel.hallBtn:SetSize(120, 22)
	panel.hallBtn:SetPoint("RIGHT", panel.cardsBtn, "LEFT", -4, 0)
	panel.hallBtn:SetText(L["Зал славы"])
	panel.hallBtn:SetScript("OnClick", function() TH.UI:SetView("hall") end)
	panel.hallBtn:SetScript("OnEnter", function(b)
		GameTooltip:SetOwner(b, "ANCHOR_TOP")
		GameTooltip:SetText(L["Зал славы"])
		GameTooltip:AddLine(L["Образы, которые трижды были первыми в «Лучших» за неделю или 8 недель держались в топ-10. Они вне конкурса: мест и наград за места больше не получают, а их авторы — достижение «Зал славы»."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	panel.hallBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- что показывать и в каком порядке
	panel.viewBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	TH.PadButton(panel.viewBtn)
	panel.viewBtn:SetSize(190, 22)
	panel.viewBtn:SetPoint("TOPRIGHT", panel, "TOPLEFT", GRID_RIGHT, -6) -- длинная надпись растёт влево
	panel.viewBtn:SetScript("OnClick", function(btn)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		local view = TH.db.achView
		local function Pick(key, value)
			view[key] = value
			panel.offset = 0
			TH:RefreshAchievementsPanel(panel, panel.lastQuery)
		end
		MenuUtil.CreateContextMenu(btn, function(_, root)
			root:CreateTitle(L["Показывать"])
			for _, o in ipairs(ACH_SHOW) do
				root:CreateRadio(o.text, function() return view.show == o.key end, function() Pick("show", o.key) end)
			end
			root:CreateTitle(L["Порядок"])
			for _, o in ipairs(ACH_SORT) do
				root:CreateRadio(o.text, function() return view.sort == o.key end, function() Pick("sort", o.key) end)
			end
			if view.catOrder and #view.catOrder > 0 then
				root:CreateButton(L["Категории — в исходном порядке"], function()
					view.catOrder = nil
					TH:RefreshAchievementsPanel(panel, panel.lastQuery)
				end)
			end
		end)
	end)
	panel.viewBtn:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(L["Вид"])
		GameTooltip:AddLine(L["Показать все достижения, только полученные или только те, что ещё впереди, и выбрать порядок."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	panel.viewBtn:SetScript("OnLeave", GameTooltip_Hide)

	-- ряд категорий: плоские вкладки одной ширины ровно по сетке карточек;
	-- у выбранной — золотой текст и черта снизу
	panel.catBtns = {}
	local GRID_W = COLS * CARD_W + (COLS - 1) * 6
	local count = #self.ACH_CATEGORIES + 1
	local TAB_GAP = 4
	local tabW = (GRID_W - (count - 1) * TAB_GAP) / count
	panel.tabW, panel.tabGap = tabW, TAB_GAP
	local function CatButton(i, key, hint)
		local b = CreateFrame("Button", nil, panel)
		b:SetSize(tabW, 22)
		b:SetPoint("TOPLEFT", 8 + (i - 1) * (tabW + TAB_GAP), -34)
		b.key = key
		-- вкладки категорий (кроме «Все») перетаскиваются
		if key ~= "all" then
			b:RegisterForDrag("LeftButton")
			b:SetScript("OnDragStart", function() TH:StartAchCategoryDrag(panel, key) end)
			b:SetScript("OnDragStop", function() TH:StopAchCategoryDrag(panel) end)
		end
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.underline = b:CreateTexture(nil, "ARTWORK")
		b.underline:SetColorTexture(1, 0.82, 0, 1)
		b.underline:SetPoint("BOTTOMLEFT")
		b.underline:SetPoint("BOTTOMRIGHT")
		b.underline:SetHeight(2)
		b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.label:SetPoint("LEFT", 4, 1)
		b.label:SetPoint("RIGHT", -4, 1)
		b.label:SetWordWrap(false)
		function b:SetLabel(text) self.label:SetText(text) end
		function b:SetSelected(on)
			self.selected = on
			self.underline:SetShown(on)
			self.bg:SetColorTexture(1, 1, 1, on and 0.10 or 0.04)
			self.label:SetTextColor(on and 1 or 0.75, on and 0.82 or 0.75, on and 0 or 0.75)
		end
		b:SetScript("OnClick", function()
			TH.db.achView.cat = key
			panel.offset = 0
			TH:RefreshAchievementsPanel(panel, panel.lastQuery)
		end)
		b:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_TOP")
			GameTooltip:SetText(btn.title or "")
			GameTooltip:AddLine(hint, 1, 1, 1, true)
			if btn.key ~= "all" then GameTooltip:AddLine(L["Перетащите, чтобы поменять порядок категорий."], 0.6, 0.8, 1, true) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", GameTooltip_Hide)
		panel.catBtns[#panel.catBtns + 1] = b
	end
	CatButton(1, "all", L["Все достижения, по категориям."])
	for i, c in ipairs(self.ACH_CATEGORIES) do CatButton(i + 1, c.key, c.hint) end
	panel.catHeaders = {}

	self:BuildLeaderboard(panel)

	for i, a in ipairs(self.ACHIEVEMENTS) do
		local card = CreateFrame("Frame", nil, panel.scrollChild)
		card:SetSize(CARD_W, CARD_H)
		card:EnableMouse(true)
		card:EnableMouseWheel(true)
		card:SetScript("OnMouseWheel", Wheel)
		card.achievement = a

		card.bg = card:CreateTexture(nil, "BACKGROUND")
		card.bg:SetAllPoints()

		card.stripe = card:CreateTexture(nil, "BORDER")
		card.stripe:SetPoint("TOPLEFT")
		card.stripe:SetPoint("BOTTOMLEFT")
		card.stripe:SetWidth(3)

		card.icon = card:CreateTexture(nil, "ARTWORK")
		card.icon:SetSize(40, 40)
		card.icon:SetPoint("LEFT", 10, 0)
		card.icon:SetTexture(a.texture)

		card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		card.name:SetPoint("TOPLEFT", card.icon, "TOPRIGHT", 8, 0)
		card.name:SetWidth(196) -- справа очки, «до 400» не должно наезжать
		card.name:SetJustifyH("LEFT")
		card.name:SetWordWrap(false)

		card.points = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		card.points:SetPoint("TOPRIGHT", -6, -6)
		card.points:SetText(a.points)

		card.desc = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		card.desc:SetPoint("TOPLEFT", card.name, "BOTTOMLEFT", 0, -2)
		card.desc:SetWidth(250)
		card.desc:SetJustifyH("LEFT")
		card.desc:SetMaxLines(1)
		card.desc:SetText(a.desc)

		-- прогресс справа, но не левее «N% игроков»: длинный обрезается, а не наезжает
		card.progress = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		card.progress:SetPoint("BOTTOMLEFT", 150, 5)
		card.progress:SetPoint("BOTTOMRIGHT", -6, 5)
		card.progress:SetJustifyH("RIGHT")
		card.progress:SetWordWrap(false)

		card.share = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		card.share:SetPoint("BOTTOMLEFT", card.icon, "BOTTOMRIGHT", 8, -1)

		card:SetScript("OnEnter", ShowCardTooltip)
		card:SetScript("OnLeave", GameTooltip_Hide)
		panel.cards[i] = card
	end
end

-- Перетаскивание категории: цель — вкладка или заголовок под курсором.
-- Тянем назад — встаём перед целью, вперёд — после неё. Линия показывает место.
local function AchDragTarget(panel)
	for _, b in ipairs(panel.catBtns) do
		if b.key ~= "all" and b:IsShown() and b:IsMouseOver() then return b.key, b, "tab" end
	end
	for _, h in ipairs(panel.catHeaders) do
		if h:IsShown() and h:IsMouseOver() then return h.key, h, "header" end
	end
end

function TH:StartAchCategoryDrag(panel, key)
	panel.dragCat = key
	if not panel.dragLine then
		panel.dragLine = panel:CreateTexture(nil, "OVERLAY")
		panel.dragLine:SetColorTexture(1, 0.82, 0, 1)
		panel.dragWatch = CreateFrame("Frame", nil, panel)
	end
	panel.dragWatch:SetScript("OnUpdate", function()
		local target, frame, kind = AchDragTarget(panel)
		local from, to = CategoryIndex(panel.dragCat), target and CategoryIndex(target)
		panel.dragLine:Hide()
		if not (from and to) or from == to then return end
		local after = to > from
		panel.dragLine:ClearAllPoints()
		if kind == "tab" then
			panel.dragLine:SetSize(2, 22)
			panel.dragLine:SetPoint(after and "LEFT" or "RIGHT", frame, after and "RIGHT" or "LEFT", after and 1 or -1, 0)
		else
			panel.dragLine:SetHeight(2)
			panel.dragLine:SetPoint("LEFT", frame, "TOPLEFT", 0, 1)
			panel.dragLine:SetPoint("RIGHT", frame, "TOPRIGHT", 0, 1)
		end
		panel.dragLine:Show()
	end)
end

function TH:StopAchCategoryDrag(panel)
	local key = panel.dragCat
	if not key then return end
	local target = AchDragTarget(panel)
	panel.dragCat = nil
	if panel.dragWatch then panel.dragWatch:SetScript("OnUpdate", nil) end
	if panel.dragLine then panel.dragLine:Hide() end
	local from, to = CategoryIndex(key), target and CategoryIndex(target)
	if from and to and from ~= to then
		self:MoveAchCategory(key, to)
		self:RefreshAchievementsPanel(panel, panel.lastQuery)
	end
end

function TH:ScrollAchievementsPanel(panel, delta)
	if panel.mode == "board" then
		local b = panel.board
		b.offset = math.min(math.max(b.offset - delta * 3, 0), math.max(0, #b.list - #b.rows))
		self:RefreshLeaderboard(panel)
		return
	end
	-- колесо — на ряд карточек; смещение в пикселях
	panel.offset = math.min(math.max(panel.offset - delta * (CARD_H + GAP), 0), self:AchievementsMaxOffset(panel))
	self:LayoutAchievementsPanel(panel, true)
end

-- Строки списка карточек: заголовок категории или ряд до COLS карточек
local HEADER_H = 22
local CARDS_HEIGHT = 508 - 60 - 6 -- высота области карточек (панель 508)
local function LineHeight(line) return line.header and HEADER_H or (CARD_H + GAP) end

local function ContentHeight(panel)
	local h = 0
	for _, line in ipairs(panel.lines or {}) do h = h + LineHeight(line) end
	return h
end

function TH:AchievementsMaxOffset(panel)
	return math.max(0, ContentHeight(panel) - CARDS_HEIGHT)
end

-- Заголовок категории в «Все» — кнопка: щелчок сворачивает и разворачивает категорию
local function HeaderLabel(panel, n)
	local h = panel.catHeaders[n]
	if not h then
		h = CreateFrame("Button", nil, panel.scrollChild)
		h:SetSize(COLS * CARD_W + (COLS - 1) * 6, HEADER_H)
		h.arrow = h:CreateTexture(nil, "ARTWORK")
		h.arrow:SetSize(14, 14)
		h.arrow:SetPoint("LEFT", 4, 0)
		h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h.text:SetPoint("LEFT", h.arrow, "RIGHT", 6, 0)
		h.text:SetJustifyH("LEFT")
		h.line = h:CreateTexture(nil, "ARTWORK")
		h.line:SetColorTexture(TH:SelColor(0.25))
		h.line:SetHeight(1)
		h.line:SetPoint("LEFT", h.text, "RIGHT", 8, 0)
		h.line:SetPoint("RIGHT", h, "RIGHT", -4, 0)
		h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
		h:EnableMouseWheel(true)
		h:SetScript("OnMouseWheel", function(_, delta) TH:ScrollAchievementsPanel(panel, delta) end)
		h:SetScript("OnClick", function(btn)
			local collapsed = TH.db.achView.collapsed
			collapsed[btn.key] = not collapsed[btn.key] or nil
			TH:RefreshAchievementsPanel(panel, panel.lastQuery)
		end)
		h:RegisterForDrag("LeftButton")
		h:SetScript("OnDragStart", function(btn) TH:StartAchCategoryDrag(panel, btn.key) end)
		h:SetScript("OnDragStop", function() TH:StopAchCategoryDrag(panel) end)
		h:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_TOP")
			GameTooltip:SetText(TH.db.achView.collapsed[btn.key] and L["Развернуть категорию"] or L["Свернуть категорию"])
			GameTooltip:AddLine(L["Перетащите заголовок, чтобы поменять порядок категорий."], 0.6, 0.8, 1, true)
			GameTooltip:Show()
		end)
		h:SetScript("OnLeave", GameTooltip_Hide)
		panel.catHeaders[n] = h
	end
	return h
end

-- scrollOnly — изменилось только смещение: раскладку не трогаем
function TH:LayoutAchievementsPanel(panel, scrollOnly)
	local board = panel.mode == "board"
	panel.scroll:SetShown(not board)
	if board then
		panel.empty:Hide()
		return
	end
	if not scrollOnly then
		for _, card in ipairs(panel.cards) do card:Hide() end
		for _, h in ipairs(panel.catHeaders) do h:Hide() end
		local y, headers = 0, 0
		for _, line in ipairs(panel.lines or {}) do
			if line.header then
				headers = headers + 1
				local h = HeaderLabel(panel, headers)
				h:ClearAllPoints()
				h:SetPoint("TOPLEFT", 8, y)
				h.key = line.key
				h.text:SetText(line.header)
				h.arrow:SetTexture(line.collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
				h:Show()
			else
				for col, card in ipairs(line.cards) do
					card:ClearAllPoints()
					card:SetPoint("TOPLEFT", 8 + (col - 1) * (CARD_W + 6), y)
					card:Show()
				end
			end
			y = y - LineHeight(line)
		end
		panel.scrollChild:SetHeight(math.max(1, -y))
	end
	local maxOffset = self:AchievementsMaxOffset(panel)
	panel.offset = math.min(math.max(panel.offset or 0, 0), maxOffset)
	panel.scroll:SetVerticalScroll(panel.offset)
	panel.empty:SetShown(#(panel.lines or {}) == 0) -- все свёрнуты — не «пусто»
	panel.bar:Sync(panel.offset, maxOffset)
	panel.up:SetEnabled(panel.offset > 0)
	panel.down:SetEnabled(panel.offset < maxOffset)
	panel.pos:SetText("") -- справа кнопка «Показать»; прокрутка — стрелками и колесом
end

-- Порядок редкости: от низкой к легендарной, потом скрытые, позорные в конце
local function RarityRank(a)
	if a.rarity == -1 then return 100 end
	return a.rarity
end

local function SortCards(cards, mode, earnedAt)
	table.sort(cards, function(x, y)
		local a, b = x.achievement, y.achievement
		local ta, tb = earnedAt[a.id], earnedAt[b.id]
		if mode == "recent" and (ta or tb) and ta ~= tb then
			if ta and tb then return ta > tb end
			return ta ~= nil
		end
		if mode == "earned" and (ta ~= nil) ~= (tb ~= nil) then return ta ~= nil end
		local ra, rb = RarityRank(a), RarityRank(b)
		if ra ~= rb then return ra < rb end
		if (ta ~= nil) ~= (tb ~= nil) then return ta ~= nil end
		return a.num < b.num
	end)
end

-- query — строка поиска: ищем в названии, условии, подписи и редкости
function TH:RefreshAchievementsPanel(panel, query)
	panel.lastQuery = query
	panel.cardsBtn:SetEnabled(panel.mode == "board")
	panel.boardBtn:SetEnabled(panel.mode ~= "board")
	panel.board:SetShown(panel.mode == "board")
	if panel.mode == "board" then
		panel.viewBtn:Hide()
		for _, b in ipairs(panel.catBtns) do b:Hide() end
		self:LayoutAchievementsPanel(panel)
		self:RefreshLeaderboard(panel, query)
		return
	end
	query = self.Lower(strtrim(query or ""))
	if query ~= panel.query then
		panel.query, panel.offset = query, 0
	end
	local view = self.db.achView
	local showText = L["все"]
	for _, o in ipairs(ACH_SHOW) do if o.key == view.show then showText = o.short end end
	panel.viewBtn:SetShown(true)
	panel.viewBtn:SetText(L["Показать: "] .. showText)
	-- категории: число полученных и выбранная кнопка
	local cat = view.cat or "all"
	local got, all = {}, {}
	for _, a in ipairs(self.ACHIEVEMENTS) do
		local c = self:AchievementCategory(a)
		all[c] = (all[c] or 0) + 1
		if self.db.achievements[a.id] then got[c] = (got[c] or 0) + 1 end
	end
	-- «Все» — как в заголовке: без позорных (они не достижения, а штрафы)
	local earnedAll, totalAll = self:GetAchievementTotals()
	local order = self:GetAchCategoryOrder()
	local slot = { all = 1 }
	for i, c in ipairs(order) do slot[c.key] = i + 1 end
	for _, b in ipairs(panel.catBtns) do
		local name, have, total = L["Все"], earnedAll, totalAll
		for _, c in ipairs(self.ACH_CATEGORIES) do
			if c.key == b.key then name, have, total = c.name, got[c.key] or 0, all[c.key] or 0 end
		end
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", 8 + (slot[b.key] - 1) * (panel.tabW + panel.tabGap), -34)
		b.title = name
		b:SetLabel(string.format("%s  |cff8c8c8c%d/%d|r", name, have, total))
		b:SetSelected(b.key == cat)
		b:Show()
	end

	local groups = {}
	for _, card in ipairs(panel.cards) do
		local a = card.achievement
		local have = self.db.achievements[a.id] ~= nil
		local secret = a.hidden and not have
		local hay = secret and self.Lower(a.hint .. " " .. self.RARITY[a.rarity].name)
			or self.Lower(a.name .. " " .. a.desc .. " " .. (a.flavor or "") .. " " .. self.RARITY[a.rarity].name)
		local shown = view.show == "all" or (view.show == "earned") == have
		local c = self:AchievementCategory(a)
		if shown and (cat == "all" or c == cat) and (query == "" or hay:find(query, 1, true)) then
			groups[c] = groups[c] or {}
			table.insert(groups[c], card)
		end
	end
	-- строки: в «Все» — заголовок категории и её карточки, иначе только карточки
	local visible, lines = {}, {}
	for _, c in ipairs(order) do
		local cards = groups[c.key]
		if cards then
			SortCards(cards, view.sort, self.db.achievements)
			-- в «Все» категорию можно свернуть щелчком по заголовку (при поиске — всё развёрнуто)
			local collapsed = cat == "all" and query == "" and view.collapsed[c.key] or false
			if cat == "all" then
				lines[#lines + 1] = { header = string.format("%s  |cff999999%d/%d|r", c.name, got[c.key] or 0, all[c.key] or 0),
					key = c.key, collapsed = collapsed }
			end
			for i = 1, collapsed and 0 or #cards, COLS do
				local row = {}
				for j = i, math.min(i + COLS - 1, #cards) do
					row[#row + 1] = cards[j]
					visible[#visible + 1] = cards[j]
				end
				lines[#lines + 1] = { cards = row }
			end
		end
	end
	panel.visible, panel.lines = visible, lines
	self:LayoutAchievementsPanel(panel)
	local earned, total, points = self:GetAchievementTotals()
	local counts, players = self:GetAchievementPrevalence()
	panel.header:SetText(string.format(L["Получено: %d из %d  —  Очки стиля: %d"], earned, total, points))
	for _, card in ipairs(panel.cards) do
		local a = card.achievement
		local at = self.db.achievements[a.id]
		local r, g, b = self:RarityRGB(a.rarity)
		card.stripe:SetColorTexture(r, g, b, at and 1 or 0.35)
		card.bg:SetColorTexture(r, g, b, at and 0.12 or 0.03)
		card.icon:SetDesaturated(not at)
		card.icon:SetAlpha(at and 1 or 0.4)
		-- Неполученные заметно тусклее, чтобы полученные серые от них отличались
		local secret = a.hidden and not at
		card.name:SetText(at and (self:RarityHex(a.rarity) .. a.name .. "|r")
			or ("|cff5a5a5a" .. (secret and L["Скрытое достижение"] or a.name) .. "|r"))
		card.desc:SetText(secret and a.hint or a.desc)
		card.icon:SetTexture(secret and "Interface\\Icons\\INV_Misc_QuestionMark" or a.texture)
		if at then card.desc:SetTextColor(1, 1, 1) else card.desc:SetTextColor(0.45, 0.45, 0.45) end
		if a.seasonal then
			-- уровень вместо даты, очки — за текущий уровень (или «до N»)
			card.progress:SetText(self:GetAchievementProgress(a))
			local tier = self:GetTier(a)
			card.points:SetText(tier >= 1 and self:GetAchievementPoints(a) or (L["до "] .. self:GetAchievementPoints(a, 5)))
		else
			card.progress:SetText(at and ((a.shame and "|cffff3030" or "|cff40ff40") .. date("%d.%m.%Y", at) .. "|r") or self:GetAchievementProgress(a))
		end
		local n = counts[a.id] or 0
		card.share:SetText(players > 0 and string.format(L["|cff6fa8dc%d%% игроков|r"], math.floor(n / players * 100 + 0.5)) or "")
	end
end

---------------------------------------------------------------------------
-- Экран рейтинга
---------------------------------------------------------------------------
local BOARD_ROWS, BOARD_ROW_H = 15, 24 -- снизу кодекс подиума
local BOARD_LIMIT = 100 -- столько мест в таблице; кто ниже — через поиск
local BOARD_COLS = { -- x, ширина, выравнивание
	place = { 8, 40, "RIGHT" }, name = { 82, 230, "LEFT" }, best = { 320, 300, "LEFT" },
	earned = { 630, 90, "RIGHT" }, points = { 730, 90, "RIGHT" }, t = { 830, 90, "RIGHT" },
}

local function BoardText(parent, col, font)
	local c = BOARD_COLS[col]
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
	fs:SetPoint("LEFT", c[1], 0)
	fs:SetWidth(c[2])
	fs:SetJustifyH(c[3])
	fs:SetWordWrap(false)
	return fs
end

local function ShortName(name)
	local char, realm = name:match("^([^-]+)%-(.+)$")
	return char and (char .. " |cff999999(" .. realm .. ")|r") or name
end

function TH:BuildLeaderboard(panel)
	local b = CreateFrame("Frame", nil, panel)
	panel.board = b
	b:SetPoint("TOPLEFT", 8, -32)
	b:SetPoint("BOTTOMRIGHT", -30, 8)
	b.offset, b.list, b.rows = 0, {}, {}
	b:EnableMouseWheel(true)
	b:SetScript("OnMouseWheel", function(_, delta) TH:ScrollAchievementsPanel(panel, delta) end)
	b:Hide()

	b.friends = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
	b.friends:SetSize(22, 22)
	b.friends:SetPoint("TOPLEFT", 0, 0)
	b.friends:SetScript("OnClick", function() b.offset = 0; TH:RefreshLeaderboard(panel) end)
	local fl = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	fl:SetPoint("LEFT", b.friends, "RIGHT", 2, 0)
	fl:SetText(L["Только друзья"])

	b.me = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.me:SetPoint("LEFT", b.friends, "RIGHT", 120, 0)
	b.me:SetWidth(420)
	b.me:SetJustifyH("LEFT")

	-- выбор основного персонажа
	b.join = CreateFrame("Button", nil, b, "UIPanelButtonTemplate")
	TH.PadButton(b.join)
	b.join:SetSize(200, 22)
	b.join:SetPoint("TOPRIGHT", -150, 0)
	b.join:SetText(L["Основной персонаж"])
	b.join:SetScript("OnClick", function(btn)
		if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
		MenuUtil.CreateContextMenu(btn, function(_, root)
			root:CreateTitle(L["В рейтинге считать на"])
			for _, name in ipairs(TH:GetMyCharacters()) do
				root:CreateRadio(name:gsub("%-", " - ", 1),
					function() return TH.db.leader.char == name end,
					function() TH:SetLeaderChar(name); TH:RefreshLeaderboard(panel) end)
			end
		end)
	end)
	b.join:SetScript("OnEnter", function(btn)
		GameTooltip:SetOwner(btn, "ANCHOR_TOP")
		GameTooltip:SetText(L["Основной персонаж"])
		GameTooltip:AddLine(L["Достижения общие на аккаунт, поэтому в рейтинге участвует один ваш персонаж. Выберите, какой. Очки отправляет только он сам, когда вы им играете: так в рейтинге нельзя выдать себя за другого."], 1, 1, 1, true)
		GameTooltip:Show()
	end)
	b.join:SetScript("OnLeave", GameTooltip_Hide)

	b.optOut = CreateFrame("CheckButton", nil, b, "UICheckButtonTemplate")
	b.optOut:SetSize(22, 22)
	b.optOut:SetPoint("TOPRIGHT", -120, 0)
	b.optOut:SetScript("OnClick", function(cb) TH:SetLeaderOptOut(cb:GetChecked()); TH:RefreshLeaderboard(panel) end)
	local ol = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	ol:SetPoint("LEFT", b.optOut, "RIGHT", 2, 0)
	ol:SetText(L["Не участвовать"])

	local head = CreateFrame("Frame", nil, b)
	head:SetPoint("TOPLEFT", 0, -28)
	head:SetPoint("TOPRIGHT", 0, -28)
	head:SetHeight(18)
	for col, text in pairs({ place = L["Место"], name = L["Персонаж"], best = L["Самое редкое достижение"],
		earned = L["Получено"], points = L["Очки стиля"], t = L["Обновлено"] }) do
		BoardText(head, col, "GameFontNormalSmall"):SetText(text)
	end

	for i = 1, BOARD_ROWS do
		local row = CreateFrame("Frame", nil, b)
		row:EnableMouse(true)
		row:SetScript("OnMouseUp", function(r, button)
			if not r.entry then return end
			if button == "RightButton" then
				TH:OpenBoardMenu(r, r.entry, panel)
			else
				TH.UI:OpenProfile(r.entry.name)
			end
		end)
		row:SetScript("OnEnter", function(r)
			if not r.entry then return end
			GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
			GameTooltip:SetText(r.entry.name)
			local title = TH:GetPlayerTitle(r.entry.name)
			if title then GameTooltip:AddLine(title, 0.9, 0.8, 0.5) end
			GameTooltip:AddLine(L["ЛКМ — профиль, ПКМ — меню"], 0.6, 0.6, 0.6)
			if TH:IsModeratorClient() then
				local n = TH:GetReportStats(TH.PLAYER_REPORT_PREFIX .. r.entry.name)
				GameTooltip:AddLine(L["Жалоб на накрутку: "] .. n, 1, 0.5, 0.5)
			end
			GameTooltip:Show()
		end)
		row:SetScript("OnLeave", GameTooltip_Hide)
		row:SetPoint("TOPLEFT", 0, -48 - (i - 1) * BOARD_ROW_H)
		row:SetPoint("TOPRIGHT", 0, -48 - (i - 1) * BOARD_ROW_H)
		row:SetHeight(BOARD_ROW_H - 2)
		row.bg = row:CreateTexture(nil, "BACKGROUND")
		row.bg:SetAllPoints()
		for col in pairs(BOARD_COLS) do row[col] = BoardText(row, col) end
		row.avatar = row:CreateTexture(nil, "ARTWORK")
		row.avatar:SetSize(20, 20)
		row.avatar:SetPoint("LEFT", 56, 0)
		row.avatarBorder = row:CreateTexture(nil, "BORDER")
		row.avatarBorder:SetPoint("TOPLEFT", row.avatar, -1, 1)
		row.avatarBorder:SetPoint("BOTTOMRIGHT", row.avatar, 1, -1)
		row.avatarBorder:Hide()
		b.rows[i] = row
	end

	b.empty = b:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	b.empty:SetPoint("CENTER")
	b.empty:SetText(L["В рейтинге пока никого нет.\n\nОн заполнится, когда игроки с аддоном зайдут в игру."])

	-- кодекс подиума: просьба соревноваться честно и по-доброму
	b.codex = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	b.codex:SetPoint("BOTTOM", 0, 6)
	b.codex:SetWidth(860)
	b.codex:SetJustifyH("CENTER")
	b.codex:SetSpacing(2)
	b.codex:SetText(L["|cffe6cc80Кодекс подиума|r\n"]
		.. L["|cffbbbbbbСоревнуйтесь честно: очки стиля даются за достижения, а не за хитрости, и Стражи подиума умеют отличать одно от другого.\n"]
		.. L["Будьте добры к соседям по таблице. Даже Тралл когда-то стоял на арене последним, а Джайна училась на первых уроках в Даларане.|r"])
end

function TH:RefreshLeaderboard(panel, query)
	local b = panel.board
	if query ~= nil then b.query = query end
	local list, total = self:GetLeaderboard(b.friends:GetChecked(), b.query)
	-- в таблице — первые BOARD_LIMIT мест и вы, если ниже; остальных находит поиск
	local cut = false
	if not b.friends:GetChecked() and strtrim(b.query or "") == "" and #list > BOARD_LIMIT then
		local short = {}
		for _, e in ipairs(list) do
			if e.place <= BOARD_LIMIT or e.name == self.db.leader.char then short[#short + 1] = e end
		end
		list, cut = short, true
	end
	b.list = list
	b.offset = math.min(b.offset, math.max(0, #list - BOARD_ROWS))

	local me, leader = self.Net.Me(), self.db.leader
	local myPlace
	for _, e in ipairs(self:GetLeaderboard(false, "")) do
		if e.name == leader.char then myPlace = e.place end
	end
	local _, _, points = self:GetAchievementTotals()
	panel.header:SetText(string.format(L["Очки стиля: %d  —  %s"], points,
		myPlace and string.format(L["ваше место: %d из %d"], myPlace, total) or L["вы не в рейтинге"]))
	local seasonText = L["Итоги недели через "] .. self:FormatSeasonLeft()
		.. L[" — чем больше игроков, тем выше уровни наград за места"]
	if self:GetCharts() then
		seasonText = L["Официальный рейтинг на "] .. self:FormatChartsDate()
			.. (self:IsChartsStale() and L[" — устарел, обновите аддон"] or L[", обновляется каждый день"])
			.. L[". Новички — внизу, пока их не проверят"]
	end
	b.codex:SetText(L["|cffe6cc80Кодекс подиума|r  |cff999999—  "] .. seasonText .. "|r\n"
		.. L["|cffbbbbbbСоревнуйтесь честно: очки стиля даются за достижения, а не за хитрости, и Стражи подиума умеют отличать одно от другого.\n"]
		.. L["Будьте добры к соседям по таблице. Даже Тралл когда-то стоял на арене последним, а Джайна училась на первых уроках в Даларане.|r"])

	b.optOut:SetChecked(leader.optOut)
	if leader.optOut then
		b.me:SetText(L["|cff999999Вы не участвуете в рейтинге.|r"])
	elseif leader.char and leader.char ~= me then
		b.me:SetText(L["Основной: |cffffd100"] .. ShortName(leader.char) .. L["|r |cff999999(очки обновятся, когда зайдёте им)|r"])
	else
		b.me:SetText(L["Вы в рейтинге как |cffffd100"] .. ShortName(leader.char or me) .. "|r")
	end
	b.join:SetShown(not leader.optOut)

	for i, row in ipairs(b.rows) do
		local e = list[b.offset + i]
		row.entry = e
		if e then
			local a = e.best and self.ACHIEVEMENT_BY_ID[e.best]
			local mine = e.name == leader.char
			row.place:SetText(e.unverified and "|cff999999—|r" or e.place)
			-- титул рядом с именем (сервер тогда — в подсказке)
			local title = TH:GetPlayerTitle(e.name)
			if title then
				row.name:SetText(e.name:gsub("%-.*", "") .. "  |cffe6cc80" .. title .. "|r")
			else
				row.name:SetText(ShortName(e.name))
			end
			local av
			if TH.db.myChars[e.name] then
				-- свой: выбранный аватар или портрет своей расы
				av = TH:GetAvatar(e.name, select(3, UnitRace("player")), (UnitSex("player") or 2) - 2, select(2, UnitClass("player")))
			elseif e.avatar and TH:IsAvatarAllowed(e.name, e.avatar, e.mask) then
				av = e.avatar
			else
				-- аватар не выбран: портрет расы по его образам, если они у нас есть
				local look = TH:GetAuthorLook(TH:GetAuthorStats(e.name).sets)
				if look then av = TH:GetRacePortrait(look.race, look.sex, look.class) end
			end
			row.avatar:SetTexture(av or "Interface\\Icons\\INV_Misc_GroupLooking")
			TH:PaintAvatarBorder(row.avatarBorder, av)
			row.best:SetText(a and (self:RarityHex(a.rarity) .. a.name .. "|r") or "|cff999999—|r")
			row.earned:SetText(e.earned)
			if e.points < 0 then row.points:SetText("|cffff3030" .. e.points .. "|r") end
			if e.points >= 0 then row.points:SetText("|cffffd100" .. e.points .. "|r") end
			if e.unverified then row.points:SetText("|cff999999" .. e.points .. "?|r") end
			row.t:SetText(date("%d.%m.%Y", e.t))
			if mine then
				row.bg:SetColorTexture(TH:SelColor(0.15))
			elseif e.place <= 3 then
				row.bg:SetColorTexture(1, 0.5, 0, 0.08)
			else
				row.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.03 or 0)
			end
			row:Show()
		else
			row:Hide()
		end
	end
	b.empty:SetShown(#list == 0)
	panel.up:SetEnabled(b.offset > 0)
	panel.down:SetEnabled(b.offset + BOARD_ROWS < #list)
	panel.bar:Sync(b.offset, #list - BOARD_ROWS)
	panel.pos:SetText(cut and string.format(L["Первые %d из %d — остальных найдёт поиск"], BOARD_LIMIT, total)
		or (#list > BOARD_ROWS and L["Колесо мыши — прокрутка"] or ""))
end

-- ПКМ по строке рейтинга
function TH:OpenBoardMenu(row, e, panel)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local mine = self.db.myChars[e.name]
	MenuUtil.CreateContextMenu(row, function(_, root)
		root:CreateTitle(e.name)
		root:CreateButton(L["Профиль"], function() TH.UI:OpenProfile(e.name) end)
		if not mine then
			root:CreateButton(L["Пожаловаться на накрутку"], function()
				TH:ReportPlayer(e.name)
				TH:RefreshLeaderboard(panel)
			end)
		end
		if TH:IsModerator(TH.Net.Me()) then
			root:CreateDivider()
			local blocked = TH.db.net.modBlocks.players[e.name]
			root:CreateButton(blocked and L["Вернуть в рейтинг"] or L["Убрать из рейтинга (модератор)"], function()
				TH:ModDecision(blocked and "q" or "p", e.name)
				TH:RefreshLeaderboard(panel)
			end)
		end
	end)
end
