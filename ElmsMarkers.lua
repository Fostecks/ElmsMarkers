function ElmsMarkers.OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= ElmsMarkers.name) then return end

	EVENT_MANAGER:UnregisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED)

	ElmsMarkers.savedVars = ZO_SavedVars:NewCharacterIdSettings("ElmsMarkersSavedVariables", ElmsMarkers.variableVersion, nil, ElmsMarkers.defaults, nil, GetWorldName())
  SLASH_COMMANDS["/elms"] = ElmsMarkers.HandleCommandInput

	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_PLAYER_ACTIVATED, ElmsMarkers.CheckActivation)
	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ZONE_CHANGED, ElmsMarkers.CheckActivation)
	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_LEADER_UPDATE, ElmsMarkers.CheckGroupLead)
  ElmsMarkers.buildMenu()
  ElmsMarkers.setupUI()
  ElmsMarkers.setFramePosition()

  ElmsMarkers.shareMapData = LibDataShare:RegisterMap("ElmsMarkers", 2, ElmsMarkers.HandleDataShareReceived)
end

function ElmsMarkers.CheckGroupLead(eventCode, leaderTag)
  if AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
    ElmsMarkers.UI.placePublishButton:SetHidden(false)
    ElmsMarkers.UI.removePublishButton:SetHidden(false)
  else
    ElmsMarkers.UI.placePublishButton:SetHidden(true)
    ElmsMarkers.UI.removePublishButton:SetHidden(true)
  end
end

 function ElmsMarkers.HandleDataShareReceived(tag, data)
	if tag and data then
    if(tag == GetGroupLeaderUnitTag() and ElmsMarkers.savedVars.subscribeToLead) then
      local tuple = ElmsMarkers.dataShareTuple
      local dataIdentifier = data % 10
      if dataIdentifier == 1 then
        local wX = math.floor(data / 100000)
        local iconId = math.floor(data % 100000 / 10)
        tuple.wX = wX
        tuple.iconId = iconId
      elseif dataIdentifier == 2 then
        local wZ = math.floor(data / 100000)
        local zone = math.floor(data % 100000 / 10)
        tuple.wZ = wZ
        tuple.zone = zone
      elseif dataIdentifier == 3 then
        local wY = math.floor(data / 1000)
        local isAdd = math.floor(data % 1000 / 100)
        tuple.wY = wY
        tuple.isAdd = isAdd
      end

      if tuple.zone and tuple.wX and tuple.wY and tuple.wZ and tuple.iconId and tuple.isAdd then
        if(tuple.isAdd == 2) then
          ElmsMarkers.PlaceAtLocation({tuple.zone, tuple.wX, tuple.wY, tuple.wZ, tuple.iconId})
        else
          ElmsMarkers.RemoveMarkerAt({tuple.zone, tuple.wX, tuple.wY, tuple.wZ})
        end
        ElmsMarkers.dataShareTuple = { }
      end
    end
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
    local location = ElmsMarkers.PreparePublish(true)
    if(location) then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Published new marker at " .. location[2] .. ", " .. location[3] .. ", " .. location[4])      
    end
  elseif args == "removepublish" or args == "rr" then
    local location = ElmsMarkers.PreparePublish(false)
    if(location) then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Published removed marker at " .. location[2] .. ", " .. location[3] .. ", " .. location[4])      
    end
  elseif args == "place" or args == "p" then
    local location = ElmsMarkers.PlaceAtMe()
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Placed new marker at " .. location[2] .. ", " .. location[3] .. ", " .. location[4])
  elseif args == "remove" or args == "r" then
    local location = ElmsMarkers.RemoveNearMe()
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
  return ElmsMarkers.PlaceAtLocation({zone, wX, wY, wZ, ElmsMarkers.savedVars.selectedIconTexture})
end

