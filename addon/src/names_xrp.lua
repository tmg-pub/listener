-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is the name resolver for XRP users.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale
 
-------------------------------------------------------------------------------
-- This one is actually really small isn't it? Cool!
--
local function Resolve( name )

	local color = nil
	local ch = xrp.characters.byName[ name ]
	
	if ch and not ch.hide then
		local icname = ch.fields.NA or name
		
		-- get trp color code
		color = icname:match( "^|c(%x%x%x%x%x%x%x%x)" )
		icname = xrp.Strip( icname )
		
		return icname, nil, nil, color
	end
	
	return name
end

-------------------------------------------------------------------------------
-- Our register function.
--
local function Init()
	-- xrp exists if they're using XRP.
	if xrp then
		return Resolve
	end
end

table.insert( Main.name_resolvers, Init )
