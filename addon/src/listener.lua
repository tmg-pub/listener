-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2018)
--
-- This is the center that links everything together and is otherwise
-- cluttered with anything that isn't stuffed into a module.
-------------------------------------------------------------------------------
 
local Main        = ListenerAddon
local L           = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
-- The max number of frames that are allowed to be created.
--
local MAX_FRAMES          = 50 -- hell YEAH lool

-------------------------------------------------------------------------------
-- The time the addon was loaded. This is mainly for the friend list loader.
--
local g_loadtime          = 0

-------------------------------------------------------------------------------
-- This is the grace period for message to stay unread when marking all
-- messages as read. e.g. if a message is newer than this, then that
-- function will skip it.
--
local NEW_MESSAGE_HOLD    = 3
                             
-------------------------------------------------------------------------------
-- Channels that are ignored and not logged.
--
local IGNORED_CHANNELS = {
	xtensionxtooltip2 = true -- Common addon channel.
}

-------------------------------------------------------------------------------
-- The following is some serious mojo to convert localized strings into
-- matching patterns. A feeble attempt at providing message recognition that
-- works on any client.
--
-- For roll results... English is "%s rolls %d (%d-%d)"
local SYSTEM_ROLL_PATTERN = RANDOM_ROLL_RESULT 

-- Convert to a pattern.
SYSTEM_ROLL_PATTERN = SYSTEM_ROLL_PATTERN:gsub( "%%%d?$?s", "(%%S+)" )
SYSTEM_ROLL_PATTERN = SYSTEM_ROLL_PATTERN:gsub( "%%%d?$?d", "(%%d+)" )
SYSTEM_ROLL_PATTERN = SYSTEM_ROLL_PATTERN:gsub( "%(%(%%%d?$?d%+%)%-%(%%%d?$?d%+%)%)", "%%((%%d+)%%-(%%d+)%%)" ) -- this is what we call voodoo?

-- English is "|Hplayer:%s|h[%s]|h has come online."
local SYSTEM_ONLINE_PATTERN = ERR_FRIEND_ONLINE_SS
SYSTEM_ONLINE_PATTERN = SYSTEM_ONLINE_PATTERN:gsub( "|Hplayer:%%s|h%[%%s%]|h", "|Hplayer:([^|]+)|h%%[[^%%]]+%%]|h" )
SYSTEM_ONLINE_PATTERN = SYSTEM_ONLINE_PATTERN:gsub( "%.", "%%." )

-- English is "%s has gone offline."
local SYSTEM_OFFLINE_PATTERN = ERR_FRIEND_OFFLINE_S
SYSTEM_OFFLINE_PATTERN = SYSTEM_OFFLINE_PATTERN:gsub( "%%s", "(%%S+)" )
SYSTEM_OFFLINE_PATTERN = SYSTEM_OFFLINE_PATTERN:gsub( "%.", "%%." )

-------------------------------------------------------------------------------
-- Here's the layout of the chat history database.
-- Main.chat_history = {
--     [playername] = {
--         [max_messages] = {  -- previous message history
--             id = line id
--             t = time received (unixtime)
--             e = event type
--             m = message
--             r = message has not been read
--             s = sender
--         }
--     }
-- }
-- Main.chatlist = { -- list of chat messages
--     [lineid] = event reference
-- }
-------------------------------------------------------------------------------

-------------------------------------------------------------------------------
-- This table is indexed by tables (chat entries).
-- Anything in here is an unread message (e.r=true)
--
Main.unread_entries = {}

-------------------------------------------------------------------------------
-- A simple helper function to see if unread_entries has anything in it.
--
function Main.HasUnreadEntries()
	for _,_ in pairs( Main.unread_entries ) do return true end
end

-------------------------------------------------------------------------------
-- The realm the player is on, for building player-realm strings.
-- This actually isn't safe here, and it's refetched after the addon is loaded.
--
Main.realm          = select( 2, UnitFullName("player") )

-------------------------------------------------------------------------------
-- The first lineid in the chat history. This is 1 after the first load or
-- after everything is cleared from the chat history (after a long logout)
-- But otherwise the chat history is sort of like an endless buffer,
-- so this marks the start of it so that code doesn't have to iterate all
-- the way to 1 and waste time because there are no entries before this.
--
Main.first_lineid   = 1

-------------------------------------------------------------------------------
-- Where the next chat history entry can be written to.
--
Main.next_lineid    = 1

-------------------------------------------------------------------------------
-- This is the list of listener windows.
-- Frame 1 is the main frame.
-- Frame 2 is the snooper.
-- Frames 3+ are custom frames.
--
Main.frames         = {}

-------------------------------------------------------------------------------
-- The currently active frame.
--
-- This should never be nil once everything is setup.
--
Main.active_frame   = nil

-------------------------------------------------------------------------------
-- Called by Ace3, not used for anything right now.
function Main:OnInitialize() 
	
end

