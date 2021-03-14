-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This code creates the Listener addon struct, so it needs to be loaded
-- before anything else that uses it.
-------------------------------------------------------------------------------

-- We grab the version from the TOC file cache.
--
local VERSION = GetAddOnMetadata( "Listener", "Version" )

-------------------------------------------------------------------------------
ListenerAddon = LibStub("AceAddon-3.0"):NewAddon( "Listener", 
	             		  "AceEvent-3.0", "AceTimer-3.0" ) 

local Main = ListenerAddon

-------------------------------------------------------------------------------
Main.version  = VERSION
