local _, ns = ...
local L = ns.L
local TH = ns.TH

---------------------------------------------------------------------------
-- Официальный чарт. Каждый день его пересчитывают вне игры по данным
-- модератора (tools/charts/build.lua) с проверкой на накрутку и весом голосов
-- и выпускают с обновлением аддона в Data/Charts.lua. Награды за места
-- (сезонные, «доля лучших», первооткрыватели) и рейтинг очков стиля берутся
-- отсюда: их нельзя подделать своим клиентом. Пока чарта нет (разработка),
-- аддон считает места сам по данным сети.
---------------------------------------------------------------------------
local STALE_DAYS = 3 -- старше — просим обновить аддон

-- Достижения, которые выдаёт только официальный чарт
function TH:IsChartAchievement(a)
	return a.seasonal or a.stat == "topPct" or a.stat == "boardPct" or a.stat == "firstFinds" or a.stat == "hallOfFame"
		or (a.stat == "secret" and self.Secret.IsServer(a.id))
end

-- Скрытые, которые проверяет чарт: открыть название и подпись ключом из чарта,
-- а вместо условия написать, за какой образ получено
function TH:ApplyServerSecrets()
	local c = self:GetCharts()
	if not (c and type(c.secretKeys) == "table") then return end
	local names = {}
	for name in pairs(self.db.myChars) do names[name] = true end
	names[self.Net.Me()] = true
	if self.db.leader.char then names[self.db.leader.char] = true end
	for _, a in ipairs(self.ACHIEVEMENTS) do
		if a.stat == "secret" and self.Secret.IsServer(a.id) and not a.unlocked and self:GetOfficialAward(a) > 0 then
			local key = c.secretKeys[a.id]
			if key and self:ApplySecret(a, key) then
				a.unlocked = true
				local setName
				for name in pairs(names) do
					local setId = type(c.awardSets) == "table" and c.awardSets[name] and c.awardSets[name][a.id]
					local set = setId and self:GetSet(setId)
					if set then setName = self:SetName(set) break end
				end
				a.desc = setName and (L["Получено за образ «"] .. setName .. L["». Как именно — знают только Стражи подиума."])
					or L["Как именно получено — знают только Стражи подиума."]
			end
		end
	end
end

function TH:GetCharts()
	local c = TransmogHub_Charts
	if type(c) == "table" and type(c.t) == "number" and type(c.awards) == "table" then return c end
end

-- Сколько дней чарту (nil — чарта нет)
function TH:GetChartsAge()
	local c = self:GetCharts()
	if not c then return nil end
	return math.max(0, math.floor((self.Net.Now() - c.t) / 86400))
end

function TH:IsChartsStale()
	local age = self:GetChartsAge()
	return age ~= nil and age > STALE_DAYS
end

-- Свои персонажи: награды чарта выдаются автору образа и игроку в рейтинге
local function MyNames()
	local names = {}
	for name in pairs(TH.db.myChars) do names[name] = true end
	names[TH.Net.Me()] = true
	if TH.db.leader.char then names[TH.db.leader.char] = true end
	return names
end

-- Официальная награда своему аккаунту: уровень (для сезонных) или 1; 0 — нет
function TH:GetOfficialAward(a)
	local c = self:GetCharts()
	if not c then return 0 end
	local best = 0
	for name in pairs(MyNames()) do
		local v = c.awards[name] and c.awards[name][a.id]
		if v then best = math.max(best, tonumber(v) or 1) end
	end
	return best
end

-- Место образа в официальном списке: место, всего; nil — не в чарте
function TH:GetOfficialRank(listName, setId)
	local c = self:GetCharts()
	local list = c and c[listName]
	if type(list) ~= "table" or not setId then return nil end
	for i, id in ipairs(list) do
		if id == setId then return i, #list end
	end
	return nil, #list
end

-- Лучшее официальное место своих образов в списке: место, всего
function TH:GetMyOfficialRank(listName)
	local c = self:GetCharts()
	local list = c and c[listName]
	if type(list) ~= "table" then return nil, 0 end
	for i, id in ipairs(list) do
		if self:IsMine(self:GetSet(id) or { id = id }) then return i, #list end
	end
	return nil, #list
end

-- Официальные очки игрока в рейтинге: очки, место; nil — ещё не проверен
function TH:GetOfficialBoard(name)
	local c = self:GetCharts()
	if not (c and c.boardIndex) then
		if c and type(c.board) == "table" then
			c.boardIndex = {}
			for i, e in ipairs(c.board) do c.boardIndex[e[1]] = { e[2], i } end
		else
			return nil
		end
	end
	local e = c.boardIndex[name]
	if e then return e[1], e[2] end
end

-- Первооткрыватели из чарта: [id] = { имя, время }
function TH:GetOfficialFirsts()
	local c = self:GetCharts()
	return c and type(c.firsts) == "table" and c.firsts or {}
end

-- Зал славы: дата, когда образ туда попал (из официального чарта), иначе nil
function TH:GetHallDate(setId)
	local c = self:GetCharts()
	local h = c and type(c.hof) == "table" and setId and c.hof[setId]
	return h and h[4] or nil
end

-- Неделя в топ-10 и первых мест: для подсказки «до Зала славы»
function TH:GetHallProgress(setId)
	local c = self:GetCharts()
	local h = c and type(c.hof) == "table" and setId and c.hof[setId]
	if not h then return 0, 0 end
	return h[1] or 0, h[2] or 0
end

-- Дата чарта для подписей: «17.10»
function TH:FormatChartsDate()
	local c = self:GetCharts()
	return c and date("%d.%m", c.t) or ""
end

-- Раз за сессию напоминаем, если чарт устарел
function TH:CheckChartsFreshness()
	if self.chartsWarned or not self:IsChartsStale() then return end
	self.chartsWarned = true
	self:Print(string.format(L["Официальный рейтинг устарел (%d дн.). Обновите аддон, чтобы места и награды за них были свежими."],
		self:GetChartsAge()))
end
