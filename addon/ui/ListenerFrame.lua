-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- The almighty Listener window.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale
Main.Frame = {}

local Me          = ListenerAddon.Frame
local SharedMedia = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
-- For chatbox:SetMaxLines()
--
local CHAT_BUFFER_SIZE = 300

-------------------------------------------------------------------------------
-- When the frame scrolls, clicks are locked for this many seconds. This is to
-- prevent clicking on something else accidentally when the frame scrolls.
--
local CLICKBLOCK_TIME  = 0.4

-------------------------------------------------------------------------------
-- The duration of the fading animation when a frame auto_fades out.
--
local FADEOUT_DURATION = 1

-------------------------------------------------------------------------------
-- When a new frame is created, the filter is loaded with this.
--
local DEFAULT_LISTEN_EVENTS = {
	"SAY", "EMOTE", "TEXT_EMOTE", "YELL",
	"PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"ROLL"
}

-------------------------------------------------------------------------------
-- Chat events that should not make a notification.
--
local SKIP_BEEP = {
	ONLINE            = true;
	OFFLINE           = true;
	CHANNEL_JOIN      = true;
	CHANNEL_LEAVE     = true;
	GUILD_ACHIEVEMENT = true;
	GUILD_MOTD        = true;
	WHISPER_INFORM    = true;
}

Me.SKIP_BEEP = SKIP_BEEP

-------------------------------------------------------------------------------
-- Prefix behind name for these types of messages.
--
local MSG_FORMAT_PREFIX = {
	PARTY                 = "[P] ";
	PARTY_LEADER          = "[P] ";
	RAID                  = "[R] ";
	RAID_LEADER           = "[R] ";
	RP1                   = "[RP] ";
	RP2                   = "[RP2] ";
	RP3                   = "[RP3] ";
	RP4                   = "[RP4] ";
	RP5                   = "[RP5] ";
	RP6                   = "[RP6] ";
	RP7                   = "[RP7] ";
	RP8                   = "[RP8] ";
	RP9                   = "[RP9] ";
	RPW                   = "[RP!] ";
	INSTANCE_CHAT         = "[I] ";
	INSTANCE_CHAT_LEADER  = "[I] ";
	GUILD                 = "[G] ";
	OFFICER               = "[O] ";
	RAID_WARNING          = "[RW] ";
	CHANNEL               = "[C] ";
	WHISPER               = L["From"] .. " ";
	WHISPER_INFORM        = L["To"] .. " ";
}

-------------------------------------------------------------------------------
-- Static methods
-------------------------------------------------------------------------------
local ENTRY_CHAT_REMAP = { ROLL = "SYSTEM", OFFLINE = "SYSTEM", ONLINE = "SYSTEM", GUILD_MOTD = "GUILD", GUILD_ITEM_LOOTED = "GUILD_ACHIEVEMENT" }
local function GetEntryColor( e )
	local info
	if e.c then
		local index = GetChannelName( e.c )
		info = ChatTypeInfo[ "CHANNEL" .. index ]
		if not info then info = ChatTypeInfo.CHANNEL end
	else
		local t = ENTRY_CHAT_REMAP[e.e] or e.e
		info = ChatTypeInfo[t]
		if not info then info = ChatTypeInfo.SAY end
	end
	return { info.r, info.g, info.b, 1 }
end

-------------------------------------------------------------------------------
-- Private methods
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- Initialize member variables
--
local function SetupMembers( self )
	-- this is to be overridden by SetFrameIndex
	self.listen_events = {}
	
	-- the uppermost unread message ID
	-- nil if the window has no "unread" messages
	self.top_unread_id = nil
	
	-- when a new messages is added, this saves the time
	-- if the user clicks on the frame at the moment a message is added, 
	-- its ignore to prevent error
	self.clickblock = 0
	
	-- textures used for the tab strips on the left side of the window
	self.tab_texes = {}
	
	-- this is a list of things that we can pick from with the mouse
	self.pick_regions = {
		-- table of:
		-- { region = region, entry = entry }
	}
	
	-- cached auto_fade value
	self.auto_fade = 0
	self.auto_fade_opacity = 0
	
	-- time since last activity
	self.fade_time = 0
	
	-- this dictates that the mouse is being held over a region
	--self.picked = nil (too complex)
end

-------------------------------------------------------------------------------
local function PickTextRegion( self, setup_highlight )

	if self:IsMouseOver() then
		for _,v in pairs( self.pick_regions ) do
			if v.region:IsMouseOver() then
				if setup_highlight then
					self.chatbox.highlight:SetPoint( "TOP", v.region, "TOP" )
					self.chatbox.highlight:SetPoint( "BOTTOM", v.region, "BOTTOM" )
					self.chatbox.highlight:Show()
				end
				return v
			end
		end
	end
	
	if setup_highlight and self.chatbox.highlight:IsShown() then
		self.chatbox.highlight:Hide()
	end
end

-------------------------------------------------------------------------------
-- Setup the frames that form the edge around the window.
--
local function CreateEdges( self )
	if self.edges then return end
	self.edges = {}
	for i = 1,4 do
		table.insert( self.edges, self:CreateTexture( "BORDER" ))
	end
	
end

-------------------------------------------------------------------------------
-- Add or subtract from the frame's font size.
--
local function AdjustFontSize( self, delta )
	local size = 0
	size = self.frameopts.font.size or self.baseopts.font.size
	size = size + delta
	self:SetFontSize( size )
end

-------------------------------------------------------------------------------
-- Save the window layout in the database.
--
local function SaveFrameLayout( self )
	if not self.frame_index then return end
	
	local point, region, point2, x, y = self:GetPoint(1)
	local width, height = self:GetSize()
	width  = math.floor( width + 0.5 )
	height = math.floor( height + 0.5 )
	if region then region = region:GetName() end
	
	local layout = {
		anchor = { point, region, point2, x, y };
		width  = width;
		height = height;
	}
	
	self.frameopts.layout = layout
	
	LibStub("AceConfigRegistry-3.0"):NotifyChange( "Listener Frame Settings" )
end

-------------------------------------------------------------------------------
local function ShowOrHide( self, show, save )
	
	if save then
		self.charopts.hidden = not show
		if show then self.fade_time = GetTime() end
	end
	
	if self.charopts.hidden then
		if Main.active_frame == self and self.frame_index ~= 1 then
			Main.SetActiveFrame( Main.frames[1] )
		end
	end
	
	self:UpdateShown()
