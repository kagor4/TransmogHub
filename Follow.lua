local _, ns = ...
local TH = ns.TH

---------------------------------------------------------------------------
-- Подписки на авторов. Подписка — на персонажа-автора; в сеть уходит отметка от
-- текущего персонажа (как избранное), а список «на кого подписан» общий для всех
-- своих персонажей. Подписчиков автора видят все — по отметкам в сети.
-- Уведомления: новый образ того, на кого подписан; на вас подписались; ваш образ
-- оценили (только первые N оценок каждого образа). Что показывать — в настройках.
---------------------------------------------------------------------------
local NOTIFY_WINDOW = 3 * 86400  -- старше — не уведомляем (пришло при синхронизации)
local FOLLOW_WINDOW = 7 * 86400
local BATCH_DELAY, BATCH_SHOW = 3, 3 -- события копим 3 с; больше трёх — сводкой
local NOTE_COLOR = { 0.2, 0.75, 0.95 }
-- звёзды значками игры: символа ★ в шрифтах игры нет (квадратики)
local function StarMarkup(r, g, b)
	return CreateAtlasMarkup and CreateAtlasMarkup("PetJournal-FavoritesIcon", 12, 12, 0, 0, r, g, b) or "*"
end

function TH:IsFollowing(name)
	return name ~= nil and self.db.following[name] ~= nil
end

