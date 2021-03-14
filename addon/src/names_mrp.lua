-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is the name resolver for MyRolePlay users.
-------------------------------------------------------------------------------
if true return end
local Main = ListenerAddon
local L    = Main.Locale

-------------------------------------------------------------------------------
-- Try and get a result from a certain name.
-- 
-- We try with fullname (name-realm) and then normal name.
--
local function TryGet( name )
	if msp.char[name] and msp.char[name].supported 
	   and mrp.DisplayChat.NA( msp.char[name].field.NA ) ~= "" then
		
		local icname = msp.char[name].field.NA
		local color  = icname:match( "^|c(%x%x%x%x%x%x%x%x)" )
		local name   = mrp.DisplayChat.NA( msp.char[name].field.NA )
		
		return name, color
	end
end
 
-------------------------------------------------------------------------------
-- The name resolver function.
--
local function Resolve( name )
	local firstname, color
	
	local fullname = name
	if not name:find( "-" ) then
		fullname = fullname .. "-" .. Main.realm
	end
	
	firstname, color = TryGet( fullname )
	if firstname then
		return firstname, nil, nil, color
	end
	
	if fullname ~= name then
		firstname, color = TryGet( name )
		if firstname then
			return firstname, nil, nil, color
		end
	end
  
	return name
end

-------------------------------------------------------------------------------
-- Register function.
--
local function Init()

	-- check if the person is using MyRolePlay
	if mrp then
		return Resolve
	end
end

table.insert( Main.name_resolvers, Init )
