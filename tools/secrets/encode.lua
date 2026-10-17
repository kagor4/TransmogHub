-- Собирает зашифрованный Data/Secrets.lua из открытого списка скрытых достижений.
--   lua5.1 tools/secrets/encode.lua <папка аддона> <secrets/hidden.lua> <secrets/master.txt> <выход Data/Secrets.lua>
-- Открытый список и секрет хранятся ТОЛЬКО в закрытом репозитории kagor4/TransmogHub-reports.
-- Тайны за теги и слово (probe tags/word) проверяет официальный чарт: в аддон от них
-- попадают только зашифрованные название и подпись, условия — нет.
local dir, plainPath, masterPath, outPath = arg[1], arg[2], arg[3], arg[4]
assert(dir and plainPath and masterPath and outPath, "usage: encode.lua <addon dir> <hidden.lua> <master.txt> <out>")

local ns = { TH = {} }
assert(loadfile(dir .. "/Secret.lua"))("TransmogHub", ns)
local Secret = ns.TH.Secret
local plain = assert(loadfile(plainPath))()
local f = assert(io.open(masterPath))
local master = f:read("*l"):gsub("%s", "")
f:close()
assert(#master >= 16, "секрет слишком короткий")

local SERVER = { tags = true, word = true }
local ids = {}
for id in pairs(plain) do ids[#ids + 1] = id end
table.sort(ids)

-- Вариант для WoW Forever: свои условия и тексты поверх основных. Локали заменяются
-- целиком по языку (русский текст с блогером из основной игры в Forever не попадает).
local function ForeverOf(e)
	local f = e.forever
	if not f then return nil end
	local v = {}
	for k, x in pairs(e) do if k ~= "forever" and k ~= "locale" then v[k] = x end end
	for k, x in pairs(f) do if k ~= "locale" then v[k] = x end end
	v.locale = {}
	for loc, o in pairs(e.locale or {}) do v.locale[loc] = o end
	for loc, o in pairs(f.locale or {}) do v.locale[loc] = o end
	return v
end

local function Emit(lines, id, e, key)
	assert(e.probe and e.conds and #e.conds > 0 and e.name and e.desc, "неполная запись: " .. id)
	local server = SERVER[e.probe]
	local fields = { name = e.name, flavor = e.flavor or "", icon = e.icon or "INV_Misc_QuestionMark" }
	if not server then fields.desc = e.desc end -- условие сервера не публикуется даже зашифрованным
	for loc, o in pairs(e.locale or {}) do
		for k, v in pairs(o) do
			if not (server and k == "desc") then fields[loc .. "." .. k] = v end
		end
	end
	for k, v in pairs(fields) do assert(not v:find("\n"), "перевод строки в " .. id .. "." .. k) end
	if server then
		lines[#lines + 1] = string.format("\t%s = { probe = \"server\", data = %q },", id, Secret.Seal(fields, key))
	else
		local locks = {}
		for _, cond in ipairs(e.conds) do
			local full = e.probe .. ":" .. cond
			locks[#locks + 1] = string.format("{ h = %q, w = %q }", Secret.LockHash(id, full), Secret.WrapKey(id, full, key))
		end
		lines[#lines + 1] = string.format("\t%s = { probe = %q, locks = { %s },", id, e.probe, table.concat(locks, ", "))
		lines[#lines + 1] = string.format("\t\tdata = %q },", Secret.Seal(fields, key))
	end
end

local lines = {
	"-- Скрытые достижения: тексты зашифрованы, условия — у официального чарта или отпечатками (см. Secret.lua).",
	"-- Файл собирает tools/secrets/encode.lua, не правьте руками.",
	"TransmogHub_Secrets = {",
}
for _, id in ipairs(ids) do Emit(lines, id, plain[id], Secret.DeriveKey(master, id)) end
lines[#lines + 1] = "}"
-- WoW Forever: заменяет записи выше (Core.lua), ключ свой — чарт Forever выдаёт его же
lines[#lines + 1] = "TransmogHub_SecretsForever = {"
local nf = 0
for _, id in ipairs(ids) do
	local v = ForeverOf(plain[id])
	if v then Emit(lines, id, v, Secret.DeriveKey(master, id .. "@forever")) nf = nf + 1 end
end
lines[#lines + 1] = "}"
local out = assert(io.open(outPath, "w"))
out:write(table.concat(lines, "\n"), "\n")
out:close()
print(#ids .. " тайн (для Forever — " .. nf .. ") записано в " .. outPath)
