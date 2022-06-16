ElmsMarkers = ElmsMarkers or { }

function ElmsMarkers.buildMenu()
	local panelData = {
		type = "panel",
		name = "Elms Markers",
		displayName = "Elms Markers",
		author = "bitrock",
		version = ""..ElmsMarkers.version,
		registerForDefaults = true,
		registerForRefresh = true
	}

	local options = {
		{
			type = "header",
			name = "Settings",
		},
		{
			type = "checkbox",
			name = "Enabled",
			tooltip = "Toggles the UI",
			default = ElmsMarkers.defaults.enabled,
			getFunc = function() 
				return ElmsMarkers.savedVars.enabled
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.enabled = value
				ElmsMarkers.CheckActivation()
			end,
		},
	}

	LibAddonMenu2:RegisterAddonPanel(ElmsMarkers.name.."Options", panelData)
	LibAddonMenu2:RegisterOptionControls(ElmsMarkers.name.."Options", options)
end

