-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2018)
--
-- Here we control the context menu for Listener windows.
-------------------------------------------------------------------------------

local Main   = ListenerAddon
local L      = Main.Locale
local Me     = Main.Frame
local Method = Me.methods

Me.menu        = nil
Me.menu_parent = nil

Main.RegisterFilterMenu( "MAIN",
	{ "Public", "Party", "Raid", "Raid Warning", "Whisper", "Instance", "Guild", "Officer", "Rolls", "Channel", "CrossRP", "Misc" }, 
	function( filter )
		return Me.menu_parent:HasEvent( filter )
	end,
	function( filters, checked )
		if checked then
			Me.menu_parent:AddEvents( unpack( filters ))
		else
			Me.menu_parent:RemoveEvents( unpack( filters ))
		end
	end)

-------------------------------------------------------------------------------
local function InclusionClicked( self, arg1, arg2, checked )
	Me.menu_parent:SetListenAll( checked )
end

-------------------------------------------------------------------------------
local function SoundClicked( self, arg1, arg2, checked )
	Me.menu_parent.charopts.sound = checked
end

-------------------------------------------------------------------------------
local function FlashClicked( self, arg1, arg2, checked )
	Me.menu_parent.charopts.flash = checked
end

-------------------------------------------------------------------------------
local function AutoPopupClicked( self, arg1, arg2, checked )
	Me.menu_parent.frameopts.auto_popup = checked
end

local function EnableMouseClicked( self, arg1, arg2, checked )
	Me.menu_parent.frameopts.enable_mouse = checked
	Me.menu_parent:ApplyOtherOptions()
end

-------------------------------------------------------------------------------
local function LockClicked( self, arg1, arg2, checked )
	Me.menu_parent.frameopts.locked = checked
	Me.menu_parent:UpdateResizeShow()
end

local function CopyClicked()
	Me.menu_parent:CopyText()
end

-------------------------------------------------------------------------------
local g_delete_frame_index
StaticPopupDialogs["LISTENER_DELETE_WINDOW"] = {
	text         = L["Are you sure you wanna do that?"];
	button1      = L["Yeah"];
	button2      = L["No..."];
	hideOnEscape = true;
	whileDead    = true;
	timeout      = 0;
	OnAccept = function( self )
	
		if Main.frames[g_delete_frame_index] then
			Main.DestroyWindow( Main.frames[g_delete_frame_index] )
		end
	end;
}

-------------------------------------------------------------------------------
local g_rename_frame_index = nil
StaticPopupDialogs["LISTENER_RENAMEFRAME"] = {
	text         = L["Enter new name."];
	button1      = L["Save"];
	button2      = L["Nevermind..."];
	hasEditBox   = true;
	hideOnEscape = true;
	whileDead    = true;
	timeout      = 0;
	OnShow = function( self )
		self.editBox:SetText( Main.frames[g_rename_frame_index].charopts.name )
	end;
	OnAccept = function( self )
		local name = self.editBox:GetText()
		if name == "" then return end
		
		local o = Main.frames[g_rename_frame_index]
		if o then
			o.charopts.name = name
		end
	end;
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end;
	EditBoxOnEnterPressed = function(self, data)
		local parent = self:GetParent();
		local name = self:GetText();
		self:SetText("");
		
		if name ~= "" then 
			local o = Main.frames[g_rename_frame_index]
			if o then
				o.charopts.name = name
			end
		end
		
		parent:Hide();
	end;
}

-------------------------------------------------------------------------------
local function RenameClicked( self )
	g_rename_frame_index = Me.menu_parent.frame_index
	StaticPopup_Show("LISTENER_RENAMEFRAME")
end

-------------------------------------------------------------------------------
-- Iterates through unit IDs of your party or raid, excluding the player
--
-- Note that the iterator is not valid across frames.
--
local function IteratePlayers()
	local raidparty = IsInRaid() and "raid" or "party"
	local index     = -1
	
	return function()
		
		while true do
			index = index + 1
			if index == 0 then
				return Main.FullName( 'player' )
			end
			
			local unit = raidparty .. index
			if not UnitExists( unit ) then
				return nil
			end
			
			if not UnitIsUnit( unit, "player" ) then
				return Main.FullName( unit )
			end
		end
	end