end

-------------------------------------------------------------------------------
-- This enables/disables mouse interaction according to options and the shift
-- key.
--
local function UpdateMouseLock( self )
	self:EnableMouse( self.frameopts.enable_mouse or (self.frameopts.shift_mouse and IsShiftKeyDown()) )
	
	if self.snooper then
		self.chatbox:EnableMouseWheel( self.frameopts.enable_scroll or (self.frameopts.shift_mouse and IsShiftKeyDown()) )
	else
		self.chatbox:EnableMouseWheel( true )
	end
end

-------------------------------------------------------------------------------
-- Add or remove player from the filter.
--
-- @param name   Name of player.
-- @param mode   1 = add player; 0 = remove player; nil = reset player
-- @param silent Don't print chat messages.
--
local function AddOrRemovePlayer( self, name, mode, silent )
	if mode ~= 1 and mode ~= 0 and mode ~= nil then error( "Invalid mode." ) end
	name = Main.FixupName( name )
	
	if self.players[name] == mode then
		if not silent then
			if mode == 1 then
				Main.Print( string.format( L["Already listening to %s."], name ) ) 
			elseif mode == 0 then
				Main.Print( string.format( L["%s is already filtered out."], name ) ) 
			else
				Main.Print( string.format( L["%s wasn't found."], name ) ) 
			end
		end
		return
	end
	
	self.players[name] = mode
	if not silent then 
		if mode == 1 then
			Main.Print( string.format( L["Added %s."], name ) ) 
		elseif mode == 0 then
			Main.Print( string.format( L["Removed %s."], name ) ) 
		else
			Main.Print( string.format( L["Reset %s."], name ) ) 
		end
	end
	
	self:RefreshChat()
	self:UpdateProbe()
end

-------------------------------------------------------------------------------
-- Returns true if an entry should be displayed according to event filters.
--
local function EntryFilter( self, entry )
	if entry.c then
		if entry.e == "CHANNEL" then 
			return self.listen_events[ "#" .. entry.c ]
		else
			return self.listen_events[entry.e] 
			       and self.listen_events[ "#" .. entry.c ]
		end
	end
	return self.listen_events[entry.e]
end

-------------------------------------------------------------------------------
-- Public Methods
-------------------------------------------------------------------------------
local Method = {}
Me.methods = Method

Method.EntryFilter = EntryFilter

-------------------------------------------------------------------------------
-- Link this frame to the database.
--
function Method:SetFrameIndex( index )
	if index == nil then return end
	
	self.frame_index = index
	Me.InitOptions( index )
	self.players       = Main.db.char.frames[index].players
	self.listen_events = Main.db.char.frames[index].filter
	self.groups        = Main.db.char.frames[index].groups
	
	-- baseopts exist at the profile level and may contain
	-- global options.
	-- frameopts are options that override them.
	-- for the snooper frameopts is stored on the profile level
	-- otherwise theyre at the character level.
	if index == 1 then
		self.frameopts = Main.db.profile.frame
	elseif index == 2 then
		self.frameopts = Main.db.profile.snoop
	else
		self.frameopts = Main.db.char.frames[index]
	end
	self.baseopts = Main.db.profile.frame
	
	-- char options exist only at the character level and are
	-- initialized when the frame is created
	self.charopts = Main.db.char.frames[index]
	
	-- to set the title.
	self:UpdateProbe()
end

-------------------------------------------------------------------------------
local TIMESTAMP = {
	
	-- HH:MM:SS
	[1] = function( t ) return date( "%H:%M:%S ", t ) end;
	
	-- HH:MM
	[2] = function( t ) return date( "%H:%M ", t ) end;
	
	-- HH:MM (12-hour)
	[3] = function( t ) return date( "%I:%M ", t ):gsub( "^0", "" ) end;
	
	-- MM:SS
	[4] = function( t ) return date( "%M:%S ", t ) end;
	
	-- MM
	[5] = function( t ) return date( "%M ", t ) end;
}

-------------------------------------------------------------------------------
-- Normal "name: text"
local function MsgFormatNormal( e, name )
	local prefix = MSG_FORMAT_PREFIX[e.e] or ""
	return prefix .. name .. ": " .. e.m
end

-------------------------------------------------------------------------------
local function MsgFormatNormalChannel( e, name )
	local prefix = MSG_FORMAT_PREFIX[e.e] or ""
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
	return prefix .. name .. ": " .. e.m
end

-------------------------------------------------------------------------------
-- No separator between name and text.
local function MsgFormatEmote( e, name )
	if Main.db.profile.trp_emotes and e.m:sub(1,3) == "|| " then
		return e.m:sub( 4 )
	end
	if e.m:sub( 1,2 ) == ", " or e.m:sub( 1,2 ) == "'s" then
		return name .. e.m
	end
	return name .. " " .. e.m
end

-------------------------------------------------------------------------------
-- <name> <msg> - name is substituted
local function MsgFormatTextEmote( e, name )
	if e.s == "" then return e.m end -- Some dumb global emote by bosses.
	
	-- Need to convert - to %- to avoid it triggering a pattern and
	--  invalidating the name match.
	local msg = e.m:gsub( e.s:gsub("%-","%%-"), name )
	return msg
end

-------------------------------------------------------------------------------
-- x joined/left channel.
local function MsgFormatJoinLeave( e, name )
	local prefix = "[" .. GetChannelName( e.c ) .. "] "
	if e.e == "CHANNEL_JOIN" then
		return prefix .. L( "{1} joined channel.", name )
	elseif e.e == "CHANNEL_LEAVE" then
		return prefix .. L( "{1} left channel.", name )
	end
	return "<Error>"
end

-------------------------------------------------------------------------------
local function MsgFormatGuildMOTD( e, name )
	return "|cffffffff" .. L["Guild Message of the Day: "] .. "|r" .. e.m
end

