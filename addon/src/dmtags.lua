-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This module controls the DM tags feature.
--
-- The DM Tags feature is an experimental feature designed for dungeon
-- masters to better manage messages. The gist of it is that it adds
-- visible tags to your unit frames, and these tags display the time of
-- each players oldest unmarked emote (if they have any), and it also
-- highlights the oldest time, as to give them priority in a response.
--
-- It's meant to be used in conjuction with the snooper, e.g. you click
-- on the oldest time, review what they posted, make a response, and then
-- mark their emote before moving onto the next person. The tags can be
-- right clicked to mark all of a person's messages easily, when you have
-- acknowledged what they have said.
-------------------------------------------------------------------------------

local Main        = ListenerAddon
Main.DMTags       = {}
local Me          = Main.DMTags
local SharedMedia = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
-- This is a list of unitframes and is created/recreated with HookFrames.
-- 
-- The structure is as follows:
-- [playername] = { -- primarily indexed by player
--    frames = {...} -- list of party or raid frames that point to that player.
-- }
--
Me.unitframes = {}

-------------------------------------------------------------------------------
-- This is a list of DMTag frames, what we use to render the tags.
-- Naturally, we want to reuse them when we can.
--
Me.tags       = {}

-------------------------------------------------------------------------------
-- This is for update throttling. The game time of the last refresh.
--
Me.last_update = 0

-------------------------------------------------------------------------------
-- Any unmarked messages that are older than this time are ignored.
--
local CUTOFF_TIME = 3600 -- 1 hour

-------------------------------------------------------------------------------
-- Initialization function.
--
function Me.Setup()

	-- this is just a frame to hook OnUpdate
	Me.frame = CreateFrame( "Frame" )
	Me.roster_dirty = true
	Me.LoadConfig()
	
	if not Main.db.char.dmtags then
		-- if dmtags are off, we disable updates.
		Me.frame:Hide()
	end
	
	Me.frame:SetScript( "OnUpdate", function()
		Me.Update()
	end)
end

-------------------------------------------------------------------------------
-- Load/reload configuration settings.
--
function Me.LoadConfig()
	Me.Enable( Main.db.char.dmtags )
	Me.LoadFont()
end

-------------------------------------------------------------------------------
-- Update the font object from the settings from the database.
--
function Me.LoadFont()
	local font = SharedMedia:Fetch( "font", Main.db.profile.dmtags.font.face )
	ListenerDMTagFont:SetFont( font, Main.db.profile.dmtags.font.size )
	ListenerDMTagFont:SetShadowColor( 0,0,0,0 )
end

-------------------------------------------------------------------------------
-- Enable/disable DM Tags.
--
function Me.Enable( enabled )
	Main.db.char.dmtags = enabled
	if enabled then
		Me.roster_dirty = true
		Me.last_update = 0
		Me.frame:Show()
	else
		Me.frame:Hide()
		
		-- Hide any tags that are showing.
		Me.StartTagging()
		Me.DoneTagging()
	end
end

-------------------------------------------------------------------------------
-- This function scans any frames on the screen, picking out unit frames that
-- correspond to party or raid, e.g. "party1-5", "raid1-40" and then populates
-- the Me.unitframes list.
--
function Me.HookFrames()
	local frame = nil
	
	local list = {}
	
	while true do
		frame = EnumerateFrames( frame )
		if not frame then break end
		
		if frame:IsVisible() and frame:HasScript( "OnClick" ) 
		   and frame:GetScript( "OnClick" ) == SecureUnitButton_OnClick then
		   
			local unit = frame:GetAttribute( "unit" )
			if unit then
				if unit:match( "raid[0-9]+" ) or unit:match( "party[1-9]" ) then
					local name = Main.FullName( unit )
					
					if name then
						if not list[name] then
							list[name] = {
								frames = {}
							}
						end
						
						table.insert( list[name].frames, frame )
					end
				end
			end
			--thanks Semler!
			
		end
	end
	
	Me.unitframes = list
	-- [name] = { 
	--   frames = { frames ... }
	-- }
end

local function MarkPlayer( player )
	local time = time()
	local chat = Main.chat_history[ player ]
	if chat then
		for i = #chat, 1, -1 do
			local e = chat[i]
			
			-- we filter what it touches according to the snooper
			-- the tags are tied to the snooper's filter.
			if Main.frames[2]:EntryFilter(e) then
				-- only mark messages at least 3 seconds old.
				if e.t >= time - CUTOFF_TIME and e.t < time - 3 then
					e.h = true -- mark as highlighted
					e.r = nil  -- mark as read
					Main.unread_entries[e] = nil
				end
			end
		end
	end
end

-------------------------------------------------------------------------------
-- Callback for when one of the tags are clicked.
--
function Me.OnClick( self, button )
	if not self.player then return end
	
	if button == "RightButton" then
		PlaySound( SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON )
		-- when the user right-clicks one of the tags
		-- it sets highlight on all of the entries of the tag
		
		MarkPlayer( self.player )
		
		-- refresh all frames
		for _,f in pairs( Main.frames ) do
			f:CheckUnread()
			f:UpdateHighlight()
		end
		
		-- and force an update.
		Me.last_update = 0
	end
end

