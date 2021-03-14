-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This module controls the keywords feature, which is a chat filter that
-- highlights keywords found in message text, as well as making a notification
-- when it finds them.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale
local SharedMedia = LibStub("LibSharedMedia-3.0")

-------------------------------------------------------------------------------
-- This is a list of patterns that we search the text for.
-- It's built during LoadKeywordsConfig, converting the CSV entries to
-- lua patterns, making replacements and adjusting as necessary.
--
local g_triggers = {}

-------------------------------------------------------------------------------
-- This is another cached configuration value, built from the color value
-- in the database. Formatted as "|crrggbbaa".
--
local g_color    = ""

-------------------------------------------------------------------------------
-- A simple throttle variable to not spam the beep function, since the filter
-- may be used several times for the same thing. This value is the time when
-- another beep is allowed, e.g. lastbeep + 0.15 seconds to disallow it 
-- from repeating on the same frame.
--
local g_beeptime = 0

-------------------------------------------------------------------------------
local function GetHexCode( color )
	return string.format( "ff%2x%2x%2x", color[1]*255, color[2]*255, color[3]*255 )
end

-------------------------------------------------------------------------------
-- This is a list of events that we want to hook for the filter.
-- Actual event is CHAT_MSG_<entry>
--
local CHAT_EVENTS = { 
	"SAY";
	"YELL";
	"EMOTE";
	"GUILD";
	"OFFICER";
	"PARTY";
	"PARTY_LEADER";
	"RAID";
	"RAID_LEADER";
	"CHANNEL";
}

-------------------------------------------------------------------------------
-- Here's our chat filter. 
--
local function ChatFilter( self, event, msg, sender, ... )
	local bnet = select( 13-2, ... )

	-- Skip if not turned on.
	if not Main.db.profile.keywords_enable then return end
	
	local found = false
	
	-- Don't filter player's own text.
	if bnet and bnet > 0 and BNIsSelf( bnet ) then return end
	if Ambiguate( sender, "all" ) == UnitName("player") then return end
	
	local replaced = {}
	
	-- First we hide any links found, since we don't want to corrupt them.
	msg = msg:gsub( "(|cff[0-9a-f]+|H[^|]+|h[^|]+|h|r)", function( link )
		table.insert( replaced, link )
		return "\001\001" .. #replaced .. "\001\001"
	end)
	
	-- We pad with space so that word boundaries at start and end are found.
	msg = " " .. msg .. " "
	
	-- Now iterate through the triggers...
	for trigger, _ in pairs( g_triggers ) do
		
		for maxsubs = 1,10 do
					
			local subs
			msg, subs = msg:gsub( trigger, function( a,b,c )
				-- Any matches that are found are processed with the color code
				-- and then removed from the string, to be added later after
				-- all filtering is done, to prevent keyword collisions.
				--
				table.insert( replaced, g_color .. b .. "|r" )
				return a .. "\001\001" .. #replaced .. "\001\001" .. c
			end)
			
			if subs > 0 then
				found = true
				if GetTime() > g_beeptime then
					-- we have our own cooldown in here because this shit is going to be spammed a lot
					-- on message matches.
					g_beeptime = GetTime() + 0.15
					
					if Main.db.profile.keywords_sound then
						Main.Sound.Play( "messages", 10, Main.db.profile.keywords_soundfile )
						Main.SetMessageBeepCD()
					end
					
					if Main.db.profile.keywords_flash then
						Main.FlashClient()
					end
				end
			else
				break
			end
		
		end
		
	end
	
	if found then
		-- If we found any matching keywords, rebuild the message with the
		-- saved strings.
		msg = msg:gsub( "\001\001(%d+)\001\001", function( index )
			return replaced[tonumber(index)]
		end)
		
		-- msg:sub is to remove the spaces we added as padding.
		return false, msg:sub( 2, msg:len() - 1 ), sender, ...
	end
end

-------------------------------------------------------------------------------
-- Load/reload the keywords configuration.
--
function Main.LoadKeywordsConfig()
	g_color = "|c" .. GetHexCode( Main.db.profile.keywords_color )
	g_triggers = {}
	
	local quotepattern = '(['..("%^$().[]*+-?"):gsub("(.)", "%%%1")..'])'
	
	local oocname   = UnitName('player')
	local icname, short_icname = LibRPNames.Get( oocname )
	local firstname = short_icname:match( "^%s*(%S+)" ) or ""
	local lastname  = icname:match( "(%S+)%s*$" ) or ""
	
	firstname = firstname:gsub( quotepattern, "%%%1" )
	lastname  = lastname:gsub( quotepattern, "%%%1" )
	
	for word in Main.db.profile.keywords_string:gmatch( "[^,]+" ) do
	
		-- trim space, lowercase
		word = word:match( "^%s*(.-)%s*$" ):lower()
		
		
		if word then
			-- and now, format the trigger...
			
			if not word:find( quotepattern ) then
			
				-- if word doesn't have any special characters, then we
				-- make our normal substitutions,
				-- turn it into a case insensitive pattern, and wrap it
				-- in word boundaries
				
				word = word:gsub( "<firstname>", firstname )
				word = word:gsub( "<lastname>", lastname )
				word = word:gsub( "<oocname>", oocname )
				word = word:lower()
				
				word = word:gsub( "%a", function(c)
					return string.format( "[%s%s]", c:lower(), c:upper() )
				end)
				-- convert space to patterned space
				word = word:gsub( "%s+", "%%s+" )
				word = "([%s%p])(" .. word .. ")([%s%p])"
			else
				-- otherwise, they're doing something weird, and let them do it.
				-- meaning, they can use lua patterns. we just add the spaces
				-- pattern to wrap it.
				
				-- escape parenthesis because they can cause errors.
				word = word:gsub( "([%(%)])", "%%%1" )
				
				-- and match spaces on ends
				word = "([%s%p])(" .. word .. ")([%s%p])"
				
			end
			g_triggers[word] = true
		end
	end
end

-------------------------------------------------------------------------------
-- Initialize this module.
--
function Main.InitKeywords()
	Main.LoadKeywordsConfig()
	for i, event in ipairs(CHAT_EVENTS) do
		ChatFrame_AddMessageEventFilter( "CHAT_MSG_" .. event, ChatFilter );
	end
end