-------------------------------------------------------------------------------
-- This function cleans up the chat history. Done on load or reload.
--
-- Any chat entries that are deemed "old" are removed. If all chat history
-- is removed for a player, then the filter for that player is reset.
-- (And that part is done by CleanPlayerList)
--
local function CleanChatHistory()
	ListenerChatHistory = ListenerChatHistory or {}
	Main.chatlist = {}
	
	if ListenerChatHistory.version ~= Main.version then
		-- old version, drop history
		ListenerChatHistory = { 
			version = Main.version;
			data    = {};
		}
		Main.chat_history = ListenerChatHistory.data
		return
	end
	
	Main.chat_history = ListenerChatHistory.data
	
	local time = time()
	local expiry = 60*30 -- 30 mins
	
	-- we want to find the highest lineid so we can continue
	-- (it should reset overnight! :)
	local max_lineid = 0
	local min_lineid = nil
	
	for playername,chat_table in pairs( ListenerChatHistory.data ) do
		local writeto = 1
		
		for i = 1, #chat_table do
			if chat_table[i] then
				chat_table[i].r = nil
				
				if time > chat_table[i].t + expiry 
				   or chat_table[i].e == "GUILD_MOTD" then -- discard motd events.
					chat_table[i] = nil
				else
					local a = chat_table[i]
					chat_table[i] = nil
					chat_table[writeto] = a
					max_lineid = math.max( a.id, max_lineid )
					min_lineid = math.min( a.id, min_lineid or a.id )
					writeto = writeto + 1
					
					-- todo: should squish chat ids somewhere 
					-- because that could get pretty high and kill refresh performance
					
					Main.chatlist[ a.id ] = a
				end
			end
		end
		 
		-- if the list is empty, delete the player from the history
		if #chat_table == 0 then
			Main.chat_history[playername] = nil 
		end
	end
	
	Main.first_lineid = min_lineid or max_lineid
	Main.next_lineid = max_lineid + 1
end

-------------------------------------------------------------------------------
-- Reset player filters with no chat history.
--
-- This is to be called BEFORE the frames are created.
--
local function CleanPlayerList()

	for index, frame in pairs( Main.db.char.frames ) do
		for k,v in pairs( frame.players ) do
			if not Main.chat_history[k] then
				frame.players[k] = nil
			end
		end
		
		if index == 1 then
			frame.players[UnitName("player")] = 1
		end
	end
end

-------------------------------------------------------------------------------
-- Scan friends list and add them to MAIN's filter.
--
local function AddFriendsList()
	for i = 1, C_FriendList.GetNumFriends() do
		local name = C_FriendList.GetFriendInfo( i )
		
		-- name may or may not be a localized string. /shrug
		
		if name and name ~= UNKNOWN then
			Main.frames[1].players[name] = 1
		end
	end
end

-------------------------------------------------------------------------------
-- Hook the GameTooltip to a frame and prepare it for adding text.
--
function Main.StartTooltip( frame )
	-- Section the screen into 6 sextants and define the tooltip 
	-- anchor position based on which sextant the cursor is in.
	-- Code taken from WeakAuras.
	--
    local max_x = 768 * GetMonitorAspectRatio()
    local max_y = 768
    local x, y = GetCursorPosition()
	
    local horizontal = (x < (max_x/3) and "LEFT") or ((x >= (max_x/3) and x < ((max_x/3)*2)) and "") or "RIGHT"
    local tooltip_vertical = (y < (max_y/2) and "BOTTOM") or "TOP"
    local anchor_vertical = (y < (max_y/2) and "TOP") or "BOTTOM"
    GameTooltip:SetOwner( frame, "ANCHOR_NONE" )
    GameTooltip:SetPoint( tooltip_vertical..horizontal, frame, anchor_vertical..horizontal )
	GameTooltip:ClearLines()
end

-- The tooltip functions here are no longer used. To be repurposed later
-- if they are required again.
--[[

-------------------------------------------------------------------------------
local function FrameTooltip_Start( self )
	Main.StartTooltip( self )
	self.tooltip_func( self )
	GameTooltip:Show()
end

-------------------------------------------------------------------------------
local function FrameTooltip_End()
	GameTooltip:Hide()
end

-------------------------------------------------------------------------------
local function FrameTooltip_Refresh( self )
	if GameTooltip:GetOwner() == self and GameTooltip:IsShown() then
		GameTooltip:ClearLines()
		self.tooltip_func( self )
		GameTooltip:Show()
	end
end

-------------------------------------------------------------------------------
function Main:SetupTooltip( frame, func )
	frame.tooltip_func = func
	frame:SetScript( "OnEnter", FrameTooltip_Start )
	frame:SetScript( "OnLeave", FrameTooltip_End ) 
	frame.RefreshTooltip = FrameTooltip_Refresh
end	
--]]

-------------------------------------------------------------------------------
-- Setup function for setting the localized strings for the key bindings text.
--
function Main.SetupBindingText()
	_G["BINDING_NAME_LISTENER_TOGGLEFILTER"] = L["Toggle Player Filter"]
	_G["BINDING_NAME_LISTENER_MARKUNREAD"]   = L["Mark Messages as Read"]
	_G["BINDING_HEADER_LISTENER"]            = L["Listener"]
end

-------------------------------------------------------------------------------
-- Callback for when a keyboard modifier changes.
--
function Main:OnModifierChanged( evt, key, state )

	if key == "LSHIFT" or key == "RSHIFT" then
	
		for _, frame in pairs( Main.frames ) do
			frame:OnModifierPressed()
			frame:UpdateResizeShow()
		end
		
		-- allow/disable dragging
		if IsShiftKeyDown() then
		
		else
			for _, frame in pairs( Main.frames ) do
				frame:StopDragging()
			end
		end
		
		Main.Snoop2.UpdateMouseLock()
	end
end

