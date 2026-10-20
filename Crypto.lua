local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Шифрование писем разработчику и обращений открытым ключом (RSA-1024).
-- Письма расходятся по сети через клиенты других игроков и лежат в их файлах
-- сохранений, поэтому текст и имя автора уходят шифровкой: прочитать её можно
-- только закрытым ключом модератора (tools/crypto/letters.py, ключ — в закрытом
-- репозитории). Расшифровывать в игре не нужно.
--
-- Большие числа — массивы «цифр» по 24 бита (младшие первыми): произведение двух
-- цифр меньше 2^48, и сумма с переносами точно помещается в число Lua (2^53).
-- Возведение в степень 65537 — умножением Монтгомери (без деления больших чисел),
-- константы r2 = R^2 mod n и n0inv = -n^-1 mod 2^24 приходят готовыми с ключом.
--
-- Блок до шифрования: 0x01, 8 случайных байт, длина, до 100 байт данных.
-- Шифровка: «~» и base64 (0-9A-Za-z+/) из блоков по 128 байт.
---------------------------------------------------------------------------
local Crypto = {}
TH.LetterCrypto = Crypto

local B = 16777216 -- 2^24
local BLOCK, DATA = 128, 100
local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"
local floor = math.floor

-- a * b * R^-1 mod n (a, b < n; k цифр)
local function MontMul(a, b, n, n0inv, k)
	local t = {}
	for i = 1, k + 2 do t[i] = 0 end
	for i = 1, k do
		local ai, c = a[i] or 0, 0
		for j = 1, k do
			local x = t[j] + ai * (b[j] or 0) + c
			c = floor(x / B)
			t[j] = x - c * B
		end
		local x = t[k + 1] + c
		c = floor(x / B)
		t[k + 1] = x - c * B
		t[k + 2] = t[k + 2] + c
		local m = (t[1] * n0inv) % B
		x = t[1] + m * n[1]
		c = floor(x / B)
		for j = 2, k do
			x = t[j] + m * n[j] + c
			c = floor(x / B)
			t[j - 1] = x - c * B
		end
		x = t[k + 1] + c
		c = floor(x / B)
		t[k] = x - c * B
		t[k + 1] = t[k + 2] + c
		t[k + 2] = 0
	end
	-- результат < 2n: если не меньше n — вычесть n
	local ge = t[k + 1] > 0
	if not ge then
		ge = true
		for j = k, 1, -1 do
			if t[j] ~= n[j] then ge = t[j] > n[j] break end
		end
	end
	local out = {}
	if ge then
		local borrow = 0
		for j = 1, k do
			local x = t[j] - n[j] - borrow
			if x < 0 then x, borrow = x + B, 1 else borrow = 0 end
			out[j] = x
		end
	else
		for j = 1, k do out[j] = t[j] end
	end
	return out
end
Crypto.MontMul = MontMul

-- Байты (старшие первыми) -> цифры
local function FromBytes(s, k)
	local out, j = {}, 1
	for i = 1, k do out[i] = 0 end
	local pos = #s
	while pos >= 1 do
		local v, mul = 0, 1
		for _ = 1, 3 do
			if pos >= 1 then
				v = v + s:byte(pos) * mul
				mul, pos = mul * 256, pos - 1
			end
		end
		out[j], j = v, j + 1
	end
	return out
end
Crypto.FromBytes = FromBytes

-- Цифры -> ровно len байт (старшие первыми)
local function ToBytes(x, len)
	local bytes = {}
	for i = 1, #x do
		local v = x[i]
		for _ = 1, 3 do
			bytes[#bytes + 1] = v % 256
			v = floor(v / 256)
		end
	end
	local out = {}
	for i = len, 1, -1 do out[#out + 1] = string.char(bytes[i] or 0) end
	return table.concat(out)
end
Crypto.ToBytes = ToBytes

-- x^e mod n умножением Монтгомери; e — массив битов, старшие первыми (для 65537 — свой путь)
function Crypto.PowMod(x, bits, key)
	local n, n0inv, k = key.n, key.n0inv, key.k
	local xm = MontMul(x, key.r2, n, n0inv, k) -- x·R
	local acc
	for _, bit in ipairs(bits) do
		acc = acc and MontMul(acc, acc, n, n0inv, k)
		if bit == 1 then acc = acc and MontMul(acc, xm, n, n0inv, k) or xm end
	end
	local one = { 1 }
	for i = 2, k do one[i] = 0 end
	return MontMul(acc, one, n, n0inv, k)
end

local E_BITS = { 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1 } -- 65537

local function B64(s)
	local out, v, bits = {}, 0, 0
	for i = 1, #s do
		v = v * 256 + s:byte(i)
		bits = bits + 8
		while bits >= 6 do
			bits = bits - 6
			local d = floor(v / 2 ^ bits)
			v = v - d * 2 ^ bits
			out[#out + 1] = ALPHA:sub(d + 1, d + 1)
		end
	end
	if bits > 0 then
		local d = v * 2 ^ (6 - bits)
		out[#out + 1] = ALPHA:sub(d + 1, d + 1)
	end
	return table.concat(out)
end
Crypto.B64 = B64

function Crypto.Available()
	local key = TransmogHub_LetterKey
	return type(key) == "table" and type(key.n) == "table" and type(key.r2) == "table" and key.k ~= nil
end

-- Текст (байты) -> «~шифровка»; nil, если ключа нет
function Crypto.Encrypt(data, key)
	key = key or TransmogHub_LetterKey
	if not (key and key.n) then return nil end
	data = tostring(data or "")
	local out, pos = {}, 1
	repeat
		local piece = data:sub(pos, pos + DATA - 1)
		pos = pos + DATA
		local pad = {}
		for i = 1, 8 do pad[i] = string.char(math.random(0, 255)) end
		local block = "\1" .. table.concat(pad) .. string.char(#piece) .. piece
		local c = Crypto.PowMod(FromBytes(block, key.k), E_BITS, key)
		out[#out + 1] = ToBytes(c, BLOCK)
	until pos > #data
	return "~" .. B64(table.concat(out))
end

-- Похоже на шифровку: только «~» и алфавит base64
function Crypto.IsCipher(s)
	return type(s) == "string" and s:match("^~[%w+/]+$") ~= nil
end