-------------------------------------------------------------------------------
local MSG_FORMAT_FUNCTIONS = { 
	SAY                  = MsgFormatNormal;
	PARTY                = MsgFormatNormal;
	PARTY_LEADER         = MsgFormatNormal;
	RAID                 = MsgFormatNormal;
	RAID_LEADER          = MsgFormatNormal;
	RAID_WARNING         = MsgFormatNormal;
	RP                   = MsgFormatNormal;
	RPW                  = MsgFormatNormal;
	YELL                 = MsgFormatNormal;
	INSTANCE_CHAT        = MsgFormatNormal;
	INSTANCE_CHAT_LEADER = MsgFormatNormal;
	GUILD                = MsgFormatNormal;
	OFFICER              = MsgFormatNormal;
	CHANNEL              = MsgFormatNormalChannel;
	
	EMOTE   = MsgFormatEmote;
	ONLINE  = MsgFormatEmote;
	OFFLINE = MsgFormatEmote;
	GUILD_ITEM_LOOTED = MsgFormatEmote;
	GUILD_ACHIEVEMENT = MsgFormatEmote;
	
	CHANNEL_JOIN  = MsgFormatJoinLeave;
	CHANNEL_LEAVE = MsgFormatJoinLeave;
	
	TEXT_EMOTE = MsgFormatTextEmote;
	ROLL       = MsgFormatTextEmote;
	
	GUILD_MOTD = MsgFormatGuildMOTD;
}

-------------------------------------------------------------------------------
setmetatable( MSG_FORMAT_FUNCTIONS, {
	__index = function( table, key ) 
		return MsgFormatNormal
	end;
})

-------------------------------------------------------------------------------
function Method:FormatChatMessage( e )
	
	local stamp = ""
	local ts = Main.db.profile.frame.timestamps
	if TIMESTAMP[ts] then
		stamp = "|cff808080" .. TIMESTAMP[ts](e.t) .. "|r" 
	end
	
	-- get icon and name 
	local name, shortname, icon, color = LibRPNames.Get( e.s, Main.guidmap[e.s] )
	if Main.db.profile.shorten_names then
		name = shortname
	end
	
	if not icon then
		local alliance = UnitFactionGroup( "player" ) == "Alliance"
		if e.h then
			alliance = not alliance
		end
		if alliance then
			icon = "Inv_Misc_Tournaments_banner_Human"
		else
			icon = "Inv_Misc_Tournaments_banner_Orc"
		end
	end
	
	if icon and Main.db.profile.frame.show_icons then
		if Main.db.profile.frame.zoom_icons then
			icon = "|TInterface\\Icons\\" .. icon .. ":0:0:0:0:100:100:10:90:10:90:255:255:255|t "
		else
			icon = "|TInterface\\Icons\\" .. icon .. ":0|t "
		end
	else
		icon = ""
	end
	
	if color then
		name = "|c" .. color .. name .. "|r"
	end
	
	name = "|Hplayer:" .. e.s .. "|h" .. name .. "|h" 
	
	return string.format( "%s%s%s", stamp, icon, MSG_FORMAT_FUNCTIONS[e.e]( e, name ) )
end

-------------------------------------------------------------------------------
-- Blocks clicks temporarily.
--
-- This is called when a new message is added, as to prevent accidental clicks
-- when the frame is scrolling.
--
function Method:SetClickBlock()
	self.clickblock = GetTime()
end

-------------------------------------------------------------------------------
-- Toggle the frame.
--
function Method:Toggle()
	ShowOrHide( self, self.charopts.hidden, true )
end

-------------------------------------------------------------------------------
-- Hide the frame.
--
function Method:Close( dontsave )
	ShowOrHide( self, false, not dontsave )
end

-------------------------------------------------------------------------------
-- Show the frame.
--
function Method:Open( dontsave )
	ShowOrHide( self, true, not dontsave )
end

-------------------------------------------------------------------------------
function Method:UpdateVisibility()
	local hover = self:IsMouseOver( 8, -8, -8, 8 ) 
	
	local faded = self.auto_fade > 0 and GetTime() > self.fade_time + self.auto_fade
	
	self:ShowBar( 
		(hover and not (self.frameopts.locked and self.frameopts.hide_bar_when_locked))
		or self.dragging
		or (Main.active_frame == self and not faded) )
	
	if self.auto_fade > 0 then
		local alpha = self:GetAlpha()
		local newalpha
		local time = GetTime()
		
		if hover then
			newalpha = 1
		else
			local fadeout_start = self.fade_time + self.auto_fade
			if time >= fadeout_start then
				if time - fadeout_start < FADEOUT_DURATION then
					local d = (time - fadeout_start) / FADEOUT_DURATION
					newalpha = 1 + (self.auto_fade_opacity - 1) * d
					
					
				else
					newalpha = self.auto_fade_opacity
					if Main.active_frame == self and self.frame_index ~= 1 then
						Main.SetActiveFrame( Main.frames[1] )
					end
				end
			else
				newalpha = 1
				
			end
		end
		
		if alpha ~= newalpha then
			self:SetAlpha( newalpha )
		end
	end
end

-------------------------------------------------------------------------------
function Method:ShowBar( show )
	if show and not self.bar2:IsShown() then
		self.bar2:Show()
		self.chatbox:SetPoint( "TOP", self.bar2, "BOTTOM", 0, -1 )
	elseif not show and self.bar2:IsShown() then
		self.bar2:Hide()
		self.chatbox:SetPoint( "TOP", self, 0, -2 )
	end
end

-------------------------------------------------------------------------------
-- Set the chat font size.
--
function Method:SetFontSize( size )

	size = math.max( size, 6 )
	size = math.min( size, 24 )
	
	self.frameopts.font.size = size
	self:ApplyChatOptions()
end

-------------------------------------------------------------------------------
-- Load all options.
--
function Method:ApplyOptions()

	self:SetFrameIndex( self.frame_index )

	self:ApplyLayoutOptions()
	self:ApplyChatOptions()
	self:ApplyColorOptions()
	self:ApplyBarOptions()
	self:ApplyOtherOptions()
end

-------------------------------------------------------------------------------
function Method:ApplyOtherOptions()
	self.bar2.hidden_button:SetOn( self.charopts.showhidden )
	
	self.auto_fade         = self.frameopts.auto_fade or self.baseopts.auto_fade
	self.auto_fade_opacity = self.baseopts.auto_fade_opacity / 100
	
	self:UpdateResizeShow()
	UpdateMouseLock( self )
end

-------------------------------------------------------------------------------
function Method:ApplyColorOptions()
	
	local bgcolor = self.frameopts.color.bg or self.baseopts.color.bg
	self.bg:SetColorTexture( unpack( bgcolor ))
	
	local edgecolor = self.frameopts.color.edge or self.baseopts.color.edge
	for k,v in pairs( self.edges ) do
		v:SetColorTexture( unpack( edgecolor )) 
	end
	
	local bar_color = self.frameopts.color.bar or self.baseopts.color.bar
	self.bar2.bg:SetColorTexture( unpack( bar_color ) )