-------------------------------------------------------------------------------
-- FRIENDLIST_UPDATE event.
--
function Main:OnFriendlistUpdate()
	-- if this event occurs 30 seconds within load time, then we
	-- wanna update our initial friends list adding
	if GetTime() - g_loadtime < 30 then
		AddFriendsList()
		if Main.frames[1] then
			Main.frames[1]:RefreshChat()
		end
	end
	
end

-------------------------------------------------------------------------------
-- Flash the taskbar icon, if this feature is enabled in the settings.
--
function Main:FlashClient()
	--if Main.db.profile.flashclient then
	FlashClientIcon()
	--end
end

-------------------------------------------------------------------------------
-- Play the message beep.
--
local g_message_beep_cd = 0
function Main.PlayMessageBeep( sound )

	-- we want to only play a beep if a beep hasn't tried to play in the last X seconds
	-- in other words, if there is a constant stream of spam, no beeps will play
	--
	-- we moved the flash client bit outside so that if someone is tabbed out
	-- they arent going to miss a message because of this
	--
	if GetTime() < g_message_beep_cd + Main.db.profile.beeptime then
		g_message_beep_cd = GetTime()
		return
	end
	
	g_message_beep_cd = GetTime()
	Main.Sound.Play( "messages", 5, sound )
end

function Main.SetMessageBeepCD()
	g_message_beep_cd = GetTime()
end

-------------------------------------------------------------------------------
-- Check if someone has used a text emote on us and then act accordingly.
-- 
-- @param msg    Contents of text emote.
-- @param sender Sender of the event. If this matches the targeted unit, then
--               we ignore it. (Because the player is already paying attention
--               to them.)
--
function Main.CheckPoke( msg, sender )
	if not Main.db.profile.notify_poke_sound and not Main.db.profile.notify_poke_flash then return end
	
	local loc = GetLocale()
	if loc == "enUS" then
		-- Currently only supporting english.
		if msg:find( " you" ) then
			if Main.FullName('target') == sender then return end
			
			-- There are a handful of emotes that contain " you" regardless
			-- of who they're targeting. We filter those out.
			
			if msg:find( "orders you to open fire."   ) then return end
			if msg:find( "asks you to wait."          ) then return end
			if msg:find( "tells you to attack"        ) then return end
			if msg:find( "motions for you to follow." ) then return end
			if msg:find( "looks at you with crossed eyes." ) then return end
			
			if Main.db.profile.notify_poke_sound then
				Main.SetMessageBeepCD()
				Main.Sound.Play( "messages", 10, Main.db.profile.notify_poke_file )
			end
			
			if Main.db.profile.notify_poke_flash then
				Main.FlashClient()
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Hook for DiceMaster4 roll messages.
--
function Main:OnDiceMasterRoll( event, sender, message )
	Main.AddChatHistory( sender, "ROLL", message )
end

-------------------------------------------------------------------------------
-- Hook for system messages. (CHAT_MSG_SYSTEM)
--
function Main:OnSystemMsg( event, message )

	do
		-- check our special patterns to split this event
		-- into sub events
		local sender = message:match( SYSTEM_ONLINE_PATTERN )
		if sender then
			Main.AddChatHistory( sender, "ONLINE", L["has come online."] )
			return
		end
		
		local sender = message:match( SYSTEM_OFFLINE_PATTERN ) 
		if sender then
			Main.AddChatHistory( sender, "OFFLINE", L["has gone offline."] )
			return
		end
	end

	if not DiceMaster4 then
		-- skip this if theyre using dicemaster
		-- and we just listen for dicemaster's roll events.
		local sender, roll, min, max = message:match( SYSTEM_ROLL_PATTERN )
		
		if sender then
			-- this is a roll message
			Main.AddChatHistory( sender, "ROLL", message )
			return
		end
	end
end

-------------------------------------------------------------------------------
-- Hook for when the guild MOTD changes.
--
function Main:OnGuildMOTD( event, message )
	Main.AddChatHistory( "Guild", "GUILD_MOTD", message )
end

-------------------------------------------------------------------------------
-- Hook for CHAT_MSG_TEXT_EMOTE.
--
-- This is handled a little bit specially from a normal chat message event.
--
-- First of all, for some dumb reason the sender doesn't contain the player's
-- realm, so we have to search for that in the actual text.
--
-- Secondly, we call our poke detection in here.
--
function Main:OnChatMsgTextEmote( event, message, sender, language, 
                                  a4, a5, a6, a7, a8, a9, a10, a11, 
								  guid, a13, a14 )
								  
	if guid ~= UnitGUID( "player" ) then
		local realm = message:match( sender .. "%-([A-Za-z0-9']+)" )
		if realm ~= nil then
			-- delete trailing "'s"
			realm = realm:gsub( "'s$", "" )
			
			sender = sender .. "-" .. realm
		end
	end
	
	-- something to consider is that chat event filters might
	-- remove this message, for whatever reason, and it might still
	-- make a poke sound.
	if guid ~= UnitGUID( "player" ) then
		Main.CheckPoke( message, sender )
	end
	
	-- and then when that's all good and done, we forward it to the normal
	-- chat routines.
	Main:OnChatMsg( event, message, sender, language, 
	                a4, a5, a6, a7, a8, a9, a10, a11, guid, a13, a14 )
		
end

