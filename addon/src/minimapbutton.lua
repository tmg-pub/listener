-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is the module that controls the minimap button.
-------------------------------------------------------------------------------

local Main         = ListenerAddon
local L            = Main.Locale
Main.MinimapButton = {}
local Me           = Main.MinimapButton
local LDB          = LibStub:GetLibrary( "LibDataBroker-1.1" )
local DBIcon       = LibStub:GetLibrary( "LibDBIcon-1.0"     )

-------------------------------------------------------------------------------
-- Setup function.
--
-- (?) This might need to be done during OnInitialize, in the case that some 
-- addons are looking for this data before OnEnabled.
--
function Me.Setup()

	-- Create a new data source for Listener
	Me.data = LDB:NewDataObject( "Listener", {
		type = "data source";
		text = "Listener";
		icon = "Interface\\Icons\\SPELL_HOLY_SILENCE";
		OnClick = Me.OnClick;
		OnEnter = Me.OnEnter;
		OnLeave = Me.OnLeave;
	})
	
end

-------------------------------------------------------------------------------
-- Initialize DBIcon.
--
function Me.OnLoad()
	DBIcon:Register( "Listener", Me.data, Main.db.profile.minimapicon )
end

-------------------------------------------------------------------------------
-- Show or hide the minimap button.
--
-- This also saves the value in the database so it persists through reloads.
--
function Me.Show( show )
	if show then
		DBIcon:Show( "Listener" )
		Main.db.profile.minimapicon.hide = false
	else
		DBIcon:Hide( "Listener" )
		Main.db.profile.minimapicon.hide = true
	end
end

-------------------------------------------------------------------------------
-- Callback for when the minimap button is clicked.
--
function Me.OnClick( frame, button )
	
	GameTooltip:Hide()
	if button == "LeftButton" then
		
		if IsShiftKeyDown() then
			Main.frames[1]:Toggle()
		else
			Me.ShowMenu( frame, "MENU2" )
		end
		
	elseif button == "RightButton" then
		
		Main.OpenConfig()
		
	end
end

local function InitializeMenu2( self, level, menuList )
	if level == 1 then
		local info
		info = UIDropDownMenu_CreateInfo()
		info.text    = "Windows"
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
		local frames = {}
		
		-- we add everything but first frame
		for _, f in pairs( Main.frames ) do
			if f.frame_index > 2 then
				table.insert( frames, f )
			end
		end
		-- we sort the frames by their name
		table.sort( frames, function( a, b )
			local an, bn = Main.db.char.frames[a.frame_index].name or "", Main.db.char.frames[b.frame_index].name or ""
			return an < bn
		end)
		
		-- and the first/primary frame always appears at the top.
		table.insert( frames, 1, Main.frames[2] )
		table.insert( frames, 1, Main.frames[1] )
		
		for _, f in ipairs( frames ) do
			local name = f.charopts.name
			if f.frame_index == 1 then name = L["Main"] end
			if f.frame_index == 2 then name = L["Snooper"] end
			
			info = UIDropDownMenu_CreateInfo()
			info.text = name
			info.func = function()
				f.combat_ignore = true
				f:Toggle()
			end
			info.notCheckable = false
			info.isNotRadio   = true
			info.hasArrow     = true
			if f.frame_index ~= 2 then
				info.menuList   = "FRAMEOPTS_" .. f.frame_index
			else
				info.menuList   = "SNOOPER"
			end
			info.tooltipTitle     = name
			info.tooltipText      = L["Click to toggle frame."]
			info.tooltipOnButton  = true
			info.checked      = not f.charopts.hidden
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
		end
		
		info = UIDropDownMenu_CreateInfo()
		if C_Club then -- 7.x compat
			UIDropDownMenu_AddSeparator( level )
		else
			UIDropDownMenu_AddSeparator( info, level )
		end
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["DM Tags"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.hasArrow         = true
		info.menuList         = "DMTAGS"
		info.checked          = Main.db.char.dmtags
		info.func             = function( self, a1, a2, checked )
			Main.DMTags.Enable( checked )
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable DM tags."]
		info.tooltipText      = L["This is a helper feature for dungeon masters. It tags your unit frames with whoever has unmarked messages."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		if C_Club then -- 7.x compat
			UIDropDownMenu_AddSeparator( level )
		else
			UIDropDownMenu_AddSeparator( info, level )
		end
		
		info = UIDropDownMenu_CreateInfo()
		info.text = L["Settings"]
		info.func = function()
			Main.OpenConfig()
		end
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
	elseif menuList == "DMTAGS" then
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Mark All"]
		info.notCheckable     = true
		info.hasArrow         = false
		info.func             = function( self, a1, a2, checked )
			Main.DMTags.MarkAll()
		end
		info.tooltipTitle     = L["Mark all players."]
		info.tooltipText      = L["Clears any waiting DM tags."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	elseif menuList and menuList:find("FILTERS") then
		Main.PopulateFilterMenu( level, menuList )
	elseif menuList and menuList:find( "FRAMEOPTS" ) then
		Main.Frame.PopulateFrameMenu( level, menuList )
	elseif menuList and menuList:find("SNOOPER") then
		Main.Snoop2.PopulateMenu( level, menuList )
	end
end

-------------------------------------------------------------------------------
-- Initializer for the frames menu. This is the menu that shows up when you
-- left-click.
--
local function InitializeFramesMenu( self, level, menuList )
	
	if level == 1 then
		local info
		

		
		
	end
end

-------------------------------------------------------------------------------
-- Initializer for the options menu. This is the right-click menu.
--
local function InitializeOptionsMenu( self, level, menuList )
	if level == 1 then
		local info
		info = UIDropDownMenu_CreateInfo()
		info.text         = "Listener"
		info.isTitle      = true
		info.notCheckable = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Snooper"]
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "SNOOPER"
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
	elseif menuList and menuList:find("FILTERS") then
		Main.PopulateFilterMenu( level, menuList )
	elseif menuList and menuList:find( "SNOOPER" ) then
		Main.Snoop2.PopulateMenu( level, menuList )
	end
end

-------------------------------------------------------------------------------
-- Open up one of the minimap menus.
--
-- @param menu "FRAMES" or "OPTIONS"
--
function Me.ShowMenu( parent, menu )

	local menus = {
		MENU2   = InitializeMenu2;
	}
	
	Main.ToggleMenu( parent, "minimap_menu_" .. menu, menus[menu] )
end

-------------------------------------------------------------------------------
-- OnEnter script handler, for setting up the tooltip.
--
function Me.OnEnter( frame ) 
	Main.StartTooltip( frame )
	
	GameTooltip:AddDoubleLine("Listener", Main.version, 0, 0.7, 1, 1, 1, 1)
	GameTooltip:AddLine( " " )
--[[	
	local window_count = 0
	for _,_ in pairs( Main.frames ) do
		window_count = window_count + 1
	end]]
	
--	if window_count < 3 then
		GameTooltip:AddLine( L["|cff00ff00Left-click|r to open menu."], 1, 1, 1 )
--	else
--		GameTooltip:AddLine( L["|cff00ff00Left-click|r to toggle windows."], 1, 1, 1 )
--	end
	
	GameTooltip:AddLine( L["|cff00ff00Right-click|r to open settings."], 1, 1, 1 )
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
-- OnLeave script handler.
--
function Me.OnLeave( frame )
	GameTooltip:Hide()
end