function Me.MarkAll()
	for i = 1, Me.next_tag-1 do
		local p = Me.tags[i].player
		MarkPlayer( p )
	end
	
	-- refresh all frames
	for _,f in pairs( Main.frames ) do
		f:CheckUnread()
		f:UpdateHighlight()
	end
	
	-- and force an update.
	Me.last_update = 0
end

-------------------------------------------------------------------------------
-- Helper functions to easily type in the color values below (aarrggbb).
--
local function ToNumber2( expr )
	return tonumber( expr ) or 0
end
local function Hexc( hex )
	return {ToNumber2("0x"..hex:sub(1,2))/255, ToNumber2("0x"..hex:sub(3,4))/255, ToNumber2("0x"..hex:sub(5,6))/255, ToNumber2("0x"..hex:sub(7,8))/255}
end

-------------------------------------------------------------------------------
-- The colors of the tags:
-- Blue -> Gray -> Darker -> Red | Orange
-- Blue is a new message, younger than 90 seconds.
-- Tags then turn gray until 10 minutes old, where they turn red.
-- Orange is the response priority (the oldest time present).
-------------------------------------------------------------------------------
	
local COLOR_HOT = Hexc "f67502FF" -- Orange
local COLOR_90  = Hexc "1574cdFF" -- Blue
local COLOR_180 = Hexc "999999FF" -- Gray
local COLOR_300 = Hexc "888888FF" -- Darker
local COLOR_450 = Hexc "777777FF" -- Darker
local COLOR_600 = Hexc "666666FF" -- DARKER
local COLOR_OLD = Hexc "e32727FF" -- Red

-------------------------------------------------------------------------------
-- The tagging process works like this:
-- First we call StartTagging, which resets the counter.
-- Then Tag calls are made with the frames to tag as a parameter, and that's
--   what creates tags or reuses existing ones, anchoring them to the frames
--   and essentially setting them up.
-- Then DoneTagging is called, which hides any extra tag frames.
--
function Me.StartTagging()
	Me.next_tag = 1
end

-------------------------------------------------------------------------------
-- Tag a frame.
--
-- @param frame   Frame to tag. The tag will be anchored to this.
-- @param name    The playername that this tag is correpsonding to. Used for
--                clearing messages when it's right clicked.
-- @param time    What time should be displayed, in seconds. Will be converted
--                to a formatted value, e.g. "<1m" for under 60 seconds.
-- @param orange  Color this tag orange. This should be true if this is the
--                oldest tag present.
-- 
function Me.Tag( frame, name, time, orange )
	local tag = Me.tags[Me.next_tag]
	if not tag then
		tag = CreateFrame( "ListenerDMTag", "ListenerDMTag" .. Me.next_tag, UIParent )
		tag:RegisterForClicks( "RightButtonUp" )
		tag:SetScript( "OnClick", Me.OnClick )
		Me.tags[Me.next_tag] = tag
	end
	
	Me.next_tag = Me.next_tag + 1

	local color
	if orange then
		color = COLOR_HOT
	elseif time < 90 then
		color = COLOR_90
	elseif time < 180 then
		color = COLOR_180
	elseif time < 300 then
		color = COLOR_300
	elseif time < 450 then
		color = COLOR_450
	elseif time < 600 then
		color = COLOR_600
	else
		color = COLOR_OLD
	end
	
	local text
	if time < 60 then
		text = "<1m"
	else
		text = tostring(math.floor( time / 60 + 0.5 )) .. "m"
	end
	
	tag:Show()
	tag.player = name
	tag:SetText( text, color )
	tag:Attach( frame )
end

-------------------------------------------------------------------------------
-- Hide any tags that were not used.
--
function Me.DoneTagging()
	for i = Me.next_tag, #Me.tags do
		Me.tags[i]:Hide()
	end
end

-------------------------------------------------------------------------------
-- Periodic update function.
--
function Me.Update()

	if Me.roster_dirty then
		-- rehook frames. we do a little bit of delay to give the roster and
		-- unitframes times to update etc.
		C_Timer.After( 1, function()
			Me.HookFrames()
		end)
		Me.roster_dirty = false
	end

	-- we refresh every one second, or sooner if last_update is reset to 0
	if GetTime() < Me.last_update + 1 then
		return
	end
	
	Me.last_update = GetTime()
	
	Me.StartTagging()
	
	local times = {}
	local time = time()
	
	local oldest_time = time+1
	local oldest_name = nil
	
	for name, _ in pairs( Me.unitframes ) do
		local chat = Main.chat_history[ name ]
		if chat then
			local oldest = time
			
			for i = #chat, 1, -1 do
				local e = chat[i]
				if not e.h and not e.p and Main.frames[2].listen_events[e.e] then
					if e.t < time - CUTOFF_TIME then
						break
					end
					if e.t < oldest then
						oldest = e.t
					end
				end
			end
			times[name] = oldest
			
			if oldest < oldest_time then
				oldest_time = oldest
				oldest_name = name
			end
		end
	end
	
	for name, unitdata in pairs( Me.unitframes ) do
	
		-- and now, for each unit in the unitframes that have
		-- a time attached to them, we set them up accordingly.
		local t = times[name]
		if t then
			t = time - t
			if t > 0 then
				
				for _, f in pairs( unitdata.frames) do
					Me.Tag( f, name, t, name == oldest_name )
				end
			end
		end
	end
	
	Me.DoneTagging()
end