function Main:OnChatMsgClub( event, message, sender, language, channelName, sender2, specialFlags, zoneChannelID,
                             channelIndex, channelBaseName, _, lineID, guid, bnSenderID, ... )
	if not guid then
		-- this is a bnet message
		-- we use format "@name" for bnet messages
		-- this can be ambiguous with people using same name
		sender = "@" .. sender
		if BNIsSelf( bnSenderID ) then
			sender = sender .. "-self"
		end
		return -- Bnet communities not supported yet
	end
	
	-- community channel format is "#clubid:streamid"
	local club,stream = channelName:match( "Community:(%d+):(%d+)" )
	if not club then
		-- we don't know how to handle this message
		return
	end
	
	-- we pretend its a CHANNEL message, because that makes things simpler underneath
	event = "CHAT_MSG_CHANNEL"
	channelName = "Community:" .. club .. ":" .. stream
	
	if C_Club.GetStreamInfo( club, stream ).name == "#RELAY#" then
		-- RP Link relay
		return
	end
	

	Main:OnChatMsg( event, message, sender, language, channelName, sender2, specialFlags, zoneChannelID, channelIndex, channelName, nil, lineID, guid, bnSenderID, ... )
end

  
-------------------------------------------------------------------------------
-- The main chat event handler.
--
function Main:OnChatMsg( event, message, sender, language, a4, a5, a6, a7, a8, 
                         a9, a10, a11, guid, a13, a14 )
						 
	if sender == "" then return end
	
	local filters = ChatFrame_GetMessageEventFilters( event )
	event = event:sub( 10 )
	
	if event:find( "CHANNEL" ) and IGNORED_CHANNELS[a9:lower()] then
		-- this channel is ignored and not logged.
		return
	end	
	
	if filters then -- in a rare case with very little addons, the filter
	                -- list may actually be nil
					
		local skipfilters = false

		if message:sub(1,3) == "|| " then
			-- trp hack for npc emotes
			skipfilters = true
		elseif message:sub(1,2) == "'s" and event == "EMOTE" then
			-- trp hack for 's stuff
		--	skipfilters = true
		end
		
		if not skipfilters then
			for _, filterFunc in next, filters do
				local block, na1, na2, na3, na4, na5, na6, na7, na8, na9, na10, na11, na12, na13, na14 = filterFunc( ListenerFrameChat, "CHAT_MSG_"..event, message, sender, language, a4, a5, a6, a7, a8, a9, a10, a11, guid, a13, a14 )
				if( block ) then
					return
				elseif( na1 and type(na1) == "string" ) then
					local skip = false
					if event == "EMOTE" and message:sub(1,2) == "'s" and na1:sub(1,2) ~= "'s" then
						skip = true -- block out trp's ['s] hack
					end
					if event == "EMOTE" and message:sub(1,2) == ", " and na1:sub(1,2) ~= ", " then
						skip = true -- block out trp's [, ] hack
					end
					  
					if not skip then
						message, sender, language, a4, a5, a6, a7, a8, a9, a10, a11, guid, a13, a14 = na1, na2, na3, na4, na5, na6, na7, na8, na9, na10, na11, na12, na13, na14
					end
				end
			end
		end
	end
	
	Main.AddChatHistory( sender, event, message, language, guid, a9 )
end

-------------------------------------------------------------------------------
-- Hook for when entering combat. PLAYER_REGEN_DISABLED
--
function Main:OnEnterCombat()
	Main.in_combat = true
	for _, frame in pairs(Main.frames) do
		frame:CombatHide( true )
	end
end

-------------------------------------------------------------------------------
-- Hook for exiting combat. PLAYER_REGEN_ENABLED
--
function Main:OnLeaveCombat()
	Main.in_combat = false
	for _, frame in pairs( Main.frames ) do
		frame:CombatHide( false )
	end
end

-------------------------------------------------------------------------------
-- Entries in here will be substituted by textures.
--
-- e.g. {circle} or {rt2} will become a texture code for circle.
--
local RAID_TARGETS = { 
	star     = 1; rt1 = 1; yellow = 1;
	circle   = 2; rt2 = 2; orange = 2;
	diamond  = 3; rt3 = 3; purple = 3;
	triangle = 4; rt4 = 4; green  = 4;
	moon     = 5; rt5 = 5; silver = 5;
	square   = 6; rt6 = 6; blue   = 6;
	x        = 7; rt7 = 7; red    = 7; cross = 7; 
	skull    = 8; rt8 = 8; white  = 8;
}

-------------------------------------------------------------------------------
-- Substitute raid target keywords with textures.
--
local function SubRaidTargets( message )
	message = message:gsub( "{(%S-)}", function( term )
		term = term:lower()
		local t = RAID_TARGETS[term]
		if t then
			return "|TInterface/TargetingFrame/UI-RaidTargetingIcon_" .. t .. ":0|t"
		end 
	end)
	return message
end

