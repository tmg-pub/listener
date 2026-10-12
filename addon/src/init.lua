-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This code creates the Listener addon struct, so it needs to be loaded
-- before anything else that uses it.
-------------------------------------------------------------------------------

-- We grab the version from the TOC file cache. If this is a raw source
-- checkout that never ran through the release packager, the TOC will still
-- have the unsubstituted "@...@" placeholder token, so fall back to
-- something readable instead of printing that literally.
--
local VERSION = C_AddOns.GetAddOnMetadata( "Listener", "Version" )
if not VERSION or VERSION == "" or VERSION:find( "@" ) then
	VERSION = "dev"
end

-------------------------------------------------------------------------------
ListenerAddon = LibStub("AceAddon-3.0"):NewAddon( "Listener", 
	             		  "AceEvent-3.0", "AceTimer-3.0" ) 

local Main = ListenerAddon

-------------------------------------------------------------------------------
Main.version  = VERSION
