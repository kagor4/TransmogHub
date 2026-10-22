local _, ns = ...
local L = ns.L
local TH = ns.TH

-- Фильтр названий и описаний образов.
--   1. Фильтр Blizzard (C_Club.ValidateText) — только при сохранении своего образа.
--   2. Свой список корней — и при сохранении, и при получении из сети: изменённый
--      аддон может обойти проверку у себя, поэтому каждый клиент проверяет чужое сам.
-- Список нарочно короткий и консервативный: лучше пропустить редкий случай,
-- чем запрещать обычные слова («сабля», «корабля», «художник»).

-- Версия фильтра. Прошедшие проверку образы помнят её (set.textOk) и при входе в игру
-- не проверяются заново — это дорого при тысячах образов. ИЗМЕНИЛИ СПИСКИ ИЛИ ПРАВИЛА
-- НИЖЕ (в том числе бессмыслицу) — увеличьте номер, и все образы проверятся один раз.
TH.TEXT_FILTER_VERSION = 4 -- 2: мат, разбитый пробелом; 3: испанский; 4: немецкий и французский

-- Корни, которые запрещены в любом месте текста (после склейки букв)
local ANYWHERE = {
	"хуй", "хуе", "хуё", "хуя", "пизд", "ебат", "ебан", "ебуч", "еблан", "ебло",
	"выеб", "заеб", "отъеб", "уебок", "уебищ", "долбоеб", "мудак", "мудил",
	"пидор", "пидар", "пидр", "бляд", "блят", "гандон", "шлюх", "залуп",
	"fuck", "cunt", "nigg", "faggot", "whore", "asshole", "bitch",
	-- испанский («puta» — только в начале слова: «disputa», «computadora»);
	-- корни без двойных букв: слова сжимаются перед проверкой («gilipollas» -> «gilipolas»);
	-- ó и ñ — кодами: в коде аддона только знаки, которые проверяются в шрифтах
	"hijoputa", "hijodeputa", "gilipol", "malparid", "pendej", "maricon", "maric\195\179n",
	"chingad", "chingar", "culero", "conchatumadre", "conchesumadre", "mamaverga",
	-- немецкий (ä, ö, ü — кодами; «ss» после сжатия двойных букв — «s»)
	"hurensohn", "wichser", "fotze", "arschloch", "arschgeig", "missgeburt", "misgeburt", "schwuchtel", "kanake",
	-- французский (é, â — кодами)
	"connard", "conard", "connasse", "conase", "encule", "encul\195\169", "salope", "filsdepute", "niquetamere", "niquer",
	"scheis", "schei\195\159", "drecksau", "dreckssau", "spast", "vollidiot", "huresohn",
}

-- Корни, которые запрещены только в начале слова
local WORD_START = {
	"бля", "ебл", "ебу", "еби", "ебё", "сука", "суки", "сучк", "сучар", "мраз",
	"дерьм", "говн", "жоп", "дроч", "ублюд", "шалав", "педик",
	"shit", "slut", "nazi", "hitler", "porn",
	"puta", "puto", "joder", "jodid", "cabron", "cabr\195\179n", "mierd", "co\195\177o", "folad", "putit",
	"hure", "fick", "nutte", "schlampe", "wixer", "neger",
	"putain", "pute", "batard", "b\195\162tard", "merde", "couil", "p\195\169tase",
}

-- Реклама и ссылки
local SPAM = { "http", "www.", "discord.gg", "t.me/", ".com/", ".ru/" }

-- Адреса, написанные через пробел: «www gold ru», «gold . com»
local TLD = {
	ru = true, com = true, net = true, org = true, su = true, ua = true, kz = true, gg = true,
	xyz = true, tk = true, cc = true, ["рф"] = true, ["ру"] = true, ["ком"] = true,
}
-- Эти бывают обычными словами («by», «info»): реклама, только если стоят последним словом
local TLD_LAST = { by = true, io = true, me = true, top = true, site = true, online = true,
	info = true, shop = true, store = true, link = true, pro = true }
-- Площадки, куда зазывают
local SPAM_WORDS = {
	discord = true, ["дискорд"] = true, telegram = true, ["телеграм"] = true, twitch = true, ["твич"] = true,
	youtube = true, ["ютуб"] = true, boosty = true, ["бусти"] = true, funpay = true, ["фанпей"] = true,
	vk = true, ["вк"] = true, tg = true, ["тг"] = true, www = true,
}

-- Латиница и цифры, похожие на кириллицу
local LOOKALIKE = {
	a = "а", c = "с", e = "е", h = "н", k = "к", m = "м", o = "о",
	p = "р", t = "т", x = "х", y = "у", ["0"] = "о", ["3"] = "з", ["4"] = "ч",
	["6"] = "б", ["@"] = "а", ["ё"] = "е",
}

local UTF8_CHAR = "[%z\1-\127\194-\244][\128-\191]*"