-------------------------------------------------------------------------------
-- Language Filter routine.
--
-- The language filter is an experimental (and hidden) feature that filters
-- out player text when they are speaking a language that you "don't know".
--
-- @param message  Message to process.
-- @param sender   Name of sender.
-- @param event    Chat event type, e.g. "SAY"
-- @param language Language the message is in (for /say messages)
--
local function LanguageFilter( message, sender, event, language )
	local langdef = language -- langdef is language or default language
	if not langdef or langdef == "" then langdef = GetDefaultLanguage() end
	
	if Main.LanguageFilter.known[langdef] then
		-- mark this sender as understandable, they've spoken in our languages
		Main.LanguageFilter.emotes[sender] = true
		
		-- maybe we should reset this if they again speak in a language
		-- that we don't know..?
	end
	
	if event == "SAY" and not Main.LanguageFilter.known[langdef] then
		-- feature to block out unknown languages
		 
		local oocmarks = { "{{", "}}", "%[%[", "%]%]", "%(%(", "%)" }
		local ooc = false
		
		for k,v in pairs(oocmarks) do
			if message:find( v ) then ooc = true break end
		end
		
		if not ooc then
		
			if message:sub(1,1) == '"' then
				message = message:gsub( [[".-[-,.?~]"]], '"<' .. langdef .. '>"' )
			else
				message = "<" .. langdef .. ">"
			end
		end
	end
	
	if event == "EMOTE" and not Main.LanguageFilter.emotes[sender] then
		-- cut out speech from unknown emotes
		message = message:gsub( [[".-[-,.?~]"]], '"<' .. langdef .. '>"' )
	end
	
	return message
end

-------------------------------------------------------------------------------
-- Returns the full name for a unit. Full name in this case is just the
-- ingame name if they are on the same realm, or name-realm if they are
-- on a different realm.
--
function Main.FullName( unit )
	local n, r = UnitName( unit )
	if r and r ~= "" then return n .. "-" .. r end
	return n
end

-------------------------------------------------------------------------------
-- Substitute URLs found within a message with hyperlink codes.
--
local function Linkify( msg )
	msg = " " .. msg .. " "
	
	local linkified = " |cFF0FBEF4|Hlrurl|h%1|h|r "
	local links = {}
	
	local function getlink(a,b,c)
		table.insert( links, b )
		return a .. "\001" .. #links .. "\001" .. c
	end
	
	local subs
	
	for limiter = 1,10 do
	
		-- http://abc.com/aaa
		-- we also handle if its wrapped in ()
		msg,subs = msg:gsub( "([%s%(])(https?://[^%)%s]+)([%s%)])", getlink )
		
		if subs == 0 then
			-- abc.me/aaa
			msg,subs = msg:gsub( "([%s%(])([A-Za-z0-9-%.]+[A-Za-z0-9-]+%.[A-Za-z0-9]+/[^%)%s]*)([%s%)])", getlink )
		end
		
		-- and then insert them with formatting.
		if subs == 0 then
			msg,subs = msg:gsub( "\001(%d+)\001", function(i)
				return "|cFF0FBEF4|Hlrurl|h" .. links[tonumber(i)] .. "|h|r"
			end)
		end
		
		if subs == 0 then break end
	
	end
	
	return msg:sub( 2, msg:len() - 1 )
end

