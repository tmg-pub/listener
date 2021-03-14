-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- The text copying frame.
-------------------------------------------------------------------------------

local Main = ListenerAddon
Main.CopyFrame = {}
local Me = Main.CopyFrame

function Me.Show( text )
	ListenerCopyFrame.text:SetText( text )
	ListenerCopyFrame:Show()
	ListenerCopyFrame.text:SetFocus()
	ListenerCopyFrame.text:HighlightText()
end
