-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- The DM Tag frame.
-------------------------------------------------------------------------------

local Main = ListenerAddon

Main.DMTag = {}
local Me = Main.DMTag

function Me.OnLoad( self )
	self.SetText = Me.SetText
	self.Attach  = Me.Attach
	self.text:SetJustifyH( "CENTER" )
	self.text:SetJustifyV( "MIDDLE" )
end

function Me.Attach( self, frame )
	self:ClearAllPoints()
	self:SetPoint( "CENTER", frame, "BOTTOMRIGHT", 0, 0 )
end

function Me.SetText( self, text, color )
	self.text:SetText( text )
	self:SetSize( self.text:GetStringWidth() + 4, self.text:GetStringHeight() + 2 )
	self.bg:SetColorTexture( color[1], color[2], color[3], color[4] )
end
