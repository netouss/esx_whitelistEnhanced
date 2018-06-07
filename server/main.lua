ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

-- Internal variables
local WhiteList = {}
local PriorityList = {}
local currentPriorityTime = 0
local playersWaiting = {}
local onlinePlayers = 0
local inConnection = {}
local allowConnecting = false

AddEventHandler('onMySQLReady', function ()
	loadWhiteList()
end)

function loadWhiteList()
	MySQL.Async.fetchAll('SELECT * FROM whitelist', {},
		function (result)
			WhiteList = {}
			for i=1, #result, 1 do
				table.insert(WhiteList, {
					nom_rp			= result[i].nom_rp,
					identifier		= result[i].identifier,
					last_connection	= result[i].last_connexion,
					ban_reason		= result[i].ban_reason,
					ban_until		= result[i].ban_until,
					vip				= result[i].vip == 1
				})
			end
		end
	)
end

AddEventHandler('playerDropped', function(reason)
	local _source = source

	if(reason ~= "Disconnected.") then

		local steamID = GetPlayerIdentifiers(_source)[1]
		local playerName = GetPlayerName(_source)
		local isInPriorityList = false

		for i = 1, #PriorityList, 1 do
			if PriorityList[i] == steamID then
				isInPriorityList = true
				ESX.Trace("WHITELIST: " .. _U("log_already_in_priority_queue", playerName, steamID))
				break
			end
		end

		if not isInPriorityList then
			table.insert(PriorityList, steamID)
			ESX.Trace("WHITELIST: " .. _U("log_added_to_priority_queue", playerName, steamID))
		end

		local timeToWait = 2
		currentPriorityTime = currentPriorityTime + timeToWait

		for i=0,timeToWait, 1 do
			Wait(1000)
			currentPriorityTime = currentPriorityTime -1

			ESX.Trace(currentPriorityTime)

			ESX.Trace(#PriorityList)

			if(i >= timeToWait) then
				for i = 1, #PriorityList, 1 do
					if PriorityList[i] == steamID then
						table.remove(PriorityList, i)
						ESX.Trace("WHITELIST: " .. _U("log_removed_from_priority_queue", playerName, steamID))
					end
				end
			end
		end

	end

	if(inConnection[_source] ~= nil) then
		table.remove(inConnection, _source)
	end

end)

AddEventHandler("playerConnecting", function(playerName, reason, deferrals)
	local _source = source
	local steamID = GetPlayerIdentifiers(_source)[1] or false
	local found = false

	ESX.Trace("WHITELIST: " .. _U("log_trying_to_connect", playerName, steamID))

	-- TEST IF STEAM IS STARTED
	if not steamID then
		reason(_U("missing_steam_id"))
		deferrals.done(_U("missing_steam_id"))
		CancelEvent()
		ESX.Trace("WHITELIST: " .. _U("log_missing_steam_id", playerName))
	end

	-- TEST IF PLAYER IS WHITELISTED AND BANNED
	local timestamp = os.time()

	local isVip = false
	for i=1, #WhiteList, 1 do
		if WhiteList[i].identifier == steamID then
			found = true
			if WhiteList[i].ban_until ~= nil and WhiteList[i].ban_until > timestamp then
				reason(_U("banned_from_server"))
				deferrals.done(_U("banned_from_server"))
				CancelEvent()
				ESX.Trace("WHITELIST: " .. _U("log_banned_from_server", playerName, steamID, WhiteList[i].ban_reason))
			end

			isVip = WhiteList[i].vip
			break
		end
	end

	-- player is not whitelisted
	if not found then
		reason(_U("not_in_whitelist", Config.CommunityLink))
		deferrals.done(_U("not_in_whitelist", Config.CommunityLink))
		CancelEvent()
		ESX.Trace("WHITELIST: " .. _U("log_not_in_whitelist", playerName, steamID))
	end

	-- TEST IF PLAYER IS IN PRIORITY LIST
	if (onlinePlayers >= Config.PlayersToStartRocade or #PriorityList > 0)  and not isVip then
		deferrals.defer()
		local stopSystem = false
		table.insert(playersWaiting, steamID)


		while stopSystem == false do

			local waitingPlayers = #playersWaiting
			local firstIndex = -100
			for i,k in pairs(playersWaiting) do
				if(firstIndex == -100) then
					firstIndex = i
				end

				if(#PriorityList == 0) then

					if(onlinePlayers < Config.PlayersToStartRocade and k == steamID and i == firstIndex) then
						table.remove(playersWaiting, i)
						inConnection[_source] = true

						allowConnecting = false
						stopSystem = true
						deferrals.done() -- connect
					else
						if(k == steamID) then
							local currentPlace = (i - firstIndex) + 1
							deferrals.update(_U("waiting_queue_message", currentPlace, waitingPlayers))
							Citizen.Wait(250)
						end
					end
				else
					local isIn = false

					for _,k in pairs(PriorityList) do
						if k == steamid then
							isIn = true
							break
						end
					end
					if(isIn) then
						table.remove(playersWaiting, i)
						inConnection[_source] = true

						allowConnecting = false
						stopSystem = true
						deferrals.done() -- connect
					else
						local raw_minutes = currentPriorityTime/60
						local minutes = stringsplit(raw_minutes, ".")[1]
						local seconds = stringsplit(currentPriorityTime-(minutes*60), ".")[1]
						deferrals.update(_U("waiting_free_priority_slots", #PriorityList, minutes, seconds))
						Citizen.Wait(250)
					end
				end
			end
		end
	else
		if(Vip) then
			ESX.Trace("WHITELIST: " .. _U("log_player_connected_as_vip", playerName))
		end

		inConnection[_source] = true

		if Config.EnableAntiSpam then
			deferrals.defer()

			ESX.Trace("WHITELIST: " .. _U("log_started_anti_spam", playerName))
			for i = 1, Config.WaitingTime, 1 do
				deferrals.update(_U("anti_spam_message", Config.WaitingTime - i))
				Citizen.Wait(1000)
			end
			ESX.Trace("WHITELIST: " .. _U("log_stopped_anti_spam", playerName))

			deferrals.done() -- connect
		end
	end
end)

RegisterServerEvent("esx_whitelistExtended:removePlayerToInConnect")
AddEventHandler("esx_whitelistExtended:removePlayerToInConnect", function()
	local _source = source
	if _source ~= nil then
		table.remove(inConnection, _source)
	end
end)

function checkOnlinePlayers()
	SetTimeout(10000, function()
		local xPlayers = ESX.GetPlayers()

		onlinePlayers = #xPlayers + #inConnection


		if(onlinePlayers >= Config.PlayersToStartRocade) then
			if allowConnecting then
				allowConnecting = false
			end
		else
			if not allowConnecting then
				allowConnecting = true
			end
		end

		checkOnlinePlayers()
	end)
end

checkOnlinePlayers()

TriggerEvent('es:addGroupCommand', 'reloadwl', 'admin', function (source, args, user)
	loadWhiteList()
	TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, _U("whitelist_reloaded"))
end, function (source, args, user)
	TriggerClientEvent('chatMessage', source, 'SYSTEM', { 255, 0, 0 }, 'Insufficienct permissions!')
end, {help = _U("reload_whitelist")})

function stringsplit(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	local i = 1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end
