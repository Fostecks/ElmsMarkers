function ElmsMarkers.OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= ElmsMarkers.name) then return end

	EVENT_MANAGER:UnregisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED)

	ElmsMarkers.savedVars = ZO_SavedVars:NewCharacterIdSettings("ElmsMarkersSavedVariables", ElmsMarkers.variableVersion, nil, ElmsMarkers.defaults, nil, GetWorldName())
  SLASH_COMMANDS["/elms"] = ElmsMarkers.HandleCommandInput

	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_PLAYER_ACTIVATED, ElmsMarkers.CheckActivation)
	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ZONE_CHANGED, ElmsMarkers.CheckActivation)
	EVENT_MANAGER:RegisterForUpdate(ElmsMarkers.name .. 'cycle', 100, ElmsMarkers.Cycle)
  ElmsMarkers.buildMenu()
  ElmsMarkers.setupUI()

  ElmsMarkers.shareMapData = LibDataShare:RegisterMap("ElmsMarkers", 2, ElmsMarkers.HandleData)
end

 function ElmsMarkers.HandleData(tag, data)
	if tag and data then
    if(tag == GetGroupLeaderUnitTag() and ElmsMarkers.savedVars.subscribeToLead) then
      local dataIdentifier = data % 10
      if dataIdentifier == 1 then
        local wX = data / 100000
        local iconId = data % 100000 / 10

      elseif dataIdentifier == 2 then
        local wZ = data / 100000
        local zone = data % 100000 / 10

      elseif dataIdentifier == 9 then
        local wY = data / 1000
        local isAdd = data % 1000 / 100
      end
    end
  end
end

function ElmsMarkers.Cycle()
  if LibDataShare:IsSendWindow() then
  end
end

function ElmsMarkers.HandleCommandInput(args)
  args = args:gsub("%s+", "")
  if not args or args == "" then
    ElmsMarkers.UI.frame:SetHidden(false)

  elseif args == "toggle" or args == "t" then
    ElmsMarkers.savedVars.enabled = not ElmsMarkers.savedVars.enabled
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] " .. (ElmsMarkers.savedVars.enabled and "Enabled" or "Disabled"))
    ElmsMarkers.CheckActivation()
  elseif args == "publish" or args == "pp" then
    local location = ElmsMarkers.PlaceAndPublish()
    if(location) then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Published new marker at " .. location[2] .. ", " .. location[3] .. ", " .. location[4])      
    end
  elseif args == "place" or args == "p" then
    local location = ElmsMarkers.PlaceAtMe()
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Placed new marker at " .. location[2] .. ", " .. location[3] .. ", " .. location[4])
  elseif args == "remove" or args == "r" then
    local location = ElmsMarkers.RemoveNearestMarker()
    if(location) then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Removed marker at " .. location[2] .. ", " .. location[3] .. ", " .. location[4])
    end
  end
end

function ElmsMarkers.CheckActivation( eventCode )
	local zoneId = GetZoneId(GetUnitZoneIndex("player"))
  for zone, markers in pairs(ElmsMarkers.savedVars.positions) do
    ElmsMarkers.RemovePositionIcons(zone)
  end
  if (ElmsMarkers.savedVars.positions[zoneId] and ElmsMarkers.savedVars.enabled) then
    ElmsMarkers.PlacePositionIcons(ElmsMarkers.savedVars.positions[zoneId], zoneId)
  end
  ElmsMarkers.CreateConfigString()
end

function ElmsMarkers.PlacePositionIcons(positions, zoneId)
  if not ElmsMarkers.placedIcons[zoneId] then
    ElmsMarkers.placedIcons[zoneId] = {}
  end
  if OSI and OSI.CreatePositionIcon then
    for i, iconLocation in pairs(positions) do
      if iconLocation then
        ElmsMarkers.DoPlaceIcon(zoneId, iconLocation[1], iconLocation[2], iconLocation[3], ElmsMarkers.iconData[iconLocation[4]])
      end
    end
  end
end

function ElmsMarkers.RemovePositionIcons(zoneId)
  if ElmsMarkers.placedIcons[zoneId] then 
    for k, v in pairs(ElmsMarkers.placedIcons[zoneId]) do
      if OSI and OSI.DiscardPositionIcon then
        OSI.DiscardPositionIcon(v)
      end
    end
  end
  ElmsMarkers.placedIcons[zoneId] = nil
end

function ElmsMarkers.PlaceAtMe() 
  local zone, wX, wY, wZ = GetUnitRawWorldPosition( "player" )
  return ElmsMarkers.PlaceAtLocation({zone, wX, wY, wZ})
end

function ElmsMarkers.PlaceAtLocation(location)
  if not OSI or not OSI.CreatePositionIcon then return end
  local zone, wX, wY, wZ = unpack(location)
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  if not zonePositions then
    ElmsMarkers.savedVars.positions[zone] = { [1] = {wX, wY, wZ, ElmsMarkers.savedVars.selectedIconTexture} }
  else
    table.insert(ElmsMarkers.savedVars.positions[zone], {wX, wY, wZ, ElmsMarkers.savedVars.selectedIconTexture})
  end
  if not ElmsMarkers.placedIcons[zone] then
    ElmsMarkers.placedIcons[zone] = {}
  end
  ElmsMarkers.DoPlaceIcon(zone, wX, wY, wZ, ElmsMarkers.iconData[ElmsMarkers.savedVars.selectedIconTexture])
  ElmsMarkers.CreateConfigString()

  return {zone, wX, wY, wZ, ElmsMarkers.savedVars.selectedIconTexture}