-------------------------------------------------------------------------------
-- This adds a chat event into the chat history.
--
-- A lot of stuff happens in here . . .
function Main.AddChatHistory( sender, event, message, language, guid, channel )
	
	-- discard empty messages (unless the event doesn't have a message).
	if message == "" and (event ~= "CHANNEL_JOIN" and event ~= "CHANNEL_LEAVE") then return end
	if sender == "" then return end -- don't record stupid world messages.
	
	-- Strip realm if they're on the same realm.
	if sender:sub(1,1) ~= "@" then
		sender = Ambiguate( sender, "all" )
	end
	
	-- Update the guidmap. Right now, this is basically just used to
	-- get a character's class color if we otherwise don't have a color
	-- for them.
	if guid then
		Main.guidmap[sender] = guid
	end
	
	-- Create an entry in the chat history table if we don't have one yet.
	Main.chat_history[sender] = Main.chat_history[sender] or {}
	
	local isplayer = sender == UnitName("player") 
	                 or event == "WHISPER_INFORM" 
					 or sender:match( "^@.+%-self$" )
	
	---------------------------------------------------------------------------
	-- Language Filter
	---------------------------------------------------------------------------
	if Main.LanguageFilter and not isplayer then
		-- language filter option enabled
		message = LanguageFilter( message, sender, event, language )
	end
	
	-- Append language identifier.
	if language and language ~= GetDefaultLanguage() and language ~= "" then
		message = string.format( "[%s] %s", language, message )
	end
	
	---------------------------------------------------------------------------
	-- RPConnect splitter
	---------------------------------------------------------------------------
	if Main.db.profile.rpconnect and event == "PARTY" 
	   or event == "RAID" or event == "RAID_LEADER" or event == "RAID_WARNING" then
	   
		-- strip color codes because they can be inserted by chat filters
		local m2 = message:gsub( "|c[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]", "" )
		
		local name = m2:match( "^<%[(.+)%]: " )
		if name and not UnitName( name ) then
			-- We found the RP Connect pattern for a relayed message.
			-- Crop the message and change the sender.
			m2 = message:match( "%[.+%]: (.*)" )
			if m2 then
				message = m2
				sender  = name
				event   = "RAID"
				Main.chat_history[sender] = Main.chat_history[sender] or {}
			end
		end
	end
	---------------------------------------------------------------------------
	
	if Main.db.profile.convert_links then
		message = Linkify( message )
	end
	
	message = SubRaidTargets( message )
	
	-- We need to do a little work for the GUILD_ITEM_LOOTED and 
	-- GUILD_ACHIEVEMENT events.
	
	if event == "GUILD_ITEM_LOOTED" then
		-- cut off that little $s player marker
		-- hopefully this doesnt break things in other languages.
		message = message:gsub( "$s%s+", "" )
	end
	
	if event == "GUILD_ACHIEVEMENT" then
		-- cut off that little $s player marker
		-- hopefully this doesnt break things in other languages.
		message = message:gsub( "%%s%s+", "" )
	end
	
	-- Our new chat entry.
	local entry = {
		id = Main.next_lineid;
		t  = time();
		e  = event;
		m  = message;
		s  = sender;
		r  = true;              -- unread
	}
	
	if event:find( "CHANNEL" ) then
		if not channel then return end
		local c = channel:match("^%S+")
		if not c then return end
		entry.c = c:upper()
	end
	
	if isplayer then
		entry.p = true -- is player
		entry.r = nil -- read
	end
	
	if event == "YELL" or event == "GUILD_MOTD" then
		entry.r = nil -- yells/motd dont cause unread messages
	end
	
	-- save in the global list
	Main.chatlist[entry.id] = entry
	Main.next_lineid = Main.next_lineid + 1
	
	-- and then in the per-player history
	table.insert( Main.chat_history[sender], entry )
	
	if entry.r then
		Main.unread_entries[entry] = true
	end
	
	-- we don't clear read messages if theyre just whispering.
	if entry.p and event ~= "WHISPER_INFORM" then
		-- player is posting...
		if Main.db.profile.auto_clear_readmark then
			Main.MarkMessagesRead( entry )
		end
	end
	
	-- if the player's target emotes, then beep+flash
	if (Main.db.profile.notify_target_sound or Main.db.profile.notify_target_flash)
	   and not Main.Frame.SKIP_BEEP[entry.e]
	   and Main.frames[2]:EntryFilter( entry ) -- snooper filter
       and Main.FullName("target") == sender
	   and not isplayer then
		
		if Main.db.profile.notify_target_sound then
			Main.SetMessageBeepCD()
			Main.Sound.Play( "messages", 6, Main.db.profile.notify_target_file )
		end
		
		if Main.db.profile.notify_target_flash then
			Main.FlashClient()
		end
	end
	
	-- and then finally, add to the listener windows.
	for _,frame in pairs( Main.frames ) do
		frame:TryAddMessage( entry, true )
	end
end


-------------------------------------------------------------------------------
-- Clean a name so that it starts with a capital letter.
--
function Main.FixupName( name )

	if name:find( "-" ) then
		name = name:gsub( "^.+%-", string.lower )
	else
		name = name:lower()
	end
	
	-- (utf8 friendly) capitalize first character
	name = name:gsub("^[%z\1-\127\194-\244][\128-\191]*", string.upper)
	return name
end

-------------------------------------------------------------------------------
function Main.SetActiveFrame( frame )
	if frame == Main.active_frame then return end
	local old_frame = Main.active_frame
	Main.active_frame = frame
	
	if old_frame then
		old_frame:UpdateVisibility() 
		old_frame:UpdateProbe()
	end
	frame:UpdateVisibility()
	frame:UpdateProbe()
end

Main.SelectFrame = Main.SetActiveFrame

-------------------------------------------------------------------------------
-- Returns a new frame or one of the unused frames.
--
-- @param index Index to create this frame for.
--
local function GetFrameObject( index )
	
	local frame = _G[ "ListenerFrame" .. index ]
	if frame then return frame end
	
	local frame = CreateFrame( "Frame", "ListenerFrame" .. index, UIParent, "ListenerFrameTemplate" )
	return frame
end

-------------------------------------------------------------------------------
local function SetupFrames()
	
	for i,_ in pairs( Main.db.char.frames ) do
		local frame = GetFrameObject( i )
		frame:SetFrameIndex( i )
		Main.frames[i] = frame
	end
	
	-- first time load needs to create the main and snooper frames.
	--
	if not Main.db.char.frames[1] then
		Main.AddWindow()
		Main.frames[1].charopts.name = "MAIN"
	end
	
	if not Main.db.char.frames[2] then
		Main.AddWindow()
		Main.frames[2].charopts.name = "SNOOPER"
	end
	
	Main.SetActiveFrame( Main.frames[1] )
end

-------------------------------------------------------------------------------
-- Create a new Listener window.
--
function Main.AddWindow()
	local index = nil
	for i = 1, MAX_FRAMES do
		if not Main.db.char.frames[i] then
			index = i
			break
		end
	end
	
	if not index then
		Main.Print( "Denied! How did you reach this limit?" )
		return
	end
	
	local frame = GetFrameObject( index )
	frame:SetFrameIndex( index )
	Main.frames[index] = frame
	frame:ApplyOptions()
	frame:RefreshChat()
	Main.Config_NotifyChange()
	return frame
end

-------------------------------------------------------------------------------
-- Delete a Listener window.
--
-- Cannot be the primary window.
--
function Main.DestroyWindow( frame )
	if frame.frame_index <= 2 then return end -- cannot delete the primary frame or snooper
	
	if Main.FrameConfig_GetFrame() == frame then
		Main.FrameConfig_SetFrame( Main.frames[1] )
		Main.Config_NotifyChange()
	end
	
	frame:Hide()
	
	if frame == Main.active_frame then
		Main.SetActiveFrame( Main.frames[1] )
	end
	
	local index = frame.frame_index
	Main.frames[index]         = nil
	Main.db.char.frames[index] = nil
end

-------------------------------------------------------------------------------
StaticPopupDialogs["LISTENER_NEWFRAME"] = {
	text         = L["Enter name of new window."];
	button1      = L["Create"];
	button2      = L["Cancel"];
	hasEditBox   = true;
	hideOnEscape = true;
	whileDead    = true;
	timeout      = 0;
	OnAccept = function( self )
		local name = self.editBox:GetText()
		if name == "" then return end
		local frame = Main.AddWindow()
		if not frame then return end
		frame.charopts.name = name
		frame:UpdateProbe()
	end;
	EditBoxOnEscapePressed = function(self)
		self:GetParent():Hide();
	end;
	EditBoxOnEnterPressed = function(self, data)
		local parent = self:GetParent();
		local name = self:GetText();
		self:SetText("");
		
		if name ~= "" then 
			local frame = Main.AddWindow()
			if not frame then return end
			frame.charopts.name = name
			frame:UpdateProbe()
		end
		
		parent:Hide();
	end;
}

-------------------------------------------------------------------------------
-- User friendly window creation.
--
function Main.UserCreateWindow()
	-- user-friendly create window.
	StaticPopup_Show("LISTENER_NEWFRAME")
end

-------------------------------------------------------------------------------
-- Mark messages read when the player posts something.
--
-- @param e The player chat entry.
--
function Main.MarkMessagesRead( e )
	local time = time()
	for _, frame in pairs( Main.frames ) do
		
		-- skip for snooper.
		if frame.frame_index ~= 2 and frame:EntryFilter( e ) and frame:IsShown() then
			-- this frame is listening to this event, so we clear all
			-- unread messages that this frame is listening to.
			
			for k,v in pairs( Main.unread_entries ) do
				if time >= k.t + NEW_MESSAGE_HOLD and frame:EntryFilter( k ) then
					k.r = nil
					Main.unread_entries[k] = nil
				end
			end
		end
	end
	
	-- and update the frames
	for _, frame in pairs( Main.frames ) do
		frame:CheckUnread()
		frame:UpdateHighlight()
	end
end

-------------------------------------------------------------------------------
-- Mark all new messages as "read".
--
function Main.MarkAllRead()
	if not Main.HasUnreadEntries() then return end 
	
	local time = time()
	for k,v in pairs( Main.unread_entries ) do
		if time < k.t + 3 then
			-- we dont mark messages that arent 3 seconds old
			-- since theyre pretty fresh and probably not read yet!
		else
			k.r = nil
			Main.unread_entries[k] = nil
		end
	end
	
	for k,v in pairs( Main.frames ) do
		v:CheckUnread()
		v:UpdateHighlight()
	end
end

function Main.HighlightEntry( entry, highlight )
	if not highlight then highlight = nil end
	
	local unread = entry.r
	entry.h = highlight
	entry.r = nil
	
	Main.unread_entries[entry] = nil
	
	for k,v in pairs( Main.frames ) do
		if v:ShowsEntry( entry ) then
			if unread then v:CheckUnread() end
			v:UpdateHighlight()
		end
	end
end
-------------------------------------------------------------------------------
-- Reset the player filter.
--[[
function Main:ClearAllPlayers()
	wipe( self.player_list )
	Main.Print( L["Reset filter."] )
	Main:RefreshChat()
	Main:ProbePlayer()
	ListenerFrameBarToggle:RefreshTooltip()
end]]
--[[
-------------------------------------------------------------------------------
function Main:ListPlayers()
	local list = ""
	
	Main.Print( L["::Player filter::"])
	
	local count = 0
	
	for k,v in pairs( Main.player_list ) do
		
		if #list > 300 then
			Main.Print( list, true )
			list = ""
		end
		if v == 1 then
			list = list .. "|cff00ff00" .. k .. " "
		elseif v == 0 then
			list = list .. "|cffff0000" .. k .. " "
		end
		
	end
	Main.Print( list, true )
end
]]

-------------------------------------------------------------------------------
-- Print a chat messages with the Listener prefix.
--
function Main.Print( text, hideprefix )
	text = tostring( text )
	
	local prefix = hideprefix and "" or "|cff9e5aea<Listener>|r "
	print( prefix .. text )
end

-------------------------------------------------------------------------------
-- Callback for event when you join a new group.
--
-- Here we reset the groups filter.
--
function Main:OnGroupJoined()
	Main.UpdateRaidRoster()
	
	for _, frame in pairs( Main.frames ) do
		frame:ResetGroupsFilter()
	end
end

-------------------------------------------------------------------------------
-- Callback for event when the raid roster changes.
--
-- Here we update DM tags, and recache the group numbers for players.
--
function Main:OnRaidRosterUpdate()
	Main.DMTags.roster_dirty = true
	
	if IsInRaid() then
		Main.UpdateRaidRoster()
		for _, frame in pairs( Main.frames ) do
			local hasgroups = false
			for _,_ in pairs( frame.groups ) do
				hasgroups = true
				break
			end
			
			if hasgroups then
				frame:RefreshChat()
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Open up a context menu.
--
-- @param initialize The function that will populate the menu.
--
local g_menu_parent = nil
local g_menu_id     = nil
function Main.ToggleMenu( parent, menu_id, initialize, offset_x, offset_y )
	if not Main.context_menu then
		Main.context_menu = CreateFrame( "Button", "ListenerContextMenu", 
		                                 UIParent, "UIDropDownMenuTemplate" )
		Main.context_menu.displayMode = "MENU"
	end
	
	PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON);
	if UIDROPDOWNMENU_OPEN_MENU == Main.context_menu 
	   and g_menu_parent == parent
	   and g_menu_id == menu_id then
	   
		-- the menu is already open at the same parent, so we close it.
		ToggleDropDownMenu( 1, nil, Main.context_menu )
		return
	end
	
	g_menu_parent = parent
	g_menu_id     = menu_id
	
	UIDropDownMenu_Initialize( Main.context_menu, initialize )
	UIDropDownMenu_JustifyText( Main.context_menu, "LEFT" )
	
	ToggleDropDownMenu( 1, nil, Main.context_menu, parent:GetName(), offset_x or 0, offset_y or 0 )
