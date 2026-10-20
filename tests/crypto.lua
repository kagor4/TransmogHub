-- Шифрование писем и обращений: аддон шифрует (Crypto.lua), закрытый ключ расшифровывает
--   lua5.1 tests/crypto.lua .
local dir = arg[1] or "."
local TH = {}
local ns = { TH = TH, L = setmetatable({}, { __index = function(_, k) return k end }) }
assert(loadfile(dir .. "/tests/fixtures/crypto/test_key.lua"))()
assert(loadfile(dir .. "/Crypto.lua"))("TransmogHub", ns)
local C = TH.LetterCrypto
local key = TransmogHub_LetterKey

-- закрытый ключ из тестового файла
local hex = {}
for line in io.lines(dir .. "/tests/fixtures/crypto/test.key") do
	local k, v = line:match("^(%a)=(%x+)$")
	if k then hex[k] = v end
end
local function HexBits(h)
	local bits = {}
	for i = 1, #h do
		local v = tonumber(h:sub(i, i), 16)
		for b = 3, 0, -1 do bits[#bits + 1] = math.floor(v / 2 ^ b) % 2 end
	end
	while bits[1] == 0 do table.remove(bits, 1) end
	return bits
end
local dBits = HexBits(hex.d)

local ALPHA = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz+/"
local function UnB64(s)
	local out, v, bits = {}, 0, 0
	for i = 1, #s do
		v = v * 64 + (ALPHA:find(s:sub(i, i), 1, true) - 1)
		bits = bits + 6
		if bits >= 8 then
			bits = bits - 8
			local d = math.floor(v / 2 ^ bits)
			v = v - d * 2 ^ bits
			out[#out + 1] = string.char(d)
		end
	end
	return table.concat(out)
end

local function Decrypt(cipher)
	assert(C.IsCipher(cipher), "cipher format")
	local raw = UnB64(cipher:sub(2))
	raw = raw:sub(1, #raw - #raw % 128)
	local out = {}
	for i = 1, #raw, 128 do
		local m = C.ToBytes(C.PowMod(C.FromBytes(raw:sub(i, i + 127), key.k), dBits, key), 128)
		m = m:gsub("^%z+", "")
		assert(m:byte(1) == 1, "block marker")
		out[#out + 1] = m:sub(11, 10 + m:byte(10))
	end
	return table.concat(out)
end

assert(C.Available(), "key loaded")
for _, text in ipairs({ "", "Кагор-Ревущийфьорд\tПривет!", string.rep("я", 150), ("Длинное письмо разработчику. "):rep(12) }) do
	local c1, c2 = C.Encrypt(text), C.Encrypt(text)
	assert(c1 ~= c2, "random padding: same text, different cipher")
	assert(not c1:find(text ~= "" and text:sub(1, 6) or "\0", 1, true), "text not visible")
	assert(Decrypt(c1) == text, "round trip: " .. #text)
end

-- расшифровка на Python (ежедневная задача) понимает шифровку аддона
local py = io.popen("command -v python3"):read("*l")
if py and py ~= "" then
	local tmp = os.tmpname()
	local f = io.open(tmp, "w")
	f:write("1|#rabc-Гордунни|123|i|" .. C.Encrypt("Кагор-Ревущийфьорд\tИдея: тёмная тема") .. "\n")
	f:write("1|Старый-Гордунни|124|i|обычный текст\n")
	f:close()
	local out = io.popen(string.format("python3 %s/tools/crypto/letters.py decrypt %s/tests/fixtures/crypto/test.key %s 2>/dev/null",
		dir, dir, tmp)):read("*a")
	os.remove(tmp)
	assert(out:find("1|Кагор-Ревущийфьорд|123|i|Идея: тёмная тема", 1, true), "python decrypt: " .. out)
	assert(out:find("1|Старый-Гордунни|124|i|обычный текст", 1, true), "plain lines kept")
	assert(os.execute(string.format("python3 %s/tools/crypto/letters.py selftest > /dev/null", dir)) == 0, "python selftest")
end
print("CRYPTO OK")
