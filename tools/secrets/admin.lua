-- Отпечаток персонажа для TH.ADMIN_HASHES (Moderation.lua):
--   lua5.1 tools/secrets/admin.lua "Имя-Сервер" [...]
local TH = {}
assert(loadfile("Secret.lua"))("TransmogHub", { TH = TH })
for _, name in ipairs(arg) do
	print(string.format('\t["%s"] = true,', TH.Secret.Hash("thub-admin:" .. name)))
end