end

-------------------------------------------------------------------------------
-- Options for the positioning/size.
--
function Method:ApplyLayoutOptions()
	local layout
	layout = self.frameopts.layout
	
	self:ClearAllPoints()
	local anchor = layout.anchor
	if not anchor or #anchor == 0 then
		if self.frame_index == 1 then
			-- primary
			self:SetPoint( "LEFT", 50, 0 )
		else
			-- secondary
			self:SetPoint( "CENTER", 0, 0 )
		end
	else
		local region = anchor[2]
		if not region then
			region = UIParent
		else
			region = _G[region]
		end
		self:SetPoint( anchor[1], region, anchor[3], anchor[4], anchor[5] )
	end
	
	self:SetSize( math.max( layout.width, 50 ), 
	              math.max( layout.height, 50 ) )
				  
	
	-- setup edges
	local es = Main.db.profile.frame.edge_size
	if es == 0 then
		for _, edge in pairs( self.edges ) do
			edge:Hide()
		end
	else
		Me.CraftEdges( self, es )
		
	end
	
	if self.charopts.hidden then
		self:Hide()
	else
		self:Show()
	end
end

-------------------------------------------------------------------------------
-- Options for the chat/text appearance.
--
function Method:ApplyChatOptions()

	local outline = self.frameopts.font.outline or self.baseopts.font.outline
	local face    = self.frameopts.font.face    or self.baseopts.font.face
	local size    = self.frameopts.font.size    or self.baseopts.font.size
	local shadow  = self.frameopts.font.shadow
	if shadow == nil then shadow = self.baseopts.font.shadow end
	
	if outline == 2 then
		outline = "OUTLINE"
	elseif outline == 3 then
		outline = "THICKOUTLINE"
	else
		outline = nil
	end
	face = SharedMedia:Fetch( "font", face )
	
	self.chatbox:SetFont( face, size, outline )
	
	if shadow then
		self.chatbox:SetShadowColor( 0, 0, 0, 0.8 )
		self.chatbox:SetShadowOffset( 1, -1 )
	else
		self.chatbox:SetShadowColor( 0, 0, 0, 0 )
	end
	
	local tabsize = self.frameopts.tab_size or self.baseopts.tab_size
	
	self.chatbox:SetPoint( "LEFT", self, "LEFT", 2 + tabsize, 0 )
end

-------------------------------------------------------------------------------
-- Options for the title bar.
--
function Method:ApplyBarOptions()
	local o = self.frameopts.close_button
	if o == nil then o = self.baseopts.close_button end
	
	if not o then
		self.bar2.close_button:Hide()
		self.bar2.hidden_button:SetPoint( "TOPRIGHT", 0, 0 )
	else
		self.bar2.close_button:Show()
		self.bar2.hidden_button:SetPoint( "TOPRIGHT", -15, 0 )
	end
end

-------------------------------------------------------------------------------
-- Add chat events to the chat filter.
--
-- Channels are treated differently. To listen to a channel, prefix name
-- with #, e.g. "#secret"
--
function Method:AddEvents( ... )
	local arg = {...}
	local dirty = false
	
	for k,v in pairs(arg) do
		v = v:upper()
		if not self.listen_events[v] then
			self.listen_events[v] = true
			dirty = true
		end
	end
	
	if dirty then self:RefreshChat() end
end

-------------------------------------------------------------------------------
-- Remove chat events from display.
--
function Method:RemoveEvents( ... )
	local arg = {...}
	local dirty = false
	
	for k,v in pairs(arg) do
		v = v:upper()
		if self.listen_events[v] then
			self.listen_events[v] = nil
			dirty = true
		end
	end
	
	if dirty then self:RefreshChat() end
end

-------------------------------------------------------------------------------
-- Returns true if an event is being listened to.
--
function Method:HasEvent( event )
	if self.listen_events[event:upper()] then return true end
	return nil
end

-------------------------------------------------------------------------------
-- Returns true if this entry is displayed.
--
function Method:ShowsEntry( entry )
	return EntryFilter( self, entry )
end

-------------------------------------------------------------------------------
-- Returns the listen_events table.
-- This is a map of which events are being listened to.
-- Do not modify the returned table.
--
function Method:GetListenEvents()
	return self.listen_events
end	

-------------------------------------------------------------------------------
-- Add player to filter.
-- 
-- @param name   Name of player.
-- @param silent Do not print chat message.
function Method:AddPlayer( name, silent )
	AddOrRemovePlayer( self, name, 1, silent )
end

-------------------------------------------------------------------------------
function Method:RemovePlayer( name, silent )
	AddOrRemovePlayer( self, name, 0, silent )
end 

-------------------------------------------------------------------------------
-- Returns true if the window is listening to someone.
--
function Method:ListeningTo( name )
	-- filter path:
	-- global (listenall) -> group -> player
	--
	local f = self.players[name]
	
	if IsInRaid() then
		local g = Main.raid_groups[name]
		if g then
			-- if f is default then try using group filter
			f = f or self.groups[g]
		end
	end
	
	return f == 1 or (self.charopts.listen_all and f ~= 0)
end

function Method:ResetGroupsFilter()
	for k,_ in pairs( self.groups ) do
		self.groups[k] = nil
	end
end

-------------------------------------------------------------------------------
-- Toggle filter for player.
--
-- @param name   Player name.
-- @param silent Do not print chat message.
--
function Method:TogglePlayer( name, silent )
	name = Main.FixupName( name )
	if self.players[name] == 1 then
		self:RemovePlayer( name, silent )
	elseif self.players[name] == 0 then
		self:AddPlayer( name, silent )
	else
		if self.charopts.listen_all then
			self:RemovePlayer( name, silent )
		else
			self:AddPlayer( name, silent )
		end
	end
end

-------------------------------------------------------------------------------
-- Called when the window is active and the probe target changes.
--
function Method:UpdateProbe()
	if self.snooper then return end -- the snooper does not have this.

	local title = self.charopts.name
	if self.frame_index == 1 then title = "Listener" end
	local on = false
	
	local target, guid = Main:GetProbed()
	
	if target then
		
		on = self:ListeningTo( target )
		
		local name, shortname = LibRPNames.Get( target )
		title = Main.db.profile.shorten_names and shortname or name
		
	end
	
	self.bar2.title:SetText( title )
	
	if on or not target then
		self.bar2.title.text:SetAlpha( 1.0 )
	else
		self.bar2.title.text:SetAlpha( 0.5 )
	end
	
	if Main.db.profile.frame.color.tab_target[4] > 0 then
		self:UpdateHighlight()
	end
