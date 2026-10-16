local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Тайны скрытых достижений. Условие и тексты (название, описание, подпись,
-- иконка) не лежат в файлах аддона открытым текстом. Тайны за теги и слово в
-- названии (probe = "server") проверяет официальный чарт: в аддоне от них только
-- зашифрованные название и подпись, ключ к ним приходит с чартом после первой находки.
-- Остальные (расы, время, скрытые слоты) проверяет аддон:
--   * условие хранится отпечатком: аддон считает такой же отпечаток от того,
--     что есть у игрока (теги образа, слова названия, примеренные расы…),
--     и сравнивает;
--   * тексты зашифрованы ключом, который открывается только этим условием.
-- Это защита от подглядывания в файлы, а не от целенаправленного перебора.
-- Данные — Data/Secrets.lua, их собирает tools/secrets/encode.lua из открытого
-- списка в закрытом репозитории.
---------------------------------------------------------------------------
local Secret = {}
TH.Secret = Secret

local P1, P2 = 2147483647, 2147483629

-- Отпечаток строки: 16 шестнадцатеричных знаков
function Secret.Hash(s)
	local h1, h2 = 5381, 7919
	for i = 1, #s do
		local b = s:byte(i)
		h1 = (h1 * 257 + b) % P1
		h2 = (h2 * 263 + b) % P2
	end
	return string.format("%08x%08x", h1, h2)
end

local function Stream(key)
	local h = Secret.Hash(key)
	local s1 = tonumber(h:sub(1, 8), 16) % 2147483646 + 1
	local s2 = tonumber(h:sub(9, 16), 16) % 2147483398 + 1
	return function()
		s1 = (s1 * 48271) % 2147483647
		s2 = (s2 * 40692) % 2147483399
		return (s1 + s2) % 256
	end
end

function Secret.Encrypt(text, key)
	local nextByte, out = Stream(key), {}
	for i = 1, #text do out[i] = string.format("%02x", (text:byte(i) + nextByte()) % 256) end
	return table.concat(out)
end

function Secret.Decrypt(hex, key)
	local nextByte, out = Stream(key), {}
	for i = 1, #hex - 1, 2 do
		out[#out + 1] = string.char((tonumber(hex:sub(i, i + 1), 16) - nextByte()) % 256)
	end
	return table.concat(out)
end

-- Ключ тайны выводится из секрета разработчика (лежит только в закрытом репозитории):
-- шифровщик и расчёт чарта получают один и тот же ключ без отдельного хранилища
function Secret.DeriveKey(master, id) return Secret.Hash("key:" .. master .. ":" .. id) end

-- Тайны с probe = "server" проверяет только официальный чарт: в аддоне нет ни условия,
-- ни его отпечатка — перебирать нечего
function Secret.IsServer(id)
	local e = TransmogHub_Secrets and TransmogHub_Secrets[id]
	return e ~= nil and e.probe == "server"
end

-- Замок: отпечаток условия и ключ тайны, зашифрованный этим условием
function Secret.LockHash(id, cond) return Secret.Hash("lock:" .. id .. ":" .. cond) end
function Secret.WrapKey(id, cond, key) return Secret.Encrypt(key, "key:" .. id .. ":" .. cond) end
function Secret.UnwrapKey(id, cond, wrap) return Secret.Decrypt(wrap, "key:" .. id .. ":" .. cond) end

-- Тексты тайны: строки «поле=значение», первая строка — «ok» для проверки ключа
function Secret.Open(data, key)
	local text = Secret.Decrypt(data, key)
	if text:sub(1, 3) ~= "ok\n" then return nil end
	local fields = {}
	for line in text:sub(4):gmatch("[^\n]+") do
		local k, v = line:match("^([%w_%.]+)=(.*)$")
		if k then fields[k] = v end
	end
	return fields
end

function Secret.Seal(fields, key)
	local keys = {}
	for k in pairs(fields) do keys[#keys + 1] = k end
	table.sort(keys)
	local lines = { "ok" }
	for _, k in ipairs(keys) do lines[#lines + 1] = k .. "=" .. fields[k] end
	return Secret.Encrypt(table.concat(lines, "\n") .. "\n", key)
end

-- Подходит ли условие к тайне: вернёт ключ или nil
function Secret.TryCond(id, entry, cond)
	local full = entry.probe .. ":" .. cond
	local h = Secret.LockHash(id, full)
	for _, lock in ipairs(entry.locks or {}) do
		if lock.h == h then return Secret.UnwrapKey(id, full, lock.w) end
	end
end

---------------------------------------------------------------------------
-- Кандидаты условий: что есть у игрока
---------------------------------------------------------------------------
-- Буквы строки UTF-8
local function Chars(s)
	local out = {}
	for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do out[#out + 1] = ch end
	return out
end

local function SortedJoin(list)
	local copy = {}
	for i, v in ipairs(list) do copy[i] = v end
	table.sort(copy)
	return table.concat(copy, ",")
end

-- Все сочетания до 4 тегов (тегов у образа не больше 5)
local function TagSubsets(tags, add)
	local n = math.min(#tags, 6)
	for mask = 1, 2 ^ n - 1 do
		local pick, m = {}, mask
		for i = 1, n do
			if m % 2 == 1 then pick[#pick + 1] = tags[i] end
			m = math.floor(m / 2)
		end
		if #pick <= 4 then add(SortedJoin(pick)) end
	end
end

-- sets — свои образы, которые засчитываются (approved), или все
function Secret.Candidates(probe, sets)
	local out, seen = {}, {}
	local function add(v)
		if not seen[v] then seen[v] = true; out[#out + 1] = v end
	end
	local s = TH.db.stats
	if probe == "tags" then
		for _, set in ipairs(sets) do TagSubsets(TH:GetActiveTags(set), add) end
	elseif probe == "word" then
		for _, set in ipairs(sets) do
			local ch = Chars(TH.Lower(set.name or ""))
			for i = 1, #ch do
				local w = ""
				for j = i, math.min(#ch, i + 15) do
					w = w .. ch[j]
					if j > i then add(w) end
				end
			end
		end
	elseif probe == "races" then
		local races = {}
		for id in pairs(s.races or {}) do races[#races + 1] = tonumber(id) or id end
		table.sort(races, function(a, b) return tostring(a) < tostring(b) end)
		for i = 1, #races do
			for j = i + 1, #races do add(SortedJoin({ tostring(races[i]), tostring(races[j]) })) end
		end
	elseif probe == "hidden" then
		for _, set in ipairs(sets) do
			local n = 0
			for _, it in pairs(set.items or {}) do
				local d = TH:GetSourceDetails(it[1])
				if d and d.hidden then n = n + 1 end
			end
			for k = 1, n do add(tostring(k)) end
		end
	elseif probe == "clock" then
		for mark in pairs(s.clockSeen or {}) do add(mark) end
	end
	return out
end

-- Отметка времени открытия окна (десятиминутки): «00:0» — с 00:00 до 00:09
function TH:MarkClock()
	local s = self.db.stats
	s.clockSeen = s.clockSeen or {}
	s.clockSeen[string.format("%02d:%d", tonumber(date("%H")) or 0, math.floor((tonumber(date("%M")) or 0) / 10))] = true
end