end

local g_player_list = {}

-------------------------------------------------------------------------------
local function CreatePlayerList()
	local players = {}
	for p in IteratePlayers() do
		local _, icname = LibRPNames.Get( p )
		table.insert( players, {
			name   = p;
			icname = icname;
		})
	end
	
	-- sort alphabetically
	table.sort( players, function( a, b )
		return a.icname:lower() < b.icname:lower()
	end)
	
	-- split into groups of 10
	g_player_list = {}
	local list = {}
	local count = 0
	for i = 1, #players do
		table.insert( list, players[i] )
		count = count + 1
		if count >= 10 then
			table.insert( g_player_list, list )
			list = {}
			count = 0
		end
		
	end
	table.insert( g_player_list, list )
end

-------------------------------------------------------------------------------
local function PlayerMenuName( player )
	local f = Me.menu_parent.players[player.name]
	local text = player.icname
	if player.icname ~= player.name then
		text = text .. " (" .. player.name .. ")"
	end
	if f == 1 then return "|cFF1cff62" .. text end
	if f == 0 then return "|cFFff1c1c" .. text end
	return "|cFFD4D4D4" .. text
end

-------------------------------------------------------------------------------
local function PlayerMenuClicked( self, player, arg2, checked )
	local f = Me.menu_parent.players[player.name]
	local listenall = Me.menu_parent.charopts.listen_all
	
	-- filter is a tristate: include,exclude,or default (listenall)
	-- change order w/ listenall: n -> 0 -> 1
	-- change order    otherwise: n -> 1 -> 0
	if not f then
		f = listenall and 0 or 1
	elseif f == 1 then
		if listenall then f = nil else f = 0 end
	elseif f == 0 then
		if listenall then f = 1 else f = nil end
	end
	Me.menu_parent.players[player.name] = f
	self:SetText( PlayerMenuName( player ) )
	Me.menu_parent:RefreshChat()
	Me.menu_parent:UpdateProbe()
end