function ElmsMarkers.PlaceAtLocation(location)
  if not OSI or not OSI.CreatePositionIcon then return end
  local zone, wX, wY, wZ, iconId = unpack(location)
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  if not zonePositions then
    ElmsMarkers.savedVars.positions[zone] = { [1] = {wX, wY, wZ, iconId} }
  else
    table.insert(ElmsMarkers.savedVars.positions[zone], {wX, wY, wZ, iconId})
  end
  if not ElmsMarkers.placedIcons[zone] then
    ElmsMarkers.placedIcons[zone] = {}
  end
  ElmsMarkers.DoPlaceIcon(zone, wX, wY, wZ, ElmsMarkers.iconData[iconId])
  ElmsMarkers.CreateConfigString()

  return {zone, wX, wY, wZ, iconId}
end

function ElmsMarkers.PreparePublish(isAdd) 
  local timeNow = GetGameTimeMilliseconds()
  if(ElmsMarkers.lastPingTime == nil or (timeNow - ElmsMarkers.lastPingTime > ElmsMarkers.PING_RATE)) then
    if AreUnitsEqual(GetGroupLeaderUnitTag(), 'player') then
      local location
      if isAdd then
        location = ElmsMarkers.PlaceAtMe()
      else
        location = ElmsMarkers.RemoveNearMe()
      end

      ElmsMarkers.EncodeEnqueuePublish(location, isAdd)
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

  local addBit = isAdd and 2 or 1
  local endSignature = 3

  local dataPacket1 = wX * 100000 + iconId * 10 + 1
  local dataPacket2 = wZ * 100000 + zone * 10 + 2
  local dataPacket3 = wY * 1000 + addBit * 100 + endSignature

  local wX = math.floor(dataPacket1 / 100000)
  local iconId = math.floor(dataPacket1 % 100000 / 10)

  local wZ = math.floor(dataPacket2 / 100000)
  local zone = math.floor(dataPacket2 % 100000 / 10)

  local wY = math.floor(dataPacket3 / 1000)
  local isAdd = math.floor(dataPacket3 % 1000 / 100)
  
  ElmsMarkers.dataQueue = {dataPacket1, dataPacket2, dataPacket3}
  EVENT_MANAGER:RegisterForUpdate(ElmsMarkers.name .. 'Cycle', 100, ElmsMarkers.ShareData)
  ElmsMarkers.lastPingTime = GetGameTimeMilliseconds()
end

function ElmsMarkers.ShareData() 
  dataPacket = table.remove(ElmsMarkers.dataQueue, 1)
  if(dataPacket) then
    ElmsMarkers.shareMapData:SendData(dataPacket)
  else
    EVENT_MANAGER:UnregisterForUpdate(ElmsMarkers.name..'Cycle')
  end
end

function ElmsMarkers.RemoveNearMe()
  local zone, wX, wY, wZ = GetUnitRawWorldPosition("player")
  return ElmsMarkers.RemoveNearestMarker({zone, wX, wY, wZ})
end

function ElmsMarkers.RemoveNearestMarker(location) 
  if not OSI or not OSI.DiscardPositionIcon then return end
  local zone, wX, wY, wZ = unpack(location)
  local zoneIcons = ElmsMarkers.placedIcons[zone]
  if(not zoneIcons) then return end
  local closestMarker
  local closestMarkerIndex
  local shortestDistance = 9999
  local currentDistance
  for i, pos in pairs(zoneIcons) do
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
    ElmsMarkers.CreateConfigString()
    return {zone, closestMarker.x, closestMarker.y, closestMarker.z, ElmsMarkers.savedVars.selectedIconTexture}
  end
  ElmsMarkers.CreateConfigString()

end

function ElmsMarkers.RemoveMarkerAt(location)
  local zone, wX, wY, wZ = unpack(location)
  local zoneIcons = ElmsMarkers.placedIcons[zone]
  if(not zoneIcons) then return end

  for k,v in pairs(ElmsMarkers.savedVars.positions[zone]) do
    if v[1] == wX and v[2] == wY and v[3] == wZ then
      ElmsMarkers.savedVars.positions[zone][k] = nil
      ElmsMarkers.CreateConfigString()
    end
  end

  for k, v in pairs(ElmsMarkers.placedIcons[zone]) do
    if v.x == wX and v.y == wY and v.z == wZ then
      OSI.DiscardPositionIcon(v)
      ElmsMarkers.placedIcons[zone][k] = nil
    end
  end
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
