ElmsMarkers = ElmsMarkers or { }
ElmsMarkers.UI = { }
local ui = ElmsMarkers.UI

function ElmsMarkers.setupUI()
  local markerEntries = { }
  ui.frame = ElmsMarkers_Frame
  ui.subtitle = ElmsMarkers_Frame_Title_Subtitle
  ui.close = ElmsMarkers_Frame_Title_Close
  ui.placeButton = ElmsMarkers_Frame_Button_Group_Place_Button
  ui.publishButton = ElmsMarkers_Frame_Button_Group_Publish_Button
  ui.removeButton = ElmsMarkers_Frame_Button_Group_Remove_Button
  ui.markerIcon = ElmsMarkers_Frame_Marker_Dropdown_Panel_Marker_Icon

  ui.close:SetHandler("OnMouseUp", function() ui.frame:SetHidden(true) end, "ElmsMarkers")

  ui.markerDropdown = ZO_ComboBox_ObjectFromContainer(ElmsMarkers_Frame_Marker_Dropdown_Panel_Marker_Dropdown)
  ui.markerIcon:SetTexture(ElmsMarkers.iconData[ElmsMarkers.savedVars.selectedIconTexture])

  for k, v in pairs(ElmsMarkers.reverseOptionMap) do
    local entry = ui.markerDropdown:CreateItemEntry(v, function() 
      ElmsMarkers.savedVars.selectedIconTexture = k
      ui.markerIcon:SetTexture(ElmsMarkers.iconData[k])
    end)
		table.insert(markerEntries, entry)
  end

  for k,v in pairs(markerEntries) do
    ui.markerDropdown:AddItem(v)
  end

  ui.markerDropdown:SetSelectedItemText(ElmsMarkers.reverseOptionMap[ElmsMarkers.savedVars.selectedIconTexture])

  ui.placeButton:SetHandler("OnMouseUp", ElmsMarkers.PlaceAtMe, "ElmsMarkers")  
  ui.removeButton:SetHandler("OnMouseUp", ElmsMarkers.RemoveNearMe, "ElmsMarkers")
end