end

function ElmsMarkers.PlaceAndPublish() 
  local timeNow = GetGameTimeMilliseconds()
  if(ElmsMarkers.lastPingTime == nil or (timeNow - ElmsMarkers.lastPingTime > ElmsMarkers.PING_RATE)) then
    if AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
      local location = ElmsMarkers.PlaceAtMe()
      ElmsMarkers.EncodeEnqueuePublish(location, true)
      return location
    else
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] You must be the group lead to publish markers!")
    end
  else 
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] You're publishing too quickly! Publish not sent, try again later.")
  end
end

function ElmsMarkers.EncodeEnqueuePublish(location, isAdd)
  local zone, wX, wY, wZ, iconId = unpack(location)
  -- ping 1: wX iconId
  -- ping 2: wZ zone
  -- ping 3: wY isAdd/isRemove endSignature

  local addBit = isAdd and 1 or 0
  local endSignature = 99

  local dataPacket1 = wX * 100000 + iconId * 10 + 1
  local dataPacket2 = wZ * 100000 + zone * 10 + 2
  local dataPacket3 = wY * 1000 + addBit * 100 + endSignature

  local wX = math.floor(dataPacket1 / 100000)
  local iconId = math.floor(dataPacket1 % 100000 / 10)

  local wZ = math.floor(dataPacket2 / 100000)
  local zone = math.floor(dataPacket2 % 100000 / 10)

  local wY = math.floor(dataPacket3 / 1000)
  local isAdd = math.floor(dataPacket3 % 1000 / 100)
  
  d(wX, wY, wZ, zone, iconId, isAdd)
  
  zo_callLater(ElmsMarkers.shareMapData:SendData(dataPacket1), 100)
  zo_callLater(ElmsMarkers.shareMapData:SendData(dataPacket2), 200)
  zo_callLater(ElmsMarkers.shareMapData:SendData(dataPacket3), 300)

  ElmsMarkers.lastPingTime = GetGameTimeMilliseconds()
end

function ElmsMarkers.RemoveNearestMarker() 
  if not OSI or not OSI.DiscardPositionIcon then return end
  local zone, wX, wY, wZ = GetUnitRawWorldPosition( "player" )
  local zonePositions = ElmsMarkers.placedIcons[zone]
  if(not zonePositions) then return end
  local closestMarker
  local closestMarkerIndex
  local shortestDistance = 9999
  local currentDistance
  for i, pos in pairs(zonePositions) do
    currentDistance = (zo_sqrt((pos.x - wX)^2 + (pos.z - wZ)^2) / 100)
    if currentDistance < shortestDistance then
      shortestDistance = currentDistance
      closestMarker = pos
      closestMarkerIndex = i
    end
  end

  if closestMarker then
    OSI.DiscardPositionIcon(closestMarker)
    ElmsMarkers.placedIcons[zone][closestMarkerIndex] = nil

    for k,v in pairs(ElmsMarkers.savedVars.positions[zone]) do
      if v[1] == closestMarker.x and v[2] == closestMarker.y and v[3] == closestMarker.z then
        closestMarkerIndex = k
      end
    end
    ElmsMarkers.savedVars.positions[zone][closestMarkerIndex] = nil
    return {zone, closestMarker.x, closestMarker.y, closestMarker.z, ElmsMarkers.savedVars.selectedIconTexture}
  end
  ElmsMarkers.CreateConfigString()

end

function ElmsMarkers.ClearZone()
  if not OSI or not OSI.DiscardPositionIcon then return end
  local zone = GetUnitRawWorldPosition( "player" )

  for k, v in pairs(ElmsMarkers.placedIcons[zone]) do
    OSI.DiscardPositionIcon(v)
  end

  ElmsMarkers.placedIcons[zone] = nil
  ElmsMarkers.savedVars.positions[zone] = nil
  ElmsMarkers.CreateConfigString()
end

function ElmsMarkers.DoPlaceIcon(zone, x, y, z, texture)
  local iconSize = ElmsMarkers.savedVars.selectedIconSize / 64.0
  table.insert(ElmsMarkers.placedIcons[zone], OSI.CreatePositionIcon( x, y, z, texture, iconSize * OSI.GetIconSize()))
end

function ElmsMarkers.CreateConfigString()
  local zone = GetUnitRawWorldPosition( "player" )
  local configString = ""
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  if zonePositions then 
    for k, v in pairs(zonePositions) do
      configString = configString .. "/" .. zone .. "//" .. v[1] .. "," .. v[2] .. "," .. v[3] .. "," .. v[4] .. "/"
    end
  end
  ElmsMarkers.savedVars.configStringExport = configString
end

function ElmsMarkers.ParseImportConfigString()
  for zone, x, y, z, iconKey in string.gmatch(ElmsMarkers.savedVars.configStringImport, "/(%d+)//(%d+),(%d+),(%d+),(%d+)/") do
    zone = tonumber(zone)
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    iconKey = tonumber(iconKey)
    if not ElmsMarkers.savedVars.positions[zone] then
      ElmsMarkers.savedVars.positions[zone] = {}
    end
    table.insert(ElmsMarkers.savedVars.positions[zone], {x, y, z, iconKey})
  end
  ElmsMarkers.savedVars.configStringImport = ""
  ElmsMarkers.CheckActivation()
end

EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED, ElmsMarkers.OnAddOnLoaded)