-------------------------------------------------------------------------------
local function PopulatePlayersSubmenu( level, menuList )
	local index = tonumber(menuList:match("FRAMEOPTS_%d+_PLAYERS_(%d+)"))
	local list = g_player_list[index]
	
	for key, player in ipairs( list ) do
		info = UIDropDownMenu_CreateInfo()
		info.arg1             = player
		info.text             = PlayerMenuName( player )
		info.func             = PlayerMenuClicked
		info.notCheckable     = true
		info.keepShownOnClick = true
		
		info.tooltipTitle     = L["Click to toggle."]
		info.tooltipText      = L["Green = Include (show this player).\nRed = Exclude (hide this player).\nWhite = Default (inherit upper filter)."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	end
end

-------------------------------------------------------------------------------
local function PopulatePlayersMenu( level )
	if #g_player_list == 1 then
		-- if there's just one list (of max 10) then 
		-- we populate that menu here directly.
		PopulatePlayersSubmenu( level, "FRAMEOPTS_" .. Me.menu_parent.frame_index .. "_PLAYERS_1" )
	else
		for key, list in ipairs( g_player_list ) do
		
			if #list > 0 then
				-- take first letter of first and last entries
				-- e.g. "A..F"
				local letter1, letter2 = list[1].icname:match( "^[%z\1-\127\194-\244][\128-\191]*" ):upper(),
										 list[#list].icname:match( "^[%z\1-\127\194-\244][\128-\191]*" ):upper()
				local name
				if letter1 == letter2 then
					name = letter1
				else
					name = letter1 .. ".." .. letter2
				end
				
				info = UIDropDownMenu_CreateInfo()
				info.text             = name
				info.notCheckable     = true
				info.hasArrow         = true
				info.menuList         = "FRAMEOPTS_" .. Me.menu_parent.frame_index .. "_PLAYERS_" .. key
				info.keepShownOnClick = true
				UIDropDownMenu_AddButton( info, level )
			end
		end
	end
end

-------------------------------------------------------------------------------
local function GroupMenuName( group )
	local f = Me.menu_parent.groups[group]
	local text = L( "Group {1}", group )
	if f == 1 then return "|cFF1cff62" .. text end
	if f == 0 then return "|cFFff1c1c" .. text end
	return "|cFFD4D4D4" .. text
end

-------------------------------------------------------------------------------
local function RaidGroupClicked( self, group )
	local f = Me.menu_parent.groups[group]
	local listenall = Me.menu_parent.charopts.listen_all
	
	if not f then
		f = listenall and 0 or 1
	elseif f == 1 then
		if listenall then f = nil else f = 0 end
	elseif f == 0 then
		if listenall then f = 1 else f = nil end
	end
	
	Me.menu_parent.groups[group] = f
	self:SetText( GroupMenuName( group ) )
	Me.menu_parent:RefreshChat()
	Me.menu_parent:UpdateProbe()
end

-------------------------------------------------------------------------------
local function PopulateRaidGroupsMenu( level )
	for i = 1, 8 do
		info = UIDropDownMenu_CreateInfo()
		info.text             = GroupMenuName( i )
		info.arg1             = i
		info.notCheckable     = true
		info.func             = RaidGroupClicked
		info.keepShownOnClick = true
		
		info.tooltipTitle     = L["Click to toggle."]
		info.tooltipText      = L["Green = Include (show this group).\nRed = Exclude (hide this group).\nWhite = Default (inherit upper filter)."]
		info.tooltipOnButton  = true
		
		UIDropDownMenu_AddButton( info, level )
	end
end

function Me.PopulateFrameMenu( level, menuList )
	if not menuList then return end
	
	-- handle filters menu
	if menuList:find("FILTERS") then
		Main.PopulateFilterMenu( level, menuList:match( "FILTERS.*" ) )
		return
	end
	
	local info
	
	local frame_index, submenu = menuList:match( "FRAMEOPTS_(%d+)(.*)" )
	if not frame_index then return end
	frame_index = tonumber(frame_index)
	
	local frame = Main.frames[frame_index]
	Me.menu_parent = Main.frames[frame_index]
	
	if submenu == "" then
		if Me.menu_parent.frame_index > 2 then
			
			info = UIDropDownMenu_CreateInfo()
			info.text             = "|cFFECCD35" .. frame.charopts.name
			info.notCheckable     = true
			info.tooltipTitle     = frame.charopts.name
			info.tooltipText      = L["Click to rename this window."]
			info.tooltipOnButton  = true
			info.func             = RenameClicked
			UIDropDownMenu_AddButton( info, level )
		end
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Inclusion"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = frame.charopts.listen_all
		info.func             = InclusionClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Inclusion mode."]
		info.tooltipText      = L["Default to include players rather than exclude them. Typically you turn this off in crowded areas."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Auto-Popup"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = frame.frameopts.auto_popup
		info.func             = AutoPopupClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Auto-popup."]
		info.tooltipText      = L["Reopen window automatically upon receiving new messages."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Enable Mouse"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = frame.frameopts.enable_mouse
		info.func             = EnableMouseClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable mouse."]
		info.tooltipText      = L["Enables mouse interaction with content in this frame."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Lock"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = frame.frameopts.locked
		info.func             = LockClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Lock window."]
		info.tooltipText      = L["Prevents moving or resizing."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Copy Text"]
		info.notCheckable     = true
		info.func             = CopyClicked
		info.tooltipTitle     = L["Copy text."]
		info.tooltipText      = L["Opens a window to copy text."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Notify"]
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "FRAMEOPTS_" .. frame_index .. "_NOTIFY"
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Notification settings."]
		info.tooltipText      = L["Settings for alerting you when receiving new messages in this frame."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Filter"]
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "FILTERS_MAIN"
		info.tooltipTitle     = L["Display filter."]
		info.tooltipText      = L["Selects which chat types to display."]
		info.tooltipOnButton  = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
		if IsInGroup( LE_PARTY_CATEGORY_HOME ) then
			CreatePlayerList()
			info = UIDropDownMenu_CreateInfo()
			info.text             = L["Players"]
			info.notCheckable     = true
			info.hasArrow         = true
			info.menuList         = "FRAMEOPTS_" .. frame_index .. "_PLAYERS"
			info.tooltipTitle     = L["Player filter."]
			info.tooltipText      = L["Adjusts filter for players in your group."]
			info.tooltipOnButton  = true
			info.keepShownOnClick = true
			UIDropDownMenu_AddButton( info, level )
			
			if IsInRaid() then
				info = UIDropDownMenu_CreateInfo()
				info.text             = L["Raid Groups"]
				info.notCheckable     = true
				info.hasArrow         = true
				info.menuList         = "FRAMEOPTS_" .. frame_index .. "_RAID"
				info.tooltipTitle     = L["Raid group filters."]
				info.tooltipText      = L["Adjusts filter for groups in your raid."]
				info.tooltipOnButton  = true
				info.keepShownOnClick = true
				UIDropDownMenu_AddButton( info, level )
			end
		end
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Settings"]
		info.notCheckable     = true
		info.func             = function()
			frame:OpenConfig()
		end
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["New Window"]
		info.notCheckable     = true
		info.tooltipTitle     = L["New window."]
		info.tooltipText      = L["Creates a new Listener window."]
		info.tooltipOnButton  = true
		info.func             = function()
			Main.UserCreateWindow()
		end
		UIDropDownMenu_AddButton( info, level )
		
		if Me.menu_parent.frame_index > 2 then
			info = UIDropDownMenu_CreateInfo()
			info.text             = L["Delete Window"]
			info.notCheckable     = true
			info.tooltipTitle     = L["Delete window."]
			info.tooltipText      = L["Closes and deletes this menu."]
			info.tooltipOnButton  = true
			info.func             = function()
				g_delete_frame_index = Me.menu_parent.frame_index
				StaticPopup_Show("LISTENER_DELETE_WINDOW")
			end
			UIDropDownMenu_AddButton( info, level )
		end
		
	elseif submenu == "_NOTIFY" then
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Sound"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = frame.charopts.sound
		info.func             = SoundClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Notification sound."]
		info.tooltipText      = L["Play a sound when receiving new messages."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Flash"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = frame.charopts.flash
		info.func             = FlashClicked
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Taskbar flashing."]
		info.tooltipText      = L["Flash the taskbar icon when receiving new messages."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
	elseif submenu:find("_PLAYERS") then
		local sub_index = submenu:match( "_PLAYERS_(%d+)" )
		if sub_index then
			PopulatePlayersSubmenu( level, menuList )
		else
			PopulatePlayersMenu( level )
		end
	elseif submenu:find("_RAID") then
		PopulateRaidGroupsMenu( level )
	end
end

-------------------------------------------------------------------------------
local function InitializeMenu( self, level, menuList )
	if level == 1 then
		Me.PopulateFrameMenu( level, "FRAMEOPTS_" .. Me.menu_parent.frame_index )
	else
		Me.PopulateFrameMenu( level, menuList )
	end
end

-------------------------------------------------------------------------------
function Method:ShowMenu()
--[[	if not Me.menu then
	
			
		Me.menu = CreateFrame( "Button", "ListenerFrameMenu", UIParent, "UIDropDownMenuTemplate" )
		Me.menu.displayMode = "MENU"
	end]]
	
	Me.menu_parent = self
	Main.ToggleMenu( self.bar2.title, "listener_window_menu", InitializeMenu )
	--[[
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if Me.menu_parent == self and UIDROPDOWNMENU_OPEN_MENU == Me.menu then
		ToggleDropDownMenu( 1, nil, Me.menu )
		return
	end
	
	Me.menu_parent = self
	
	
	UIDropDownMenu_Initialize( ListenerFrameMenu, InitializeMenu )
	UIDropDownMenu_JustifyText( ListenerFrameMenu, "LEFT" )
	
	
	local x,y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	ToggleDropDownMenu( 1, nil, Me.menu, self:GetName() .. "Bar2TitleButton", 0, 0 )]]
end