end

-------------------------------------------------------------------------------
-- Here's a hacky little thing that gets the MOTD.
--
-- From initial testing, trying to read the motd might give you something blank
-- even if the GUILD_MOTD event has already fired (if it even did), so the
-- safe way to get it is to simply poll the function until you get a result.
--
local g_motd_tries = 0
local function TryGetMOTD()
	local motd = GetGuildRosterMOTD()
	if motd and motd ~= "" then
		Main.AddChatHistory( "Guild", "GUILD_MOTD", motd )
		return
	else
		g_motd_tries = g_motd_tries + 1
		if g_motd_tries < 30 then
			if g_motd_tries > 10 then
				-- after 10 seconds, we should be safe to test if we're actually in a guild.
				if not IsInGuild() then return end
			end
			C_Timer.After( 1, TryGetMOTD )
		end
	end
end

-------------------------------------------------------------------------------
-- This fires when your channel list updates, and we use it to just refresh
-- the frames so they have the right channel number.
--
function Main:OnChannelUIUpdate()
	for _, frame in pairs( Main.frames ) do
		frame:RefreshChat()
	end
end

local function FetchRealm()
	Main.realm = select( 2, UnitFullName("player") )
	if not Main.realm then
		-- try again if it failed.
		C_Timer.After( 1, FetchRealm )
	end
