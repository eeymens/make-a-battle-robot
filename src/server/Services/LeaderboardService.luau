-- Global kupa tablosu (tüm sunucular). OrderedDataStore'a dakikada bir yazar ve ilk 10'u okur.
-- DataStore kapalıysa (Studio) sadece bu sunucudaki oyuncuları gösterir.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local STORE_NAME = "Trophies_v1"
local REFRESH_SECONDS = 60
local TOP_COUNT = 10

local LeaderboardService = {}

local DataService
local store: OrderedDataStore? = nil
local lastWritten: { [number]: number } = {}
local nameCache: { [number]: string } = {}

local function getName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local result = if ok and name then name else "?"
	nameCache[userId] = result
	return result
end

local function getListLabel(): TextLabel?
	local arenas = Workspace:FindFirstChild("Arenas")
	local board = arenas and arenas:FindFirstChild("Leaderboard")
	local gui = board and board:FindFirstChild("BoardGui")
	return gui and gui:FindFirstChild("List") :: TextLabel?
end

local function writeScores()
	if not store then
		return
	end
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data and lastWritten[player.UserId] ~= data.Trophies and data.Trophies > 0 then
			local ok = pcall(function()
				(store :: OrderedDataStore):SetAsync(tostring(player.UserId), data.Trophies)
			end)
			if ok then
				lastWritten[player.UserId] = data.Trophies
			end
		end
	end
end

local function readTop(): { { Name: string, Trophies: number } }
	local entries = {}
	if store then
		local ok, pages = pcall(function()
			return (store :: OrderedDataStore):GetSortedAsync(false, TOP_COUNT)
		end)
		if ok and pages then
			for _, entry in pages:GetCurrentPage() do
				table.insert(entries, { Name = getName(tonumber(entry.key) or 0), Trophies = entry.value })
			end
			return entries
		end
	end

	-- Yedek: sadece bu sunucu
	for _, player in Players:GetPlayers() do
		local data = DataService.Get(player)
		if data then
			table.insert(entries, { Name = player.Name, Trophies = data.Trophies })
		end
	end
	table.sort(entries, function(a, b)
		return a.Trophies > b.Trophies
	end)
	return entries
end

local function refresh()
	writeScores()
	local label = getListLabel()
	if not label then
		return
	end
	local lines = {}
	for rank, entry in readTop() do
		if rank > TOP_COUNT then
			break
		end
		table.insert(lines, `{rank}. {entry.Name} — {entry.Trophies}`)
	end
	label.Text = if #lines > 0 then table.concat(lines, "\n") else "Henüz kimse yok.\nİlk sen ol!"
end

function LeaderboardService.Init(dataService)
	DataService = dataService
	if not DataService.IsMemoryOnly() then
		local ok, result = pcall(function()
			return DataStoreService:GetOrderedDataStore(STORE_NAME)
		end)
		if ok then
			store = result
		end
	end

	task.spawn(function()
		task.wait(5)
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return LeaderboardService