function TH:GetFollowingList()
	local list = {}
	for name in pairs(self.db.following) do list[#list + 1] = name end
	table.sort(list)
	return list
end

-- Сколько персонажей подписано на автора
function TH:GetFollowerCount(name)
	local n = 0
	for _, f in pairs(self.db.net.follows[name] or {}) do
		if f[1] == 1 then n = n + 1 end
	end
	return n
end

-- Кто подписан на автора: список имён по алфавиту
function TH:GetFollowers(name)
	local list = {}
	for who, f in pairs(self.db.net.follows[name] or {}) do
		if f[1] == 1 then list[#list + 1] = who end
	end
	table.sort(list)
	return list
end

-- Список подписчиков (и подписок — в своём профиле) меню: подписаться в ответ, профиль
function TH:OpenFollowersMenu(owner, name)
	if not (MenuUtil and MenuUtil.CreateContextMenu) then return end
	local followers = self:GetFollowers(name)
	local mine = self.db.myChars[name]
	local function Short(n) return (n:gsub("%-.*", "")) end
	MenuUtil.CreateContextMenu(owner, function(_, root)
		root:CreateTitle("Подписчики (" .. #followers .. ")")
		if #followers == 0 then root:CreateTitle("|cff888888пока никого|r") end
		for i, who in ipairs(followers) do
			if i > 40 then
				root:CreateTitle("|cff888888и ещё " .. (#followers - 40) .. "|r")
				break
			end
			local me = self.db.myChars[who]
			local label = Short(who) .. (self:IsFollowing(who) and "  |cff40ff40взаимно|r" or "")
			local sub = root:CreateButton(label)
			sub:CreateButton("Профиль", function() self.UI:OpenProfile(who) end)
			if not me then
				sub:CreateButton(self:IsFollowing(who) and "Отписаться" or "Подписаться в ответ", function() self:ToggleFollow(who) end)
			end
		end
		if mine then
			local following = self:GetFollowingList()
			root:CreateDivider()
			root:CreateTitle("Ваши подписки (" .. #following .. ")")
			for _, who in ipairs(following) do
				local sub = root:CreateButton(Short(who))
				sub:CreateButton("Профиль", function() self.UI:OpenProfile(who) end)
				sub:CreateButton("Отписаться", function() self:SetFollowing(who, false) end)
			end
		end
	end)
end

-- Подписан ли name на кого-то из своих персонажей
function TH:FollowsMe(name)
	for me in pairs(self.db.myChars) do
		local f = self.db.net.follows[me] and self.db.net.follows[me][name]
		if f and f[1] == 1 then return true end
	end
	return false
end

function TH:IsMutual(name)
	return self:IsFollowing(name) and self:FollowsMe(name)
end

function TH:SetFollowing(name, on)
	if not name or self.db.myChars[name] then return end
	if self:IsExiled() then return self:ExileNotice() end
	if on then
		self.db.following[name] = self.Net.Now()
		self.Net:SendFollow(name, 1)
		self:Notify("Вы подписались на " .. (name:gsub("%-.*", "")) .. ". Новые образы — во вкладке «Подписки».")
	else
		self.db.following[name] = nil
		self.Net:SendFollow(name, 0)
		self:Notify("Вы отписались от " .. (name:gsub("%-.*", "")) .. ".")
	end
	self:NotifyChanged()
end

-- Уведомления от конкретного автора можно выключить, не отписываясь
function TH:IsFollowMuted(name)
	return self.db.followMuted[name] == true
end

function TH:SetFollowMuted(name, muted)
	self.db.followMuted[name] = muted or nil
end

function TH:ToggleFollow(name)
	self:SetFollowing(name, not self:IsFollowing(name))
end

-- Персонаж мог подписаться раньше, а аккаунт с тех пор отписался: отписываем и его
function TH:ReconcileFollows()
	local me = self.Net.Me()
	for target, list in pairs(self.db.net.follows) do
		local f = list[me]
		if f and f[1] == 1 and not self.db.following[target] then self.Net:SendFollow(target, 0) end
	end
end

---------------------------------------------------------------------------
-- Уведомления
---------------------------------------------------------------------------
local pending = {}
local flushScheduled = false

local function Short(name) return (name or "?"):gsub("%-.*", "") end

local function Flush()
	flushScheduled = false
	local list = pending
	pending = {}
	local s = TH.db.notify
	for i, e in ipairs(list) do
		if s.chat then TH:Print(e.chat) end
		if i <= BATCH_SHOW then TH:ShowToast("note", e.toast) end
	end
	if #list > BATCH_SHOW then
		TH:ShowToast("note", { icon = "Interface\\Icons\\INV_Letter_15", header = "Transmog Hub · подписки",
			title = string.format("И ещё %d событий", #list - BATCH_SHOW), text = "Подробности — в чате", color = NOTE_COLOR,
			onClick = function() TH.UI:Open(); TH.UI:SetView("subs") end })
	end
end

local function Push(key, t, chat, toast)
	local db = TH.db
	if db.notified[key] then return end
	db.notified[key] = t
	toast.header = toast.header or "Transmog Hub · подписки"
	toast.color = toast.color or NOTE_COLOR
	toast.sound = toast.sound or (SOUNDKIT and SOUNDKIT.TELL_MESSAGE)
	pending[#pending + 1] = { chat = chat, toast = toast }
	if not flushScheduled then
		flushScheduled = true
		C_Timer.After(BATCH_DELAY, Flush)
	end
end

local function Ready()
	return TH.db and TH.loggedIn and TH.ShowToast
end

-- Новый образ того, на кого подписан
function TH:OnSetStored(set)
	if not Ready() or not set.author or not self:IsFollowing(set.author) or self:IsFollowMuted(set.author) then return end
	local s = self.db.notify
	if not s.sets or (s.mutualOnly and not self:IsMutual(set.author)) then return end
	if self.Net.Now() - (set.created or 0) > NOTIFY_WINDOW then return end
	Push("s:" .. set.id, self.Net.Now(), "Новый образ от " .. Short(set.author) .. ": «" .. (set.name or "?") .. "»", {
		icon = self:GetSetIcon(set),
		title = "Новый образ от " .. Short(set.author),
		text = "«" .. (set.name or "?") .. "»",
		onClick = function() self.UI:Open(); self.UI:SetView("subs"); self.UI:Select(set.id) end,
	})
end

-- Ваш образ оценили: только первые N оценок каждого образа
function TH:OnVoteStored(setId, voter, stars, t)
	if not Ready() or self.db.myChars[voter] then return end
	local s = self.db.notify
	if not s.votes then return end
	local set = self.db.net.sets[setId]
	if not (set and set.author and self.db.myChars[set.author]) then return end
	if self.Net.Now() - (t or 0) > NOTIFY_WINDOW then return end
	if (s.mutualOnly and not self:IsMutual(voter)) or self:IsFollowMuted(voter) then return end
	if (s.voteLimit or 0) > 0 then
		local n = 0
		for _ in pairs(self.db.net.votes[setId] or {}) do n = n + 1 end
		if n > s.voteLimit then return end
	end
	local starsText = string.rep(StarMarkup(255, 255, 255), stars) .. string.rep(StarMarkup(90, 90, 90), 5 - stars)
	Push("v:" .. setId .. ":" .. voter, self.Net.Now(), Short(voter) .. " оценил ваш образ «" .. (set.name or "?") .. "»: " .. stars .. " из 5", {
		icon = self:GetSetIcon(set),
		title = Short(voter) .. " оценил ваш образ",
		text = "«" .. (set.name or "?") .. "»  " .. starsText,
		onClick = function() self.UI:Open(); self.UI:SetView("mine"); self.UI:Select(setId) end,
	})
end

-- Ваш образ добавили в избранное (настройка та же, что у оценок)
function TH:OnFavStored(setId, who, t)
	if not Ready() or self.db.myChars[who] then return end
	local s = self.db.notify
	if not s.votes then return end
	local set = self.db.net.sets[setId]
	if not (set and set.author and self.db.myChars[set.author]) then return end
	if self.Net.Now() - (t or 0) > NOTIFY_WINDOW then return end
	if (s.mutualOnly and not self:IsMutual(who)) or self:IsFollowMuted(who) then return end
	Push("a:" .. setId .. ":" .. who, self.Net.Now(), Short(who) .. " добавил ваш образ «" .. (set.name or "?") .. "» в избранное", {
		icon = self:GetSetIcon(set),
		title = Short(who) .. " добавил в избранное",
		text = "«" .. (set.name or "?") .. "»",
		onClick = function() self.UI:Open(); self.UI:SetView("mine"); self.UI:Select(setId) end,
	})
end

-- На вас подписались
function TH:OnFollowStored(target, who, on, t)
	if not Ready() or on ~= 1 or not self.db.myChars[target] or self.db.myChars[who] then return end
	if not self.db.notify.follows or self.Net.Now() - (t or 0) > FOLLOW_WINDOW then return end
	local mutual = self:IsFollowing(who)
	Push("f:" .. who, self.Net.Now(), Short(who) .. " подписался на вас" .. (mutual and " — теперь взаимно" or "") .. ".", {
		icon = "Interface\\Icons\\Achievement_Reputation_01",
		title = Short(who) .. " подписался на вас",
		text = mutual and "Теперь подписка взаимная" or "Кликните, чтобы открыть профиль",
		onClick = function() self.UI:Open(); self.UI:OpenProfile(who) end,
	})
end

-- Старые отметки «уже уведомили» забываем (месяц)
function TH:PruneNotified()
	local now = self.Net.Now()
	for key, t in pairs(self.db.notified) do
		if now - t > 30 * 86400 then self.db.notified[key] = nil end
	end
end
