-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2018)
--
-- This module handles slash commands.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

function Main.ToggleCommand( arg, command )
	
	arg = arg or Main.GetProbed()
	if not arg then
		Main.Print( L["Specify name or target someone."] )
		return
	end
	
	if command == "add" then
		Main.active_frame:AddPlayer( arg )
	elseif command == "remove" then
		Main.active_frame:RemovePlayer( arg )
	elseif command == "toggle" then
		Main.active_frame:TogglePlayer( arg )
	end
end

-------------------------------------------------------------------------------
function SlashCmdList.LISTENER( msg )
	local args = {}
	
	for i in string.gmatch( msg, "%S+" ) do
		table.insert( args, i )
	end
	
	if args[1] == nil then
		Main.OpenConfig()
		return
	end
	
	if args[1] ~= nil then args[1] = string.lower( args[1] ) end
	
	if args[1] == "read" or args[1] == L["read"] then
	
		Main.MarkAllRead()
		
	elseif args[1] == "add" or args[1] == L["add"] then
	
		Main.ToggleCommand( args[2], "add" )
		
	elseif args[1] == "remove" or args[1] == L["remove"] then
	
		Main.ToggleCommand( args[2], "remove" )
		
	elseif args[1] == "toggle" or args[1] == L["toggle"] then
	
		Main.ToggleCommand( args[2], "toggle" )
	
	elseif args[1] == "show" or args[1] == L["show"] then
	
		Main.frames[1]:Open()

	elseif args[1] == "hide" or args[1] == L["hide"] then
		
		Main.frames[1]:Close()
	
	end  
end

-------------------------------------------------------------------------------
function Main.InitConsole()
	SLASH_LISTENER1 = "/listener"
	SLASH_LISTENER2 = "/lr"
end
