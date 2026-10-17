-- Заглушка игрового API: ровно столько, чтобы загрузить логику аддона без игры.
-- Интерфейс не строится: любые методы кадров ничего не делают.
local M = {}

local function frame()
	return setmetatable({}, { __index = function(_, k)
		if type(k) == "string" and k:match("^%l") then return nil end
		return function() return nil end
	end })
end

function M.install(now)
	_G.CreateFrame = function(_, name)
		local f = frame()
		if name then _G[name] = f end
		return f
	end
	UIParent, GameTooltip, Minimap = frame(), frame(), frame()
	UISpecialFrames, StaticPopupDialogs, SlashCmdList = {}, {}, {}
	time = function() return now end
	date = os.date
	tinsert, tremove = table.insert, table.remove
	wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
	strtrim = function(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end
	tContains = function(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
	CopyTable = function(t) local r = {} for k, v in pairs(t) do r[k] = type(v) == "table" and CopyTable(v) or v end return r end
	Mixin = function(o, ...) for _, m in ipairs({ ... }) do for k, v in pairs(m) do o[k] = v end end return o end
	Clamp = function(v, a, b) return math.min(math.max(v, a), b) end
	C_Timer = { After = function() end, NewTicker = function() end }
	C_AddOns = { GetAddOnMetadata = function() return "build" end, LoadAddOn = function() end }
	C_ChatInfo = { RegisterAddonMessagePrefix = function() return true end, SendAddonMessage = function() return 0 end }
	C_CreatureInfo = { GetRaceInfo = function(id) return { raceName = "Раса" .. id } end }
	C_TransmogCollection, C_Item, C_Texture, C_BattleNet, C_FriendList = {}, {}, {}, {}, {}
	Enum = { SendAddonMessageResult = {}, ItemTryOnReason = {} }
	Constants = { Transmog = {} }
	GetLocale = function() return "ruRU" end
	GetServerTime = function() return now end
	GetTime = function() return 0 end
	UnitName = function() return "Сборщик" end
	GetNormalizedRealmName = function() return "Чарт" end
	UnitClass = function() return "Воин", "WARRIOR" end
	UnitRace = function() return "Человек", "Human", 1 end
	UnitSex = function() return 2 end
	GetFileIDFromPath = function() return 1 end
	BNGetNumFriends = function() return 0 end
	IsInGroup = function() return false end
	PlaySound = function() end
	GameTooltip_Hide = function() end
end

-- Файлы логики аддона в порядке загрузки (без интерфейса)
M.FILES = { "Locales/Locale.lua", "Locales/enUS.lua", "Data/Bundled.lua", "Data/Blocklist.lua", "Data/Charts.lua", "Data/Secrets.lua", "Data/TagIcons.lua", "Core.lua",
	"Moderation.lua", "Network.lua", "Secret.lua", "Achievements.lua", "Charts.lua", "Standing.lua" }

function M.load(dir)
	local ns = {}
	for _, f in ipairs(M.FILES) do
		assert(loadfile(dir .. "/" .. f))("TransmogHub", ns)
	end
	return ns.TH
end

return M
