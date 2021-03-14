-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
-------------------------------------------------------------------------------

local Listener = ListenerAddon
Listener.Locale = {}
local L = Listener.Locale

-------------------------------------------------------------------------------
setmetatable( L, { 

	-- Normally, the key is the translation in english. 
	-- If a value isn't found, just return the key.
	__index = function( table, key ) 
		return key 
	end;
	
	-- When treating the L table like a function, it can accept arguments
	-- that will replace {1}, {2}, etc in the text.
	__call = function( table, key, ... )
		key = table[key] -- first we get the translation
		
		local args = {...}
		for i = 1, #args do
			local text = select( i, ... )
			key = key:gsub( "{" .. i .. "}", args[i] )
		end
		return key
	end;
})

-- remove excess whitespace and newlines, and convert "\n" to newline
local function tidystring( str )

	return (str:gsub( "%s+", " " ):match("^%s*(.-)%s*$"):gsub("\\n","\n"))
end

--warning: there are a lot of strings not declared in here.


-------------------------------------------------------------------------------
--L["Version:"] =                          -- Version string for help

--L["read"]     =                          -- Chat command
--L["add"]      =                          -- Chat command
--L["remove"]   =                          -- Chat command
--L["clear"]    =                          -- Chat command
--L["list"]     =                          -- Chat command
--L["Specify name or target someone."] =   -- Error message

--L["Player list: "]        =              -- When listing players.
--L["Cleared all players."] =              -- When resetting player list.
--L["Removed: "]            =              -- When removing a player.
--L["Not listening: "]      =              -- When trying to remove a player.
--L["Added: "]              =              -- When adding a player.
--L["Already listening: "]  =              -- When trying to add a player.

-------------------------------------------------------------------------------
L.help_listenerframe2 = tidystring [[
	This is a Listener window. They're like an advanced chatbox. You can filter
	out players by holding shift and right-clicking them. Right click the upper
	left corner to open a menu for settings and such. If you close this window,
	you can open it again by clicking the minimap button. You may also right-click 
	the minimap	button to access the main configuration. See the Curse.com page for
	more instructions.
]]

-------------------------------------------------------------------------------
L.help_snooper2 = tidystring [[
	This is the "Snooper" display. When you mouseover or target someone, their
	recent chat history will show up in here. It's for helping keep track of
	what a player is saying. You can adjust the settings by clicking the top
	left corner, or clicking the minimap button and going to Snooper.
]]
