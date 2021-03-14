-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- The Snooper module.
-------------------------------------------------------------------------------

local Main        = ListenerAddon
local L           = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

Main.Snoop2       = {}
local Me          = Main.Snoop2

-------------------------------------------------------------------------------
-- The name of the current player that's being snooped.
--
local g_current_name = nil

-------------------------------------------------------------------------------
-- The time since the last refresh (to throttle updates).
--
local g_update_time = 0

-------------------------------------------------------------------------------
-- Setup the Snooper.
--
function Me.Setup()

	Main.RegisterFilterMenu( "SNOOPER",
		{ "Public", "Party", "Raid", "Raid Warning", "Instance", 
		  "Guild", "Officer", "Rolls", "Whisper", "Channel", "CrossRP" },
		function( filter )
			return Main.frames[2].charopts.filter[filter]
		end,
		function( filters, checked )
			if checked then
				Main.frames[2]:AddEvents( unpack( filters ))
			else
				Main.frames[2]:RemoveEvents( unpack( filters))
			end
		end)
	
	local frame = Main.frames[2]
	frame.snooper             = true
	frame.charopts.listen_all = false
	frame.charopts.showhidden = false
	frame.frameopts.readmark  = false
	frame.players             = {}
	
	frame.FormatChatMessage = Me.FormatChatMessage
	frame.UpdateResizeShow  = Me.UpdateResizeShow
	
	-- customize the ui a bit
	frame.bar2.title:SetText( "Snooper" )
	frame.bar2.hidden_button:Hide()
	
	Me.LoadConfig()
	
	Me.update_frame = CreateFrame( "Frame" )
	Me.update_frame:SetScript( "OnUpdate", function()
		Me.OnUpdate( frame )
	end)
end

-------------------------------------------------------------------------------
-- Load/reload the Snooper configuration.
--
function Me.LoadConfig()
	local snooper = Main.frames[2]
	
	Me.UpdateMouseLock()
	
	snooper:UpdateResizeShow()
	snooper:RefreshChat()
end

-------------------------------------------------------------------------------
-- This enables/disables mouse interaction according to options and the shift
-- key.
--
function Me.UpdateMouseLock()
	local snooper = Main.frames[2]
	snooper:EnableMouse( snooper.frameopts.enable_mouse or (snooper.frameopts.shift_mouse and IsShiftKeyDown()) )
	snooper.chatbox:EnableMouseWheel( snooper.frameopts.enable_scroll or (snooper.frameopts.shift_mouse and IsShiftKeyDown()) )
end

-------------------------------------------------------------------------------
-- Periodic update function.
--
-- @param self The snooper frame (Main.frames[2]).
--
function Me.OnUpdate( self )
	
	if self.frameopts.hidecombat and InCombatLockdown() then return end
	
	local name = (IsShiftKeyDown() or self.mouseon) and g_current_name or Main.GetProbed()
	if self.frameopts.target_only and not UnitExists( "target" ) then
		name = nil
	end
	
	if g_current_name == name and GetTime() - g_update_time < 10 then
		-- throttle updates when the name matches
		return
	end
	
	local hard_update = g_current_name ~= name
	
	g_current_name = name
	
	-- setup filter.
	self.players = {}
	if name then
		-- the snooper filter is a single player.
		self.players[name] = 1
		self.snoop_player = name
	else
		self.snoop_player = nil
	end
	
	if hard_update then
		-- and refresh chat
		self:RefreshChat()
		g_update_time = GetTime()
	else
		-- if they're scrolled up, don't mess with them.
		-- 
		if self.chatbox:AtBottom() then
			self:RefreshChat()
			g_update_time = GetTime()
		end
	end
	
	if self.frameopts.hideempty and not self.charopts.hidden then
		if name then
			if self.chatbox:GetNumMessages() > 0 then
				if not (InCombatLockdown() and self.frameopts.combathide) then
					self:Open( true )
				end
			end
		else
			if self.frameopts.hideempty then
				self:Close(true)
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Updates showing the resize thumb according to options.
--
function Me:UpdateResizeShow()
	if not self.frameopts.locked then
		self.resize_thumb:Show()
	else
		self.resize_thumb:Hide()
	end
end

