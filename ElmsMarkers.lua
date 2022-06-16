function ElmsMarkers.OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= ElmsMarkers.name) then return end

	EVENT_MANAGER:UnregisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED)

	ElmsMarkers.savedVars = ZO_SavedVars:NewCharacterIdSettings("ElmsMarkersSavedVariables", ElmsMarkers.variableVersion, nil, ElmsMarkers.defaults, nil, GetWorldName())
  SLASH_COMMANDS["/elms"] = ElmsMarkers.HandleCommandInput
  SLASH_COMMANDS["/placeatme"] = ElmsMarkers.PlaceAtMe
  SLASH_COMMANDS["/removeclose"] = ElmsMarkers.RemoveNearestMarker
  

	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_PLAYER_ACTIVATED, ElmsMarkers.CheckActivation)
	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ZONE_CHANGED, ElmsMarkers.CheckActivation)
  ElmsMarkers.buildMenu()
end

function ElmsMarkers.HandleCommandInput(args)
	ElmsMarkers.savedVars.enabled = not ElmsMarkers.savedVars.enabled
	CHAT_SYSTEM:AddMessage("[ElmsMarkers] " .. (ElmsMarkers.savedVars.enabled and "Enabled" or "Disabled"))
  ElmsMarkers.CheckActivation()
end

function ElmsMarkers.CheckActivation( eventCode )
	local zoneId = GetZoneId(GetUnitZoneIndex("player"))
  if (ElmsMarkers.savedVars.positions[zoneId] and ElmsMarkers.savedVars.enabled) then
    ElmsMarkers.PlacePositionIcons(ElmsMarkers.savedVars.positions[zoneId], zoneId)
  elseif not ElmsMarkers.savedVars.enabled then
    ElmsMarkers.RemovePositionIcons(zoneId)
  end

  for zone, markers in pairs(ElmsMarkers.savedVars.positions) do
    if zone ~= zoneId then
      ElmsMarkers.RemovePositionIcons(zone)
    end
  end
end

function ElmsMarkers.PlacePositionIcons(positions, zoneId)
  if not ElmsMarkers.placedIcons[zoneId] then
    ElmsMarkers.placedIcons[zoneId] = {}
  end
  if OSI and OSI.CreatePositionIcon then
    for i, iconLocation in pairs(positions) do
      if iconLocation then
        table.insert(ElmsMarkers.placedIcons[zoneId], OSI.CreatePositionIcon( iconLocation[1], iconLocation[2], iconLocation[3], ElmsMarkers.iconTexture, OSI.GetIconSize()))
      end
    end
  end
end

function ElmsMarkers.RemovePositionIcons(zoneId)
  if ElmsMarkers.placedIcons[zoneId] then 
    for k, v in pairs(ElmsMarkers.placedIcons[zoneId]) do
      if OSI.DiscardPositionIcon then
        OSI.DiscardPositionIcon(v)
      end
    end
  end
  ElmsMarkers.placedIcons[zoneId] = nil
end

function ElmsMarkers.PlaceAtMe()
  if not OSI.CreatePositionIcon then return end
  local zone, wX, wY, wZ = GetUnitRawWorldPosition( "player" )
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  local zonePositionIndex = ElmsMarkers.savedVars.positionIndeces[zone] or 0
  if not zonePositions then
    ElmsMarkers.savedVars.positions[zone] = { [1] = {wX, wY, wZ} }
  else
    ElmsMarkers.savedVars.positions[zone][zonePositionIndex+1] = {wX, wY, wZ}
  end
  ElmsMarkers.savedVars.positionIndeces[zone] = zonePositionIndex + 1
  if not ElmsMarkers.placedIcons[zone] then
    ElmsMarkers.placedIcons[zone] = {}
  end
  table.insert(ElmsMarkers.placedIcons[zone], OSI.CreatePositionIcon( wX, wY, wZ, ElmsMarkers.iconTexture, OSI.GetIconSize()))
end

function ElmsMarkers.RemoveNearestMarker() 
  if not OSI.DiscardPositionIcon then return end
  local zone, wX, wY, wZ = GetUnitRawWorldPosition( "player" )
  local zonePositions = ElmsMarkers.placedIcons[zone]

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
  end
end

function ElmsMarkers.ClearZone()
  if not OSI.DiscardPositionIcon then return end
  local zone = GetUnitRawWorldPosition( "player" )

  for k, v in pairs(ElmsMarkers.placedIcons[zone]) do
    OSI.DiscardPositionIcon(v)
  end

  ElmsMarkers.placedIcons[zone] = nil
  ElmsMarkers.savedVars.positions[zone] = nil

end



EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED, ElmsMarkers.OnAddOnLoaded)
