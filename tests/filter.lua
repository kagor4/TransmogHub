local ns = { TH = {}, L = setmetatable({}, { __index = function(_, k) return k end }) }
local TH = ns.TH
strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
-- Lower from Core.lua
local CYR = {}
do
  local up, lo = "АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ", "абвгдеёжзийклмнопрстуфхцчшщъыьэюя"
  local u, l = {}, {}
  for ch in up:gmatch("[\192-\255][\128-\191]*") do u[#u+1]=ch end
  for ch in lo:gmatch("[\192-\255][\128-\191]*") do l[#l+1]=ch end
  for i=1,#u do CYR[u[i]]=l[i] end
  for code = 0xC0, 0xDE do
    if code ~= 0xD7 then CYR["\195" .. string.char(code - 0x40)] = "\195" .. string.char(code - 0x20) end
  end
end
TH.Lower = function(s) return (s:lower():gsub("[\195\208\209][\128-\191]", CYR)) end
assert(loadfile(arg[1] .. "/Moderation.lua"))("TransmogHub", ns)
local bad = { "Hijo de puta", "HIJOPUTA", "Puta madre", "Gilipollas", "Pendejo", "Maricón", "Cabrón", "CABRÓN", "Joder tío", "Mierda pura", "Coño", "Chingada", "Hijodeputa", "Follador",
	"Хуй", "ХУЙ", "х.у.й", "х у й", "хууууй", "xуй", "ПИЗДАТЫЙ рыцарь", "Блядский пират", "бля", "Бля буду",
  "Ебанутый маг", "долбоёб", "Мудак", "пидор", "Сука", "fuck off", "Bitch please", "shitty set", "ж0па", "Жопа",
  "заебал", "сучка", "гандон", "www.mysite.ru", "http://x", "discord.gg/abc", "п и з д а", "ПиЗдЕц",
  "Www gold ru", "gold . com", "голд точка рф", "золото gold-shop ru", "пиши в дискорд", "Мой twitch", "w w w . g o l d . r u",
  "Продам голд тг", "Канал на ютуб", "gold.store", "Сайт gold info", "Подпишись vk", "Gold r u", "Gold р у", "голд . р . ф", "w w w gold",
  "Х-уй", "Пи-зда", "Ху*йня", "х_у_й", "Пи.здец", "Ё-бaный", "Б-ля", "Су-ка", "Му-дак", "Пид-ор", "x-уй", "Хуй-пират", "Па-ра-хуй",
  "Пиз-дюк", "Муд-ак", "Еба-ный", "Ган-дон", "Пидо-рас", "Залу-па", "Шлю-ха", "Fu-ck", "Bit-ch", "Сук-ин",
  "Пиз\194\160дюк", "Пиз\226\128\139дюк", "Х★уй", "Пиз1дюк", "Му|дак", "Е#бан",
  "Бля-дский", "Бля.дь", "Бля*тство", "Сбля-дский",
  "Пиз дача", "Пи зда", "Ху йня", "Бля дский", "Му дак", "Еба ный", "Пидо рас", "Залу па", "Шлю ха" }
local good = { "Disputa del rey", "Computadora", "Conocer", "Corazón de león", "Caballero de la Muerte", "Señor del Fuego", "Ñandú dorado", "Pollito",
	"Сабля дракона", "Абордажная сабля", "Корабля капитан", "Художник", "Розовый троль", "Пират Кровавых Парусов",
  "Херувимский страж", "Хлебный пекарь", "Скорбящий рыцарь", "Тёмный некромант", "Shadow Hunter", "Dickens style",
  "Король Лич", "Употребляй с умом", "Сук-ко", "Великий страж Азерота", "Рубашка", "Мундир", "Жокей", "Скибидей",
  "Made by Dkag", "Русский богатырь", "Компания героев", "Netherlight", "Информатор", "Пират 12312",
  "Ком", "Topaz knight", "Король и Шут", "Плащ и кинжал", "Т 5 воин", "Wwise",
  "Сабля-дракон", "Тёмный-светлый", "Плащ-невидимка", "Северо-западный", "Рыцарь-маг", "Ху-ан-лун", "По-боевому", "Кто-нибудь",
  "Сто-лица", "Пират-капитан", "Т-2", "Мех-воин", "Дух-хранитель",
  "Корабля-дракон", "Рубля-дань", "Сабля-тень", "Жёлто-зелёный", "Сине-белый", "Небо-батальон", "Чёрно-красный", "Рыцарь-скелет",
  "Сабля-тень", "Корабля-дракон-призрак", "Дирижабля-трос", "Капитан корабля-дракона",
  "Сабля дракона", "Абордажная сабля дракона", "Ось зла", "Тень хаоса", "Мой рыцарь", "Лес эльфов", "Дух леса",
  "Ночной эльф", "Лук да стрелы", "Пол ночи", "Сто лиц", "Огонь и лёд", "Бой с тенью", "Меч и щит", "Хан Ули",
  "Пира т", "Кот ик", "Ведьма леса", "Мех и кожа", "Ход конём", "Дом у реки", "Сила духа", "Ад и рай", "Боец ада" }
local fails = 0
for _, t in ipairs(bad) do if TH:IsTextAllowed(t) then print("NOT BLOCKED:", t); fails = fails + 1 end end
for _, t in ipairs(good) do if not TH:IsTextAllowed(t) then print("FALSE POSITIVE:", t); fails = fails + 1 end end
-- названия: из одних цифр нельзя, ссылки — понятная ошибка
C_Club = nil
local function check(name, expect)
  local err = TH:ValidateSetText(name, "")
  local ok
  if expect == "" then ok = err == nil else ok = err ~= nil and err:find(expect, 1, true) ~= nil end
  if not ok then
    print("NAME CHECK:", name, tostring(err)); fails = fails + 1
  end
end
check("12312", "буквы"); check("123 45 !", "буквы"); check("Пират 12312", ""); check("T5 рыцарь", "")
check("Www gold ru", "Ссылки")
for _, n in ipairs({ "Пират ★", "Маг@", "#топ", "Рыцарь {череп}", "Плащ/кинжал", "Меч_тьмы", "Тень~", "Love ♥", "Огонь 🔥",
    "Цена 5$", "Сет=топ", "Рыцарь;", "Тёмный «лорд» \"x\"", "a|cffff0000b" }) do
  if not TH:ValidateSetText(n, "") then print("SYMBOL ALLOWED:", n); fails = fails + 1 end
end
for _, n in ipairs({ "Король-лич", "Пират, капитан!", "Что? Где? Когда?", "Т2 (классика)", "Рыцарь: Начало", "D'Artagnan",
    "«Тёмный» лорд", "Garçon élégant", "Über Krieger", "Señor Pirata", "검은 기사", "黑暗骑士", "Ну и ну...", "Ура!!!", "Меч & щит", "Dungeons&Dragons" }) do
  local err = TH:ValidateSetText(n, "")
  if err then print("SYMBOL REJECTED:", n, err); fails = fails + 1 end
end
check("Ура!!!!", "подряд")
for _, n in ipairs({ "фывфвфыв", "Фыва образ", "йцукен", "asdfgh", "Пиратааа", "бвгджз", "qwerty топ", "ывывыв" }) do
  check(n, "случайный")
end
for _, n in ipairs({ "Пират кровавых парусов", "Шварцкопф", "Strength", "Ночной эльф", "Лич", "Ммм пирог", "Schwarzschild",
    "Аллиансовец", "Варсонг", "Ниндзя в ночи", "Сильвана", "Кель'Тас", "Иллидари", "Анна", "Ассасин", "Тролль" }) do
  check(n, "")
end
if TH:IsSetTextAllowed({ name = "12312", desc = "" }) then print("NUMERIC NET SET ALLOWED"); fails = fails + 1 end
print(fails == 0 and "FILTER OK" or ("FAILS: " .. fails))