end

-------------------------------------------------------------------------------
-- Add a message directly to the chat window.
--
-- @param e    Message event data.
-- @param beep Enable playing a beep.
--
function Method:AddMessage( e, beep, from_refresh )
	if not EntryFilter( self, e ) then return false end
	
	if not self.refreshing then
		self.fade_time = GetTime()
	end
	
	local hidden = not self:ListeningTo( e.s )
	
	if hidden and not self.bar2.hidden_button:IsShown() and not self.snooper then
		self.bar2.hidden_button:Show()
	end
	
	if e.r and not e.p and not hidden then -- not read and not from the player and not hidden
		if self:IsShown() then
			if beep and not SKIP_BEEP[e.e] then
				if self.charopts.sound then
					Main.PlayMessageBeep( self.frameopts.notify_sound or self.baseopts.notify_sound )
				end
				
				if self.charopts.flash then
					Main.FlashClient()
				end
			end
		end
		
		if self.top_unread_id == nil then
			self.top_unread_id = e.id
		end
	end
	
	local color = GetEntryColor( e )
	
	self.chatbox:AddMessage( self:FormatChatMessage( e ), color[1], color[2], color[3], nil, nil, nil, e )
	
	-- autopopup/hideempty popup
	if not self:IsShown() and not from_refresh then
		if self.frameopts.auto_popup and not hidden then
			if self.frameopts.combathide and InCombatLockdown() then
				-- if we're in combat, just clear the hidden flag
				-- so that it opens when we exit combat
				self.charopts.hidden = false
				
				-- this causes the window to fade in after combat ends.
				self.fadein_after_combat = true 
			else
				self:Open()
			end
		end
		
		if self.frameopts.hideempty then
			self:UpdateShown()
		end
	end
	
	return true
end

-------------------------------------------------------------------------------
-- Add a message into the chat window if it passes our filters.
--
function Method:TryAddMessage( e, beep )
	if self.charopts.showhidden or self:ListeningTo( e.s ) then
		
		if self:AddMessage( e, beep ) then
			if self.chatbox:GetScrollOffset() == 0 then
				self:SetClickBlock()
			end
		end
		
	else
		if EntryFilter( self, e ) and not self.snooper then
			self.bar2.hidden_button:Show()
		end
	end
end

-------------------------------------------------------------------------------
function Method:CheckUnread()
	self.top_unread_id = nil
	local id = nil
	
	for k,v in pairs( Main.unread_entries ) do
		if EntryFilter( self, k ) and self:ListeningTo( k.s ) then
			if not id or k.id < id then
				id = k.id
			end
		end
	end
	
	self.top_unread_id = id
end

-------------------------------------------------------------------------------
-- Update the unread messages marker.
--
-- Sub function for UpdateHighlight.
--
-- @param region This is the fontstring that is showing the first unread
--               region
--
local function UpdateReadmark( self, region, first_id )

	-- todo: option for hiding readmark here.
	
	self.readmark:SetColorTexture( unpack( Main.db.profile.frame.color.readmark ) )
	if region then
		
		-- set the marker here
		local point = region:GetTop() - self.chatbox:GetBottom()
		if point > self.chatbox:GetHeight()+1  then 
			--point = self.chatbox:GetHeight() 
			--self.readmark:SetHeight( 2 )
			self.readmark:Hide()
			return
		else
			self.readmark:SetHeight( 1 )
		end
		self.readmark:SetPoint( "TOP", self.chatbox, "BOTTOM", 0, point )
		self.readmark:Show()
		
	elseif self.top_unread_id then
		
		if first_id < self.top_unread_id then
			-- past the bottom
			self.readmark:SetHeight( 2 )
			self.readmark:SetPoint( "TOP", self, "BOTTOM", 0, 3 )
		else
			-- past the top
			
			self.readmark:Hide()
			return
			--self.readmark:SetPoint( "TOP", self.chatbox, "BOTTOM", 0, self.chatbox:GetHeight() - 1 )
		end
		self.readmark:Show()
		
	else
		-- no unread messages
		self.readmark:Hide()
	end
	
end

-------------------------------------------------------------------------------
function Method:UpdateHighlight()
	if not Main.db then return end -- not initialized yet
	
	local regions = {}

	-- create a list of message regions
	for k,v in pairs( { self.chatbox.FontStringContainer:GetRegions() } ) do
		if v:GetObjectType() == "FontString" and v:IsShown() then
			v:SetNonSpaceWrap( true ) -- a nice hack for nonspacewrap text
			table.insert( regions, v )
		end
	end
	
	-- sort by Y
	table.sort( regions, function( a, b ) 
		return a:GetTop() < b:GetTop()
	end)
	
	local bottom = self.chatbox:GetNumMessages() - self.chatbox:GetScrollOffset()
	local index = bottom
	
	local top_edge = self.chatbox:GetTop() + 1 -- that one pixel
	
	local first_unread_region = nil
	--local first_unread_id     = 0
	
	local tabsize = self.frameopts.tab_size or self.baseopts.tab_size
					
	-- we'll build the pick_regions table in here too!
	local pick_regions = {}
	
	local count = 0
	
	for k,v in ipairs( regions ) do
		if index < 1 then break end
		
		local _,_,_,_,_,_,_,e = self.chatbox:GetMessageInfo( index )
		index = index - 1
		
		if not e then break end
		
		if v:GetBottom() < top_edge then -- within the chatbox only
		
			table.insert( pick_regions, { region = v, entry = e } )
		
			local hidden = not self:ListeningTo( e.s )
			v:SetAlpha( hidden and 0.35 or 1.0 )
			
			if e.id == self.top_unread_id then
				first_unread_region = v
			end
			
			local targeted = (Main.GetProbed() == e.s) and (Main.db.profile.frame.color.tab_target[4] > 0)

			if tabsize > 0 and ((targeted or e.p) and not self.snooper) or e.h then
				-- setup block
				count = count + 1
				if not self.tab_texes[count] then
					self.tab_texes[count] = self:CreateTexture() 
				end 
				local tex = self.tab_texes[count]
				
				tex:ClearAllPoints()
				tex:SetPoint( "LEFT", v, "LEFT", -1 - tabsize, 0 )
				tex:SetPoint( "RIGHT", v, "LEFT", -1, 0 )
				tex:SetPoint( "BOTTOM", v, "BOTTOM", 0, 0 )
				
				local clip = math.max( v:GetTop() - top_edge, 0 )
				
				tex:SetPoint( "TOP", v, "TOP", 0, -clip )
				tex:SetBlendMode( "BLEND" )
				if e.h then
					tex:SetColorTexture( unpack( Main.db.profile.frame.color.tab_marked ) )
				elseif e.p then
					tex:SetColorTexture( unpack( Main.db.profile.frame.color.tab_self ) )
				elseif targeted then
					tex:SetColorTexture( unpack( Main.db.profile.frame.color.tab_target ) )
				end
				tex:Show()	
			end
		end
	end
	
	self.pick_regions = pick_regions
	
	local _,_,_,_,_,_,_,e = self.chatbox:GetMessageInfo( bottom )
	if e and (self.baseopts.color.readmark[4] > 0) and self.frameopts.readmark then
		UpdateReadmark( self, first_unread_region, e.id )
	else
		self.readmark:Hide()
	end
	
	for i = count+1, #self.tab_texes do
		self.tab_texes[i]:Hide()
	end