end

-------------------------------------------------------------------------------
-- The Ace3 callback when the addon is fully loaded.
--
function Main:OnEnable()
	
	FetchRealm()
	Main.SetupBindingText()

	CleanChatHistory() 
	Main.CreateDB()
	CleanPlayerList()
	
	Main.MinimapButton.Setup()
	Main.MinimapButton.OnLoad()
	
	if Main.next_lineid == 1 then
		-- we don't have anything in our history
		-- so we can discard the old guid map.
		Main.db.realm.guids = {}
	end
	Main.guidmap = Main.db.realm.guids
	SetupFrames()
	
	AddFriendsList()
	g_loadtime = GetTime()
	Main:RegisterEvent( "FRIENDLIST_UPDATE", "OnFriendlistUpdate" )

	Main:RegisterEvent( "CHAT_MSG_SAY",                  "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_EMOTE",                "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_TEXT_EMOTE",           "OnChatMsgTextEmote" )
	Main:RegisterEvent( "CHAT_MSG_WHISPER",              "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_WHISPER_INFORM",       "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_PARTY",                "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_PARTY_LEADER",         "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_RAID",                 "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_RAID_LEADER",          "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_RAID_WARNING",         "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_YELL",                 "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_GUILD",                "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_OFFICER",              "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_CHANNEL",              "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_CHANNEL_JOIN",         "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_CHANNEL_LEAVE",        "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_INSTANCE_CHAT",        "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_INSTANCE_CHAT_LEADER", "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_GUILD_ITEM_LOOTED",    "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_GUILD_ACHIEVEMENT",    "OnChatMsg" )
	Main:RegisterEvent( "CHAT_MSG_COMMUNITIES_CHANNEL",  "OnChatMsgClub" )
	Main:RegisterEvent( "GUILD_MOTD",                    "OnGuildMOTD" )
	Main:RegisterEvent( "CHAT_MSG_SYSTEM",               "OnSystemMsg" )
	Main:RegisterMessage( "DiceMaster4_Roll",            "OnDiceMasterRoll" )
	
	Main:RegisterEvent( "PLAYER_REGEN_DISABLED", "OnEnterCombat" )
	Main:RegisterEvent( "PLAYER_REGEN_ENABLED",  "OnLeaveCombat" )
	
	Main:RegisterEvent( "MODIFIER_STATE_CHANGED", "OnModifierChanged" )
	
	Main:RegisterEvent( "GROUP_JOINED",        "OnGroupJoined" )
	Main:RegisterEvent( "GROUP_ROSTER_UPDATE", "OnRaidRosterUpdate" )
	
	Main:RegisterEvent( "CHANNEL_UI_UPDATE", "OnChannelUIUpdate" )
	
	Main.Print( L["Version:"] .. " " .. Main.version )
	
	Main.Snoop2.Setup()
	Main.DMTags.Setup()
	
	Main:ApplyConfig()
	
	Main.SetupProbe()
	
	C_Timer.After( 1, function() 
		for _, frame in pairs( Main.frames ) do
			frame:RefreshChat()
			frame:UpdateProbe()
		end
	end)
	
	C_Timer.After( 3, function() Main:OnRaidRosterUpdate() end )
	
	Main.InitKeywords()
	
	C_Timer.After( 1, TryGetMOTD )
	
	Main.Help_Init()
	Main.InitConsole()
end