-- Буквы без повторов подряд: «хуууй» -> «хуй»
local function Squash(s)
	local out, prev = {}, nil
	for ch in s:gmatch(UTF8_CHAR) do
		if ch ~= prev then out[#out + 1] = ch end
		prev = ch
	end
	return table.concat(out)
end

local function CodePoint(ch)
	local b1, b2, b3 = ch:byte(1, 3)
	if #ch == 1 then return b1 end
	if #ch == 2 then return (b1 - 192) * 64 + (b2 - 128) end
	if #ch == 3 then return ((b1 - 224) * 64 + (b2 - 128)) * 64 + (b3 - 128) end
	return 0x10000 -- 4 байта: эмодзи и редкие знаки
end

-- Буквы не-ASCII: латиница с диакритикой, греческий, кириллица, кана, иероглифы, хангыль
local LETTER_RANGES = {
	{ 0xC0, 0x24F }, { 0x370, 0x3FF }, { 0x400, 0x52F }, { 0x1100, 0x11FF }, { 0x1E00, 0x1EFF },
	{ 0x3040, 0x30FF }, { 0x3130, 0x318F }, { 0x3400, 0x4DBF }, { 0x4E00, 0x9FFF }, { 0xAC00, 0xD7AF },
}
local function IsLetterCode(cp)
	for _, r in ipairs(LETTER_RANGES) do
		if cp >= r[1] and cp <= r[2] then return true end
	end
	return false
end

-- латиница или буква другого языка; невидимые пробелы и значки — не буквы
local function IsLetter(ch)
	if #ch == 1 then return ch:match("^%a$") ~= nil end
	return IsLetterCode(CodePoint(ch))
end


-- Слова в двух видах: как есть (латиница) и с заменой похожих символов на кириллицу
local function Words(text)
	local plain, cyr = {}, {}
	local w1, w2 = {}, {}
	local function flush()
		if #w1 > 0 then
			plain[#plain + 1] = Squash(table.concat(w1))
			cyr[#cyr + 1] = Squash(table.concat(w2))
		end
		w1, w2 = {}, {}
	end
	for ch in TH.Lower(text):gmatch(UTF8_CHAR) do
		if IsLetter(ch) or LOOKALIKE[ch] then
			w1[#w1 + 1] = ch
			w2[#w2 + 1] = LOOKALIKE[ch] or ch
		else
			flush()
		end
	end
	flush()
	return plain, cyr
end

-- Слово, разорванное символами: «Х-уй», «Пи*зда», «ху_йня». Внутри одного слова
-- (без пробелов) склеиваем куски, если хотя бы один из соседних короче 3 букв:
-- «сабля-дракон» не склеится и не даст ложного «бляд».
local function TornWords(text)
	local out = {}
	for token in TH.Lower(text):gmatch("%S+") do
		local parts, cur1, cur2 = {}, {}, {}
		local function cut()
			if #cur1 > 0 then parts[#parts + 1] = { table.concat(cur1), table.concat(cur2), n = #cur1 } end
			cur1, cur2 = {}, {}
		end
		for ch in token:gmatch(UTF8_CHAR) do
			if IsLetter(ch) or LOOKALIKE[ch] then
				cur1[#cur1 + 1] = ch
				cur2[#cur2 + 1] = LOOKALIKE[ch] or ch
			else
				cut()
			end
		end
		cut()
		local group, size = nil, 0
		local function emit()
			if group and size > 1 then
				out[#out + 1] = Squash(group[1])
				out[#out + 1] = Squash(group[2])
			end
		end
		for i, p in ipairs(parts) do
			local prev = parts[i - 1]
			if group and (p.n < 3 or prev.n < 3) then
				group = { group[1] .. p[1], group[2] .. p[2] }
				size = size + 1
			else
				emit()
				group, size = { p[1], p[2] }, 1
			end
		end
		emit()
	end
	return out
end

-- Слово целиком без символов внутри: «Пиз-дюк» -> «пиздюк», «Бля-дский» -> «блядский».
-- Только для слов, в которых были символы. Обычные слова на «-бля» («сабля-дракон»)
-- в склейке не участвуют, иначе получилось бы «саблядракон».
local BLYA_WORDS = {
	["сабля"] = true, ["корабля"] = true, ["рубля"] = true, ["ансамбля"] = true, ["дирижабля"] = true,
	["грабля"] = true, ["оглобля"] = true, ["стебля"] = true,
}

local function JoinedWords(text)
	local out = {}
	for token in TH.Lower(text):gmatch("%S+") do
		local parts, cur1, cur2 = {}, {}, {}
		local function cut()
			if #cur1 > 0 then parts[#parts + 1] = { table.concat(cur1), table.concat(cur2) } end
			cur1, cur2 = {}, {}
		end
		for ch in token:gmatch(UTF8_CHAR) do
			if IsLetter(ch) or LOOKALIKE[ch] then
				cur1[#cur1 + 1] = ch
				cur2[#cur2 + 1] = LOOKALIKE[ch] or ch
			else
				cut()
			end
		end
		cut()
		if #parts > 1 then
			local j1, j2 = {}, {}
			for _, p in ipairs(parts) do
				-- слово из белого списка — граница, через неё не склеиваем
				local sep = (BLYA_WORDS[p[1]] or BLYA_WORDS[p[2]]) and " " or nil
				j1[#j1 + 1] = sep or p[1]
				j2[#j2 + 1] = sep or p[2]
			end
			out[#out + 1] = Squash(table.concat(j1))
			out[#out + 1] = Squash(table.concat(j2))
		end
	end
	return out
end

local function StartsWithAny(word, roots)
	for _, root in ipairs(roots) do
		if word:sub(1, #root) == root then return true end
	end
end

local function ContainsAny(s, roots)
	for _, root in ipairs(roots) do
		if s:find(root, 1, true) then return true end
	end
end

-- Реклама и ссылки, в том числе через пробелы и точки
local function IsSpam(text)
	local lower = TH.Lower(text)
	if ContainsAny(lower, SPAM) then return true end
	-- слова; идущие подряд одиночные буквы склеиваем: «gold r u» -> «gold», «ru»
	local words, prevSingle = {}, false
	for w in lower:gmatch("[%w\128-\255]+") do
		local single = #w:gsub("[\128-\191]", "") == 1
		if single and prevSingle then
			words[#words] = words[#words] .. w
		else
			words[#words + 1] = w
		end
		prevSingle = single
	end
	for i, w in ipairs(words) do
		if SPAM_WORDS[w] or w:find("www", 1, true) == 1 then return true end
		if i > 1 and (TLD[w] or (TLD_LAST[w] and i == #words)) then return true end
	end
	return false
end
TH.IsSpamText = IsSpam

-- true, если текст проходит собственный фильтр
function TH:IsTextAllowed(text)
	if not text or text == "" then return true end
	if IsSpam(text) then return false end
	local plain, cyr = Words(text)
	for i = 1, #plain do
		if ContainsAny(plain[i], ANYWHERE) or ContainsAny(cyr[i], ANYWHERE) then return false end
		if StartsWithAny(plain[i], WORD_START) or StartsWithAny(cyr[i], WORD_START) then return false end
	end
	-- «х.у.й», «х у й»: склеиваем только идущие подряд одиночные буквы,
	-- иначе «сабля дракона» превратилась бы в «саблядракона»
	local run = {}
	local function checkRun()
		if #run >= 2 then
			local joined = Squash(table.concat(run))
			if ContainsAny(joined, ANYWHERE) or StartsWithAny(joined, WORD_START) then return true end
		end
		run = {}
	end
	for i = 1, #cyr do
		if #cyr[i]:gsub("[\128-\191]", "") == 1 then
			run[#run + 1] = cyr[i]
		elseif checkRun() then
			return false
		end
	end
	if checkRun() then return false end
	for _, word in ipairs(TornWords(text)) do
		if ContainsAny(word, ANYWHERE) or StartsWithAny(word, WORD_START) then return false end
	end
	for _, word in ipairs(JoinedWords(text)) do
		if ContainsAny(word, ANYWHERE) or StartsWithAny(word, WORD_START) then return false end
	end
	-- мат, разбитый пробелом: «Пиз дача», «Ху йня». Склеиваем соседние слова, если одно
	-- из них короткое (до 4 букв): «сабля дракона» так не склеится, а «бля» в «сабля» —
	-- граница и не склеивается вовсе
	for i = 1, #cyr - 1 do
		local a, b = cyr[i], cyr[i + 1]
		local la, lb = #a:gsub("[\128-\191]", ""), #b:gsub("[\128-\191]", "")
		if (la <= 4 or lb <= 4) and not BLYA_WORDS[a] and not BLYA_WORDS[b] then
			local joined = Squash(a .. b)
			if ContainsAny(joined, ANYWHERE) or StartsWithAny(joined, WORD_START) then return false end
		end
	end
	return true
end

-- Фильтр Blizzard (тот же, что для названий сообществ)
local function BlizzardSaysProfane(text)
	if not (C_Club and C_Club.ValidateText and Enum.ClubType and Enum.ClubFieldType and Enum.ValidateNameResult) then
		return false
	end
	local ok, result = pcall(C_Club.ValidateText, Enum.ClubType.Character, text, Enum.ClubFieldType.ClubDescription)
	return ok and result == Enum.ValidateNameResult.Profane
end

-- Сколько букв (латиница или любая не-ASCII буква) в тексте
local function LetterCount(s)
	local _, ascii = s:gsub("%a", "")
	local _, other = s:gsub("[\192-\255]", "")
	return ascii + other
end

local MIN_NAME_LETTERS = 2 -- «12312» — не название

-- Символы в названии: буквы любых языков, цифры, пробел и немного знаков.
-- Значки (★ ♥ ═), эмодзи и «служебные» символы (@ # { } / …) запрещены.
local NAME_PUNCT = "-'!?,.:()&"
TH.NAME_ALLOWED_TEXT = L["буквы, цифры, пробел и - ' ! ? , . : ( ) & « »"]
local MAX_PUNCT_RUN = 3

local EXTRA_PUNCT = { [0xAB] = true, [0xBB] = true } -- « »

-- nil, если все символы разрешены; иначе неразрешённый символ
-- (второе значение "run" — слишком много знаков подряд)
function TH.FindBadNameChar(name)
	local run = 0
	for ch in (name or ""):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		local punct = false
		if #ch == 1 then
			if ch:match("[%w ]") then
				-- ок
			elseif NAME_PUNCT:find(ch, 1, true) then
				punct = true
			else
				return ch
			end
		else
			local cp = CodePoint(ch)
			if EXTRA_PUNCT[cp] then
				punct = true
			elseif cp == 0xD7 or cp == 0xF7 then
				return ch -- × ÷
			else
				if not IsLetterCode(cp) then return ch end
			end
		end
		run = punct and run + 1 or 0
		if run > MAX_PUNCT_RUN then return ch, "run" end
	end
end

-- Проверка перед сохранением своего образа. Возвращает nil или текст ошибки.
-- «Фывфвфыв», «йцукен», «ааааа», «бвгдж» — образ клавиш вместо названия.
-- Проверяем только слова кириллицей и латиницей: в других письменностях гласных нет.
local MASH = { "фыва", "ывап", "вапр", "апро", "прол", "йцук", "цуке", "укен", "кенг", "ячсм", "чсми", "смит",
	"qwer", "wert", "erty", "asdf", "sdfg", "dfgh", "zxcv", "xcvb" }
local VOWELS = {}
for ch in ("аеёиоуыэюяaeiouy"):gmatch("[%z\1-\127\194-\244][\128-\191]*") do VOWELS[ch] = true end

function TH.IsGibberish(name)
	local low = TH.Lower(name or "")
	for _, m in ipairs(MASH) do
		if low:find(m, 1, true) then return true end
	end
	for word in low:gmatch("[^%s%p%d]+") do
		local chars, plain = {}, true
		for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
			chars[#chars + 1] = ch
			local b = ch:byte(1)
			if not ((b >= 97 and b <= 122) or b == 0xD0 or b == 0xD1) then plain = false end
		end
		local n = #chars
		if plain and n >= 3 then
			local distinct, vowels, run, cons, maxCons = {}, 0, 1, 0, 0
			for i, ch in ipairs(chars) do
				distinct[ch] = true
				if VOWELS[ch] then vowels, cons = vowels + 1, 0 else cons = cons + 1 end
				if cons > maxCons then maxCons = cons end
				if i > 1 and ch == chars[i - 1] then
					run = run + 1
					if run >= 3 and n >= 5 then return true end -- «пиратааа»; короткое «ммм» можно
				else
					run = 1
				end
			end
			local d = 0
			for _ in pairs(distinct) do d = d + 1 end
			if n >= 5 and vowels == 0 then return true end      -- «бвгдж»
			if n >= 6 and d <= 3 then return true end           -- «фывфвфыв»
			if maxCons >= 6 then return true end                -- «вшщзхъц»
		end
	end
	return false
end

function TH:ValidateSetText(name, desc)
	name = strtrim(name or "")
	if #name < 3 then return L["Название слишком короткое."] end
	if LetterCount(name) < MIN_NAME_LETTERS then return L["В названии должны быть буквы, а не только цифры."] end
	local bad, why = TH.FindBadNameChar(name)
	if bad then
		if why == "run" then return L["Не больше "] .. MAX_PUNCT_RUN .. L[" знаков препинания подряд."] end
		return L["Символ «"] .. bad .. L["» нельзя. Можно: "] .. TH.NAME_ALLOWED_TEXT .. "."
	end
	for _, text in ipairs({ name, desc or "" }) do
		if text ~= "" and (not self:IsTextAllowed(text) or BlizzardSaysProfane(text)) then
			if IsSpam(text) then
				return L["Ссылки и реклама в названии и описании запрещены."]
			end
			return text == name and L["Название содержит недопустимые слова."] or L["Описание содержит недопустимые слова."]
		end
	end
	if TH.IsGibberish(name) then return L["Название похоже на случайный набор букв. Придумайте настоящее."] end
end

-- Можно ли показывать образ из сети
-- Проверка текстов дорогая, а лента пересчитывается часто: ответ запоминаем по самому
-- тексту (зависит только от него и от списков в коде аддона)
local textVerdict = {}
function TH:IsSetTextAllowed(set)
	-- уже проверен этой версией фильтра (тексты образа после публикации не меняются)
	if set.textOk == TH.TEXT_FILTER_VERSION then return true end
	local key = (set.name or "") .. "\0" .. (set.desc or "")
	local ok = textVerdict[key]
	if ok == nil then
		ok = LetterCount(set.name or "") >= MIN_NAME_LETTERS and not TH.FindBadNameChar(set.name)
			and self:IsTextAllowed(set.name) and self:IsTextAllowed(set.desc) or false
		textVerdict[key] = ok
	end
	if ok then set.textOk = TH.TEXT_FILTER_VERSION end
	return ok
end

---------------------------------------------------------------------------
-- Жалобы и блокировки
--
-- Жалобы расходятся по сети, как голоса, и игрокам не показываются.
-- Образ скрывается:
--   * если он в чёрном списке из обновления аддона (Data/Blocklist.lua);
--   * если его заблокировал модератор сообщением напрямую (M);
--   * автоматически — при >= AUTO_HIDE_REPORTS жалоб от разных персонажей,
--     и если жалующиеся составляют >= AUTO_HIDE_SHARE от всех, кто оценил
--     образ или пожаловался. Авторов автоматически не блокируем.
---------------------------------------------------------------------------
TH.REPORT_REASONS = {
	{ key = "a", label = L["Реклама"] },
	{ key = "o", label = L["Оскорбительное название или описание"] },
	{ key = "x", label = L["Другое (опишите сами)"] },
}
TH.REPORT_LABEL = {}
for _, r in ipairs(TH.REPORT_REASONS) do TH.REPORT_LABEL[r.key] = r.label end
-- жалоба на игрока в рейтинге очков стиля: id «p:Имя-Сервер»
TH.REPORT_LABEL.c = L["Накрутка рейтинга"]
TH.PLAYER_REPORT_PREFIX = "p:"

local AUTO_HIDE_REPORTS = 100
local AUTO_HIDE_SHARE = 0.3

-- Персонажи-модераторы. Их решения (M) принимаются только напрямую от них:
-- имя отправителя гарантирует игра, пересланные решения не принимаются.
-- Роли. Админ (персонажи разработчика, только здесь, в коде) — всё, включая назначение
-- модераторов. Модератор — только разбор жалоб. Модераторы: список в обновлении аддона
-- (Data/Blocklist.lua, moderators) и назначенные админом в сети (решения m / x
-- принимаются только напрямую от админа).
-- Имён админов в коде нет — только отпечатки «thub-admin:Имя-Сервер» (TH.Secret.Hash):
-- кто админ, по файлам аддона не узнать. Добавить персонажа — посчитать отпечаток
-- (tools/secrets/admin.lua «Имя-Сервер») и дописать сюда.
TH.ADMIN_HASHES = {
	["5fe2bfbe2ab00c43"] = true,
	["20fd3e866f86c41b"] = true,
	["32fdf0e461c99b3c"] = true,
	["2a9ce2380422f910"] = true,
	["1b9cb42a2e7e90be"] = true,
	["6f37a0d4483bce50"] = true,
	["6a3a2f263267d1fd"] = true,
	-- WoW Forever: «Имя Фамилия» без сервера
	["1cdf589d7e035947"] = true,
	["029f843e68c47dd2"] = true,
	["782712237a0b3dff"] = true,
}
TH.MODERATORS = {} -- для тестов и временных прав в этом сеансе

local adminCache = {}
function TH:IsAdmin(name)
	if name == nil then return false end
	local v = adminCache[name]
	if v == nil then
		v = self.ADMIN_HASHES[self.Secret.Hash("thub-admin:" .. name)] == true
		adminCache[name] = v
	end
	return v
end

function TH:IsModerator(name)
	if not name then return false end
	if self.MODERATORS[name] or self:IsAdmin(name) then return true end
	local list = TransmogHub_Blocklist and TransmogHub_Blocklist.moderators
	if list and list[name] then
		local r = self.db and self.db.net.modRoles[name]
		return not (r and r[1] == 0) -- админ снял в сети раньше, чем вышло обновление
	end
	local r = self.db and self.db.net.modRoles[name]
	return r ~= nil and r[1] == 1
end

-- Все модераторы (без админов): { имя, откуда }
function TH:GetModeratorList()
	local list, seen = {}, {}
	for name in pairs((TransmogHub_Blocklist and TransmogHub_Blocklist.moderators) or {}) do
		if self:IsModerator(name) and not self:IsAdmin(name) then
			seen[name] = true
			list[#list + 1] = { name, L["в обновлении"] }
		end
	end
	for name, r in pairs(self.db.net.modRoles) do
		if r[1] == 1 and not seen[name] and not self:IsAdmin(name) then list[#list + 1] = { name, L["назначен в сети"] } end
	end
	table.sort(list, function(a, b) return a[1] < b[1] end)
	return list
end

-- Имя игрока из окна ввода: «Ник» или «Ник-Мир» (с опечаткой в мире, другим регистром,
-- пробелами) → точное «Ник-Мир» из тех, кого знает аддон (авторы, рейтинг, подписки,
-- оценки). Возвращает имя и true, если игрок найден.
function TH:ResolvePlayerName(input)
	if self.FOREVER then
		-- Forever: «Имя Фамилия», пробелы значимы; ввод только имени — ищем по имени
		input = strtrim(input or ""):gsub("%s+", " ")
	else
		input = strtrim(input or ""):gsub("%s+", "")
	end
	if input == "" then return nil, false end
	local short, realm
	if self.FOREVER then
		short, realm = input:match("^(%S+)%s?(.*)$")
	else
		short, realm = input:match("^([^%-]+)%-?(.*)$")
	end
	local lshort, lrealm = self.Lower(short), self.Lower(realm or "")
	local known, net = {}, self.db.net
	local function Add(n) if self:IsCharName(n) then known[n] = true end end
	for _, set in pairs(net.sets) do Add(set.author) end
	for n in pairs(net.scores) do Add(n) end
	for target, list in pairs(net.follows) do
		Add(target)
		for n in pairs(list) do Add(n) end
	end
	for _, list in pairs(net.votes) do for n in pairs(list) do Add(n) end end
	for _, key in ipairs({ "banned", "warned", "authors", "players" }) do
		for n in pairs(net.modBlocks[key] or {}) do Add(n) end
	end
	if known[input] then return input, true end
	local matches = {}
	for n in pairs(known) do
		local s2, r2
		if self.FOREVER then s2, r2 = n:match("^(%S+) (.*)$") else s2, r2 = n:match("^([^%-]+)%-(.*)$") end
		if s2 and self.Lower(s2) == lshort then
			if lrealm ~= "" and self.Lower(r2) == lrealm then return n, true end
			matches[#matches + 1] = n
		end
	end
	if #matches == 1 then return matches[1], true end
	-- неизвестен или ников несколько: как ввели (без мира — свой мир)
	if realm == "" and not self.FOREVER then input = short .. "-" .. (GetNormalizedRealmName and GetNormalizedRealmName() or "") end
	return input, false, matches
end

-- Назначить или снять модератора (только админ)
function TH:SetModerator(name, on)
	if not self:IsAdmin(self.Net.Me()) then return end
	name = self:ResolvePlayerName(name)
	if not name then return end
	if self:IsAdmin(name) then return self:Notify(L["Это персонаж админа."]) end
	self:ModDecision(on and "m" or "x", name)
	self:Notify(on and (L["Назначен модератором: "] .. name) or (L["Снят с модераторов: "] .. name))
end

-- Клиент модератора копит журнал жалоб для выгрузки коннектором
function TH:IsModeratorClient()
	return self.db and self.db.moderator or false
end

local function Blocklist()
	return TransmogHub_Blocklist or { sets = {}, authors = {} }
end

function TH:IsBlocked(set)
	if not set then return false end
	local list, mod = Blocklist(), self.db.net.modBlocks
	return (list.sets and list.sets[set.id]) or (list.authors and set.author and list.authors[set.author])
		or mod.sets[set.id] or (set.author and mod.authors[set.author]) or false
end

-- Сколько разных персонажей пожаловалось, и по каким причинам
function TH:GetReportStats(setId)
	local reports = self.db.net.reports[setId]
	local total, byReason = 0, { a = 0, o = 0, x = 0 }
	for _, r in pairs(reports or {}) do
		if r[1] ~= "u" then -- отозванные не считаем
			total = total + 1
			byReason[r[1]] = (byReason[r[1]] or 0) + 1
		end
	end
	return total, byReason
end

function TH:IsAutoHidden(set)
	local reports = self.db.net.reports[set.id]
	if not reports then return false end
	local reporters = self:GetReportStats(set.id)
	if reporters < AUTO_HIDE_REPORTS then return false end
	-- все, кто как-то отметился: голосовавшие и пожаловавшиеся (без двойного счёта)
	local seen = {}
	for name, r in pairs(reports) do if r[1] ~= "u" then seen[name] = true end end
	for name in pairs(self.db.net.votes[set.id] or {}) do seen[name] = true end
	local everyone = 0
	for _ in pairs(seen) do everyone = everyone + 1 end
	return reporters / everyone >= AUTO_HIDE_SHARE
end

-- Журнал модератора: одна строка на жалобу, поля через «|» (его нет в текстах образов).
-- Формат: 1|id образа|кто пожаловался|причина|время|автор|название|описание
local MOD_LOG_MAX = 5000

function TH:LogReport(setId, reporter, reason, t)
	if not self:IsModeratorClient() then return end
	local set = self.db.net.sets[setId] or {}
	if setId:sub(1, 2) == self.PLAYER_REPORT_PREFIX then
		local s = self.db.net.scores[setId:sub(3)]
		set = { author = setId:sub(3), name = "рейтинг", desc = s and s.points and ("очки " .. s.points .. ", маска " .. (s.mask or "")) or "" }
	end
	local line = table.concat({ "1", setId, reporter, reason, t, set.author or "", set.name or "", set.desc or "" }, "|")
	local log = self.db.modLog
	log[#log + 1] = line
	while #log > MOD_LOG_MAX do tremove(log, 1) end
end

-- Решения модератора для выгрузки: 1|действие|цель|время
-- действия: s — заблокировать образ, a — автора, u — разблокировать образ,
-- v — разблокировать автора, d — жалобы необоснованны, n — просмотрено без решения (без последствий),
-- m / x — админ назначил / снял модератора, w — снято наказание за занижение оценок
function TH:LogDecision(action, target)
	local log = self.db.modDecisions
	log[#log + 1] = table.concat({ "1", action, target, self.Net.Now() }, "|")
end

---------------------------------------------------------------------------
-- Предложения тегов. Расходятся по сети скрыто, как жалобы; у модератора
-- копятся в журнале, коннектор выгружает их, а ежедневная проверка
-- добавляет теги, которые просят многие.
---------------------------------------------------------------------------
local TAG_MIN, TAG_MAX = 2, 24        -- длина в буквах
local SUGGEST_PER_DAY = 5

local function CharCount(s)
	return #s:gsub("[\128-\191]", "")
end

-- Текст тега в едином виде: строчные буквы, цифры, пробел и дефис. nil — не годится.
function TH.NormalizeTag(text)
	if type(text) ~= "string" then return nil end
	text = text:gsub("[^%w%s%-\128-\255]", " "):gsub("%s+", " ")
	text = TH.Lower(strtrim(text))
	local n = CharCount(text)
	if n < TAG_MIN or n > TAG_MAX then return nil end
	return text
end

-- Возвращает nil или текст ошибки
function TH:SuggestTag(text)
	if self:IsExiled() then return L["Стражи подиума закрыли для вас эту возможность."] end
	local norm = self.NormalizeTag(text)
	if not norm then return L["Тег — от "] .. TAG_MIN .. L[" до "] .. TAG_MAX .. L[" букв."] end
	if not self:IsTextAllowed(norm) or BlizzardSaysProfane(norm) then return L["Тег содержит недопустимые слова."] end
	for key, label in pairs(self.TAG_LABEL) do
		if self.Lower(label) == norm and not self.TAG_RETIRED[key] then return L["Такой тег уже есть."] end
	end
	if self.db.mySuggest[norm] then return L["Вы уже предлагали этот тег."] end
	local now, today = self.Net.Now(), 0
	for _, t in pairs(self.db.mySuggest) do
		if now - t < 86400 then today = today + 1 end
	end
	if today >= SUGGEST_PER_DAY then return L["Не больше "] .. SUGGEST_PER_DAY .. L[" предложений в день."] end
	self.db.mySuggest[norm] = now
	self.Net:SendTagSuggestion(norm)
	self:TrackCount("suggested")
	self:Thanks(L["Тег «"] .. norm .. L["» предложен. Если его попросят и другие, он появится в обновлении."])
end

-- Обращения (оспаривание решений) для коннектора: 1|кто|время|текст
function TH:LogAppeal(name, t, text)
	if not self:IsModeratorClient() then return end
	local log = self.db.modAppeals
	log[#log + 1] = table.concat({ "1", name, t, (text:gsub("|", "/")) }, "|")
	while #log > MOD_LOG_MAX do tremove(log, 1) end
end

-- Предложения разработчику для коннектора: 1|кто|время|вид|текст
function TH:LogIdea(name, t, kind, text)
	if not self:IsModeratorClient() then return end
	local log = self.db.modIdeas
	log[#log + 1] = table.concat({ "1", name, t, kind, (text:gsub("|", "/")) }, "|")
	while #log > MOD_LOG_MAX do tremove(log, 1) end
end

-- Журнал предложений для коннектора: 1|тег|кто предложил|время
function TH:LogTagSuggestion(text, name, t)
	if not self:IsModeratorClient() then return end
	local log = self.db.modTags
	log[#log + 1] = table.concat({ "1", text, name, t }, "|")
	while #log > MOD_LOG_MAX do tremove(log, 1) end
end

-- Раз в день: сколько образов с каждым тегом (чтобы убирать неиспользуемые).
-- 1|дата|всего образов|ключ=число,ключ=число,…
function TH:SnapshotTagStats()
	if not self:IsModeratorClient() then return end
	local log, day = self.db.modTagStats, date("%Y-%m-%d")
	local last = log[#log]
	if last and last:sub(3, 12) == day then return end
	local counts, parts = self:GetTagCounts(), {}
	for _, key in ipairs(self.TAG_ORDER) do parts[#parts + 1] = key .. "=" .. (counts[key] or 0) end
	log[#log + 1] = table.concat({ "1", day, #(self.feed and self.feed.sets or {}), table.concat(parts, ",") }, "|")
	while #log > 90 do tremove(log, 1) end
end

---------------------------------------------------------------------------
-- Проверка на накрутку. Каждый аддон сам смотрит на оценки образа: если
-- почти все — пятёрки и при этом голоса пришли подозрительно (от игроков,
-- которые больше ничего не оценивали; почти все за один час; почти все с
-- сервера автора), образ не попадает в чарт и не даёт мест для достижений,
-- пока модератор не проверит его. Сами оценки остаются и видны.
---------------------------------------------------------------------------
local SUS_MIN_VOTES = 8      -- меньше оценок — судить рано
local SUS_FIVES = 0.9        -- доля пятёрок
local SUS_LONELY = 0.6       -- доля голосов от тех, кто оценил только этот образ
local SUS_BURST = 0.7        -- доля голосов за один час
local SUS_REALM = 0.8        -- доля голосов с сервера автора
local suspicion, voterActivity

local lastFullCheck
function TH:ResetSuspicion()
	suspicion, voterActivity = {}, nil
	lastFullCheck = GetTime()
end

-- После пересчёта ленты: заново — только образы с новыми голосами, а целиком
-- (активность голосующих общая на все образы) — не чаще раза в минуту
local FULL_CHECK_EVERY = 60
function TH:RefreshSuspicion(changed)
	if not suspicion or not lastFullCheck or GetTime() - lastFullCheck > FULL_CHECK_EVERY then
		self:ResetSuspicion()
		return
	end
	for _, setId in ipairs(changed) do suspicion[setId] = nil end
end

local function VoterActivity()
	if voterActivity then return voterActivity end
	voterActivity = {}
	for _, votes in pairs(TH.db.net.votes) do
		for name in pairs(votes) do voterActivity[name] = (voterActivity[name] or 0) + 1 end
	end
	return voterActivity
end

local function Verified(setId)
	local list = Blocklist().verified or {}
	local mod = TH.db.net.modBlocks.verified or {}
	return math.max(list[setId] or 0, mod[setId] or 0)
end

-- nil — всё в порядке, иначе { причины } для модератора
local function CheckVotes(set)
	local votes = TH.db.net.votes[set.id]
	if not votes then return nil end
	local n, fives, lonely, sameRealm, times = 0, 0, 0, 0, {}
	local activity = VoterActivity()
	local realm = set.author and set.author:match("%-(.+)$")
	for name, v in pairs(votes) do
		n = n + 1
		if v[1] == 5 then fives = fives + 1 end
		if (activity[name] or 0) <= 1 then lonely = lonely + 1 end
		if realm and name:match("%-(.+)$") == realm then sameRealm = sameRealm + 1 end
		times[#times + 1] = v[2] or 0
	end
	if n < SUS_MIN_VOTES or fives / n < SUS_FIVES then return nil end
	-- проверенный модератором образ снова под подозрением, только если оценок стало в полтора раза больше
	local checked = Verified(set.id)
	if checked > 0 and n < checked * 1.5 then return nil end
	-- больше всего голосов за любой час
	table.sort(times)
	local burst, first = 0, 1
	for i = 1, #times do
		while times[i] - times[first] > 3600 do first = first + 1 end
		burst = math.max(burst, i - first + 1)
	end
	local reasons = {}
	if lonely / n >= SUS_LONELY then reasons[#reasons + 1] = string.format(L["разовые голоса %d%%"], 100 * lonely / n) end
	if burst / n >= SUS_BURST then reasons[#reasons + 1] = string.format(L["за час %d%%"], 100 * burst / n) end
	if sameRealm / n >= SUS_REALM then reasons[#reasons + 1] = string.format(L["сервер автора %d%%"], 100 * sameRealm / n) end
	if #reasons == 0 then return nil end
	table.insert(reasons, 1, string.format(L["пятёрок %d%%"], 100 * fives / n))
	return reasons
end

function TH:GetSuspicion(set)
	if not set or not set.id then return nil end
	suspicion = suspicion or {}
	local cached = suspicion[set.id]
	if cached == nil then
		cached = CheckVotes(set) or false
		suspicion[set.id] = cached
	end
	return cached or nil
end

-- Модератор: оценки проверены, накрутки нет
function TH:VerifyVotes(setId)
	self:ModDecision("k", setId)
end

---------------------------------------------------------------------------
-- Журнал рейтингов для разработчика: раз в день модераторский аддон
-- записывает снимок сети, коннектор выгружает его в закрытый репозиторий
-- (reports/stats/ГГГГ-ММ.tsv). По снимкам потом видно, как меняются оценки,
-- чарты и достижения, и можно настраивать формулы. Имён голосовавших нет.
--   1|S|дата|образов|с оценками|в чарте|подозрительных|оценок|голосовавших|игроков в рейтинге|средняя оценка|1★/2★/3★/4★/5★
--   1|V|дата|id образа|автор|оценок|средняя|балл|тренд|1★/2★/3★/4★/5★|c в чарте, s подозрение, n мало оценок
--   1|X|дата|id образа|автор|оценок|причины подозрения
--   1|A|дата|id достижения|у скольких игроков|игроков в рейтинге
--   1|T|дата|id образа|автор|погасший тег|сколько отметили|оценок образа (0 отметок — убрал автор)
---------------------------------------------------------------------------
local STATS_DAYS = 30   -- снимков храним (коннектор выгружает раньше)
local STATS_SETS = 300  -- образов в дневном снимке (самые оцениваемые)

function TH:SnapshotStats()
	if not self:IsModeratorClient() or not self.feed then return end
	local log, day = self.db.modStats, date("%Y-%m-%d")
	for _, line in ipairs(log) do
		if line:sub(5, 14) == day then return end
	end
	self:ResetSuspicion()
	local sets, rated, charted, suspicious, votes = #self.feed.sets, {}, 0, {}, 0
	local total = { 0, 0, 0, 0, 0 }
	for _, set in ipairs(self.feed.sets) do
		local r = set.rating
		if r and r.dist and (r.n or 0) > 0 then
			rated[#rated + 1] = set
			votes = votes + r.n
			for i = 1, 5 do total[i] = total[i] + (r.dist[i] or 0) end
			if self:IsCharted(set) then charted = charted + 1 end
			if self:GetSuspicion(set) then suspicious[#suspicious + 1] = set end
		end
	end
	local voters = 0
	for _ in pairs(VoterActivity()) do voters = voters + 1 end
	local sum = 0
	for i = 1, 5 do sum = sum + i * total[i] end
	local counts, players = self:GetAchievementPrevalence()
	local out = {}
	local function Add(...) out[#out + 1] = table.concat({ "1", ... }, "|") end
	local function Clean(s) return (tostring(s or ""):gsub("|", "/")) end
	-- рост сети: все известные игроки (авторы, голосовавшие, игроки рейтинга), авторы,
	-- голосовавшие за сутки и порог чарта
	local known, authors, active, now = {}, {}, {}, self.Net.Now()
	for _, set in ipairs(self.feed.sets) do
		if set.author then known[set.author], authors[set.author] = true, true end
	end
	for _, list in pairs(self.db.net.votes) do
		for name, v in pairs(list) do
			known[name] = true
			if now - (v[2] or 0) < 86400 then active[name] = true end
		end
	end
	for name, sc in pairs(self.db.net.scores) do
		if not sc.removed then known[name] = true end
	end
	local function Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
	Add("S", day, sets, #rated, charted, #suspicious, votes, voters, players,
		votes > 0 and string.format("%.2f", sum / votes) or "0", table.concat(total, "/"),
		Count(known), Count(authors), Count(active), self:GetMinChartVotes())
	table.sort(rated, function(a, b) return a.rating.n > b.rating.n end)
	for i = 1, math.min(#rated, STATS_SETS) do
		local set = rated[i]
		local r = set.rating
		local flag = self:GetSuspicion(set) and "s" or self:IsCharted(set) and "c" or "n"
		Add("V", day, set.id, Clean(set.author), r.n, string.format("%.2f", r.avg), string.format("%.3f", self:GetScore(set)),
			set.trend or 0, table.concat(r.dist, "/"), flag)
	end
	for _, set in ipairs(suspicious) do
		Add("X", day, set.id, Clean(set.author), set.rating.n, table.concat(self:GetSuspicion(set), ", "))
	end
	-- погасшие теги: какие теги чаще всего ставят не к месту
	for _, set in ipairs(self.feed.sets) do
		for tag, n in pairs(self:GetDisputedTags(set)) do
			Add("T", day, set.id, Clean(set.author), tag, n, set.rating and set.rating.n or 0)
		end
	end
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if (counts[a.id] or 0) > 0 then Add("A", day, a.id, counts[a.id], players) end
	end
	for _, line in ipairs(out) do log[#log + 1] = line end
	-- храним последние дни
	local keep, days = {}, {}
	for i = #log, 1, -1 do
		local d = log[i]:sub(5, 14)
		if not days[d] then days[d] = true; days.n = (days.n or 0) + 1 end
		if days.n <= STATS_DAYS then tinsert(keep, 1, log[i]) end
	end
	self.db.modStats = keep
end

function TH:Report(setId, reason)
	if self:IsTestId(setId) or self:IsLocalId(setId) then return end
	if self:IsExiled() then return self:ExileNotice() end
	local restricted = self:VoteRestrictionText()
	if restricted then return self:Notify(restricted) end
	self.db.myReports[setId] = self.Net.Now()
	self.Net:SendReport(setId, reason)
	self.db.hidden[setId] = true -- у пожаловавшегося образ сразу пропадает
	self.db.favorites[setId] = nil
	self:LoadFeed()
	self:NotifyChanged()
	self:Thanks(L["Жалоба отправлена модератору. Образ скрыт у вас."])
end

-- Вернуть один скрытый образ (или игрока рейтинга): своя жалоба на него отзывается
function TH:UndoReport(id)
	local r = self.db.net.reports[id] and self.db.net.reports[id][self.Net.MyAnonKey()]
	local retracted = r and r[1] ~= "u"
	if retracted then self.Net:SendReport(id, "u") end
	self.db.hidden[id] = nil
	self.db.myReports[id] = nil
	self.db.falseReports[id] = nil
	self:LoadFeed()
	self:NotifyChanged()
	return retracted
end

-- Скрытое у вас: { id, название, жалоба этого персонажа (причина) }, новые сверху по имени
function TH:GetHiddenList()
	local list = {}
	for id in pairs(self.db.hidden) do
		local name
		if id:sub(1, #self.PLAYER_REPORT_PREFIX) == self.PLAYER_REPORT_PREFIX then
			name = L["Игрок рейтинга "] .. id:sub(#self.PLAYER_REPORT_PREFIX + 1):gsub("%-.*", "")
		else
			local set = self.db.net.sets[id]
			name = set and ("«" .. (set.name or "?") .. "»  |cff888888" .. (set.author or "?"):gsub("%-.*", "") .. "|r") or L["|cff888888образа уже нет в базе|r"]
		end
		local r = self.db.net.reports[id] and self.db.net.reports[id][self.Net.MyAnonKey()]
		list[#list + 1] = { id = id, name = name, reason = r and r[1] ~= "u" and (self.REPORT_LABEL[r[1]] or r[1]) or nil }
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

-- Меню: что скрыто, по клику — вернуть
function TH:OpenHiddenMenu(owner)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local list = self:GetHiddenList()
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle(L["Скрыто у вас ("] .. #list .. ")")
		if #list == 0 then root:CreateTitle(L["|cff888888ничего не скрыто|r"]) end
		for i, e in ipairs(list) do
			if i > 50 then root:CreateTitle(L["|cff888888и ещё "] .. (#list - 50) .. "|r") break end
			local label = e.name .. (e.reason and (L["  |cffff9020жалоба: "] .. e.reason .. "|r") or "")
			local b = root:CreateButton(label, function()
				local retracted = self:UndoReport(e.id)
				self:Notify(L["Снова видно: "] .. e.name .. (retracted and L[". Жалоба отозвана."] or "."))
			end)
			if b and b.SetTooltip then
				b:SetTooltip(function(tip) GameTooltip_SetTitle(tip, L["Вернуть"]); GameTooltip_AddNormalLine(tip, e.reason and L["Образ снова будет виден, ваша жалоба отозвана у всех."] or L["Образ снова будет виден."]) end)
			end
		end
	end)
end

-- Отменить свои жалобы и скрытия (например, после проверки аддона): скрытое у вас
-- снова видно, жалобы этого персонажа отзываются у всех (отметка «u»), отметки
-- «тег не подходит» снимаются. Жалобы других своих персонажей отзываются на них.
function TH:UndoMyReports()
	local me, reports, flags = self.Net.Me(), 0, 0
	local myKey = self.Net.MyAnonKey()
	for setId, list in pairs(self.db.net.reports) do
		local r = list[myKey]
		if r and r[1] ~= "u" then
			self.Net:SendReport(setId, "u")
			reports = reports + 1
		end
	end
	for setId, tags in pairs(self.db.net.tagFlags) do
		for tag, list in pairs(tags) do
			local f = list[me]
			if f and f[1] == 1 then
				self.Net:SendTagFlag(setId, tag, 0)
				flags = flags + 1
			end
		end
	end
	local hidden = 0
	for _ in pairs(self.db.hidden) do hidden = hidden + 1 end
	wipe(self.db.hidden)
	wipe(self.db.myReports)
	wipe(self.db.falseReports)
	self:LoadFeed()
	self:NotifyChanged()
	self:Notify(string.format(L["Скрытых снова видно: %d. Отозвано жалоб: %d, отметок тегов: %d."], hidden, reports, flags))
end

-- Решение модератора: действует сразу у всех, до кого дотягиваемся напрямую,
-- и попадает в журнал для чёрного списка в обновлении аддона.
-- Игрок убран из рейтинга (чёрный список или решение модератора)
function TH:IsPlayerBlocked(name)
	local list = Blocklist()
	return (list.players and list.players[name]) or self.db.net.modBlocks.players[name] or false
end

-- Жалоба на накрутку рейтинга
function TH:ReportPlayer(name)
	if not name or self.db.myChars[name] then return end
	if self:IsExiled() then return self:ExileNotice() end
	local restricted = self:VoteRestrictionText()
	if restricted then return self:Notify(restricted) end
	local id = self.PLAYER_REPORT_PREFIX .. name
	self.Net:SendReport(id, "c")
	self.db.hidden[id] = true -- у пожаловавшегося игрок из рейтинга пропадает
	self:NotifyChanged()
	self:Thanks(L["Жалоба отправлена. Игрок скрыт из вашего рейтинга."])
end

function TH:ModDecision(action, target)
	if not self:IsModerator(self.Net.Me()) then return end
	if (action == "m" or action == "x") and not self:IsAdmin(self.Net.Me()) then return end
	self.Net:ApplyModDecision(action, target)
	self.Net:Send("M" .. action .. "\t" .. target)
	self:LogDecision(action, target)
	self:LoadFeed()
	self:NotifyChanged()
end