end	

-------------------------------------------------------------------------------
function Method:UpdateShown()
	if self:IsShown() then
		if self.charopts.hidden 
		   or ((not self.combat_ignore) and self.frameopts.combathide and ((InCombatLockdown() or Main.in_combat))) 
		   or (self.chatbox:GetNumMessages() == 0 and self.frameopts.hideempty and not self.mouseon) then
		   
			self:Hide()
		end
	else
		if not self.charopts.hidden
		   and not ((not self.combat_ignore) and self.frameopts.combathide and (InCombatLockdown() or Main.in_combat)) 
		   and not (self.chatbox:GetNumMessages() == 0 and self.frameopts.hideempty) then
			self:Show()
		end
	end
end

-------------------------------------------------------------------------------
function Method:RefreshChat()
	self.refreshing = true
	self.chatbox:Clear()
	self:CheckUnread()
	
	if not self.snooper then
		local entries = {}
		
		local listen_all = self.charopts.listen_all
		local showhidden = self.charopts.showhidden
		local start_messages = self.frameopts.start_messages or self.baseopts.start_messages
		local hashidden = false
		
		-- go through the chat list and populate entries
		for i = Main.next_lineid-1, Main.first_lineid, -1 do
			local entry = Main.chatlist[i]
			if entry then
				if EntryFilter( self, entry ) then
					
					if showhidden or self:ListeningTo( entry.s ) then
						table.insert( entries, entry )
					else
						hashidden = true
					end
				end
			end
			
			-- break when we have enough messages
			if #entries >= start_messages then
				break
			end
		end
		
		if hashidden then
			self.bar2.hidden_button:Show()
		else
			self.bar2.hidden_button:Hide()
		end

		-- TODO: disable chatbox refreshes until this is done
		-- (check to see if its spammed.)
		for i = #entries, 1, -1 do
			self:AddMessage( entries[i], false, true )
		end
		
	else
		if self.snoop_player then
			local chat = Main.chat_history[self.snoop_player]
			
			if chat then
				local entries = {}
				local start_messages = self.frameopts.start_messages or self.baseopts.start_messages
				for i = #chat, 1, -1 do
					local e = chat[i]
					if EntryFilter( self, e ) then
						table.insert( entries, e )
					end
					if #entries >= start_messages then
						break
					end
				end
				
				for i = #entries, 1, -1 do
					self:AddMessage( entries[i], false, true )
				end
			end
		end
	end
	
	self:UpdateShown()
	self.refreshing = false
end

-------------------------------------------------------------------------------
-- Set the window colors.
-- 
-- @param bg, edge, bar Colors for the background, edge, and titlebar
--                      {r, g, b, a}, range = 0-1, pass nil to not change.
--
function Method:SetColors( bg, edge, bar )
	if bg then   self.frameopts.color.bg   = bg   end
	if edge then self.frameopts.color.edge = edge end
	if bar then  self.frameopts.color.bar  = bar  end
	self:ApplyColorOptions()
end

-------------------------------------------------------------------------------
-- Set Listen All mode. (default filter mode)
--
function Method:SetListenAll( listen_all )
	listen_all = not not listen_all
	if self.charopts.listen_all == listen_all then return end
	
	self.charopts.listen_all = listen_all
	
	self:RefreshChat()
	self:UpdateProbe()
end

-------------------------------------------------------------------------------
-- Enable/disable showing filtered out players.
--
function Method:ShowHidden( showhidden )
	
	showhidden = not not showhidden
	if self.charopts.showhidden == showhidden then return end
	self.charopts.showhidden = showhidden
	
	self:RefreshChat() 
	
	if showhidden then
		self.bar2.hidden_button:SetOn( true )
	else
		self.bar2.hidden_button:SetOn( false )
	end
end

-------------------------------------------------------------------------------
-- Update the visibility of the resize thumb.
--
function Method:UpdateResizeShow()
	if not self.frameopts.locked then
		self.resize_thumb:Show()
		return
	end
	
	if (self.mouseon and IsShiftKeyDown()) or self.doingSizing then
		self.resize_thumb:Show()
	else
		self.resize_thumb:Hide()
	end
end

-------------------------------------------------------------------------------
function Method:StartDragging()
	self.dragging = true
	self:StartMoving() 
end

-------------------------------------------------------------------------------
function Method:StopDragging()
	if self.dragging then
		self.dragging = false
		self:StopMovingOrSizing()
		SaveFrameLayout( self )
	end
end

-------------------------------------------------------------------------------
function Method:CombatHide( combat )
	-- the combat_ignore flag is set when the user toggles the frame on
	-- so that, if they're in combat, they can turn on the frame
	-- on manually, still, but the next time they enter combat
	-- it will be reset.
	if combat then
		self.combat_ignore = nil
	end
	
	self:UpdateShown()
	
	if not combat and self.fadein_after_combat then
		self.fade_time = GetTime()
	end
end

-------------------------------------------------------------------------------
function Method:OpenConfig()
	Main.FrameConfig_Open( self )
end

-------------------------------------------------------------------------------
function Method:CopyText()
	local text = ""
	
	for i = 1, self.chatbox:GetNumMessages() - self.chatbox:GetScrollOffset() do
		local msg = self.chatbox:GetMessageInfo( i )
		if text ~= "" then text = text .. "\n" end
		text = text .. msg
	end
	
	-- filter out some things (icons)
	text = text:gsub( "|T.-|t%s*", "" )
	
	Main.CopyFrame.Show( text )
