ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local WhiteList = {}
local PlayersOnlineBeforeAntiSpam = 0
local PlayersToStartRocade = 1
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
	MySQL.Async.fetchAll(
		'SELECT * FROM whitelist',
		{},
		function (whitelisted_users)
			WhiteList = {}
			for i=1, #whitelisted_users, 1 do
				table.insert(WhiteList, {
					nom_rp 			= whitelisted_users[i].nom_rp,
					identifier 		= string.lower(whitelisted_users[i].identifier),
					last_connexion 	= whitelisted_users[i].last_connexion,
					ban_reason		= whitelisted_users[i].ban_reason,
					ban_until 		= whitelisted_users[i].ban_until,
					vip 			= whitelisted_users[i].vip == 1
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
				print("WHITELIST: " .. _("log_already_in_priority_queue", playerName, steamID))
				break
			end
		end

		if not isInPriorityList then
			table.insert(PriorityList, steamID)
			print("WHITELIST: " .. _("log_added_to_priority_queue", playerName, steamID))
		end

		local timeToWait = 2
		currentPriorityTime = currentPriorityTime + timeToWait

		for i=0,timeToWait, 1 do
			Wait(1000)
			currentPriorityTime = currentPriorityTime -1

			print(currentPriorityTime)

			print(#PriorityList)

			if(i >= timeToWait) then
				for i = 1, #PriorityList, 1 do
					if PriorityList[i] == steamID then
						table.remove(PriorityList, i)
						print("WHITELIST: " .. _("log_removed_from_priority_queue", playerName, steamID))
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
	local banned = false
	local isInPriorityList = false

	print("WHITELIST: " .. _("log_trying_to_connect", playerName, steamID))

	-- TEST IF STEAM IS STARTED
	if not steamID then
		reason(_("missing_steam_id"))
		deferrals.done(_("missing_steam_id"))
		CancelEvent()
		print("WHITELIST: " .. _("log_missing_steam_id", playerName))
	end

	-- TEST IF PLAYER IS WHITELISTED AND BANNED
	local timestamp = os.time()

	local Vip = false
	for i=1, #WhiteList, 1 do
		if WhiteList[i].identifier == steamID then
			found = true
			if WhiteList[i].ban_until ~= nil and WhiteList[i].ban_until > timestamp then
				reason(_("banned_from_server"))
				deferrals.done(_("banned_from_server"))
				CancelEvent()
				print("WHITELIST: " .. _("log_banned_from_server", playerName, steamID, WhiteList[i].ban_reason))
			end

			Vip = WhiteList[i].vip
			break
		end
	end

	-- player is not whitelisted, ask him to join your community
	if not found then
		reason(_("not_in_whitelist", Config.CommunityLink))
		deferrals.done(_("not_in_whitelist", Config.CommunityLink))
		CancelEvent()
		print("WHITELIST: " .. _("log_not_in_whitelist", playerName, steamID))
	end

	-- TEST IF PLAYER IS IN PRIORITY LIST
	-- if((onlinePlayers >= PlayersToStartRocade or #PriorityList > 0)  and Vip == false) then
	if false then
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

					if(onlinePlayers < PlayersToStartRocade and k == steamID and i == firstIndex) then
						table.remove(playersWaiting, i)
						inConnection[_source] = true

						allowConnecting = false
						stopSystem = true
						deferrals.done() -- connect
					else
						if(k == steamID) then
							local currentPlace = (i - firstIndex) + 1
							deferrals.update(_("waiting_queue_message", currentPlace, waitingPlayers))
							Citizen.Wait(250)
						end
					end
				else
					local isIn = false

					for _,k in pairs(PriorityList) do
						if(k==steamid) then
							isIn = true
							break;
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
						deferrals.update(_("waiting_free_priority_slots", #PriorityList, minutes, seconds))
						Citizen.Wait(250)
					end
				end
			end

		end
	else

		deferrals.defer()

		if(Vip) then
			print("WHITELIST: " .. _("log_player_connected_as_vip", playerName))
		end

		inConnection[_source] = true

		print("WHITELIST: " .. _("log_started_anti_spam", playerName))
		for i = 1, Config.WaitingTime, 1 do
			deferrals.update(_("anti_spam_message", Config.WaitingTime - i))
			Citizen.Wait(1000)
		end
		print("WHITELIST: " .. _("log_stopped_anti_spam", playerName))

		deferrals.done() -- connect

	end

end)



RegisterServerEvent("rocade:removePlayerToInConnect")
AddEventHandler("rocade:removePlayerToInConnect", function()
	table.remove(inConnection, source)
end)



function checkOnlinePlayers()
	SetTimeout(10000, function()
		local xPlayers = ESX.GetPlayers()

		onlinePlayers = #xPlayers + #inConnection


		if(onlinePlayers >= PlayersToStartRocade) then
			if(allowConnecting) then
				allowConnecting = false
			end
		else
			if(not allowConnecting) then
				allowConnecting = true
			end
		end

		checkOnlinePlayers()
	end)
end

checkOnlinePlayers()

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

TriggerEvent(
	'es:addGroupCommand',
	Config.ReloadWhitelistCommand,
	Config.ReloadWhitelistGroup,
	function (source, args, user)
		loadWhiteList()
		TriggerClientEvent('chatMessage', source, "SYSTEM", {255, 0, 0}, _("whitelist_reloaded"))
	end,
	function (source, args, user)
		TriggerClientEvent('chatMessage', source, 'SYSTEM', { 255, 0, 0 }, 'Insufficienct permissions!')
	end,
	{
		help = _("reload_whitelist")
	}
)