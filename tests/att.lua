-- Сборка встроенной базы источников из AllTheThings: на маленьком образце его базы
--   lua5.1 tests/att.lua .
local dir = arg[1] or "."
local out = os.tmpname()
local ok = os.execute(string.format("lua5.1 %s/tools/att/build.lua %s/tests/fixtures/att %s > /dev/null", dir, dir, out))
assert(ok == 0 or ok == true, "build failed")
dofile(out)
os.remove(out)
local db = TransmogHub_ATT
assert(db and db.items, "data written")
-- вещь с боссом: подземелье, босс, координаты подземелья
assert(db.items[16800] == "I|I741|e1519|232:54.1:31.2|", "boss drop: " .. tostring(db.items[16800]))
-- вещь под заголовком: заголовок с названиями, цена
assert(db.items[16801] == "I|I741|h-12|232:54.1:31.2|g500000,c1220x5", "header + cost: " .. tostring(db.items[16801]))
assert(db.headers[-12].ruRU == "Достижения" and db.headers[-12].enUS == "Achievements", "header names")
-- задание, пропущенное через встроенную функцию базы: свои координаты
assert(db.items[16802] == "I|I741|q8905|87:43.5:52.6|", "quest: " .. tostring(db.items[16802]))
-- вещи без облика (i) не берём
assert(not db.items[17000], "plain items skipped")
print("ATT OK")
