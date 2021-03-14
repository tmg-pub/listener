-------------------------------------------------------------------------------
-- LISTENER by Tammya-MoonGuard (2017)
--
-- This is an icon button, such as the eye or the close button.
-------------------------------------------------------------------------------
local Main = ListenerAddon

-------------------------------------------------------------------------------
local methods = {
-------------------------------------------------------------------------------
	SetTexture = function( self, index )
		local left = (index % 4) * 0.25
		local top = math.floor(index / 4) * 0.5
		local texcoords = { left, left+0.25, top, top+0.25 }
		
		self.tex_shadow:SetTexCoord( left, left+0.25, top, top+0.25 )
		self.tex:SetTexCoord( left, left+0.25, top, top+0.25 )
		self.tex_hl:SetTexCoord( left, left+0.25, top+0.25, top+0.5 )
	end;
	
	SetOn = function( self, on )
		self.on = on
		if not on then
			self:SetAlpha( 0.4 )
		else
			self:SetAlpha( 1.0 )
		end
	end;
}

-------------------------------------------------------------------------------
function Main.BarButton_Init( self )
	self.on = true
	for k,v in pairs( methods ) do
		self[k] = v
	end
	self.tex_hl:SetBlendMode( "ADD" )
end

-------------------------------------------------------------------------------