end

-------------------------------------------------------------------------------
function Method:MouseOn()
	self.mouseon = true
	self:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Method:MouseOff()
	self.mouseon = false
	C_Timer.After( 0.1, function()
		self:UpdateShown()
		self:UpdateResizeShow()
	end)
end

-------------------------------------------------------------------------------
function Method:OnModifierPressed()
	UpdateMouseLock( self )
end

-------------------------------------------------------------------------------
-- Handlers (And psuedo ones.)
-------------------------------------------------------------------------------
function Me.OnLoad( self )
	-- populate with methods
	for k,v in pairs( Method ) do
		self[k] = v
	end
	
	SetupMembers( self )
	
	-- initial settings
	self.chatbox:SetMaxLines( CHAT_BUFFER_SIZE )
	self:EnableMouse( true )
	self:SetClampedToScreen( true )
	Me.CraftEdges( self, 2 )
	
	hooksecurefunc( self.chatbox, "RefreshDisplay", function()
		Me.OnChatboxRefresh( self )
	end)
end

-------------------------------------------------------------------------------
function Me.OnEnter( self )
	self:MouseOn()
	self.show_highlight = true
end

-------------------------------------------------------------------------------
function Me.OnLeave( self )
	self:MouseOff()
	self.show_highlight = false
end

-------------------------------------------------------------------------------
local function DoPainting( self, pid )
	if not self.painting then return end
	
	local step = 1
	if pid < self.painting_id then
		step = -1
	end
	
	local showhidden = self.charopts.showhidden
	
	local found = false
	for id = self.painting_id, pid, step do
		local e = Main.chatlist[id]
		if e and e.h ~= self.painting_on 
		   and EntryFilter( self, e )
		   and (showhidden or self:ListeningTo( e.s )) then
			found = true
			Main.HighlightEntry( e, self.painting_on )
		end
	end
	
	self.painting_id = pid
end

