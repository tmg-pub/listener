-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is the frame that houses the text on the Listener titlebars.
-------------------------------------------------------------------------------
local Main = ListenerAddon

-------------------------------------------------------------------------------
local methods = {
-------------------------------------------------------------------------------
	SetText = function( self, text )
		self.text:SetText( text )
		if self.auto_size then
			local width = self.text:GetStringWidth() - 1 + (self.auto_size_padding or 4)
			if self.min_width then width = math.max( width, self.min_width ) end
			if self.max_width then width = math.min( width, self.max_width ) end
			self:SetWidth( self.text:GetStringWidth() + (self.auto_size_padding or 4) )
		end
	end;
	SetFont = function( self, font )
		self.text:SetFontObject( font )
	end;
}

-------------------------------------------------------------------------------
function Main.TextButton_Init( self )
	for k,v in pairs( methods ) do
		self[k] = v
	end
	self.text:SetJustifyH( "CENTER" )
	self:SetFont( ListenerBarFont )
end

-------------------------------------------------------------------------------
