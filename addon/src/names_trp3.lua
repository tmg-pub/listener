-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is the name resolver for Total RP 3.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

-------------------------------------------------------------------------------
-- Helper function to access the TRP profile database.
--
-- Returns a struct of profile data.
--
-- @param name Ingame name. Realm is optional.
--
local function GetTRPCharacterInfo( name )
	if not TRP3_API.register.getCharacterList() then return {} end
	local char, realm = TRP3_API.utils.str.unitIDToInfo( name )
	if not realm then
		realm = Main.realm
	end
	name = TRP3_API.utils.str.unitInfoToID( char, realm )
	
	if name == TRP3_API.globals.player_id then
		return TRP3_API.profile.getData("player");
	elseif TRP3_API.register.isUnitIDKnown( name ) then
		return TRP3_API.register.getUnitIDCurrentProfile( name ) or {};
	end
	return {};
end

-------------------------------------------------------------------------------
-- The name resolver.
--
local function Resolve( name )
	local firstname, lastname, title, icon, color = name, "", "", nil, nil
	
	if UnitFactionGroup( "player" ) == "Alliance" then
		icon = "Inv_Misc_Tournaments_banner_Human"
	else
		icon = "Inv_Misc_Tournaments_banner_Orc"
	end
			
	local info = GetTRPCharacterInfo( name )
	local ci = info.characteristics
	
	if ci then
		firstname = ci.FN or name
		lastname = ci.LN or ""
		title = "" -- todo?  
		
		if ci.CH then 
			color = "ff" .. ci.CH
		end
		
		if ci.IC and ci.IC ~= "" then
			icon = ci.IC 
		end
		
	end
	
	return firstname, lastname, icon, color
end

-------------------------------------------------------------------------------
-- Register function.
--
local function Init()
	
	-- if this exists, they're using TRP3.
	if TRP3_API then
		return Resolve
	end
end

table.insert( Main.name_resolvers, Init )