-------------------------------------------------------------------------------
-- Prefixes for messages within the snooper.
--
-- The snooper has its own message formatting functions for special timestamps
-- (and it's meant to only show one player, so some things may be omitted).
--
local MESSAGE_PREFIXES = {
	PARTY           = "[P] ";
	PARTY_LEADER    = "[P] ";
	RAID            = "[R] ";
	RAID_LEADER     = "[R] ";
	RP1             = "[RP] ";
	RP2             = "[RP2] ";
	RP3             = "[RP3] ";
	RP4             = "[RP4] ";
	RP5             = "[RP5] ";
	RP6             = "[RP6] ";
	RP7             = "[RP7] ";
	RP8             = "[RP8] ";
	RP9             = "[RP9] ";
	RPW             = "[RP!] ";
	INSTANCE        = "[I] ";
	INSTANCE_LEADER = "[I] ";
	OFFICER         = "[O] ";
	GUILD           = "[G] ";
	CHANNEL         = "[C] ";
	RAID_WARNING    = "[RW] ";
	WHISPER         = L["[W From] "];
	WHISPER_INFORM  = L["[W To] "];
}

-------------------------------------------------------------------------------
-- Normal "name: text"
--
local function MsgFormatNormal( e, name )
	local prefix = MESSAGE_PREFIXES[e.e] or ""
	if e.e == "CHANNEL" then
		local index = GetChannelName( e.c )
		if index ~= 0 then
			prefix = prefix:gsub( "C", index )
		else
			-- this is an unregistered channel
			local club, stream = e.c:match( "(%d+):(%d+)" )
			if not club then
				prefix = prefix:gsub( "C", e.c )
			else
				local club_info = C_Club.GetClubInfo( club )
				channel_name = club_info.shortName
				if channel_name == "" then channel_name = club_info.name end
				local stream_info = C_Club.GetStreamInfo( club, stream )
				if stream_info.streamType ~= Enum.ClubStreamType.General then
					channel_name = channel_name .. " - " .. stream_info.name
				end
				prefix = prefix:gsub( "C", channel_name )
			end
		end
	end
	return prefix .. e.m
end

-------------------------------------------------------------------------------
-- No separator between name and text.
--
local function MsgFormatEmote( e, name )
	-- If they prefix with a pipe, cut off the name and remove the pipes.
	-- Note that this is specially different from the main window.
	-- The name is implied in the snooper window, so we don't need 
	-- to check against the trp_emotes option.
	-- It's common to prefix with "|" or "||" in emotes to denote that your
	-- emote should not consider the name before it.
	--
	-- And, pipes are doubled up, because they're wow's escape character.
	--
	if e.m:match( "^||" ) then
		-- cut off pipes and trailing space.
		return e.m:match( "^|+%s*(.*)" )
	end
	
	-- 
	if e.m:match( "^»" ) then
		return e.m
	end
	if e.m:sub( 1,2 ) == ", " or e.m:sub( 1,2 ) == "'s" then
		return name .. e.m
	end
	if e.m:match( "^%s*%p" ) then
		return e.m
	end
	return name .. " " .. e.m
end

-------------------------------------------------------------------------------
-- <name> <msg> - name is substituted
--
local function MsgFormatTextEmote( e, name )
	-- Need to convert - to %- to avoid it triggering a pattern and
	--  invalidating the name match.
	local msg = e.m:gsub( e.s:gsub("%-","%%-"), name )
	return msg
end

-------------------------------------------------------------------------------
-- Function table for formatting events.
--
local MSG_FORMAT_FUNCTIONS = {
	SAY                  = MsgFormatNormal;
	PARTY                = MsgFormatNormal;
	PARTY_LEADER         = MsgFormatNormal;
	RAID                 = MsgFormatNormal;
	RAID_LEADER          = MsgFormatNormal;
	RAID_WARNING         = MsgFormatNormal;
	RP1                  = MsgFormatNormal;
	RP2                  = MsgFormatNormal;
	RP3                  = MsgFormatNormal;
	RP4                  = MsgFormatNormal;
	RP5                  = MsgFormatNormal;
	RP6                  = MsgFormatNormal;
	RP7                  = MsgFormatNormal;
	RP8                  = MsgFormatNormal;
	RP9                  = MsgFormatNormal;
	RPW                  = MsgFormatNormal;
	YELL                 = MsgFormatNormal;
	INSTANCE_CHAT        = MsgFormatNormal;
	INSTANCE_CHAT_LEADER = MsgFormatNormal;
	GUILD                = MsgFormatNormal;
	OFFICER              = MsgFormatNormal;
	CHANNEL              = MsgFormatNormal;
	
	EMOTE = MsgFormatEmote;
	
	TEXT_EMOTE = MsgFormatTextEmote;
	ROLL       = MsgFormatTextEmote;
}

-------------------------------------------------------------------------------
-- If any events are missing, this will default them to MsgFormatNormal.
--
setmetatable( MSG_FORMAT_FUNCTIONS, {
	__index = function( table, key ) 
		return MsgFormatNormal
	end;
})

-------------------------------------------------------------------------------
-- Function override for formatting chat messages. The snooper is special.
--
function Me:FormatChatMessage( e )
	
	local stamp = ""
	local old = time() - e.t
	
	if old < 30*60 then
		-- within 30 minutes, use relative time
		if old < 60 then
			stamp = "<1m"
		else
			stamp = string.format( "%sm", math.floor(old / 60) )
		end
	else
		-- use absolute stamp
		stamp = date( "%H:%M", e.t )
	end
	
	if self.frameopts.timestamp_brackets then
		stamp = "[" .. stamp .. "]"
	end
	
	local timecolor
	if old >= 600 then
		timecolor = "|cff777777"
	elseif old >= 300 then
		timecolor = "|cff888888"
	elseif old >= 60 then
		timecolor = "|cffbbbbbb"
	else
		timecolor = "|cff05ACF8"
	end
	
	stamp = timecolor .. stamp .. "|r "
	
	local name, shortname, _, color = LibRPNames.Get( e.s, Main.guidmap[e.s] )
	if Main.db.profile.shorten_names then
		name = shortname
	end
	
	if color and self.frameopts.name_colors then
		name = "|c" .. color .. name .. "|r"
	end
	
	if self.frameopts.enable_mouse then
		-- we only make links for players when the mouse is enabled.
		name = "|Hplayer:" .. e.s .. "|h" .. name .. "|h"
	end
	
	return string.format( "%s%s", stamp, MSG_FORMAT_FUNCTIONS[e.e]( e, name ) )
end

-------------------------------------------------------------------------------
-- Open the snooper menu. (From clicking the titlebar button.)
--
function Me.ShowMenu()
	Main.ToggleMenu( ListenerFrame2Bar2TitleButton, "snooper_context",
		function( self, level, menuList )
			if level == 1 then
				menuList = "SNOOPER"
			end
			Me.PopulateMenu( level, menuList )
		end)
end

-------------------------------------------------------------------------------
-- This may be called from two places. Just above, and within the minimap
-- menu.
--
function Me.PopulateMenu( level, menuList )
	local info
	
	if menuList == "SNOOPER" then
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Enable Mouse"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.profile.snoop.enable_mouse
		info.func             = function( self, a1, a2, checked )
			Main.db.profile.snoop.enable_mouse = checked
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable mouse."]
		info.tooltipText      = L["Enables interaction with the snooper frame (e.g. to mark messages)."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Enable Scroll"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.profile.snoop.enable_scroll
		info.func             = function( self, a1, a2, checked )
			Main.db.profile.snoop.enable_scroll = checked
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Enable mouse scrolling."]
		info.tooltipText      = L["Enables scrolling the text in the snooper window while the mouse is over the interactive area."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Lock"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.profile.snoop.locked
		info.func             = function( self, a1, a2, checked )
			Main.db.profile.snoop.locked = checked
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Lock frame."]
		info.tooltipText      = L["Prevents the snooper from being moved or resized."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
--[[		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Hide"]
		info.notCheckable     = false
		info.isNotRadio       = true
		info.checked          = Main.db.char.frames[2].hidden
		info.func             = function( self, a1, a2, checked )
			if checked then
				Main.frames[2]:Close()
			else
				Main.frames[2]:Open()
			end
			Me.LoadConfig()
		end
		info.keepShownOnClick = true
		info.tooltipTitle     = L["Hide."]
		info.tooltipText      = L["Hides/disables the snooper window."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )]]
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Copy Text"]
		info.notCheckable     = true
		info.func             = function() Main.frames[2]:CopyText() end
		info.tooltipTitle     = L["Copy text."]
		info.tooltipText      = L["Opens a window to copy text."]
		info.tooltipOnButton  = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Filter"]
		info.notCheckable     = true
		info.hasArrow         = true
		info.menuList         = "FILTERS_SNOOPER"
		info.tooltipTitle     = L["Display filter."]
		info.tooltipText      = L["Selects which chat types to display."]
		info.tooltipOnButton  = true
		info.keepShownOnClick = true
		UIDropDownMenu_AddButton( info, level )
		
		info = UIDropDownMenu_CreateInfo()
		info.text             = L["Settings"]
		info.notCheckable     = true
		info.func             = function( self, a1, a2, checked )
			Main.FrameConfig_Open( Main.frames[2] )
		end
		UIDropDownMenu_AddButton( info, level )
	elseif menuList and menuList:find("FILTERS") then
		Main.PopulateFilterMenu( level, menuList:match( "FILTERS.*" ) )
	end
end
