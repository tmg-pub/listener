-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This little module controls the help tags that appear when you first
-- load Listener.
-------------------------------------------------------------------------------

local Main = ListenerAddon
local L    = Main.Locale

-------------------------------------------------------------------------------
-- Called when the user clicks a help note.
--
function Main.HelpNote_OnClose( self )

	-- mark as "read", so that it won't show on the next load.
	Main.db.global.help[ self.id ] = true
end

-------------------------------------------------------------------------------
-- Setup a new help note.
--
-- @param note The HelpNote frame being set up.
-- @param id   The unique identifier for this help note, which corresponds
--             to whatever data associated to it in the database.
--             e.g. "snooper" for the snooper help note.
-- @param text The text attached to this help note.
--             Ideally a localized string.
--
function Main.HelpNote_Setup( note, id, text ) 
	note.id = id
	note:SetPoint( "CENTER", 0, 50 )
	note.text:SetText( text )
	note:SetHeight( note.text:GetStringHeight() + 22 ) 
	note:Show()
end


-------------------------------------------------------------------------------
-- Add a help element to the system.
--
-- @param frame  Frame to attach the help note to.
-- @param id     ID of this help note.
-- @param onload Function to run if this help is loaded.
--
local function AddHelp( frame, id, onload )

	if Main.db.global.help[id] then return end -- this help was already shown
	
	if frame.helpnote then
		frame.helpnote:Show()
		return
	end
	
	local note = CreateFrame( "ListenerHelpNote", nil, frame ) 
	
	-- see translations for text help_<id>
	note:Setup( id, L["help_" .. id] )
	frame.helpnote = note
	if onload then onload() end
end

-------------------------------------------------------------------------------
-- Called during initialization. The frames that the help notes attach to
-- must be created by now.
--
function Main.Help_Init()
	
	--
	-- see locale for help text, they're stored under help_<id>
	--
	
	AddHelp( ListenerFrame1, "listenerframe2" ) 
	AddHelp( ListenerFrame2, "snooper2", function()
	end)
end

-------------------------------------------------------------------------------
-- Reset which help notes have been acknowledged, and they will be shown on
-- next load.
--
function Main.Help_Reset()
	Main.db.global.help = {}
end

