-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is the simple interface for getting IC names from ingame names.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

-------------------------------------------------------------------------------
-- This is where the name resolver submodules register themselves.
-- Ideally there will only be one module that registers unless the user is 
-- doing something wonky like loading multiple RP addons.
--
-- What's registered is a function that checks for the RP addon and then
-- returns a function to resolve names.
--
Main.name_resolvers = {}

-------------------------------------------------------------------------------
-- This is a table (built below) that contains common titles, used for
-- filtering out player titles.
--
-- The MSP doesn't have different slots for title, first name and last name,
-- so this is necessary to cut out titles if someone is using a non TRP
-- addon.
--
Main.titles = {}

do
	local titles = {
		"private", "corporal", "sergeant", "lieutenant",
		"captain", "commander", "major", "admiral",
		"pvt.", "ensign", "officer", "cadet",
		"guard", "pfc", "dame", "knight", "sir",
		"lady", "lord", "mister", "mr", "mr.", 
		"mistress", "mrs.", "mrs", "master", "miss",
		"king", "queen", "baroness", "baron"
	}
	for _,v in pairs( titles ) do
		Main.titles[v] = true
	end
end

-------------------------------------------------------------------------------
-- Okay, during addon load, despite this addon having RP addons as optional
-- dependencies, it seems that they still load after this in some cases.
--
-- Because of that, we look for a name resolver during runtime rather than
-- at load time. Once we find one, it's cached in here.
--
local g_resolver

--------------------------------------------------------------------------------
-- This is a simple cache to speed things up!
--
local g_cache = {}

-------------------------------------------------------------------------------
-- Sets the name resolver directly. Currently not directly used by anything
-- within Listener.
--
function Main.SetNameResolver( func )
	g_resolver = func
end

-------------------------------------------------------------------------------
-- Returns a character's class color from a guid. This might be the only
-- function in Listener that depends on a guid.
--
local function GetCharacterClassColor( guid )
	if not guid then
		return nil -- unknown player guid
	end
	
	local _, cls = GetPlayerInfoByGUID( guid )
	if cls and RAID_CLASS_COLORS[cls] then
		local c = RAID_CLASS_COLORS[cls]
		return ("ff%.2x%.2x%.2x"):format(c.r*255, c.g*255, c.b*255)
	end
end

-------------------------------------------------------------------------------
-- Searches through the name resolver registry for a valid name resolver
-- and then sets g_resolver.
--
local function FindResolver()
	if g_resolver then return g_resolver end
	for k,v in ipairs( Main.name_resolvers ) do
		g_resolver = v()
		if g_resolver then return g_resolver end
	end
	
	return g_resolver
end

-- resolvers return firstname, lastname, icon, color
-- firstname is either the first name or the whole name
-- lastname can be the last name or nothing
--

Main.GetCharacterClassColor = GetCharacterClassColor

function Main.ClearICNameCache()
	g_cache = {}
end

-------------------------------------------------------------------------------
-- Gets a character's IC name for chat formatting.
--
-- @param name     Full name of player, including realm if off server.
-- @param get_full Get full name (first+last) regardless of options.
-- 
-- @returns name (string), icon (texture path), color (aarrggbb hexstring)
--
function Main.GetICName( name, get_full )

	-- the simple cache here is to prevent a lot of load when refreshing chat frames
	-- that's when they add a ton of messages and a lot of them could very well
	-- be spamming this function for the same result over and over.
	--
	if not get_full then
		-- note that get_full isn't cached. That might change in the future if
		-- we actually start doing lots of calls of that.
		local c = g_cache[name]
		if c and GetTime() < c.t + 5 then
			return unpack( c.r )
		end
	end

	if not g_resolver then
		if not FindResolver() then
			local col = GetCharacterClassColor( Main.guidmap[name] )
			
			g_cache[name] = {
				t = GetTime();
				r = {name, nil, col};
			}
			return name, nil, col
		end
	end
	
	local firstname, lastname, icon, color = g_resolver( name )
	
	-- strip title
	local a = firstname:match( "^%s*%S+" ) or firstname
	if Main.titles[a:lower()] then
		-- note that this pattern should not destroy the word if it
		-- is the only word.
		firstname = firstname:gsub( "^%s*%S+%s+", "" )
	end
	
	if Main.db.profile.shorten_names and not get_full then
		local newname = ""
		
		local source = (firstname .. " " .. (lastname or "")):gmatch( "%S+" )
		while newname:len() < 5 do
			local term = source()
			if not term then break end
			newname = newname .. " " .. term
			
		end
		firstname = newname:sub( 2 )
	else
		if lastname and lastname ~= "" then
			firstname = firstname .. " " .. lastname
		end
	end
	
	if color == nil then
		color = GetCharacterClassColor( Main.guidmap[name] )
	end
	
	if not get_full then
		g_cache[name] = {
			t = GetTime();
			r = {firstname, icon, color};
		}
	end
	return firstname, icon, color
end
