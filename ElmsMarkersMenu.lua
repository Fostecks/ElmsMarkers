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
		{
			type = "button",
			name = "Clear Zone",
			tooltip = "This will clear all markers from this zone",
			isDangerous = true,
			func = function(value)
				ElmsMarkers.ClearZone()
			end,
		},
		{
			type = "dropdown",
			name = "Icon",
			tooltip = "Icon to use for the next marker placements",
			choices = ElmsMarkers.options,
			scrollable = true,
			getFunc = function() 
				return ElmsMarkers.reverseOptionMap[ElmsMarkers.savedVars.selectedIconTexture]
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.selectedIconTexture = ElmsMarkers.optionMap[value]
			end,
		},
		{
			type = "slider",
			name = "Icon size",
			min = 12,
			max = 192,
			default = ElmsMarkers.defaults.selectedIconSize,
			getFunc = function() 
				return ElmsMarkers.savedVars.selectedIconSize
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.selectedIconSize = value
				ElmsMarkers.CheckActivation()
			end,
		},
		{
			type = "checkbox",
			name = "Subscribe to Group Lead",
			tooltip = "Automatically updates your zone's markers with the group lead's added/removed markers",
			default = ElmsMarkers.defaults.subscribeToLead,
			getFunc = function() 
				return ElmsMarkers.savedVars.subscribeToLead
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.subscribeToLead = value
				ElmsMarkers.CheckActivation()
			end,
		},
		{
			type = "header",
			name = " Import",
		},
		{
			type = "editbox",
			name = "Config",
			tooltip = "Insert a valid ElmsMarkers string to import new icons into your zone",
			default = ElmsMarkers.defaults.configStringImport,
			isMultiline = true,
			isExtraWide = true,
			getFunc = function() 
				return ElmsMarkers.savedVars.configStringImport
			end,
			setFunc = function(value)
				ElmsMarkers.savedVars.configStringImport = value
			end,
		},
		{
			type = "button",
			name = "Import",
			tooltip = "Import a config string for this zone",
			func = function(value)
				ElmsMarkers.ParseImportConfigString()
			end,
		},
		{
			type = "header",
			name = " Export String",
		},
		{
			type = "editbox",
			name = "Config",
			tooltip = "String that describes the icons you have configured to this zone",
			default = ElmsMarkers.defaults.configStringExport,
			isMultiline = true,
			isExtraWide = true,
			getFunc = function() 
				return ElmsMarkers.savedVars.configStringExport
			end,
			setFunc = function(value)
			end,
		},
	}

	LibAddonMenu2:RegisterAddonPanel(ElmsMarkers.name.."Options", panelData)
	LibAddonMenu2:RegisterOptionControls(ElmsMarkers.name.."Options", options)
end

