function ElmsMarkers.OnAddOnLoaded( eventCode, addonName )
	if (addonName ~= ElmsMarkers.name) then return end

	EVENT_MANAGER:UnregisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED)

	ElmsMarkers.savedVars = ZO_SavedVars:NewCharacterIdSettings("ElmsMarkersSavedVariables", ElmsMarkers.variableVersion, nil, ElmsMarkers.defaults, nil, GetWorldName())
  SLASH_COMMANDS["/elms"] = ElmsMarkers.HandleCommandInput

	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_PLAYER_ACTIVATED, ElmsMarkers.CheckActivation)
	EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ZONE_CHANGED, ElmsMarkers.CheckActivation)
  ElmsMarkers.buildMenu()
end

function ElmsMarkers.HandleCommandInput(args)
  args = args:gsub("%s+", "")
  if not args or args == "" then
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] help")
    CHAT_SYSTEM:AddMessage("/elms toggle (or t) - shows/hides markers")
    CHAT_SYSTEM:AddMessage("/elms place (or p)  - place marker at your position")
    CHAT_SYSTEM:AddMessage("/elms remove (or r) - remove nearest marker to your position")

  elseif args == "toggle" or args == "t" then
    ElmsMarkers.savedVars.enabled = not ElmsMarkers.savedVars.enabled
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] " .. (ElmsMarkers.savedVars.enabled and "Enabled" or "Disabled"))
    ElmsMarkers.CheckActivation()
  elseif args == "place" or args == "p" then
    local location = ElmsMarkers.PlaceAtMe()
    CHAT_SYSTEM:AddMessage("[ElmsMarkers] Placed new marker at " .. location[1] .. ", " .. location[2] .. ", " .. location[3])
  elseif args == "remove" or args == "r" then
    local location = ElmsMarkers.RemoveNearestMarker()
    if(location) then
      CHAT_SYSTEM:AddMessage("[ElmsMarkers] Removed marker at " .. location[1] .. ", " .. location[2] .. ", " .. location[3])
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
        table.insert(ElmsMarkers.placedIcons[zoneId], OSI.CreatePositionIcon( iconLocation[1], iconLocation[2], iconLocation[3], ElmsMarkers.iconTexture, OSI.GetIconSize()))
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
  if not OSI or not OSI.CreatePositionIcon then return end
  local zone, wX, wY, wZ = GetUnitRawWorldPosition( "player" )
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  if not zonePositions then
    ElmsMarkers.savedVars.positions[zone] = { [1] = {wX, wY, wZ} }
  else
    table.insert(ElmsMarkers.savedVars.positions[zone], {wX, wY, wZ})
  end
  if not ElmsMarkers.placedIcons[zone] then
    ElmsMarkers.placedIcons[zone] = {}
  end
  table.insert(ElmsMarkers.placedIcons[zone], OSI.CreatePositionIcon( wX, wY, wZ, ElmsMarkers.iconTexture, OSI.GetIconSize()))
  ElmsMarkers.CreateConfigString()

  return {wX, wY, wZ}
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
    return {closestMarker.x, closestMarker.y, closestMarker.z}
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

function ElmsMarkers.CreateConfigString()
  local zone = GetUnitRawWorldPosition( "player" )
  local configString = ""
  local zonePositions = ElmsMarkers.savedVars.positions[zone]
  if zonePositions then 
    for k, v in pairs(zonePositions) do
      configString = configString .. "/" .. zone .. "//" .. v[1] .. "," .. v[2] .. "," .. v[3] .. "/"
    end
  end
  ElmsMarkers.savedVars.configStringExport = configString
end

function ElmsMarkers.ParseImportConfigString()
  for zone, x, y, z in string.gmatch(ElmsMarkers.savedVars.configStringImport, "/(%d+)//(%d+),(%d+),(%d+)/") do
    zone = tonumber(zone)
    x = tonumber(x)
    y = tonumber(y)
    z = tonumber(z)
    if not ElmsMarkers.savedVars.positions[zone] then
      ElmsMarkers.savedVars.positions[zone] = {}
    end
    table.insert(ElmsMarkers.savedVars.positions[zone], {x, y, z})
  end
  ElmsMarkers.CheckActivation()
end

EVENT_MANAGER:RegisterForEvent(ElmsMarkers.name, EVENT_ADD_ON_LOADED, ElmsMarkers.OnAddOnLoaded)