-------------------------------------------------------------------------------
function Me.OnUpdate( self )
	self:UpdateVisibility()
	
	local picked = nil
	
	if (self.show_highlight or self.painting) then
		-- do some picking
		picked = PickTextRegion( self, true )
		
		if self.painting and GetTime() > self.clickblock + CLICKBLOCK_TIME then
			if picked and picked.entry  then
				DoPainting( self, picked.entry.id )
			else
				local x,y = GetCursorPosition()
				local scale = UIParent:GetEffectiveScale()
				x = x / scale
				y = y / scale
				if x >= self.chatbox:GetLeft() and x <= self.chatbox:GetRight() then
					local p
					local top = self.pick_regions[#self.pick_regions]
					if top then top = top.region:GetTop() end
					
					if y <= self.chatbox:GetBottom() then
						p = self.pick_regions[1]
					elseif y >= top then
						p = self.pick_regions[#self.pick_regions]
					end
					
					if p and p.entry then
						DoPainting( self, p.entry.id )
					end
				end
			end
		
		end
	else
		if self.chatbox.highlight:IsShown() then
			self.chatbox.highlight:Hide()
		end
	end
end

-------------------------------------------------------------------------------
function Me.OnMouseDown( self, button )
	local active = Main.active_frame == self
	
--	if not active and not self.snooper then
--		Main.SetActiveFrame( self )
--	end
	
	local faded = false

	if self.auto_fade > 0 and GetTime() > self.fade_time + self.auto_fade then
		faded = true
	end
	
	if GetTime() > self.clickblock + CLICKBLOCK_TIME then
		local p = PickTextRegion( self, false )
		if p then
		
			local tabsize = self.frameopts.tab_size or self.baseopts.tab_size
			
			if button == "LeftButton" and tabsize > 0 then
				self.painting    = true
				self.painting_on = not p.entry.h
				if not self.painting_on then self.painting_on = nil end
				self.painting_id = p.entry.id
				
				Main.HighlightEntry( p.entry, not p.entry.h )
			elseif button == "RightButton" then
				if IsShiftKeyDown() and not self.snooper then
					PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
					self:TogglePlayer( p.entry.s, true )
				end
			end
		end
	end
	
	self.fade_time = GetTime()
end

-------------------------------------------------------------------------------
function Me.OnMouseUp( self )
	self.painting = false
end

-------------------------------------------------------------------------------
-- For scrollwheel.
--
function Me.OnChatboxScroll( self, delta )
	
	local reps = IsShiftKeyDown() and 5 or 1
	
	-- for the snooper, shift is used to activate the mouse sometimes
	-- if so, ignore the shift modifier in here.
	-- for normal windows, mouse wheel always works, so functionality is normal
	if self.snooper and self.frameopts.shift_mouse then
		reps = 1
	end
	
	if delta > 0 then
		if IsAltKeyDown() then
			self.chatbox:ScrollToTop()
		elseif IsControlKeyDown() then
			AdjustFontSize( self, 1 )
		else
			for i = 1, reps do self.chatbox:ScrollUp() end
		end
	else
		if IsAltKeyDown() then
			self.chatbox:ScrollToBottom()
		elseif IsControlKeyDown() then
			AdjustFontSize( self, -1 )
		else
			for i = 1,reps do self.chatbox:ScrollDown() end
		end
	end
	
	self.fade_time = GetTime()
end

-------------------------------------------------------------------------------
local g_listener_copylink_text = ""
StaticPopupDialogs["LISTENER_COPYLINK"] = {
	text                   = L["Copy Link"];
	button1                = L["Got it!"];
	timeout                = 0,
	whileDead              = true,
	hideOnEscape           = true,
	enterClicksFirstButton = true,
	hasEditBox             = true,
	
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end;
	EditBoxOnEnterPressed = function(self, data)
		self:GetParent():Hide();
	end;
	OnShow = function ( self )
		self.editBox:SetMaxLetters( 0 )
		self.editBox:SetText( g_listener_copylink_text )
		self.editBox:HighlightText()
	end
}

-------------------------------------------------------------------------------
function Me.OnChatboxHyperlinkClick( self, link, text, button )
	if GetTime() < self.clickblock + CLICKBLOCK_TIME then
		-- block clicks when scroll changes
		return
	end
	
	if strsub(link, 1, 6) == "player" then
		local namelink, isGMLink;
		if strsub(link, 7, 8) == "GM" then
			namelink = strsub(link, 10);
			isGMLink = true;
		else
			namelink = strsub(link, 8);
		end
		
		local name, lineid, chatType, chatTarget = strsplit(":", namelink);
		
		if IsShiftKeyDown() and button == "RightButton" and not self.snooper then
			PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
			self:TogglePlayer( name, true )
			return
		end
	end
	
	if link == "lrurl" then
		g_listener_copylink_text = text:match( "url|h(%S+)|h|r$" )
		StaticPopup_Show( "LISTENER_COPYLINK" )
		return
	end
	
	SetItemRef( link, text, button, DEFAULT_CHAT_FRAME );
	
	self.fade_time = GetTime()
end

-------------------------------------------------------------------------------
function Me.OnChatboxRefresh( self )
	-- show or hide the scroll marker if we are scrolled up
	if self.chatbox:GetScrollOffset() ~= 0 then
		self.scrollmark:Show()
	else
		self.scrollmark:Hide()
	end

	-- this should only be called when the scroll actually changes
	
	self:UpdateHighlight()
end

-------------------------------------------------------------------------------
function Me.TogglePlayerClicked( self, button )
	if button == "LeftButton" then
		
		-- shift-click for normal windows toggles listen_all
		-- snooper doesn't have that feature
		if IsShiftKeyDown() and not self.snooper then
			PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
			self:SetListenAll( not self.charopts.listen_all )
		else
			-- if you aren't targeting anyone, then left click
			-- opens the menu, otherwise it toggles the player
			--
			local name = Main.GetProbed()
			if name and not self.snooper then
				PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
				self:TogglePlayer( name, true )
			else
				if self.snooper then
					Main.Snoop2.ShowMenu()
				else
					self:ShowMenu()
				end
			end
		end
	elseif button == "RightButton" then
		if self.snooper then
			Main.Snoop2.ShowMenu()
		else
			self:ShowMenu()
		end
	end
end

-------------------------------------------------------------------------------
function Me.ShowHiddenClicked( self, button )
	if button == "LeftButton" then
		PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
		self:ShowHidden( not self.charopts.showhidden )
	end
end

-------------------------------------------------------------------------------
function Me.CloseClicked( self, button )
	if button == "LeftButton" then
		PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
		self:Close()
	end
end

-------------------------------------------------------------------------------
function Me.BarMouseDown( self )
	self.fade_time = GetTime()
	
	if not self.snooper then
		Main.SelectFrame( self )
	end
	
	if (not self.frameopts.locked) or IsShiftKeyDown() then
		self:StartDragging()
	end
end

function Me.BarMouseUp( self ) 
	self:StopDragging()
	self.fade_time = GetTime()
end

function Me.BarDragStart( self )
	
end

function Me.BarDragStop( self )
	
end

-------------------------------------------------------------------------------
-- resize_thumb handlers.
-------------------------------------------------------------------------------
function Me.ResizeThumb_OnMouseDown( self, button )
	self:SetButtonState( "PUSHED", true ); 
	self:GetHighlightTexture():Hide();
	self:GetParent():StartSizing( "BOTTOMRIGHT" );
	self:GetParent().doingSizing = true
end

-------------------------------------------------------------------------------
function Me.ResizeThumb_OnMouseUp( self, button )
	
	self:SetButtonState( "NORMAL", false );
	self:GetHighlightTexture():Show();
	local parent = self:GetParent()
	parent:StopMovingOrSizing();
	SaveFrameLayout( parent )
	parent.doingSizing = false
	parent:UpdateResizeShow()
end

-------------------------------------------------------------------------------
function Me.ResizeThumb_OnLeave( self )

end

-------------------------------------------------------------------------------
-- Other static functions
-------------------------------------------------------------------------------

function Me.CraftEdges( frame, width )
	if not frame.edges then
		frame.edges = {}
		for i = 1,4 do frame.edges[i] = frame:CreateTexture( "BORDER" ) end
	end
	
	-- top
	frame.edges[1]:SetPoint( "TOPLEFT",     frame, "TOPLEFT",  -width, width )
	frame.edges[1]:SetPoint( "BOTTOMRIGHT", frame, "TOPRIGHT",  width, 0 )
	-- bottom
	frame.edges[2]:SetPoint( "TOPLEFT",     frame, "BOTTOMLEFT",  -width, 0 )
	frame.edges[2]:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT",  width, -width )
	-- left
	frame.edges[3]:SetPoint( "TOPLEFT",     frame, "TOPLEFT",    -width, 0 )
	frame.edges[3]:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMLEFT", -0,     0 )
	-- right
	frame.edges[4]:SetPoint( "TOPLEFT",     frame, "TOPRIGHT",     0,     0 )
	frame.edges[4]:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT",  width, 0 )
	
	for _, edge in pairs( frame.edges ) do
		edge:Show()
	end
end

-------------------------------------------------------------------------------
-- Initialize a section in the database for a new frame
--
function Me.InitOptions( index )
	-- only initialize things that are per-character options
	-- don't initialize things that you don't want in the
	-- primary frame's options
	
	if not Main.db.char.frames[index] then
		-- initial creation.
		Main.db.char.frames[index] = {
			players    = {};
			groups     = {};
			listen_all = true;
			filter     = {}; -- filled in below
			showhidden = true;
			layout     = {
				anchor   = {};
				width    = 200;
				height   = 300;
			};
			hidden       = false;
			color        = {};
			font         = {};
			readmark     = true;
			enable_mouse = true;
		}
		for k,v in pairs( DEFAULT_LISTEN_EVENTS ) do
			Main.db.char.frames[index].filter[v] = true
		end
	end
	
	-- we also want to make sure that all tables are there so errors don't happen
	local data = Main.db.char.frames[index]
	data.players = data.players or {}
	data.groups  = data.groups or {}
	data.filter  = data.filter or {}
	data.layout  = data.layout or {
		anchor        = {};
		width         = 200;
		height        = 300;
	}
	data.color = data.color or {}
	data.font  = data.font or {}
	
	-- we might want to make an option for this.
	data.players[ UnitName("player") ] = 1
	data.players[ "Guild" ] = 1
end

-------------------------------------------------------------------------------
-- Apply the globally set options (ones that affect all frames, like the
-- titlebar font).
--
function Me.ApplyGlobalOptions()
	
	-- bar font
	local font = SharedMedia:Fetch( "font", Main.db.profile.frame.barfont.face )
	ListenerBarFont:SetFont( font, Main.db.profile.frame.barfont.size )
	
end
